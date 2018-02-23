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


class APTRepositoryCacheUpdateRule(ansiblelint.AnsibleLintRule):
    id = "OSA0002"
    shortdesc = "apt_repository update_cache should be disabled."
    description = (
        "apt_repository cache updates silently fail when a task is retried. "
        "Disable cache updates by setting `update_cache: no` and use a "
        "separate apt task to update the APT cache. This bug is tracked by "
        "https://github.com/ansible/ansible/issues/36605."
    )
    tags = ["bug"]

    def matchtask(self, file, task):
        module = task["action"]["__ansible_module__"]
        update_cache_enabled = task["action"].get("update_cache", True)

        return module == "apt_repository" and update_cache_enabled
