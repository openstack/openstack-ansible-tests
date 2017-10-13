#!/usr/bin/env python
# Copyright 2017, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Ansible linter for passing packages as list to package modules."""
import os
import unittest

from ansiblelint import AnsibleLintRule, RulesCollection, Runner

TEST_PLAYBOOK_DIR = "{}/test/".format(
    os.path.dirname(os.path.realpath(__file__))
)
PACKAGE_MODULES = [
    'apt',
    'dnf',
    'package',
    'pip',
    'yum',
    'zypper'
]


def is_package_action(task):
    """Test if task is using a package module."""
    return task['action']['__ansible_module__'] in PACKAGE_MODULES


class PassListToPackageModules(AnsibleLintRule):
    """Ansible linter for passing packages as list to package modules."""
    id = 'OSA0002'
    shortdesc = 'Pass packages as a list to package modules'
    description = (
        "When passing multiple packages to a package module, pass the "
        "packages as a list rather than using 'with_items'. This provides a "
        "performance boost for deployments."
    )
    tags = ['performance']

    def matchtask(self, file, task):
        """Search the task for our concerns."""
        return is_package_action(task) and 'with_items' in task


class TestPassListToPackageModules(unittest.TestCase):
    """Test the PassListToPackageModules lint rule."""
    collection = RulesCollection()

    def setUp(self):
        """Set up the linter testing."""
        self.collection.register(PassListToPackageModules())

    def test_file_positive(self):
        """A valid playbook should pass the linter."""
        playbook = '{}/package_module_pass_list.yml'.format(
            TEST_PLAYBOOK_DIR
        )
        runner = Runner(self.collection, playbook, [], [], [])
        self.assertEqual([], runner.run())

    def test_file_negative(self):
        """An invalid playbook should fail the linter."""
        playbook = '{}/package_module_with_items.yml'.format(
            TEST_PLAYBOOK_DIR
        )
        runner = Runner(self.collection, playbook, [], [], [])
        self.assertNotEqual([], runner.run())


if __name__ == '__main__':
    unittest.main()
