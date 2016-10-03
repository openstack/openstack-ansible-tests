OpenStack-Ansible testing
=========================

This is the ``openstack-ansible-tests`` repository, providing a framework and
consolidation of testing configuration and playbooks. This can be used to
integrate new projects, and ensure that code duplication is minimized whilst
allowing the addition of new testing scenarios with greater ease.

Role Integration
~~~~~~~~~~~~~~~~

To enable the ``openstack-ansible-tests`` repository, ensure that the
``tox.ini`` configuration in the role repository matches the `galera_client
repository tox.ini`_ with the exception of the value for ``ROLE_NAME``.
A more advanced configuration which implements multiple functional test
scenarios is available in the `neutron role tox.ini`_.

To override variables you can create a ``${rolename}-overrides.yml`` file inside the
role's tests folder. This variable file can be includes in the functional tox
target configuration in ``tox.ini`` as demonstrated in the following extract:

.. code-block:: bash

    ansible-playbook -i {toxinidir}/tests/inventory \
                     -e @{toxinidir}/tests/${rolename}-overrides.yml \
                     {toxinidir}/tests/test.yml -vvvv

In your repositories ``tests/test.yml`` file, you can call any of the
included playbooks, for example:

.. code-block:: yaml

    - include: common/test-prepare-keys.yml

.. _galera_client repository tox.ini: https://github.com/openstack/openstack-ansible-galera_client/blob/master/tox.ini
.. _neutron role tox.ini: https://github.com/openstack/openstack-ansible-os_neutron/blob/master/tox.ini

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
``alias``: Add an alias IP address

For example, a Nova setup may look like this:

.. code-block:: yaml

    bridges:
      - name: "br-mgmt"
        ip_addr: "10.1.0.1"
      - name: "br-vxlan"
        ip_addr: "10.1.1.1"
      - name: "br-vlan"
        ip_addr: "10.1.2.200"
        veth_peer: "eth12"
        alias: "10.1.2.1"

