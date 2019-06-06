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
  config.vm.hostname = 'nfsserver'
  config.vm.network :forwarded_port, guest: 80, host: 8085

  config.vm.provider 'virtualbox' do |v|
    v.customize ['modifyvm', :id, '--memory', 1024 * 1 ]
    v.customize ["modifyvm", :id, "--cpus", 1]
    disk = './secondDisk.vdi'
    unless File.exist?(disk)
        v.customize ['createhd', '--filename', disk, '--variant',\
                     'Fixed', '--size', 2 * 1024]
    end
    # other attempts 'SATAController', 'SATA Controller', 'SATA'
    v.customize ['storageattach', :id,  '--storagectl', 'IDE',
                 '--port', 1, '--device', 0, '--type', 'hdd', '--medium', disk]
  end
  config.vm.provision 'ansible' do |s|
    s.playbook = 'nfs.yml'
    s.groups = {
      "nfs" => [ "default" ],
      "nfs:vars" => [
       "http_proxy=http://proxy-server",
       "https_proxy=http://proxy-server",
       "no_proxy=10.0.0.0/8,192.168.0.0/16,localhost"
         ]
    }
    s.raw_arguments = ["-vv"]
    s.become = true
  end

end

