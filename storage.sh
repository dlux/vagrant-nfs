#!/bin/bash

# Bash version of the configuration
# More into Storage File System Enablement
# NFS, SMB, SCSI

set -o xtrace

function fix_new_disk {
    dnum=${1:-1}
    # Having an extra plain disk
    device_list=($(lsblk -n -p --output NAME | grep '^/'))
    device=${device_list[$dnum]}
    # Create partition on second device /dev/sdb
    # use optimal and % to align partition
    fix=$(parted $device --script print 2>&1 | grep 'Error\|Warning')
    [[ -n $fix ]] && sgdisk -e $device
    parted -a optimal $device mkpart primary 0% 100%
    # In case you want LVM
    # parted $device --script set 4 lvm on
    # Format partition - ext4, if HW RAID -- Calculate stripe & stripe width
    # Calculate stripe if needed
    #      mkfs.ext4 -E stride=256,stripe-width=512 /dev/sdb1
    partition=$(fdisk -l /dev/sdb |tail -1 |awk '{print $1}'|tr -d ' ')
    partition="$device$partition"
    [[ $device == $partition ]] && echo 'ERROR: No partitioned' && return 1
    mkfs.ext4 $partition
    # Mount partition on the system
    mkdir -p $local_folder
    mount $partition $local_folder
    # Get partition UUID
    _u=$(blkid | grep $partition | awk -F 'UUID=' '{print $2}' |
            awk -F '"' '{print $2}')
    # Mount partition after boot
    printf "UUID=$_u  $local_folder  ext4  defaults  0  0" >> /etc/fstab
}

function disable_selinux {
    # Disable selinux
    if [[ $(getenforce) == "Enforcing" ]]; then
        setenforce 0
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        sestatus
    fi

}

function setup_nfs_server {
    # Install & Start NFS
    [[ -z "$1" ]] && echo "Error: provide local shared folder" && exit 1
    _installer="${2:-yum install -y}"

    local_folder="$1"
    mkdir -p "$local_folder"
    $_installer nfs-utils vim

    #service_list=(rpcbind nfs-server nfs-lock nfs-idmap)
    systemctl enable nfs-server
    systemctl start nfs-server

    # Setup folder to export - All users to connect using anonymous user
    chmod -R 755 $local_folder
    chown nfsnobody:nfsnobody $local_folder

    # Set exports configuration
    str="$local_folder 10.0.2.0/24(rw,sync,insecure,all_squash,subtree_check)"
    printf "$str" >> /etc/exports
    exportfs -arv

    # Open firewalld ports
    if [[ $(firewall-cmd --state) == 'running' ]]; then
        firewall-cmd --permanent --zone=public --add-service=nfs
        firewall-cmd --permanent --zone=public --add-service=mountd
        firewall-cmd --permanent --zone=public --add-service=rpc-bind
        firewall-cmd --reload
    fi
    disable_selinux
    showmount -e localhost
}

function setup_samba_server {
    [[ -z "$1" ]] && echo "Error: provide local shared folder" && exit 1
    [[ -z "$2" ]] && echo "Error: provide samba username" && exit 1
    [[ -z "$3" ]] && echo "Error: provide samba userpassword" && exit 1
    _installer="${4:-yum install -y}"

    $_installer samba samba-client samba-common vim
    local_folder="$1"
    smbuser="$2"
    smbpass="$3"

    # set user
    groupadd smbgrp
    useradd -M -s /sbin/nologin $smbuser
    echo "$smbuser:$smbpass" | chpasswd
    usermod -aG smbgrp $smbuser
    printf "$smbpass\n$smbpass\n" | smbpasswd -a $smbuser
    smbpasswd -e $smbuser
    mkdir -p "$local_folder"
    chown -R nobody:smbgrp "$local_folder"
    chmod -R 0775 "$local_folder"

    # set configuration - user access
    mv /etc/samba/smb.conf /etc/samba/smb.$(date +"%d-%m-%y-%s").bak
    cat <<EOF > /etc/samba/smb.conf
[global]
    workgroup = SAMBA
    server string = Samba Server %v
    security = user
    log file = /var/log/samba/%m.log
    log level = 2
    interfaces = eth1
    bind interfaces only = yes

[shared]
    path = $local_folder
    valid users = @smbgrp
    guest ok = no
    writeable = yes
    browseable = yes
    read only = no
EOF
    list=('smb.service' 'nmb.service')
    for service in "${list[@]}"; do
        systemctl enable $service
        systemctl restart $service
    done
    # Open firewalld ports
    if [[ $(firewall-cmd --state) == 'running' ]]; then
        firewall-cmd --permanent --zone=public --add-service=samba
        firewall-cmd --reload
    fi
    disable_selinux
    printf '\n' | testparm
}

