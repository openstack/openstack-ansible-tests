#!/usr/bin/env python
# Copyright 2016, Rackspace US, Inc.
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
#


import ansiblelint


class YAMLdictchecker(ansiblelint.AnsibleLintRule):
    id = 'OSA0001'
    shortdesc = 'Please use ":" YAML dictionary format instead of "="'
    description = 'Please follow YAML dictionary format while creating'
    'task and other roles in Ansible'
    'Follow this url for examples of how to use YAML dictionary '
    'format. "https://docs.openstack.org/openstack-ansible/latest/'
    'contribute/contribute.html#ansible-style-guide"'
    tags = ['task']

    def match(self, file, line):
        for l in line.split(" "):
            if "=" in l:
                return True
            return False
