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
# This script collects, renames and compresses the logs produced in
# a role test if the host is in OpenStack-CI.

## Vars ----------------------------------------------------------------------

export WORKING_DIR=${WORKING_DIR:-$(pwd)}
export RSYNC_CMD="rsync --archive --verbose --safe-links --ignore-errors"
export ARA_CMD="${WORKING_DIR}/.tox/functional/bin/ara generate html"
export TESTING_HOME=${TESTING_HOME:-$HOME}

## Main ----------------------------------------------------------------------

if [[ -d "/etc/nodepool" ]]; then
  mkdir -p "${WORKING_DIR}/logs/host" "${WORKING_DIR}/logs/openstack"
  ${RSYNC_CMD} /var/log/ "${WORKING_DIR}/logs/host" || true
  ${RSYNC_CMD} /openstack/log/ "${WORKING_DIR}/logs/openstack" || true

  if [ ! -z "${ANSIBLE_LOG_DIR}" ]; then
    mkdir -p "${WORKING_DIR}/logs/ansible"
    ${RSYNC_CMD} "${ANSIBLE_LOG_DIR}/" "${WORKING_DIR}/logs/ansible" || true
  fi

  # Rename all files gathered to have a .txt suffix so that the compressed
  # files are viewable via a web browser in OpenStack-CI.
  find "${WORKING_DIR}/logs/" -type f ! -name '*.html' -exec mv {} {}.txt \;
  # Get the ara sqlite database
  ${RSYNC_CMD} "${TESTING_HOME}/.ara/ansible.sqlite" "${WORKING_DIR}/logs/" || true
  # Generate the ARA report
  ${ARA_CMD} "${WORKING_DIR}/logs/ara" || true
  # output ram usage
  free -m > "${WORKING_DIR}/logs/memory-available.txt" || true
  # Compress the files gathered so that they do not take up too much space.
  # We use 'command' to ensure that we're not executing with some sort of alias.
  command gzip --best --recursive "${WORKING_DIR}/logs/"
fi
