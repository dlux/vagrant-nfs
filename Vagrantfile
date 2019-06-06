# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.require_version ">= 1.8.4"

Vagrant.configure(2) do |config|
  config.vm.box = 'centos/7'
  config.vm.box_version = '1902.01'
  config.vm.box_check_update = false
  #config.vm.synced_folder "./", "/opt/dlux"

  config.vm.define :servernode do |svr|
    svr.vm.hostname = 'servernode'
    #svr.vm.network :forwarded_port, guest: 80, host: 8085
    #svr.vm.network :forwarded_port, guest: 2049, host: 8049
    svr.vm.network "private_network",ip: "172.172.0.5"
    svr.vm.provider 'virtualbox' do |v|
      v.customize ["modifyvm", :id, "--natnet1", "192.168.0.0/27"]
      v.customize ['modifyvm', :id, '--memory', 1024 * 1 ]
      v.customize ["modifyvm", :id, "--cpus", 1]
      disk = './secondDisk.vdi'
      unless File.exist?(disk)
        v.customize ['createhd', '--filename', disk, '--variant',\
                     'Fixed', '--size', 2 * 1024]
      end
      # other attempts 'SATAController', 'SATA Controller', 'SATA'
      v.customize ['storageattach', :id,  '--storagectl', 'IDE', '--port', 1,
                   '--device', 0, '--type', 'hdd', '--medium', disk]
    end
    svr.vm.provision 'shell' do |s|
      s.path = './storage.sh'
      s.args = ['--smb', '-f', '/shared', '-u', 'smbuser', '-p', 'secure9' ]
    end
  end

  config.vm.define :clientnode do |svr|
    svr.vm.hostname = 'clientnode'
    svr.vm.network "private_network",ip: "172.172.0.6"
    svr.vm.provider 'virtualbox' do |v|
      v.customize ["modifyvm", :id, "--natnet1", "192.168.1.0/27"]
      v.customize ['modifyvm', :id, '--memory', 1024 * 1 ]
      v.customize ["modifyvm", :id, "--cpus", 1]
    end
    svr.vm.provision 'shell' do |s|
      # Test samba
      s.path = 'client.sh'
      s.args = ['--smb', '-r', '172.172.0.5', '-f', '/shared', '-u', 'smbuser', '-p', 'secure9' ]
    end
  end
end

