#!/bin/bash

echo "Installing pssh..."
sudo apt-get update
sudo apt-get install -y pssh haveged

echo "Setting up SSH directories..."
parallel-ssh -i -h all-nodes.txt -A -O StrictHostKeyChecking=no 'mkdir ~/.ssh'

echo "Generating SSH key..."
mkdir ~/.ssh
ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ""

echo "Installing public key..."
parallel-scp -h worker-nodes.txt -A -O StrictHostKeyChecking=no ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

echo "Installing Kubernetes dependencies..."
parallel-ssh -i -h all-nodes.txt -O StrictHostKeyChecking=no -t 600 'sudo apt-get update &&
sudo apt-get upgrade &&
sudo apt-get install -y ntp haveged ebtables socat'

echo "Installing Kubernetes package sources..."
parallel-ssh -i -h all-nodes.txt -O StrictHostKeyChecking=no -t 600 'curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - &&
sudo echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list &&
sudo apt-get update'

echo "Installing Kubernetes..."
parallel-ssh -i -h all-nodes.txt -O StrictHostKeyChecking=no -t 600 'cd /tmp &&
wget https://raw.githubusercontent.com/ngpitt/apprenda-rpi-k8-cluster/master/kubeadm_1.7.0-alpha.4-00_armhf.deb &&
wget https://raw.githubusercontent.com/ngpitt/apprenda-rpi-k8-cluster/master/kubectl_1.7.0-alpha.4-00_armhf.deb &&
wget https://raw.githubusercontent.com/ngpitt/apprenda-rpi-k8-cluster/master/kubelet_1.7.0-alpha.4-00_armhf.deb &&
wget https://raw.githubusercontent.com/ngpitt/apprenda-rpi-k8-cluster/master/kubernetes-cni_0.5.1-00_armhf.deb &&
sudo dpkg -i kubeadm_1.7.0-alpha.4-00_armhf.deb kubectl_1.7.0-alpha.4-00_armhf.deb kubelet_1.7.0-alpha.4-00_armhf.deb kubernetes-cni_0.5.1-00_armhf.deb'

#sudo apt-get install -y kubeadm kubectl kubelet kubernetes-cni

echo "Setting up Kubernetes..."
sudo cp basic_auth.csv /etc/kubernetes/
sudo cp abac_policy.json /etc/kubernetes/
sudo kubeadm init --config config.yaml
sudo cp /etc/kubernetes/admin.conf $HOME/.kubeconfig
sudo chown $(id -u):$(id -g) $HOME/.kubeconfig
export KUBECONFIG=$HOME/.kubeconfig
echo "export KUBECONFIG=\$HOME/.kubeconfig" >> ~/.bashrc
kubectl apply -f weave-kube-1.6.yaml

echo "Waiting for Kubernetes DNS..."
DNS=$(kubectl get deployment -n kube-system kube-dns | tail -n 1 | awk '{print $2}')
while [ $(kubectl get deployment -n kube-system kube-dns | tail -n 1 | awk '{print $5}') -ne $DNS ]
do
    sleep 5
done

echo "Joining nodes to the cluster..."
TOKEN="$(sudo kubeadm token list | tail -n 1 | awk '{print $1}')"
URL="$(kubectl cluster-info | head -n 1 | awk '{print $6}')"
parallel-ssh -i -h worker-nodes.txt -O StrictHostKeyChecking=no -t 600 "sudo kubeadm join --token $TOKEN $URL"

echo "Setting up Blinkt..."
kubectl apply -f blinkt-k8s-controller-rbac.yaml
kubectl apply -f blinkt-k8s-controller-ds.yaml

echo "Waiting for Blinkt..."
BLINKT=$(kubectl get daemonset -n kube-system blinkt-k8s-controller | tail -n 1 | awk '{print $2}')
while [ $(kubectl get daemonset -n kube-system blinkt-k8s-controller | tail -n 1 | awk '{print $6}') -ne $BLINKT ]
do
    sleep 5
done

echo "Setting up Traefik.."
kubectl apply -f traefik-rbac.yaml
kubectl apply -f traefik.yaml

echo "Run 'kubectl label <node> nginx-controller=traefik' to create a load balancer node"
echo "Setup complete."
