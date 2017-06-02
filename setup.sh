#!/bin/bash

sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
sudo echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install -y kubeadm ntp haveged
sudo dpkg-reconfigure tzdata
sudo cp basic_auth.csv /etc/kubernetes/
sudo cp abac_policy.json /etc/kubernetes/
sudo kubeadm init --config config.yaml
sudo kubectl apply -f weave-kube.yaml
sudo kubectl apply -f blinkt-k8s-controller-ds.yaml
