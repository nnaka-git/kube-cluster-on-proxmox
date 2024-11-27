#!/usr/bin/env bash

# template settings
TEMPLATE_VMID=9001
TEMPLATE_NAME=almalinux-template
QCOW2_FILE=/var/lib/vz/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2

# create a new VM and attach Network Adaptor
# vmbr0=Service Network Segment (192.168.1.0/24)
qm create ${TEMPLATE_VMID} --bios seabios --cpu x86-64-v2-AES --cores 2 --memory 4096 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --ostype l26 --name ${TEMPLATE_NAME}

# set scsi0 disk from downloaded disk
qm set ${TEMPLATE_VMID} --scsi0 local-lvm:0,import-from=${QCOW2_FILE},format=qcow2,cache=writeback,discard=on

# add Cloud-Init CD-ROM drive
qm set ${TEMPLATE_VMID} --ide0 local-lvm:cloudinit

# set the bootdisk parameter to scsi0
qm set ${TEMPLATE_VMID} --boot c --bootdisk scsi0

# migrate to template
qm template ${TEMPLATE_VMID}