######################### MAIN FLOW #######################################
comrepo='https://github.com/dlux/InstallScripts/raw/master/common_functions'
function _PrintHelp {
    scriptName=$(basename "$0")
    echo "Script: $scriptName. Optionally uses given proxy"
    echo " "
    echo "Usage:"
    echo "scriptName [ -x <http://proxy:port> | -n | -s | -i ]"
    echo " "
    echo "     --proxy  | -x     Uses given proxy server in the installation."
    echo "     --folder | -f     Use given folder name to be shared."
    echo "     --isci   | -i     Installs isci protocol server services."
    echo "     --nfs    | -n     Installs nfs protocol server services."
    echo "     --smb    | -s     Installs samba protocol server services."
    echo "     --user   | -u     User name to use"
    echo "     --password | -p   User password to use"
    echo "     --help            Prints current help text. "
    echo " "
    exit 1
}

# Handle options
while [[ ${1} ]]; do
    case "${1}" in
    --proxy|-x)
        [[ -z "$2" || "$2" == -* ]] && echo "Error: Missing proxy." && exit 1
        [[ ! -f common_functions ]] && curl -OL $comrepo -x $2
        source common_functions
        SetProxy "${2}"
        shift
        ;;
    --nfs|-n)
        _nfs=true
        ;;
    --smb|-s)
        _smb=true
        ;;
    --isci|-i)
        _isci=true
        ;;
    --folder|-f)
        [[ -z "$2" || "$2" == -* ]] && echo "Error: Missing dir name" && exit 1
        _folder="$2"
        shift
        ;;
    --password|-p)
        [[ -z "$2" || "$2" == -* ]] && echo "Error: Missing password" && exit 1
        _password="$2"
        shift
        ;;
    --user|-u)
        [[ -z "$2" || "$2" == -* ]] && echo "Error: Missing username" && exit 1
        _user="$2"
        shift
        ;;
    *)
        _PrintHelp
        ;;
    esac
    shift
done

[[ ! -f common_functions ]] && curl -OL $comrepo
source common_functions
EnsureRoot
SetPackageManager
UpdatePackageManager
$_INSTALLER_CMD gdisk
fix_new_disk
[[ $_nfs == true ]] && setup_nfs_server "$_folder" "$_INSTALLER_CMD"
[[ $_smb == true ]] && setup_samba_server "$_folder" "$_user" "$_password" \
    "$_INSTALLER_CMD"
#[[ $_isci == true ]] && setup_isci_server "$_INSTALLER_CMD"

echo 'COMPLETED'



######################### REFERENCES #######################################
# RAID Math: https://wiki.centos.org/HowTos/Disk_Optimization
# FSStripe: https://gryzli.info/2015/02/26/calculating-filesystem-stride_size-and-stripe_width-for-best-performance-under-raid/
# lspci (yum install pciutils): lspci -knn | grep 'RAID bus controller'
# LSI RAID controller MegaCLI: https://www.broadcom.com/support/knowledgebase/1211161499760/lsi-command-line-interface-cross-reference-megacli-vs-twcli-vs-s
# Partition alignment: https://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/
# Mount NFS on windows10 https://mapr.com/docs/51/DevelopmentGuide/c-mounting-nfs-on-a-windows-client.html
# https://www.tecmint.com/installing-network-services-and-configuring-services-at-system-boot/
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/system_administrators_guide/ch-file_and_print_servers#setting_up_samba_as_a_domain_member
