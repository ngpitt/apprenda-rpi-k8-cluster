#!/bin/bash

echo "
Installing pssh..."
sudo apt-get update
sudo apt-get install -y pssh haveged

echo "
Generating SSH key..."
mkdir -p ~/.ssh
ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ""

echo "
Installing public key..."
parallel-ssh -i -h all-nodes.txt -A -O StrictHostKeyChecking=no "mkdir -p ~/.ssh
echo \"$(cat ~/.ssh/id_rsa.pub)\" > ~/.ssh/authorized_keys"

echo "
Installing Kubernetes dependencies..."
parallel-ssh -i -h all-nodes.txt -O StrictHostKeyChecking=no -t 600 "sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y ntp haveged ebtables socat"

echo "
Installing Kubernetes package sources..."
parallel-ssh -i -h all-nodes.txt -O StrictHostKeyChecking=no -t 600 "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo bash -c \"echo \\\"deb http://apt.kubernetes.io/ kubernetes-xenial main\\\" > /etc/apt/sources.list.d/kubernetes.list\"
sudo apt-get update"
#sudo apt-get install -y kubeadm kubectl kubelet kubernetes-cni

echo "
Downloading Kubernetes..."
wget -O /tmp/kubeadm.deb https://github.com/ngpitt/apprenda-rpi-k8-cluster/raw/master/kubeadm_1.7.0-alpha.4-00_armhf.deb
wget -O /tmp/kubectl.deb https://github.com/ngpitt/apprenda-rpi-k8-cluster/raw/master/kubectl_1.7.0-alpha.4-00_armhf.deb
wget -O /tmp/kubelet.deb https://github.com/ngpitt/apprenda-rpi-k8-cluster/raw/master/kubelet_1.7.0-alpha.4-00_armhf.deb
wget -O /tmp/kubernetes-cni.deb https://github.com/ngpitt/apprenda-rpi-k8-cluster/raw/master/kubernetes-cni_0.5.1-00_armhf.deb
parallel-scp -h worker-nodes.txt -O StrictHostKeyChecking=no /tmp/kube*.deb /tmp

echo "
Installing Kubernetes..."
parallel-ssh -i -h all-nodes.txt -O StrictHostKeyChecking=no -t 600 "cd /tmp
sudo dpkg -i kubeadm.deb kubectl.deb kubelet.deb kubernetes-cni.deb"

echo "
Setting up Kubernetes..."
sudo kubeadm reset
sudo cp basic_auth.csv /etc/kubernetes/
sudo cp abac_policy.json /etc/kubernetes/
sudo kubeadm init --config config.yaml
sudo cp /etc/kubernetes/admin.conf $HOME/.kubeconfig
sudo chown $(id -u):$(id -g) $HOME/.kubeconfig
echo "export KUBECONFIG=\$HOME/.kubeconfig" >> ~/.bashrc
. ~/.bashrc
kubectl apply -f weave-kube-1.6.yaml

echo "
Waiting for Kubernetes DNS..."
DNS=$(kubectl get deployment -n kube-system kube-dns | tail -n 1 | awk '{print $2}')
while [ $(kubectl get deployment -n kube-system kube-dns | tail -n 1 | awk '{print $5}') -ne $DNS ]
do
    sleep 5
done

echo "
Joining nodes to the cluster..."
TOKEN=$(sudo kubeadm token list | tail -n 1 | awk '{print $1}')
URL=$(kubectl cluster-info | head -n 1 | awk '{print $6}' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")
parallel-ssh -i -h worker-nodes.txt -O StrictHostKeyChecking=no -t 600 "sudo kubeadm reset
sudo kubeadm join --token $TOKEN $URL"

echo "
Setting up Blinkt..."
kubectl apply -f blinkt-k8s-controller-rbac.yaml
kubectl apply -f blinkt-k8s-controller-ds.yaml

echo "
Waiting for Blinkt..."
BLINKT=$(kubectl get daemonset -n kube-system blinkt-k8s-controller | tail -n 1 | awk '{print $2}')
while [ $(kubectl get daemonset -n kube-system blinkt-k8s-controller | tail -n 1 | awk '{print $6}') -ne $BLINKT ]
do
    sleep 5
done

echo "
Setting up Traefik..."
kubectl apply -f traefik-rbac.yaml
kubectl apply -f traefik.yaml

echo "
Run \"kubectl label <node> nginx-controller=traefik\" to create a load balancer node
Install /etc/kubernetes/pki/ca.crt on all Apprenda management nodes
"
