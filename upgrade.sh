#!/bin/bash

set -e

TARGET_MAJOR_MINOR_VERSION=1.19
MASTER_NODE=nuc1
WORKER_NODES=( nuc2 nuc3 nuc4 )

CURRENT_VERSION=$(ssh $MASTER_NODE "kubeadm version -o short | cut -d'v' -f2")
TARGET_VERSION=$(ssh $MASTER_NODE "sudo apt-cache madison kubeadm | grep '${TARGET_MAJOR_MINOR_VERSION}' | sort -r | head -1 | cut -d'|' -f2 | tr -d ' '")

echo "CURRENT_VERSION: $CURRENT_VERSION"
echo " TARGET_VERSION: $TARGET_VERSION"
echo ""

while true; do
    read -p "Do you wish to continue with the upgrade (y/n)? " yn
    case $yn in
        [Yy]* ) echo "Continuing with upgrade..."; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "Upgrading control plane node (${MASTER_NODE})"


MASTER_KUBEADM_CURR_VERSION=$(ssh $MASTER_NODE "kubeadm version -o short | cut -d'v' -f2")
while true; do
    read -p "Do you wish to upgrade kubeadm from ${MASTER_KUBEADM_CURR_VERSION} to ${TARGET_VERSION} on ${MASTER_NODE} (y/n/skip)? " yn
    case $yn in
        [Yy]* ) ssh $MASTER_NODE "sudo apt-mark unhold kubeadm \
            && sudo apt update && sudo apt install -y kubeadm=${TARGET_VERSION} \
            && sudo apt-mark hold kubeadm"; break;;
        [Nn]* ) exit;;
        [Ss]* ) echo "Skipping"; break;;
        * ) echo "Please answer (y)es, (n)o or (s)kip.";;
    esac
done

echo "Draining ${MASTER_NODE}..."
kubectl drain ${MASTER_NODE} --ignore-daemonsets

ssh ${MASTER_NODE} "sudo kubeadm upgrade plan"

KUBEADM_UPGRADE_COMMAND_VERSION=$(ssh $MASTER_NODE "kubeadm version -o short")
KUBEADM_UPGRADE_COMMAND="sudo kubeadm upgrade apply ${KUBEADM_UPGRADE_COMMAND_VERSION}"
while true; do
    read -p "Do you wish to execute '${KUBEADM_UPGRADE_COMMAND}' on ${MASTER_NODE} (y/n/skip)? " yn
    case $yn in
        [Yy]* ) ssh $MASTER_NODE "${KUBEADM_UPGRADE_COMMAND}"; break;;
        [Nn]* ) exit;;
        [Ss]* ) echo "Skipping"; break;;
        * ) echo "Please answer (y)es, (n)o or (s)kip.";;
    esac
done

KUBELET_UPGRADE_COMMAND_VERSION=$(ssh $MASTER_NODE "kubeadm version -o short")
KUBELET_UPGRADE_COMMAND="sudo apt update && sudo apt install -y --allow-change-held-packages kubelet=${TARGET_VERSION} kubectl=${TARGET_VERSION}"
KUBELET_RESTART_COMMAND="sudo systemctl daemon-reload && sudo systemctl restart kubelet"
while true; do
    read -p "Do you wish to execute '${KUBELET_UPGRADE_COMMAND}' and '${KUBELET_RESTART_COMMAND}' on ${MASTER_NODE} (y/n/skip)? " yn
    case $yn in
        [Yy]* ) ssh $MASTER_NODE "${KUBELET_UPGRADE_COMMAND}"; ssh $MASTER_NODE "${KUBELET_RESTART_COMMAND}"; break;;
        [Nn]* ) exit;;
        [Ss]* ) echo "Skipping"; break;;
        * ) echo "Please answer (y)es, (n)o or (s)kip.";;
    esac
done

KUBEADM_UPGRADE_COMMAND="sudo apt update && sudo apt install -y --allow-change-held-packages kubeadm=${TARGET_VERSION}"
for node in "${WORKER_NODES[@]}"; do 
    echo "Upgrading kubeadm on worker node: ${node}..."
    ssh ${node} "${KUBEADM_UPGRADE_COMMAND}"

    echo "Draining worker node: ${node}..."
    kubectl drain ${node} --ignore-daemonsets --delete-local-data

    echo "Upgrading worker node: ${node}..."
    ssh ${node} "sudo kubeadm upgrade node"

    echo "Upgrading kubelet and kubectl on worker node: ${node}..."
    ssh ${node} "sudo apt update && sudo apt install -y --allow-change-held-packages kubelet=${TARGET_VERSION} kubectl=${TARGET_VERSION}"
    ssh ${node} "sudo systemctl daemon-reload && sudo systemctl restart kubelet"
    
    echo "Uncordoning worker node: ${node}..."
    kubectl uncordon ${node}
done

sleep 5
kubectl get nodes

echo
echo "Kubernetes cluster upgrade to version ${TARGET_VERSION} is complete!"
echo
