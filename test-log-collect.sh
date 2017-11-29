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
export TESTING_HOME=${TESTING_HOME:-$HOME}

export RSYNC_CMD="rsync --archive --safe-links --ignore-errors --quiet --no-perms --no-owner --no-group"

# NOTE(cloudnull): This is a very simple list of common directories in /etc we
#                  wish to search for when storing gate artifacts. When adding
#                  things to this list please alphabetize the entries so it's
#                  easy for folks to find and adjust items as needed.
COMMON_ETC_LOG_NAMES="apt \
                      aodh \
                      barbican \
                      ceilometer \
                      cinder \
                      designate \
                      glance \
                      gnocchi \
                      haproxy \
                      heat \
                      horizon \
                      ironic \
                      keystone \
                      magnum \
                      memcached \
                      molteniron \
                      my.cnf \
                      mysql \
                      network \
                      nginx \
                      neutron \
                      nova \
                      octavia \
                      rabbitmq \
                      rally \
                      repo \
                      rsyslog \
                      sahara \
                      swift \
                      sysconfig/network-scripts \
                      sysconfig/network \
                      tacker \
                      tempest \
                      trove \
                      yum \
                      zypp"

## Functions -----------------------------------------------------------------

function store_artifacts {
  # Store known artifacts only if they exist. If the target directory does
  # exist, it will be created.
  # USAGE: store_artifacts /src/to/artifacts /path/to/store
  if [[ -e "${1}" ]]; then
    if [[ ! -d "${2}" ]]; then
      mkdir -vp "${2}"
    fi
    echo "Running artifact sync for \"${1}\" to \"${2}\""
    sudo ${RSYNC_CMD} ${1} ${2} || true
  fi
}

## Main ----------------------------------------------------------------------

echo "#### BEGIN LOG COLLECTION ###"

mkdir -vp "${WORKING_DIR}/logs"

# Gather basic logs
store_artifacts /openstack/log/ansible-logging/ "${WORKING_DIR}/logs/ansible"
store_artifacts /openstack/log/ "${WORKING_DIR}/logs/openstack"
store_artifacts /var/log/ "${WORKING_DIR}/logs/host"

# Get the ara sqlite database
store_artifacts "${TESTING_HOME}/.ara/ansible.sqlite" "${WORKING_DIR}/logs/ara/"

# Gather host etc artifacts
for service in ${COMMON_ETC_LOG_NAMES}; do
    store_artifacts "/etc/${service}" "${WORKING_DIR}/logs/etc/host/"
done

# Gather container etc artifacts
if which lxc-ls &> /dev/null; then
 for CONTAINER_NAME in $(sudo lxc-ls -1); do
   CONTAINER_PID=$(sudo lxc-info -p -n ${CONTAINER_NAME} | awk '{print $2}')
   ETC_DIR="/proc/${CONTAINER_PID}/root/etc"
   LOG_DIR="/proc/${CONTAINER_PID}/root/var/log"
   for service in ${COMMON_ETC_LOG_NAMES}; do
      store_artifacts ${ETC_DIR}/${service} "${WORKING_DIR}/logs/etc/openstack/${CONTAINER_NAME}/"
      store_artifacts ${LOG_DIR}/${service} "${WORKING_DIR}/logs/openstack/${CONTAINER_NAME}/"
   done
 done
fi

# NOTE(mhayden): All of the files must be world-readable so that the log
# pickup jobs will work properly. Without this, you get a "File not found"
# when trying to read the files in the job results.
# NOTE(odyssey4me): Using '--chown $(whoami) --chmod=ugo+rX' in the rsync
# CMD to achieve this would be optimal, but the CentOS version of rsync
# (3.0.x) does not support that option.
sudo chmod -R ugo+rX "${WORKING_DIR}/logs/"
sudo chown -R $(whoami) "${WORKING_DIR}/logs/"

# Rename all files gathered to have a .txt suffix so that the compressed
# files are viewable via a web browser in OpenStack-CI.
find "${WORKING_DIR}/logs/" -type f ! -name '*.html' -exec mv {} {}.txt \;

# Figure out the correct path for ARA
# As this script is not run through tox, and the tox envs are all
# different names, we need to try and find the right path to execute
# ARA from.
ARA_CMD="$(find ${WORKING_DIR}/.tox -path "*/bin/ara" -type f | head -n 1)"

# If we could not find ARA, assume it was not installed
# and skip all the related activities.
if [[ "${ARA_CMD}" != "" ]]; then
    # Generate the ARA report
    # In order to reduce the quantity of unnecessary log content
    # being kept in OpenStack-Infra we only generate the ARA report
    # when the test result is a failure. The ARA sqlite database is
    # still available for self generation if desired for successful
    # tests.
    mkdir -vp "${WORKING_DIR}/logs/ara"
    if [[ "${TEST_EXIT_CODE}" != "0" ]] && [[ "${TEST_EXIT_CODE}" != "true" ]]; then
        echo "Generating ARA report."
        ${ARA_CMD} generate html "${WORKING_DIR}/logs/ara" || true
    else
        echo "Not generating ARA report."
    fi

    # We still want the subunit report though, as that reflects
    # success/failure in OpenStack Health
    ${ARA_CMD} generate subunit "${WORKING_DIR}/logs/ara/testrepository.subunit" || true
fi

# Get a dmesg output so we can look for kernel failures
dmesg > "${WORKING_DIR}/logs/dmesg.log.txt" || true

# output ram usage
free -m > "${WORKING_DIR}/logs/memory-available.txt" || true

# Redhat package debugging
if which yum &>/dev/null || which dnf &>/dev/null; then
    # Prefer dnf over yum for CentOS.
    which dnf &>/dev/null && RHT_PKG_MGR='dnf' || RHT_PKG_MGR='yum'
    sudo $RHT_PKG_MGR repolist -v > "${WORKING_DIR}/logs/redhat-rpm-repolist.txt" || true
    sudo $RHT_PKG_MGR list installed > "${WORKING_DIR}/logs/redhat-rpm-list-installed.txt" || true

# SUSE package debugging
elif which zypper &>/dev/null; then
    sudo zypper lr -d > "${WORKING_DIR}/logs/suse-zypper-repolist.txt" || true
    sudo zypper pa -i > "${WORKING_DIR}/logs/suse-zypper-list-installed.txt" || true

# Ubuntu package debugging
elif which apt-get &> /dev/null; then
    sudo apt-cache policy | grep http | awk '{print $1" "$2" "$3}' | sort -u > "${WORKING_DIR}/logs/ubuntu-apt-repolist.txt" || true
    sudo apt list --installed > "${WORKING_DIR}/logs/ubuntu-apt-list-installed.txt" || true
fi

# Record the active interface configs
for interface in $(ip -o link | awk -F':' '{print $2}'); do
    if which ethtool &> /dev/null; then
        ethtool -k ${interface} > "${WORKING_DIR}/logs/ethtool-${interface}-cfg.txt"
    else
        echo "No ethtool available" | tee -a "${WORKING_DIR}/logs/no-ethtool.txt"
    fi
done

# Compress the files gathered so that they do not take up too much space.
# We use 'command' to ensure that we're not executing with some sort of alias.
command gzip --best --recursive "${WORKING_DIR}/logs/"

echo "#### END LOG COLLECTION ###"

