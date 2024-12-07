#!/usr/bin/env bash

# region : set variables

TARGET_BRANCH=$1
TEMPLATE_VMID=9000
CLOUDINIT_IMAGE_TARGET_VOLUME=local-lvm
TEMPLATE_BOOT_IMAGE_TARGET_VOLUME=local-lvm
BOOT_IMAGE_TARGET_VOLUME=local-lvm
SNIPPET_TARGET_VOLUME=local
SNIPPET_TARGET_PATH=/var/lib/vz/snippets
VM_DISK_IMAGE=/var/lib/vz/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
REPOSITORY_RAW_SOURCE_URL="https://raw.githubusercontent.com/nnaka-git/kube-cluster-on-proxmox/${TARGET_BRANCH}"
VM_LIST=(
    # ---
    # vmid:       proxmox上でVMを識別するID
    # vmname:     proxmox上でVMを識別する名称およびホスト名
    # cpu:        VMに割り当てるコア数(vCPU)
    # mem:        VMに割り当てるメモリ(MB)
    # disksize:   VMに割り当てるディスクサイズGB
    # vmsrvip:    VMのService Segment側NICに割り振る固定IP
    # ---
    #vmid #vmname    #cpu #mem  #disksize #vmsrvip    
    "1120 k8s-master 2    4096  60GB      192.168.1.120"
    "1121 k8s-node1  4    8192  60GB      192.168.1.121"
    "1122 k8s-node2  4    8192  60GB      192.168.1.122"
)
GATEWAY_IPADDRESS=192.168.1.1
DNS1_IPADDRESS=192.168.1.1
DNS2_IPADDRESS=8.8.8.8

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
	echo "${array}" | while read -r vmid vmname cpu mem disksize vmsrvip 
	do
		# clone from template
		qm clone "${TEMPLATE_VMID}" "${vmid}" --name "${vmname}" --full true
		
		# set compute resources
		qm set "${vmid}" --cores "${cpu}" --memory "${mem}"

		# resize disk (Resize after cloning, because it takes time to clone a large disk)
		qm resize "${vmid}" scsi0 "${disksize}"

		# create snippet for cloud-init(user-config)
		cat > "${SNIPPET_TARGET_PATH}"/"$vmname"-user.yaml <<- EOF
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
			  - name: cloudinit
			    lock_passwd: false
			    # mkpasswd --method=SHA-512 --rounds=4096
			    # password: mypassword
			    passwd: \$6\$rounds=4096\$hRSSL7OThTE.bfU0\$Jzv3h18280dqlMc8cmHfraR53Izc1XGbgJTobh5yV8FVhEYpMhcV4Q6NFzMIFjk3/irHvCRJk56fFwepM6eyF.
			    sudo: ALL=(ALL) NOPASSWD:ALL
			    uid: 1000
			disable_root: false
			ssh_pwauth:   true
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
			  - su - cloudinit -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
			  - su - cloudinit -c "curl -sS https://github.com/nnaka-git.keys >> ~/.ssh/authorized_keys"
			  - su - cloudinit -c "chmod 600 ~/.ssh/authorized_keys"
			  # pull bootstrap script and exec ansible
			  - su - cloudinit -c "curl -s ${REPOSITORY_RAW_SOURCE_URL}/scripts/bootstrap.sh > ~/bootstrap.sh"
			  - su - cloudinit -c "bash ~/bootstrap.sh ${vmname} ${TARGET_BRANCH}"
			  - su - cloudinit -c "sudo localedef -f UTF-8 -i ja_JP ja_JP"
			# REBOOT
			power_state:
			  mode: reboot
		EOF

		# create snippet for cloud-init(network-config)
		cat > "${SNIPPET_TARGET_PATH}"/"$vmname"-network.yaml <<- EOF
			version: 1
			config:
			  - type: physical
			    name: eth0
			    subnets:
			      - type: static
			        address: ${vmsrvip}/24
			        gateway: ${GATEWAY_IPADDRESS}
			  - type: nameserver
			    address:
			      - ${DNS1_IPADDRESS}
			      - ${DNS2_IPADDRESS}
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

