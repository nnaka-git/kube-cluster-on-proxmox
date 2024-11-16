#!/usr/bin/env bash

# region : set variables

TEMPLATE_VMID=9000
CLOUDINIT_IMAGE_TARGET_VOLUME=local-lvm
TEMPLATE_BOOT_IMAGE_TARGET_VOLUME=local-lvm
BOOT_IMAGE_TARGET_VOLUME=local-lvm
SNIPPET_TARGET_VOLUME=local
SNIPPET_TARGET_PATH=/var/lib/vz/snippets
VM_DISK_IMAGE=/var/lib/vz/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
REPOSITORY_RAW_SOURCE_URL=https://raw.githubusercontent.com/nnaka-git
VM_LIST=(
    # ---
    # vmid:       proxmox上でVMを識別するID
    # vmname:     proxmox上でVMを識別する名称およびホスト名
    # cpu:        VMに割り当てるコア数(vCPU)
    # mem:        VMに割り当てるメモリ(MB)
    # vmsrvip:    VMのService Segment側NICに割り振る固定IP
    # ---
    #vmid #vmname #cpu #mem  #vmsrvip    
    "1111 kube-cp1 2    4096  192.168.1.111"
#    "1112 kube-wk1 4    8192  192.168.1.112"
#    "1113 kube-wk2 4    8192  192.168.1.113"
)

# endregion

# ---

# region : create template-vm

# create a new VM and attach Network Adaptor
# vmbr0=Service Network Segment (192.168.1.0/24)
qm create $TEMPLATE_VMID --bios seabios --cpu x86-64-v2-AES --cores 2 --memory 4096 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --ostype l26 --name kube-template

# set scsi0 disk from downloaded disk
qm set $TEMPLATE_VMID --scsi0 local-lvm:0,import-from=${VM_DISK_IMAGE},format=qcow2,cache=writeback,discard=on

# add Cloud-Init CD-ROM drive
qm set $TEMPLATE_VMID --ide0 $CLOUDINIT_IMAGE_TARGET_VOLUME:cloudinit

# set the bootdisk parameter to scsi0
qm set $TEMPLATE_VMID --boot c --bootdisk scsi0

# migrate to template
qm template $TEMPLATE_VMID

# endregion

# ---

# region : setup vm from template-vm

for array in "${VM_LIST[@]}"
do
	echo "${array}" | while read -r vmid vmname cpu mem vmsrvip 
	do
		# clone from template
		qm clone "${TEMPLATE_VMID}" "${vmid}" --name "${vmname}" --full true
		
		# set compute resources
		qm set "${vmid}" --cores "${cpu}" --memory "${mem}"

		# resize disk (Resize after cloning, because it takes time to clone a large disk)
		qm resize "${vmid}" scsi0 60G

		# create snippet for cloud-init(user-config)
		cat > "$SNIPPET_TARGET_PATH"/"$vmname"-user.yaml <<- EOF
			#cloud-config
			# SYSTEM
			hostname: ${vmname}
			fqdn: ${vmname}.local
			manage_etc_hosts: true
			locale: ja_JP.UTF-8
			timezone: Asia/Tokyo
			# USER
			users:
			  - default
			  - name: red
			    lock_passwd: false
			    # mkpasswd --method=SHA-512 --rounds=4096
			    passwd: \$6\$rounds=4096\$2dcpst67UO5pMw7H\$OlPx45objlhjmlFx7dj0/BA/Bv/JVI/z6xNNjRr/7wwqAEgi8XjROA8f/WCoiPnaTSz.P6OMKtLNyq4jTrHnq0
			    sudo: ALL=(ALL) NOPASSWD:ALL
			    uid: 1000
			disable_root: false
			ssh_pwauth:   true
			chpasswd:
			  expire: false
			  users:
			  - {name: root, password: \$6\$rounds=4096\$Q8.soBzTd197aiV1\$kLND.9Ncudev2N01P89KT63kwxa3Ba4dPPsO4iRTdxu8a9.SNrKxvzEj1cvvz7DdtY3JyOUxHym8KEECarXq1.}
			package_upgrade: true
			# for LANG=ja_JP.UTF-8
			packages:
			  - glibc-locale-source
			  - glibc-langpack-ja
			runcmd:
			  # disable SELinux
			  - setenforce 0
			  - sed -i -e 's/^\SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
			  - systemctl restart rsyslog
			  # set ssh_authorized_keys
			  - su - red -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
			  - su - red -c "curl -sS https://github.com/nnaka-git.keys >> ~/.ssh/authorized_keys"
			  - su - red -c "chmod 600 ~/.ssh/authorized_keys"
			  - su - red -c "curl -sS ${REPOSITORY_RAW_SOURCE_URL}/kube-cluster-on-proxmox/refs/heads/main/scripts/bootstrap.sh | bash"
			  - su - red -c "sudo localedef -f UTF-8 -i ja_JP ja_JP"
			# REBOOT
			power_state:
			  mode: reboot
		EOF

		# create snippet for cloud-init(network-config)
		cat > "$SNIPPET_TARGET_PATH"/"$vmname"-network.yaml <<- EOF
			version: 1
			config:
			  - type: physical
			    name: eth0
			    subnets:
			      - type: static
			        address: ${vmsrvip}/24
			        gateway: 192.168.1.1
			  - type: nameserver
			    address:
			      - 192.168.1.1
			      - 8.8.8.8
			    search:
			      - local
		EOF

		# set snippet to vm
		qm set "${vmid}" --cicustom "user=${SNIPPET_TARGET_VOLUME}:snippets/${vmname}-user.yaml,network=${SNIPPET_TARGET_VOLUME}:snippets/${vmname}-network.yaml"

	done
done

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid vmname cpu mem vmsrvip
    do
        # start vm
        qm start "${vmid}"
        
    done
done

# endregion

