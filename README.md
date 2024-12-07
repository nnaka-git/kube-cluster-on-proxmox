# kubernetes cluster on proxmox

1ノードの Proxmox 上に Kubernetes の 3 ノードクラスタの VM を作成する
cloud-init、Ansible で作成
## VM

deploy.sh に定義

|VMID|Host name|role|IP address|vCPU|Mem|Disk|
|---|---|---|:---:|---:|---:|---:|
|1120|k8s-master|master|192.168.1.120|2|4GB|60GB|
|1121|k8s-node1|node|192.168.1.121|4|8GB|60GB|
|1122|k8s-node2|node|192.168.1.122|4|8GB|60GB|

## kubernetes
|kubernetes |構成内容||
|---|---|---|
|ランタイム|CRI-O||
|CNI|Flannel|pod network CIDR : 10.244.0.0/16(default) |
|ロードバランサー|MetalLB| IP Address Pool : 192.168.1.131-192.168.1.140<br>ansible 14-kube-config templates にて定義|


## 作成フロー

 1. proxmoxのホストコンソール上で`deploy.sh`を実行すると、上記VMが作成され、クラスタの初期セットアップが行われる。`TARGET_BRANCH`はデプロイ対象のコードが反映されたブランチ名に変更する。

```sh
export TARGET_BRANCH=main
# clear
/bin/bash <(curl -s https://raw.githubusercontent.com/nnaka-git/kube-cluster-on-proxmox/${TARGET_BRANCH}/clear.sh) ${TARGET_BRANCH}
# deploy
/bin/bash <(curl -s https://raw.githubusercontent.com/nnaka-git/kube-cluster-on-proxmox/${TARGET_BRANCH}/deploy.sh) ${TARGET_BRANCH}
```

### デバッグ用
```sh
## check cloud-init 
sudo cloud-init query userdata
sudo cloud-init schema --system --annotate
```
```sh
## check /var/log/cloud-init-output.log
sudo cat /var/log/cloud-init-output.log
```

```sh
# ansible 手動実行
export ANSIBLE_CONFIG="$HOME"/kube-cluster-on-proxmox/ansible/ansible.cfg
ansible-playbook "$HOME"/kube-cluster-on-proxmox/ansible/kube-setup.yml --syntax-check
ansible-playbook "$HOME"/kube-cluster-on-proxmox/ansible/kube-setup.yml --list-tasks
ansible-playbook "$HOME"/kube-cluster-on-proxmox/ansible/kube-setup.yml --vvv

# ansible log
cat "$HOME"/kube-cluster-on-proxmox/ansible/ansible.log
```
