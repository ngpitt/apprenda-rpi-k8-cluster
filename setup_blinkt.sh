#!/bin/bash

kubectl apply -f blinkt-k8s-controller-rbac.yaml
kubectl apply -f blinkt-k8s-controller-ds.yaml
