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
# This script executes ansible-lint against the role directory.

## Shell Opts ----------------------------------------------------------------

set -e
set -x

## Vars ----------------------------------------------------------------------

export WORKING_DIR=${WORKING_DIR:-$(pwd)}
export COMMON_TESTS_PATH="${WORKING_DIR}/tests/common"
export TEST_PLAYBOOK=${TEST_PLAYBOOK:-$WORKING_DIR/tests/test.yml}
export ANSIBLE_LINT_PARAMS=${ANSIBLE_LINT_PARAMS:-}

echo "TEST_PLAYBOOK: ${TEST_PLAYBOOK}"
echo "ANSIBLE_LINT_PARAMS: ${ANSIBLE_LINT_PARAMS}"

## Main ----------------------------------------------------------------------

# Ensure that the Ansible environment is properly prepared
source "${COMMON_TESTS_PATH}/test-ansible-env-prep.sh"

# Run unit tests for OSA ansible-lint rules
# Only do it if the repository being tested is the openstack-ansible-tests
# repository.
if [[ "$(basename ${WORKING_DIR})" == "openstack-ansible-tests" ]]; then
  python -m unittest discover -s "${WORKING_DIR}/ansible-lint" -p 'Test*.py'
fi

# Execute ansible-lint. We do not want to test dependent roles located
# in $HOME/.ansible/roles since we only care about the role we are currently
# testing.
ANSIBLE_LINT_WARNINGS="-w 204 -w 208 -w 306 -w metadata"
ansible-lint ${ANSIBLE_LINT_PARAMS} ${ANSIBLE_LINT_WARNINGS} --exclude=$HOME/.ansible/roles \
  -R -r ${COMMON_TESTS_PATH}/ansible-lint/ ${TEST_PLAYBOOK}
