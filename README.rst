===============
vagrant-storage
===============

.. image:: https://travis-ci.com/dlux/vagrant-storage.svg?branch=master
    :target: https://travis-ci.com/dlux/vagrant-storage

STATUS: **COMPLETE: nfs,smb,iscsi**

Example for diffent file system examples.

* NFS - Share file system across the network: between linux boxes. Special native NFS mount can be done also on Windows10
* Samba - Share files from the network: between linux and windows boxes.
* ISCSI - Share block device across the network.

Will use an extra disk configured as the storage disk.

This example started with a vagrant ansible example for NFS.
To use this version ansible must be installed on the host.

To Run
------

.. code-block:: bash

   $ vagrant up
   # 2 vms are spined up a server and a client
   # Modify Vagrantfile provisioner to change services deployed (nfs/smb/iscsi)

NFS Ansible Run
---------------

.. code-block:: bash

   # PREREQUISITES
   $ git clone https://github.com/dlux/vagrant-nfs.git
   $ cd vagrant-nfs
   $ virtualenv venv
   $ . venv/bin/activate
   $ pip install ansible

   # Change Vagrant server to use ansible playbook
   # Startup VM
   $ vagrant up


Additional information
----------------------

Go to  http://www.luzcazares.com/storage

