#!/usr/bin/env python
# Copyright 2018, Rackspace US, Inc.
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

try:
    from ansible.module_utils.parsing.convert_bool import boolean
except ImportError:
    try:
        from ansible.utils.boolean import boolean
    except ImportError:
        try:
            from ansible.utils import boolean
        except ImportError:
            from ansible import constants
            boolean = constants.mk_boolean


class NoLogPasswordsRule(ansiblelint.AnsibleLintRule):
    id = "OSA0003"
    shortdesc = "password should not be logged."
    description = (
        "all the modules that take a password argument must fail "
        "if no_log is not set or set to False in the task."
    )
    tags = ["passwords"]

    def matchtask(self, file, task):

        has_password = False
        for param in task["action"].keys():
            if 'password' in param:
                has_password = True
        # No nog_log and no_log: False behave the same way
        # and should return a failure (return True), so we
        # need to invert the boolean
        return has_password and not boolean(task.get('no_log', False))
