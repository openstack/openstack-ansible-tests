OpenStack-Ansible testing
=========================

This is a PoC for centralizing the testing within OpenStack-Ansible.
Aiming to move out the common pieces so that changes that affect
testing don't have to occur in every single repository.
This allows you to run the common set of plays based on your requirements,
and will work based on the inventory specs.
The aim is to avoid (as much as possible) the requirement to change the same
thing in 50 different places.

Steps so far:

#. Move out playbooks for role installs
#. Move out variables to become a ``test-default`` vars.
#. Genericize rolename calls

General notes
~~~~~~~~~~~~~

I've patched some issues that I've put upstream (Mostly for nova):

| https://review.openstack.org/#/c/321472/
| https://review.openstack.org/#/c/321148/

These are incorporated in the patches I have for the repositories.

Discussion points
~~~~~~~~~~~~~~~~~

Variable locations/precendence
------------------------------

Currently using testing defaults as an include within the play files - this
lives inside the generic repository (this one)
Using a ``{rolename}-overrides.yml`` within each role's repository we can set
various vars that are non-default (these are pretty minimal though for the
roles I've done. ``nova/glance/keystone/swift``).
Open to suggestions/discussion.

Rolename includes
-----------------

To use a generic keystone playbook for testing (as an example), we need to set
the rolename to be a default of ``os_keystone`` (this is how we specify it
in ``ansible-role-requirements``).
However for keystone testing we need it to be ``openstack-ansible-os_keystone``,
so there are 2 options:

#. We set the the ``ansible-role-requirements`` to clone ALL repos to
   ``openstack-ansible-x`` and code the rolenames as such.

#. We have a var per repo to specify its own rolename
   (e.g. ``openstack-ansible-os_keystone``) and use the shortname as a default.

I've gone with option 2 for the purposes of this PoC
Open to other suggestions/discussion.

Inventory management
--------------------

For swift I have split out the ``group/host_vars`` so that very little is in the
inventory, I think this is the way forward.
This isn't generic to roles - so isn't really covered in this, but I'd like a uniform
method of preparing hosts.

Method of running plays
-----------------------

There was an idea to simply run the ``test.yml`` from the generic repo
which will call all the appropriate repos. This will fail if the requirements
repositories don't exist though, regardless of whether they are used.
For example, rabbitmq isn't used by swift, but you would need to download the
role just to be able to ignore the rabbitmq role.
I've gone with the alternative, for the purposes of this PoC, which is to specify
in the role repositories, which generic playbooks to run.

I think the decisions made so far are solid but feel free to give ideas/discuss etc.
Here are the 4 repositories I have working with this method, so you can see the
patch required to get it working on each repository:

| Swift_
| Keystone_
| Glance_
| Nova_

.. _Swift: http://github.com/andymcc/openstack-ansible-os_swift/
.. _Keystone: http://github.com/andymcc/openstack-ansible-os_keystone/
.. _Glance: http://github.com/andymcc/openstack-ansible-os_glance/
.. _Nova: http://github.com/andymcc/openstack-ansible-os_nova/


