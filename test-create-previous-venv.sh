#!/bin/bash
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

## Shell Opts ----------------------------------------------------------------

set -e

## Vars ----------------------------------------------------------------------

export WORKING_DIR=${WORKING_DIR:-$(pwd)}
export PREVIOUS_VENV=${PREVIOUS_VENV:-"ansible-previous"}


pushd ${WORKING_DIR}/.tox
  virtualenv ${PREVIOUS_VENV}
  ${PREVIOUS_VENV}/bin/pip install -c https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=stable/pike \
    -rhttps://git.openstack.org/cgit/openstack/openstack-ansible/plain/global-requirement-pins.txt?h=stable/pike \
    -r${WORKING_DIR}/tests/common/previous/test-ansible-deps.txt ara
  # Display venv contents
  ${PREVIOUS_VENV}/bin/pip freeze
popd
