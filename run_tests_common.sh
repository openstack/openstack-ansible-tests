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

# Set the source branch for upgrade tests
# Be sure to change this whenever a new stable branch
# is created. The checkout must always be N-1.
UPGRADE_SOURCE_BRANCH=${UPGRADE_SOURCE_BRANCH:-'stable/queens'}

# The bindep file contains the basic distribution packages
# required in order to install pip, and ansible via pip.
BINDEP_FILE=${BINDEP_FILE:-bindep.txt}

## Main ----------------------------------------------------------------------

# If this test set includes an upgrade test, the
# previous stable release tests repo must also be
# cloned.
# Note:
# Dependent patches to the previous stable release
# tests repo are not supported.
if [[ ! -d "${COMMON_TESTS_PATH}/previous" ]]; then
  git clone -b ${UPGRADE_SOURCE_BRANCH} \
      https://git.openstack.org/openstack/openstack-ansible-tests \
      ${COMMON_TESTS_PATH}/previous
fi

# Perform the initial distribution package install
# to allow pip and bindep to work.
case "${ID,,}" in
    *suse*)
        # Need to pull libffi and python-pyOpenSSL early
        # because we install ndg-httpsclient from pip on Leap 42.1
        [[ "${VERSION}" == "42.1" ]] && extra_suse_deps="libffi-devel python-pyOpenSSL"
        pkg_list="ca-certificates-mozilla python-devel python-xml lsb-release ${extra_suse_deps:-}"
        ;;
    amzn|centos|rhel)
        pkg_list="python-devel redhat-lsb-core yum-utils"
        ;;
    fedora)
        pkg_list="python-devel redhat-lsb-core redhat-rpm-config yum-utils"
        ;;
    ubuntu|debian)
        pkg_list="python-dev lsb-release"
        sudo apt-get update
        ;;
    gentoo)
        sudo emaint-sync -A
        ;;
    *)
        echo "Unsupported distribution: ${ID,,}"
        exit 1
        ;;
esac
eval sudo ${pkg_mgr_cmd} ${pkg_list}

# Install pip
if ! which pip &>/dev/null; then
    curl --silent --show-error --retry 5 \
        https://bootstrap.pypa.io/pip/3.3/get-pip.py | sudo python2.7
fi

# Install bindep and tox
sudo pip install 'bindep>=2.4.0' tox

if [[ "${ID,,}" == "fedora" ]]; then
    sudo dnf -y install redhat-lsb-core yum-utils
# openSUSE 42.1 does not have python-ndg-httpsclient
elif [[ "${ID,,}" == *suse* ]] && [[ ${VERSION} == "42.1" ]]; then
    sudo pip install ndg-httpsclient
fi

# Get a list of packages to install with bindep. If packages need to be
# installed, bindep exits with an exit code of 1.
BINDEP_PKGS=$(bindep -b -f "${BINDEP_FILE}" test || true)
echo "Packages to install: ${BINDEP_PKGS}"

# Install OS packages using bindep
if [[ ${#BINDEP_PKGS} > 0 ]]; then
    case "${ID,,}" in
        *suse*)
            sudo zypper -n in ${BINDEP_PKGS}
            ;;
        centos|fedora)
            sudo "${RHT_PKG_MGR}" install -y ${BINDEP_PKGS}
            ;;
        ubuntu|debian)
            sudo apt-get update
            DEBIAN_FRONTEND=noninteractive \
                sudo apt-get -q --option "Dpkg::Options::=--force-confold" \
                --assume-yes install ${BINDEP_PKGS}
            ;;
        gentoo)
            sudo emerge -q --jobs="$(nrpoc)" ${BINDEP_PKGS}
            ;;
    esac
fi

# Get envlist in a $env1,$env2,...,$envn format
toxenvs="$(tox -l | tr '\n' ',' | sed 's/,$//')"

# Execute all $toxenvs or only a specific one
tox -e "${1:-$toxenvs}"

# vim: set ts=4 sw=4 expandtab:
