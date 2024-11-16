#!/bin/bash
# Install Ansible
sudo dnf install -y ansible-core
# Clone your Ansible repository
git config --system user.name "nnaka-git"
git config --system user.email nori.nakamura@gmail.com
git clone https://github.com/nnaka-git/kube-cluster-on-proxmox.git "$HOME"/kube-cluster-on-proxmox
# Run your initial Ansible playbook
# ansible-playbook /etc/ansible/playbooks/initial-setup.yml