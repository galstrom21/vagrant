#!/usr/bin/env bash

set -xe

sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y git python3 python3-pip python3-venv python3-dev redis-server

sudo DEBIAN_FRONTEND=noninteractive apt install -y libmysqlclient-dev mysql-server pkg-config

# Create Nautobot Database
echo "INSTALL | Create nautobot database"
DB_PASSWD="secrete"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS nautobot;"
echo "INSTALL | Create nautobot user"
sudo mysql -e "CREATE USER IF NOT EXISTS'nautobot'@'localhost' IDENTIFIED BY '${DB_PASSWD}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON nautobot.* to 'nautobot'@'localhost';"

# Verify Redis is running
echo "INSTALL | Verify redis is available"
redis-cli ping

# Create the Nautobot System User
if ! id nautobot &>/dev/null; then
  sudo useradd --system --shell /bin/bash --create-home --home-dir /opt/nautobot nautobot
fi

# Create the Python Virtual Environment
sudo -iu nautobot python3 -m venv /opt/nautobot

# Update nautobot .bashrc
echo "export NAUTOBOT_ROOT=/opt/nautobot" | sudo tee -a ~nautobot/.bashrc

# This does not work as python was installed via apt-get
sudo -iu nautobot pip3 install --upgrade pip wheel

# Install Nautobot
sudo -iu nautobot pip3 install --no-binary=pyuwsgi "nautobot[mysql]"

sudo -iu nautobot nautobot-server --config-path nautobot_config.py --version
if sudo -iu nautobot test -f "/opt/nautobot/nautobot_config.py"; then
  echo "Nautobot config exists: SKIPPING INIT"
else
  echo "NAUTOBOT | Init"
  sudo -iu nautobot NAUTOBOT_ROOT=/opt/nautobot nautobot-server init --disable-installation-metrics

  sudo -iu nautobot tee -a /opt/nautobot/nautobot_config.py >/dev/null <<END
ALLOWED_HOSTS = ['0.0.0.0']

DATABASES = {
    "default": {
        "NAME": os.getenv("NAUTOBOT_DB_NAME", "nautobot"),  # Database name
        "USER": os.getenv("NAUTOBOT_DB_USER", "nautobot"),  # Database username
        "PASSWORD": os.getenv("NAUTOBOT_DB_PASSWORD", "secrete"),  # Database password
        "HOST": os.getenv("NAUTOBOT_DB_HOST", "localhost"),  # Database server
        "PORT": os.getenv("NAUTOBOT_DB_PORT", ""),  # Database port (leave blank for default)
        "CONN_MAX_AGE": int(os.getenv("NAUTOBOT_DB_TIMEOUT", "300")),  # Database timeout
        "ENGINE": os.getenv(
            "NAUTOBOT_DB_ENGINE",
            "django_prometheus.db.backends.mysql" if METRICS_ENABLED else "django.db.backends.mysql",
        ),  # Database driver ("mysql" or "postgresql")
    }
}
END
fi

sudo -iu nautobot nautobot-server migrate --config-path nautobot_config.py

sudo -iu nautobot NAUTOBOT_ROOT=/opt/nautobot nautobot-server shell <<EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'password!234')
EOF

sudo -iu nautobot NAUTOBOT_ROOT=/opt/nautobot nautobot-server collectstatic --no-input

sudo -iu nautobot NAUTOBOT_ROOT=/opt/nautobot nautobot-server check

sudo -iu nautobot tee /opt/nautobot/uwsgi.ini &>/dev/null <<EOF
[uwsgi]
; The IP address (typically localhost) and port that the WSGI process should listen on
socket = 127.0.0.1:8001

; Fail to start if any parameter in the configuration file isn’t explicitly understood by uWSGI
strict = true

; Enable master process to gracefully re-spawn and pre-fork workers
master = true

; Allow Python app-generated threads to run
enable-threads = true

;Try to remove all of the generated file/sockets during shutdown
vacuum = true

; Do not use multiple interpreters, allowing only Nautobot to run
single-interpreter = true

; Shutdown when receiving SIGTERM (default is respawn)
die-on-term = true

; Prevents uWSGI from starting if it is unable load Nautobot (usually due to errors)
need-app = true

; By default, uWSGI has rather verbose logging that can be noisy
disable-logging = true

; Assert that critical 4xx and 5xx errors are still logged
log-4xx = true
log-5xx = true

; Enable HTTP 1.1 keepalive support
http-keepalive = 1

;
; Advanced settings (disabled by default)
; Customize these for your environment if and only if you need them.
; Ref: https://uwsgi-docs.readthedocs.io/en/latest/Options.html
;

; Number of uWSGI workers to spawn. This should typically be 2n+1, where n is the number of CPU cores present.
; processes = 5

