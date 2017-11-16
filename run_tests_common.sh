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

set -o pipefail
set -euov

BINDEP_FILE=${BINDEP_FILE:-bindep.txt}

source /etc/os-release || source /usr/lib/os-release

# Prefer dnf over yum for CentOS.
which dnf &>/dev/null && RHT_PKG_MGR='dnf' || RHT_PKG_MGR='yum'

case "${ID,,}" in
    *suse*)
        # FIXME(hwoarang) workaround for broken rsync.opensuse.org. See
        # https://progress.opensuse.org/issues/27699
        for repo in /etc/zypp/repos.d/*.repo; do
           sudo sed -i "/baseurl/s@\(http://\).*/opensuse\(.*\)@\1download.opensuse.org\2@" $repo
        done
        sudo zypper --non-interactive clean -a
        sudo zypper --no-gpg-checks --non-interactive ref -f
        sudo zypper --no-gpg-checks --non-interactive modifyrepo --all --refresh
        # Need to pull libffi and python-pyOpenSSL early
        # because we install ndg-httpsclient from pip on Leap 42.1
        [[ "${VERSION}" == "42.1" ]] && extra_suse_deps="libffi-devel python-pyOpenSSL"
        sudo zypper -n in python-devel lsb-release ${extra_suse_deps:-}
        ;;
    amzn|centos|rhel)
        sudo $RHT_PKG_MGR install -y python-devel redhat-lsb-core epel-release yum-utils
        ;;
    fedora)
        sudo dnf install -y python-devel redhat-lsb-core redhat-rpm-config yum-utils
        ;;
    ubuntu|debian)
        sudo apt-get update && sudo apt-get install -y python-dev lsb-release
        ;;
    *)
        echo "Unsupported distribution: ${ID,,}"
        exit 1
esac

# Install pip
if ! which pip &>/dev/null; then
    curl --silent --show-error --retry 5 \
        https://bootstrap.pypa.io/get-pip.py | sudo python2.7
fi

# Install bindep and tox
sudo pip install 'bindep>=2.4.0' tox

if [[ ${ID,,} == "centos" ]]; then
    # epel-release could be installed but not enabled (which is very common
    # in openstack-ci) so enable it here if needed
    sudo yum-config-manager --enable epel > /dev/null || true
elif [[ ${ID,,} == "fedora" ]]; then
    sudo dnf -y install redhat-lsb-core yum-utils
# openSUSE 42.1 does not have python-ndg-httpsclient
elif [[ ${ID,,} == *suse* ]] && [[ ${VERSION} == "42.1" ]]; then
    sudo pip install ndg-httpsclient
fi

# Get a list of packages to install with bindep. If packages need to be
# installed, bindep exits with an exit code of 1.
BINDEP_PKGS=$(bindep -b -f ${BINDEP_FILE} test || true)
echo "Packages to install: ${BINDEP_PKGS}"

# Install OS packages using bindep
if [[ ${#BINDEP_PKGS} > 0 ]]; then
    case "${ID,,}" in
        *suse*)
            sudo zypper -n in $BINDEP_PKGS
            ;;
        centos|fedora)
            sudo $RHT_PKG_MGR install -y $BINDEP_PKGS
            ;;
        ubuntu|debian)
            sudo apt-get update
            DEBIAN_FRONTEND=noninteractive \
                sudo apt-get -q --option "Dpkg::Options::=--force-confold" \
                --assume-yes install $BINDEP_PKGS
            ;;
    esac
fi

# Get envlist in a $env1,$env2,...,$envn format
toxenvs="$(tox -l | tr '\n' ',' | sed 's/,$//')"

# Execute all $toxenvs or only a specific one
tox -e "${1:-$toxenvs}"

# vim: set ts=4 sw=4 expandtab:
