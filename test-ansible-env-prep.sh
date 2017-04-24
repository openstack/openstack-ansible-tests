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
# This script prepares the host with all the required Ansible
# roles and plugins to execute the test playbook.

## Shell Opts ----------------------------------------------------------------

set -e

## Vars ----------------------------------------------------------------------

export TESTING_HOME=${TESTING_HOME:-$HOME}
export WORKING_DIR=${WORKING_DIR:-$(pwd)}
export ROLE_NAME=${ROLE_NAME:-''}
export ANSIBLE_INVENTORY=${ANSIBLE_INVENTORY:-$WORKING_DIR/tests/inventory}

export ANSIBLE_CFG_PATH="${TESTING_HOME}/.ansible.cfg"
export ANSIBLE_LOG_DIR="${TESTING_HOME}/.ansible/logs"
export ANSIBLE_NOCOLOR=1
export ANSIBLE_PLUGIN_DIR="${TESTING_HOME}/.ansible/plugins"
export ANSIBLE_ROLE_DIR="${TESTING_HOME}/.ansible/roles"
export ANSIBLE_ROLE_REQUIREMENTS_PATH="${WORKING_DIR}/tests/ansible-role-requirements.yml"
export COMMON_TESTS_PATH="${WORKING_DIR}/tests/common"

echo "TESTING_HOME: ${TESTING_HOME}"
echo "WORKING_DIR: ${WORKING_DIR}"
echo "ROLE_NAME: ${ROLE_NAME}"
echo "ANSIBLE_INVENTORY: ${ANSIBLE_INVENTORY}"

# Output all the zuul parameters if they're set
if [ -z "${ZUUL_CHANGE_IDS}" ]; then
  echo -e "\n### ZUUL PARAMETERS BEGIN ###\n"
  printenv | grep ^ZUUL || true
  echo -e "\n### ZUUL PARAMETERS END ###\n"
fi

# Toggle the reset of all data cloned from other repositories.
export TEST_RESET=${TEST_RESET:-false}

# Make sure that python is not buffering output so that the
# console output is immediate.
export PYTHONUNBUFFERED=1

## Main ----------------------------------------------------------------------

# If the test reset toggle is set, destroy the existing cloned data.
if [ "${TEST_RESET}" == "true" ]; then
  echo "Resetting all cloned data."
  rm -f  "${ANSIBLE_CFG_PATH}"
  rm -rf "${ANSIBLE_LOG_DIR}"
  rm -rf "${ANSIBLE_PLUGIN_DIR}"
  rm -rf "${ANSIBLE_ROLE_DIR}"
fi

# Create the directory which will hold all Ansible logs
mkdir -p "${ANSIBLE_LOG_DIR}"

# Download the Ansible plugins repository if it is not present on the host.
if [ ! -d "${ANSIBLE_PLUGIN_DIR}" ]; then
  git clone https://git.openstack.org/openstack/openstack-ansible-plugins \
              "${ANSIBLE_PLUGIN_DIR}"
fi

# Download the Ansible role repositories if they are not present on the host.
# This is ignored if there is no ansible-role-requirements file.
if [ ! -d "${ANSIBLE_ROLE_DIR}" ] && [ -f "${ANSIBLE_ROLE_REQUIREMENTS_PATH}" ]; then
   ansible-playbook -i ${ANSIBLE_INVENTORY} \
         ${COMMON_TESTS_PATH}/get-ansible-role-requirements.yml \
         -e "toxinidir=${WORKING_DIR} homedir=${TESTING_HOME}" \
         -v
fi


# If a role name is provided, replace the role in the roles folder with a link
# to the current folder. This ensures that the test executes with the checked
# out git repo.
if [ ! -z "${ROLE_NAME}" ]; then
  echo "Linking ${ANSIBLE_ROLE_DIR}/${ROLE_NAME} to ${WORKING_DIR}"
  mkdir -p "${ANSIBLE_ROLE_DIR}"
  rm -rf "${ANSIBLE_ROLE_DIR}/${ROLE_NAME}"
  ln -s "${WORKING_DIR}" "${ANSIBLE_ROLE_DIR}/${ROLE_NAME}"
else
  echo "Skipping the role link because no role name was provided."
fi

# Ensure that the Ansible configuration file is in the right place
if [ ! -f "${ANSIBLE_CFG_PATH}" ]; then
  if [ -f "${COMMON_TESTS_PATH}/test-ansible.cfg" ]; then
    echo "Linking ${ANSIBLE_CFG_PATH} to ${COMMON_TESTS_PATH}/test-ansible.cfg"
    ln -s "${COMMON_TESTS_PATH}/test-ansible.cfg" "${ANSIBLE_CFG_PATH}"
  else
    echo "Skipping the ansible.cfg link because ${COMMON_TESTS_PATH}/test-ansible.cfg is not there!"
  fi
else
  echo "Found ${ANSIBLE_CFG_PATH} so there's nothing more to do."
fi

