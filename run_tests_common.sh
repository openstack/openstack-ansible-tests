#!/usr/bin/env bash
# Copyright 2015, Rackspace US, Inc.
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

set -o pipefail
set -xeuo

## Prerequisite check --------------------------------------------------------

# Check whether the require environment variables are set.
if [[ -z ${WORKING_DIR+x} ]] ||\
   [[ -z ${COMMON_TESTS_PATH+x} ]] ||\
   [[ -z ${TESTING_HOME+x} ]] ||\
   [[ -z ${TESTING_BRANCH+x} ]] ||\
   [[ -z ${pkg_mgr_cmd+x} ]] ||\
   [[ -z ${ID+x} ]] ||\
   [[ -z ${VERSION+x} ]]; then
     echo "Required environment variables are not set."
     echo "Please ensure that run_tests.sh is used to execute tests."
     exit 1
fi

## Vars ----------------------------------------------------------------------

# The bindep file contains the basic distribution packages
# required in order to install pip, and ansible via pip.
BINDEP_FILE=${BINDEP_FILE:-bindep.txt}

## Main ----------------------------------------------------------------------

# Perform the initial distribution package install
# to allow pip and bindep to work.
case "${ID,,}" in
    rocky)
        pkg_list="python38 python38-devel redhat-lsb-core"
       ;;
    amzn|centos|rhel)
        case ${VERSION_ID} in
            8)
                pkg_list="python38 python38-devel redhat-lsb-core"
                ;;
            9)
                pkg_list="python3 python3-devel redhat-lsb-core"
               ;;
        esac
        ;;
    ubuntu|debian)
        pkg_list="python3-dev python3-pip virtualenv lsb-release curl"
        sudo apt-get update
        ;;
    *)
        echo "Unsupported distribution: ${ID,,}"
        exit 1
        ;;
esac
eval sudo ${pkg_mgr_cmd} ${pkg_list}

PIP_EXEC_PATH=$(which pip3 || which pip)

if [[ "${ID,,}" == "centos" ]] && [[ ${VERSION_ID} == "8" ]]; then
    sudo alternatives --set python3 /usr/bin/python3.8
fi

# Install bindep and tox
sudo "${PIP_EXEC_PATH}" install 'bindep>=2.4.0' tox

if [[ "${ID,,}" == "fedora" ]]; then
    sudo dnf -y install redhat-lsb-core yum-utils
fi

# Get a list of packages to install with bindep. If packages need to be
# installed, bindep exits with an exit code of 1.
BINDEP_PKGS=$(bindep -b -f "${BINDEP_FILE}" test || true)
echo "Packages to install: ${BINDEP_PKGS}"

# Install OS packages using bindep
if [[ ${#BINDEP_PKGS} > 0 ]]; then
    case "${ID,,}" in
        centos|fedora|rhel|rocky)
            sudo dnf install -y ${BINDEP_PKGS}
            ;;
        ubuntu|debian)
            sudo apt-get update
            sudo DEBIAN_FRONTEND=noninteractive \
                apt-get -q --option "Dpkg::Options::=--force-confold" \
                --assume-yes install ${BINDEP_PKGS}
            ;;
    esac
fi

# Get envlist in a $env1,$env2,...,$envn format
toxenvs="$(tox -l | tr '\n' ',' | sed 's/,$//')"

# Execute all $toxenvs or only a specific one
tox -e "${1:-$toxenvs}"

# vim: set ts=4 sw=4 expandtab:
