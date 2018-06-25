#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install git python-virtualenv python-dev libyaml-dev dnsmasq screen mercurial

pushd /opt/djeep
./fetch_images.sh
tee ~/.hgrc <<EOF
[trusted]
users = vagrant
groups = vagrant
EOF
python tools/install_venv.py
tools/with_venv.sh ./reset.sh
ln -s /etc/dnsmasq.conf /opt/djeep/local/etc/dnsmasq.conf
touch /etc/ethers
ln -s /etc/ethers /opt/djeep/local/etc/ethers
service dnsmasq restart
sed  -i 's/^exit 0//' /etc/rc.local 
echo "cd /opt/djeep" >> /etc/rc.local
echo 'screen -d -m tools/with_venv.sh python manage.py runeventlet 0.0.0.0:8000' >> /etc/rc.local
screen -d -m tools/with_venv.sh python manage.py runeventlet 0.0.0.0:8000
popd
