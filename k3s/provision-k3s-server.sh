#!/bin/bash

# configure the motd..Tis was generated at
# http://patorjk.com/software/taag/#p=display&f=Big&t=k3s%0Aserver.
cat >/etc/motd <<'EOF'
  _    ____
 | |  |___ \
 | | __ __) |___
 | |/ /|__ </ __|
 |   < ___) \__ \
 |_|\_\____/|___/   _____ _ __
 / __|/ _ \ '__\ \ / / _ \ '__|
 \__ \  __/ |   \ V /  __/ |
 |___/\___|_|    \_/ \___|_|

EOF

# see https://docs.k3s.io/installation/configuration
# see https://docs.k3s.io/reference/server-config
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -

# check whether this system has the k3s requirements.
k3s check-config

# wait for this node to be Ready.
$SHELL -c 'node_name=$(hostname); echo "waiting for node $node_name to be ready..."; while [ -z "$(kubectl get nodes $node_name | grep -E "$node_name\s+Ready\s+")" ]; do sleep 4; done; echo "node ready!"'
# sudo chmod 777 /etc/rancher/k3s/k3s.yaml

# install the bash completion scripts.
sudo sh -c 'kubectl completion bash >/usr/share/bash-completion/completions/kubectl'

# symlink the default kubeconfig path so local tools like k9s can easily
# find it without exporting the KUBECONFIG environment variable.
ln -s /etc/rancher/k3s/k3s.yaml ~/.kube/config

# setup vagrant user .kube/config
mkdir /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chmod 600 /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# show cluster-info.
kubectl cluster-info

# list nodes.
#kubectl get nodes -o wide
kubectl get nodes

# rbac info.
#kubectl get serviceaccount --all-namespaces
#kubectl get role --all-namespaces
#kubectl get rolebinding --all-namespaces
#kubectl get rolebinding --all-namespaces -o json | jq .items[].subjects
#kubectl get clusterrole --all-namespaces
#kubectl get clusterrolebinding --all-namespaces
#kubectl get clusterrolebinding --all-namespaces -o json | jq .items[].subjects

# list system secrets.
#kubectl -n kube-system get secret

# list all objects.
#kubectl get all --all-namespaces

# list services.
kubectl get svc

# list running pods.
#kubectl get pods --all-namespaces -o wide
kubectl get pods --all-namespaces

# show listening ports.
#ss -n --tcp --listening --processes

# show network routes.
#ip route

# show memory info.
#free
