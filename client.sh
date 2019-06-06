#!/bin/bash

# Bash version of the configuration
# More into Storage File System Enablement
# NFS, SMB, SCSI

set -o xtrace

function test_nfs_server {
    [[ -z "$1" ]] && echo "Error: provide server ip/name" && exit 1
    [[ -z "$2" ]] && echo "Error: provide remote shared folder" && exit 1
    _installer="${3:-yum install -y}"
    $_installer nfs-common

    server="$1"
    remote_folder="$2"

    # Test it out
    showmount -e "$server"
    mkdir ./tmp
    mount "${server}:${remote_folder}" ./tmp
    [[ $? != 0 ]] && echo "Error: unable to mount remote folder" && exit 1
    mkdir ./tmp/testfolder
    [[ $? != 0 ]] && echo "Error: unable to create folder" && exit 1
    touch ./tmp/testfile
    [[ $? != 0 ]] && echo "Error: unable to create file" && exit 1
}

function test_samba_server {
    [[ -z "$1" ]] && echo "Error: provide server ip/name" && exit 1
    [[ -z "$2" ]] && echo "Error: provide remote shared folder" && exit 1
    [[ -z "$3" ]] && echo "Error: provide samba username" && exit 1
    [[ -z "$4" ]] && echo "Error: provide samba userpassword" && exit 1
    _installer="${5:-yum install -y}"
    $_installer samba-client

    server="$1"
    remote_folder="$2"
    samba_user="$3"
    samba_pass="$4"
    cmd="smbclient -U $samba_user //${server}${remote_folder} -c"
    testname="testfolder$(date +'%s')"
    echo $samba_pass | $cmd "mkdir $testname"
    echo $samba_pass | $cmd "ls" | grep $testname
    [[ $? != 0 ]] && echo "Error: unable to create folder" && exit 1
    mkdir -p tmp
    mount -t cifs //${server}${remote_folder}  ./tmp -o \
        user=${samba_user},pass=${samba_pass}
    ls tmp | grep $testname
    [[ $? != 0 ]] && echo "Error: unable to mount share" && exit 1
    testname="testfile$(date +'%s')"
    touch ./tmp/$testname
    if [[ -z $(ls tmp | grep $testname) ]]; then
        echo 'Error: Unable to create file'
        exit 1
    fi
}

######################### MAIN FLOW #######################################
comrepo='https://github.com/dlux/InstallScripts/raw/master/common_functions'
function _PrintHelp {
    scriptName=$(basename "$0")
    echo "Script: $scriptName. Optionally uses given proxy"
    echo " "
    echo "Usage:"
    echo "$scriptName [ -x <http://proxy:port> | -n | -s | -i ]"
    echo " "
    echo "     --proxy  | -x     Uses given proxy server in the installation."
    echo "     --folder | -f     Shared folder on remote server."
    echo "     --isci   | -i     Test isci protocol server."
    echo "     --nfs    | -n     Test nfs protocol server."
    echo "     --smb    | -s     Test samba protocol server."
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
    --remote|-r)
        etxt="Error: Missing remote server"
        [[ -z "$2" || "$2" == -* ]] && echo $etxt && exit 1
        _server="$2"
        shift
        ;;
    --user|-u)
        etxt="Error: Missing user name"
        [[ -z "$2" || "$2" == -* ]] && echo $etxt && exit 1
        _user="$2"
        shift
        ;;
    --password|-p)
        etxt="Error: Missing user password"
        [[ -z "$2" || "$2" == -* ]] && echo $etxt && exit 1
        _password="$2"
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
#UpdatePackageManager
[[ $_nfs == true ]] && test_nfs_server $_server $_folder "$_INSTALLER_CMD"
[[ $_smb == true ]] && test_samba_server "$_server" "$_folder" "$_user" \
    "$_password"  "$_INSTALLER_CMD"
#[[ $_isci == true ]] && test_isci_server "$_INSTALLER_CMD"

echo 'COMPLETED'

