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
# This script executes a test Ansible playbook for the purpose of
# functionally testing the role. It supports a convergence test,
# check mode and an idempotence test.

## Shell Opts ----------------------------------------------------------------

set -e

## Vars ----------------------------------------------------------------------
# Source distribution information
source /etc/os-release || source /usr/lib/os-release

#TODO: cleanup on ansible 2.10 if debian is in config/base.yml
if [ "${ID}" == "debian" ] && [ "${VERSION_ID}" == "10" ]; then
  ANSIBLE_PYTHON_INTERPRETER="/usr/bin/python3"
fi

export ANSIBLE_PYTHON_INTERPRETER=${ANSIBLE_PYTHON_INTERPRETER:-auto}

export TESTING_HOME=${TESTING_HOME:-$HOME}
export WORKING_DIR=${WORKING_DIR:-$(pwd)}
export ROLE_NAME=${ROLE_NAME:-''}

export ANSIBLE_REMOTE_TEMP="/tmp"
export ANSIBLE_OVERRIDES=${ANSIBLE_OVERRIDES:-$WORKING_DIR/tests/$ROLE_NAME-overrides.yml}
export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-""}
export TEST_PLAYBOOK=${TEST_PLAYBOOK:-$WORKING_DIR/tests/test.yml}
export TEST_CHECK_MODE=${TEST_CHECK_MODE:-false}
export TEST_IDEMPOTENCE=${TEST_IDEMPOTENCE:-false}

export COMMON_TESTS_PATH="${WORKING_DIR}/tests/common"

echo "ANSIBLE_OVERRIDES: ${ANSIBLE_OVERRIDES}"
echo "ANSIBLE_PARAMETERS: ${ANSIBLE_PARAMETERS}"
echo "TEST_PLAYBOOK: ${TEST_PLAYBOOK}"
echo "TEST_CHECK_MODE: ${TEST_CHECK_MODE}"
echo "TEST_IDEMPOTENCE: ${TEST_IDEMPOTENCE}"
echo "ANSIBLE_PYTHON_INTERPRETER: ${ANSIBLE_PYTHON_INTERPRETER}"

## Functions -----------------------------------------------------------------

function set_ansible_parameters {

  if [ -f "${ANSIBLE_OVERRIDES}" ]; then
    ANSIBLE_CLI_PARAMETERS="${ANSIBLE_PARAMETERS} -e @${ANSIBLE_OVERRIDES}"
  else
    ANSIBLE_CLI_PARAMETERS="${ANSIBLE_PARAMETERS}"
  fi

}

function execute_ansible_playbook {

  CMD_TO_EXECUTE="ansible-playbook ${TEST_PLAYBOOK} $@ ${ANSIBLE_CLI_PARAMETERS}"
  echo "Executing: ${CMD_TO_EXECUTE}"
  echo "With:"
  echo "    ANSIBLE_INVENTORY: ${ANSIBLE_INVENTORY}"
  echo "    ANSIBLE_LOG_PATH: ${ANSIBLE_LOG_PATH}"

  ${CMD_TO_EXECUTE}

}

## Main ----------------------------------------------------------------------
source /etc/os-release

# Check if SELinux is present and which mode is currently set.
if [[ -x /usr/sbin/getenforce ]]; then
  SELINUX_STATUS=$(/usr/sbin/getenforce)
else
  SELINUX_STATUS="Unavailable"
fi
echo "Current SELinux status: ${SELINUX_STATUS}"

# NOTE(mhayden): SELinux policies for CentOS are still incomplete. Ensure
# SELinux is not in enforcing mode during tests.
if [ "${SELINUX_STATUS}" == "Enforcing" ]; then
  echo "NOTE: CentOS SELinux policies are incomplete."
  echo "Switching SELinux mode from Enforcing to Permissive."
  sudo /usr/sbin/setenforce 0
fi

# Ensure that the Ansible environment is properly prepared
source "${COMMON_TESTS_PATH}/test-ansible-env-prep.sh"

# Prepare the extra CLI parameters used in each execution
set_ansible_parameters

# If the test for check mode is enabled, then execute it
if [ "${TEST_CHECK_MODE}" == "true" ]; then

  # Set the path for the output log
  export ANSIBLE_LOG_PATH="${ANSIBLE_LOG_DIR}/ansible-check.log"

  # Execute the test playbook in check mode
  execute_ansible_playbook --check

fi

# Set the path for the output log
export ANSIBLE_LOG_PATH="${ANSIBLE_LOG_DIR}/ansible-execute.log"

# Execute the test playbook
execute_ansible_playbook

# If the idempotence test is enabled, then execute the
# playbook again and verify that nothing changed/failed
# in the output log.

if [ "${TEST_IDEMPOTENCE}" == "true" ]; then

  # Set the path for the output log
  export ANSIBLE_LOG_PATH="${ANSIBLE_LOG_DIR}/ansible-idempotence.log"

  # Execute the test playbook
  execute_ansible_playbook

  # Exit with a failure if we find "changed" or "failed" followed by anything
  # other than a zero.
  if grep -qP '(changed|failed)=(?!0)' ${ANSIBLE_LOG_PATH}; then
    echo "Idempotence test: fail"
    exit 1
  else
    echo "Idempotence test: pass"
  fi

fi
