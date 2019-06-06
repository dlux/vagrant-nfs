#!/bin/bash

# Bash version of the configuration

set -o xtrace

local_nfs='/nfsshare'

function fix_new_disk {
    dnum=${1:-1}
    # Having an extra plain disk
    device_list=($(lsblk -n -p --output NAME | grep '^/'))
    device=${device_list[$dnum]}
    # Create partition on second device /dev/sdb
    # use optimal and % to align partition
    fix=$(parted $device --script print 2>&1 | grep 'Error\|Warning')
    [[ -n $fix_part ]] && sgdisk -e $device
    parted -a optimal $device mkpart primary 0% 100%
    # In case you want LVM
    # parted $device --script set 4 lvm on
    # Format partition - ext4, if HW RAID -- Calculate stripe & stripe width
    # Calculate stripe if needed
    #      mkfs.ext4 -E stride=256,stripe-width=512 /dev/sdb1
    partition=$(fdisk -l /dev/sdb |tail -1 |awk '{print $1}'|tr -d ' ')
    partition="$device$partition"
    mkfs.ext4 $partition
    e4label $partition nfsshare
    # Mount partition on the system
    mkdir -p $local_nfs
    mount $partition $local_nfs
    # Get partition UUID
    _u=$(blkid | grep $partition | awk -F 'UUID=' '{print $2}' | 
            awk -F '"' '{print $2}')
    # Mount partition after boot
    printf "UUID=$_u  $local_nfs  ext4  defaults  0  0" >> /etc/fstab
}

function setup_nfs_server {
    # Install & Start NFS
    _INSTALLER_CMD="$1"
    $_INSTALLER_CMD nfs-utils
    #service_list=(rpcbind nfs-server nfs-lock nfs-idmap)
    systemctl enable nfs-server
    systemctl start nfs-server
    # Setup folder to export - All users to connect using anonymous user
    chmod -R 755 $local_nfs
    chown nfsnobody:nfsnobody $local_nfs
    # Set exports configuration
    str="$local_nfs 10.0.2.0/24(rw,sync,insecure,all_squash,subtree_check)"
    printf $str >> /etc/exports
    exportfs -arv
    # Open firewalld ports
    if [[ $(firewall-cmd --state) == 'running' ]]; then
        firewall-cmd --permanent --zone=public --add-service=nfs
        firewall-cmd --permanent --zone=public --add-service=mountd
        firewall-cmd --permanent --zone=public --add-service=rpc-bind
        firewall-cmd --reload
    fi
    # Test it out
    showmount -e localhost
}

function setup_samba_nfs {
    # Make sure nfs is running
    
}

######################### MAIN FLOW #######################################
# Update repos
curl -OL https://github.com/dlux/InstallScripts/raw/master/common_functions
source common_functions
EnsureRoot
UpdatePackageManager
fix_new_disk
setup_nfs_server "$_INSTALLER_CMD"




######################### REFERENCES #######################################
# RAID Math: https://wiki.centos.org/HowTos/Disk_Optimization
# FSStripe: https://gryzli.info/2015/02/26/calculating-filesystem-stride_size-and-stripe_width-for-best-performance-under-raid/
# lspci (yum install pciutils): lspci -knn | grep 'RAID bus controller'
# LSI RAID controller MegaCLI: https://www.broadcom.com/support/knowledgebase/1211161499760/lsi-command-line-interface-cross-reference-megacli-vs-twcli-vs-s
# Partition alignment: https://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/
# Mount NFS on windows10 https://mapr.com/docs/51/DevelopmentGuide/c-mounting-nfs-on-a-windows-client.html
# https://www.tecmint.com/installing-network-services-and-configuring-services-at-system-boot/
