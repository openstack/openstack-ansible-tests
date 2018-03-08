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
export ANSIBLE_ROLE_REQUIREMENTS_PATH=${ANSIBLE_ROLE_REQUIREMENTS_PATH:-$WORKING_DIR/tests/ansible-role-requirements.yml}
export ANSIBLE_EXTRA_ROLE_DIRS=${ANSIBLE_EXTRA_ROLE_DIRS:-''}

export ANSIBLE_CFG_PATH="${TESTING_HOME}/.ansible.cfg"
export ANSIBLE_LOG_DIR="${TESTING_HOME}/.ansible/logs"
export ANSIBLE_NOCOLOR=1
export ANSIBLE_PLUGIN_DIR="${TESTING_HOME}/.ansible/plugins"
export ANSIBLE_ROLE_DEP_DIR="${TESTING_HOME}/.ansible/roles"
export ANSIBLE_ROLE_DIR="${TESTING_HOME}/.ansible/testing-role"
export COMMON_TESTS_PATH="${WORKING_DIR}/tests/common"
export OSA_OPS_DIR="${WORKING_DIR}/openstack-ansible-ops"

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

## Functions -----------------------------------------------------------------

function create_plugins_clonemap {

# Prepare the clonemap for zuul-cloner to use
cat > ${TESTING_HOME}/plugins-clonemap.yaml << EOF
clonemap:
  - name: openstack/openstack-ansible-plugins
    dest: ${ANSIBLE_PLUGIN_DIR}
  - name: openstack/openstack-ansible-ops
    dest: ${OSA_OPS_DIR}
EOF

}

function setup_ara {

  # Don't do anything if ARA has already been set up
  [[ -L "${ANSIBLE_PLUGIN_DIR}/callback/ara" ]] && return 0

  # Install ARA from source if running in ARA gate, otherwise install from PyPi
  ARA_SRC_HOME="${TESTING_HOME}/src/git.openstack.org/openstack/ara"
  if [[ -d "${ARA_SRC_HOME}" ]]; then
    pip install \
      --constraint "${COMMON_TESTS_PATH}/test-ansible-deps.txt" \
      --constraint ${UPPER_CONSTRAINTS_FILE:-https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt} \
      "${ARA_SRC_HOME}"
  else
    pip install \
      --constraint "${COMMON_TESTS_PATH}/test-ansible-deps.txt" \
      --constraint ${UPPER_CONSTRAINTS_FILE:-https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt} \
      ara
  fi

  # Dynamically figure out the location of ARA (ex: py2 vs py3)
  ara_location=$(python -c "import os,ara; print(os.path.dirname(ara.__file__))")

  echo "Linking ${ANSIBLE_PLUGIN_DIR}/callback/ara to ${ara_location}/plugins/callbacks/"
  mkdir -p "${ANSIBLE_PLUGIN_DIR}/callback/ara"
  ln -sf "${ara_location}/plugins/callbacks" "${ANSIBLE_PLUGIN_DIR}/callback/ara/"

}

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

# If zuul-cloner is present, use it so that we
# also include any dependent patches from the
# plugins repo noted in the commit message.
# We only want to use zuul-cloner if we detect
# zuul v2 running, so we check for the presence
# of the ZUUL_REF environment variable.
# ref: http://git.openstack.org/cgit/openstack-infra/zuul/tree/zuul/ansible/filter/zuul_filters.py?h=feature/zuulv3#n17
if [[ -x /usr/zuul-env/bin/zuul-cloner ]] && [[ "${ZUUL_REF:-none}" != "none" ]]; then

    # Prepare the clonemap for zuul-cloner to use
    create_plugins_clonemap

    # Execute the clone
    /usr/zuul-env/bin/zuul-cloner \
        --cache-dir /opt/git \
        --map ${TESTING_HOME}/plugins-clonemap.yaml \
        git://git.openstack.org \
        openstack/openstack-ansible-plugins \
        openstack/openstack-ansible-ops

    # Clean up the clonemap.
    rm -f ${TESTING_HOME}/plugins-clonemap.yaml

# Alternatively, use a simple git-clone. We do
# not re-clone if the directory exists already
# to prevent overwriting any local changes which
# may have been made.
else
    if [[ ! -d "${ANSIBLE_PLUGIN_DIR}" ]]; then
        # The plugins repo doesn't need a clone, we can just
        # symlink it. As zuul v3 clones into a folder called
        # 'workspace' we have to use one of its environment
        # variables to determine the project name.
        if [[ "${ZUUL_SHORT_PROJECT_NAME:-none}" == "openstack-ansible-plugins" ]] ||\
           [[ "$(basename ${WORKING_DIR})" == "openstack-ansible-plugins" ]]; then
            ln -s ${WORKING_DIR} "${ANSIBLE_PLUGIN_DIR}"
        else
            git clone \
                https://git.openstack.org/openstack/openstack-ansible-plugins \
                "${ANSIBLE_PLUGIN_DIR}"
        fi
    fi

    if [[ ! -d "${OSA_OPS_DIR}" ]]; then
        # The ops repo doesn't need a clone, we can just
        # symlink it. As zuul v3 clones into a folder called
        # 'workspace' we have to use one of its environment
        # variables to determine the project name.
        if [[ "${ZUUL_SHORT_PROJECT_NAME:-none}" == "openstack-ansible-ops" ]] ||\
           [[ "$(basename ${WORKING_DIR})" == "openstack-ansible-ops" ]]; then
            ln -s ${WORKING_DIR} "${OSA_OPS_DIR}"
        else
            git clone \
                https://git.openstack.org/openstack/openstack-ansible-ops \
                "${OSA_OPS_DIR}"
        fi
    fi
fi

# Download the Ansible role repositories if they are not present on the host.
# This is ignored if there is no ansible-role-requirements file.
if [[ ! -d "${ANSIBLE_ROLE_DEP_DIR}" ]]; then
  # Download the common test Ansible role repositories.
  ANSIBLE_ROLE_REQUIREMENTS_PATH=${COMMON_TESTS_PATH}/test-ansible-role-requirements.yml \
    ansible-playbook -i ${ANSIBLE_INVENTORY} \
    ${COMMON_TESTS_PATH}/get-ansible-role-requirements.yml \
    -v

  if [[ -f "${ANSIBLE_ROLE_REQUIREMENTS_PATH}" ]]; then
     ansible-playbook -i ${ANSIBLE_INVENTORY} \
           ${COMMON_TESTS_PATH}/get-ansible-role-requirements.yml \
           -v
    if [[ ! -e "${ANSIBLE_ROLE_DEP_DIR}/plugins" ]]; then
      ln -s "${ANSIBLE_PLUGIN_DIR}" "${ANSIBLE_ROLE_DEP_DIR}/plugins"
    fi
  fi
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

# Adjust the Ansible configuration file to include the extra
# role paths if any are provided and they're not already set.
if [ ! -z "${ANSIBLE_EXTRA_ROLE_DIRS}" ]; then
  if ! grep -q "roles_path.*${ANSIBLE_EXTRA_ROLE_DIRS}" "${ANSIBLE_CFG_PATH}"; then
    sed -i "s|roles_path.*HOME/.ansible/roles.*|roles_path       = $HOME/.ansible/roles:${ANSIBLE_ROLE_DIR}:${ANSIBLE_EXTRA_ROLE_DIRS}|" "${ANSIBLE_CFG_PATH}"
  fi
fi

setup_ara
