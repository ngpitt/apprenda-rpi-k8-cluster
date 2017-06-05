#!/bin/bash

sudo cp basic_auth.csv /etc/kubernetes/
sudo cp abac_policy.json /etc/kubernetes/
sudo kubeadm init --config config.yaml
sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
export KUBECONFIG=$HOME/admin.conf
echo "export KUBECONFIG=\$HOME/admin.conf" >> ~/.bashrc
kubectl apply -f weave-kube-1.6.yaml
