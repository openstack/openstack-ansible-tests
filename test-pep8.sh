#!/usr/bin/env bash

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

# WARNING:
# This file is use by all OpenStack-Ansible roles for testing purposes.
# Any changes here will affect all OpenStack-Ansible role repositories
# with immediate effect.

# PURPOSE:
# This script executes flake8 against all the files it find that match
# the search pattern. The search pattern is meant to find any python
# scripts present in the role.

export WORKING_DIR=${WORKING_DIR:-$(pwd)}

grep --recursive --binary-files=without-match \
        --files-with-match '^.!.*python$' \
        --exclude-dir .eggs \
        --exclude-dir .git \
        --exclude-dir .tox \
        --exclude-dir *.egg-info \
        --exclude-dir doc \
        "${WORKING_DIR}" | xargs flake8 --verbose