; If using subdirectory hosting e.g. example.com/nautobot, you must uncomment this line. Otherwise you'll get double paths e.g. example.com/nautobot/nautobot/.
; Ref: https://uwsgi-docs.readthedocs.io/en/latest/Changelog-2.0.11.html#fixpathinfo-routing-action
; route-run = fixpathinfo:

; If hosted behind a load balancer uncomment these lines, the harakiri timeout should be greater than your load balancer timeout.
; Ref: https://uwsgi-docs.readthedocs.io/en/latest/HTTP.html?highlight=keepalive#http-keep-alive
; harakiri = 65
; add-header = Connection: Keep-Alive
; http-keepalive = 1
EOF

sudo tee /etc/systemd/system/nautobot.service &>/dev/null <<EOF
[Unit]
Description=Nautobot WSGI Service
Documentation=https://docs.nautobot.com/projects/core/en/stable/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment="NAUTOBOT_ROOT=/opt/nautobot"

User=nautobot
Group=nautobot
PIDFile=/var/tmp/nautobot.pid
WorkingDirectory=/opt/nautobot

ExecStart=/opt/nautobot/bin/nautobot-server start --pidfile /var/tmp/nautobot.pid --ini /opt/nautobot/uwsgi.ini
ExecStop=/opt/nautobot/bin/nautobot-server start --stop /var/tmp/nautobot.pid
ExecReload=/opt/nautobot/bin/nautobot-server start --reload /var/tmp/nautobot.pid

Restart=on-failure
RestartSec=30
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/nautobot-worker.service &>/dev/null <<EOF
[Unit]
Description=Nautobot Celery Worker
Documentation=https://docs.nautobot.com/projects/core/en/stable/
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
Environment="NAUTOBOT_ROOT=/opt/nautobot"

User=nautobot
Group=nautobot
PIDFile=/var/tmp/nautobot-worker.pid
WorkingDirectory=/opt/nautobot

ExecStart=/opt/nautobot/bin/nautobot-server celery worker --loglevel INFO --pidfile /var/tmp/nautobot-worker.pid

Restart=always
RestartSec=30
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/nautobot-scheduler.service &>/dev/null <<EOF
[Unit]
Description=Nautobot Celery Beat Scheduler
Documentation=https://docs.nautobot.com/projects/core/en/stable/
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
Environment="NAUTOBOT_ROOT=/opt/nautobot"

User=nautobot
Group=nautobot
PIDFile=/var/tmp/nautobot-scheduler.pid
WorkingDirectory=/opt/nautobot

ExecStart=/opt/nautobot/bin/nautobot-server celery beat --loglevel INFO --pidfile /var/tmp/nautobot-scheduler.pid

Restart=always
RestartSec=30
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now nautobot nautobot-worker nautobot-scheduler
sudo systemctl status nautobot.service

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nautobot.key \
  -out /etc/ssl/certs/nautobot.crt \
  -subj "/C=US/ST=Texas/L=Sprint/O=HPE/OU=HCOCTO/CN=example.com"

# Install and configure nginx
echo "INSTALL | nginx"
sudo DEBIAN_FRONTEND=noninteractive apt install -y nginx
sudo tee /etc/nginx/sites-available/nautobot.conf &>/dev/null <<EOF
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;

    server_name _;

    ssl_certificate /etc/ssl/certs/nautobot.crt;
    ssl_certificate_key /etc/ssl/private/nautobot.key;

    client_max_body_size 25m;

    location /static/ {
        alias /opt/nautobot/static/;
    }

    # For subdirectory hosting, you'll want to toggle this (e.g. $(/nautobot/)).
    # Don't forget to set $(FORCE_SCRIPT_NAME) in your $(nautobot_config.py) to match.
    # location /nautobot/ {
    location / {
        include uwsgi_params;
        uwsgi_pass  127.0.0.1:8001;
        uwsgi_param Host \$host;
        uwsgi_param X-Real-IP \$remote_addr;
        uwsgi_param X-Forwarded-For \$proxy_add_x_forwarded_for;
        uwsgi_param X-Forwarded-Proto \$http_x_forwarded_proto;

        # If you want subdirectory hosting, uncomment this. The path must match
        # the path of this location block (e.g. $(/nautobot)). For NGINX the path
        # MUST NOT end with a trailing "/".
        # uwsgi_param SCRIPT_NAME /nautobot;
    }

}

server {
    # Redirect HTTP traffic to HTTPS
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/nautobot.conf /etc/nginx/sites-enabled/nautobot.conf
sudo usermod -aG nautobot www-data
sudo chmod 750 /opt/nautobot
sudo systemctl restart nginx
