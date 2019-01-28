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
export OSA_PROJECT_NAME="$(sed -n 's|^project=openstack/\(.*\).git$|\1|p' $(pwd)/.gitreview)"
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

# Use pip opts to add options to the pip install command.
# This can be used to tell it which index to use, etc.
export PIP_OPTS=${PIP_OPTS:-""}

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

function setup_ara {

  # Don't do anything if ARA has already been set up
  [[ -L "${ANSIBLE_PLUGIN_DIR}/callback/ara" ]] && return 0

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

if [[ ! -d "${ANSIBLE_PLUGIN_DIR}" ]]; then
  # The plugins repo doesn't need a clone, we can just
  # symlink it.
  if [[ "${OSA_PROJECT_NAME}" == "openstack-ansible-plugins" ]]; then
    ln -s ${WORKING_DIR} "${ANSIBLE_PLUGIN_DIR}"
  else
    git clone \
        https://git.openstack.org/openstack/openstack-ansible-plugins \
        "${ANSIBLE_PLUGIN_DIR}"
  fi
fi

# Ensure we use the HTTPS/HTTP proxy with pip if it is specified
if [ -n "$HTTPS_PROXY" ]; then
  PIP_OPTS+=" --proxy $HTTPS_PROXY"
elif [ -n "$HTTP_PROXY" ]; then
  PIP_OPTS+=" --proxy $HTTP_PROXY"
fi

# Using tox for requirements management requires in-repo
# requirements files for all our repositories. Rather than
# do that, we make use of the tests repo to capture our
# common requirements and use this to install them.
# This reduces our review requirement rate and simplifies
# maintenance for us for the tox config. It also makes it
# usable with 'Depends-On', which is marvellous!

# If the repo has its own test-requirements file, then use
# it with the common one.
if [[ -f "${WORKING_DIR}/test-requirements.txt" ]]; then
  PIP_OPTS+=" --requirement ${WORKING_DIR}/test-requirements.txt"
fi

# We add the common requirements after the in-repo requirements
# so that the in-repo ones take precedence.
PIP_OPTS+=" --requirement ${COMMON_TESTS_PATH}/test-requirements.txt"

# If the repo has a doc/requirements.txt file, add it to the
# requirements list. This is necessary for the linters test
# to be able to execute doc8.
if [[ -f "${WORKING_DIR}/doc/requirements.txt" ]]; then
  PIP_OPTS+=" --requirement ${WORKING_DIR}/doc/requirements.txt"
fi

# We want to install ansible, but also constrain it.
# This is necessary due to ARA having ansible as a
# requirement.
PIP_OPTS+=" --requirement ${COMMON_TESTS_PATH}/test-ansible-deps.txt"
PIP_OPTS+=" --constraint ${COMMON_TESTS_PATH}/test-ansible-deps.txt"

# If Depends-On is used, the integrated repo will be cloned. We
# therefore prefer a local copy over fetching it via a URL.
OSA_INTEGRATED_REPO_HOME="${TESTING_HOME}/src/git.openstack.org/openstack/openstack-ansible"
if [[ -d "${OSA_INTEGRATED_REPO_HOME}" ]]; then
  PIP_OPTS+=" --constraint ${OSA_INTEGRATED_REPO_HOME}/global-requirement-pins.txt"
else
  PIP_OPTS+=" --constraint https://git.openstack.org/cgit/openstack/openstack-ansible/plain/global-requirement-pins.txt"
fi

# We add OpenStack's upper constraints last, as we want all our own
# constraints to take precedence. If Depends-On is used, the requirements
# repo will be cloned, so we prefer a local copy.
REQS_REPO_HOME="${TESTING_HOME}/src/git.openstack.org/openstack/requirements"
if [[ -d "${REQS_REPO_HOME}" ]]; then
  PIP_OPTS+=" --constraint ${REQS_REPO_HOME}/upper-constraints.txt"
else
  PIP_OPTS+=" --constraint ${UPPER_CONSTRAINTS_FILE:-https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt}"
fi

# Install ARA from source if running in ARA gate, otherwise install from PyPi
ARA_SRC_HOME="${TESTING_HOME}/src/git.openstack.org/openstack/ara"
if [[ -d "${ARA_SRC_HOME}" ]]; then
  PIP_OPTS+=" ${ARA_SRC_HOME}"
else
  PIP_OPTS+=" ara"
fi

# Install all python packages
pip install ${PIP_OPTS}

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

# Setup ARA
setup_ara

# Ensure that SElinux bindings are linked into the venv
source /etc/os-release || source /usr/lib/os-release
if [[ ${ID,,} =~ (centos|rhel|fedora) ]]; then
  PYTHON_FOLDER=$(find ${VIRTUAL_ENV}/lib -maxdepth 1 -type d -name "python*")
  SELINUX_FOLDER=$(rpm -ql libselinux-python | egrep '^.*python2.7.*/(site|dist)-packages/selinux$')
  echo "RHEL variant found. Linking ${PYTHON_FOLDER}/site-packages/selinux to ${SELINUX_FOLDER}..."
  ln -sfn ${SELINUX_FOLDER} ${PYTHON_FOLDER}/site-packages/selinux
fi
