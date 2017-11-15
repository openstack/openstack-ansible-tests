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
# This script executes ansible-syntax against the role test playbook.

## Shell Opts ----------------------------------------------------------------

set -e

## Vars ----------------------------------------------------------------------

export WORKING_DIR=${WORKING_DIR:-$(pwd)}
export COMMON_TESTS_PATH="${WORKING_DIR}/tests/common"
export ANSIBLE_INVENTORY=${ANSIBLE_INVENTORY:-$WORKING_DIR/tests/inventory}
export TEST_PLAYBOOK=${TEST_PLAYBOOK:-$WORKING_DIR/tests/test.yml}

## Main ----------------------------------------------------------------------

# Ensure that the Ansible environment is properly prepared
source "${COMMON_TESTS_PATH}/test-ansible-env-prep.sh"

# Execute the Ansible syntax check
ansible-playbook --syntax-check \
                 --list-tasks \
                 ${TEST_PLAYBOOK}
