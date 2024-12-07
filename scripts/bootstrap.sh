#!/bin/bash
# Exit except control-plane
if [ $1 != "k8s-master" ]; then
    exit 0
fi

# Set global variables
TARGET_BRANCH=$2

# Install Ansible
sudo dnf install -y ansible-core

# Clone your Ansible repository
git clone -b "${TARGET_BRANCH}" https://github.com/nnaka-git/kube-cluster-on-proxmox.git "$HOME"/kube-cluster-on-proxmox

# Run your initial Ansible playbook
# export ansible.cfg target
export ANSIBLE_CONFIG="$HOME"/kube-cluster-on-proxmox/ansible/ansible.cfg

# ansible-galaxy
ansible-galaxy role install -r "$HOME"/kube-cluster-on-proxmox/ansible/roles/requirements.yml
ansible-galaxy collection install -r "$HOME"/kube-cluster-on-proxmox/ansible/roles/requirements.yml
# ansible-playbook
ansible-playbook "$HOME"/kube-cluster-on-proxmox/ansible/kube-setup.yml