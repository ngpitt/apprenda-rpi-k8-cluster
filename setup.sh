#!/bin/bash

echo "
Setting up Kubernetes..."
sudo kubeadm reset
sudo cp basic_auth.csv /etc/kubernetes/
sudo cp abac_policy.json /etc/kubernetes/
sudo kubeadm init --config config.yaml
sudo cp /etc/kubernetes/admin.conf $HOME/.kubeconfig
sudo chown $(id -u):$(id -g) $HOME/.kubeconfig
kubectl apply -f kube-flannel-rbac.yaml
kubectl apply -f kube-flannel.yaml

echo "
Waiting for Kubernetes DNS..."
DNS=$(kubectl get deployment -n kube-system kube-dns | tail -n 1 | awk '{print $2}')
while [ $(kubectl get deployment -n kube-system kube-dns | tail -n 1 | awk '{print $5}') -ne $DNS ]
do
    sleep 5
done

echo "
Joining workers to the cluster..."
TOKEN=$(sudo kubeadm token list | tail -n 1 | awk '{print $1}')
URL=$(kubectl cluster-info | head -n 1 | awk '{print $6}' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | cut -d "/" -f 3)
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
Setting up nginx ingress..."
kubectl apply -f nginx-ingress.yaml

echo "
Run \"kubectl label node <node> nginx-controller=traefik\" to create a load balancer node
Install /etc/kubernetes/pki/ca.crt on all Apprenda management nodes
"
