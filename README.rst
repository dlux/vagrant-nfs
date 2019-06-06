===========
vagrant-nfs
===========

.. image:: https://travis-ci.com/dlux/vagrant-nfs.svg?branch=master
    :target: https://travis-ci.com/dlux/vagrant-nfs

STATUS: **INCOMPLETE**

Using NFS to share storage

This example also uses vagrant ansible hence it must be installed on the host.
Will use an extra disk configured as the storage disk

To Run
------

.. code-block:: bash

   # PREREQUISITES
   $ git clone https://github.com/dlux/vagrant-nfs.git
   $ cd vagrant-nfs
   $ virtualenv venv
   $ . venv/bin/activate
   $ pip install ansible

   # Startup VM
   $ vagrant up

# Additional information on pip and virtualenv.

# See: http://www.luzcazares.com/openstack/empaqueta-tus-proyectos-python/

