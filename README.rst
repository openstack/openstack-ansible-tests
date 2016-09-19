OpenStack-Ansible testing
=========================

This is the ``openstack-ansible-tests`` repository, providing a framework and
consolidation of testing configuration and playbooks. This can be used to
integrate new projects, and ensure that code duplication is minimized whilst
allowing the addition of new testing scenarios with greater ease.

Roles Currently using the ``openstack-ansible-tests`` repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- openstack-ansible-galera_server
- openstack-ansible-tests
- openstack-ansible-os_rally
- openstack-ansible-memcached_server
- openstack-ansible-openstack_hosts
- openstack-ansible-repo_build
- openstack-ansible-repo_server
- openstack-ansible-lxc_container_create
- openstack-ansible-os_keystone
- openstack-ansible-os_aodh
- openstack-ansible-os_zaqar

Variables are generic and based on inventory so variable overrides should be
able to be very minimal.

Role Integration
~~~~~~~~~~~~~~~~

To enable the ``openstack-ansible-tests`` repository add the following to your
repositories tox.ini, at the bottom of the ``[testenv:ansible]]`` stanza, in the
``commands`` section.

.. code-block:: bash

    rm -rf {toxinidir}/tests/playbooks
    git clone https://git.openstack.org/openstack/openstack-ansible-tests \
              {toxinidir}/tests/playbooks

To override variables you can create a role-overrides.yml file inside tests,
which you can include in your tox.ini.
You will have to set the rolename for the repository due to how the base
repository is cloned when gates run, the below example shows keystone's
settings:

.. code-block:: bash

    -e @{toxinidir/tests/keystone-overrides.yml \
    -e "keystone_rolename={toxinidir}" \

In your repositories ``tests/test.yml`` file, you can call any of the
included playbooks, for example:

.. code-block:: yaml

    - include: playbooks/test-prepare-keys.yml

Network Settings
~~~~~~~~~~~~~~~~

The networking can be configured and setup using the ``bridges`` variable.

The base option, when only 1 interface is required is to specify just a single
base - this is only for backwards compatibility with existing test setup and
will default to ``br-mgmt`` with an IP of ``10.1.0.1``.

.. code-block:: yaml

    bridges:
      - "br-mgmt"

To allow a more complicated network setup we can specify
``ip_addr``: The IP address on the interface.
``netmask``: Netmask of the interface (defaults to 255.255.255.0)
``name``: Name of the interface
``veth_peer``: Set up a veth peer for the interface

For example, a Nova setup may look like this:

.. code-block:: yaml

    bridges:
      - name: "br-mgmt"
        ip_addr: "10.1.0.1"
      - name: "br-vxlan"
        ip_addr: "10.1.1.1"
      - name: "br-vlan"
        ip_addr: "10.1.2.1"
        veth_peer: "eth12"

