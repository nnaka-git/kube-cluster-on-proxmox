#!/bin/bash
# Install Ansible
sudo dnf install -y ansible-core
# Clone your Ansible repository
git clone https://github.com/nnaka-git/kube-cluster-on-proxmox.git "$HOME"/kube-cluster-on-proxmox
# Run your initial Ansible playbook
# export ansible.cfg target
export ANSIBLE_CONFIG="$HOME"/kube-cluster-on-proxmox/ansible/ansible.cfg
ansible-playbook "$HOME"/kube-cluster-on-proxmox/ansible/kube-setup.yaml