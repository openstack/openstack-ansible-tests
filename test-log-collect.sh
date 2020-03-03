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

export RSYNC_CMD="rsync --archive --safe-links --ignore-errors --quiet --no-perms --no-owner --no-group --whole-file --inplace"

# NOTE(cloudnull): This is a very simple list of common directories in /etc we
#                  wish to search for when storing gate artifacts. When adding
#                  things to this list please alphabetize the entries so it's
#                  easy for folks to find and adjust items as needed.
COMMON_ETC_LOG_NAMES="almanach \
                      apt \
                      aodh \
                      apache2 \
                      barbican \
                      blazar \
                      ceilometer \
                      cinder \
                      cloudkitty \
                      congress \
                      designate \
                      glance \
                      gnocchi \
                      haproxy \
                      heat \
                      horizon \
                      httpd \
                      ironic \
                      karbor \
                      keystone \
                      magnum \
                      memcached \
                      molteniron \
                      monasca \
                      mongodb \
                      my.cnf \
                      mysql \
                      netplan \
                      network \
                      nginx \
                      neutron \
                      nova \
                      octavia \
                      panko \
                      pip.conf \
                      qpid-dispatch \
                      rabbitmq \
                      rally \
                      repo \
                      resolv.conf \
                      rsyslog \
                      sahara \
                      searchlight \
                      sasl2 \
                      swift \
                      sysconfig/network-scripts \
                      sysconfig/network \
                      systemd/network \
                      tacker \
                      tempest \
                      trove \
                      watcher \
                      yum \
                      yum.repos.d \
                      zaqar \
                      zun \
                      zypp"

## Functions -----------------------------------------------------------------

function repo_information {
    [[ "${1}" != "host" ]] && lxc_cmd="lxc-attach --name ${1} --" || lxc_cmd=""
    echo "Collecting list of installed packages and enabled repositories for \"${1}\""
    # Redhat package debugging
    if eval sudo ${lxc_cmd} which yum &>/dev/null || eval sudo ${lxc_cmd} which dnf &>/dev/null; then
        # Prefer dnf over yum for CentOS.
        eval sudo ${lxc_cmd} which dnf &>/dev/null && RHT_PKG_MGR='dnf' || RHT_PKG_MGR='yum'
        eval sudo ${lxc_cmd} $RHT_PKG_MGR repolist -v > "${WORKING_DIR}/logs/redhat-rpm-repolist-${1}.txt" || true
        eval sudo ${lxc_cmd} $RHT_PKG_MGR list installed > "${WORKING_DIR}/logs/redhat-rpm-list-installed-${1}.txt" || true

    # SUSE package debugging
    elif eval sudo ${lxc_cmd} which zypper &>/dev/null; then
        eval sudo ${lxc_cmd} zypper lr -d > "${WORKING_DIR}/logs/suse-zypper-repolist-${1}.txt" || true
        eval sudo ${lxc_cmd} zypper --disable-repositories pa -i > "${WORKING_DIR}/logs/suse-zypper-list-installed-${1}.txt" || true

    # Ubuntu package debugging
    elif eval sudo ${lxc_cmd} which apt-get &> /dev/null; then
        eval sudo ${lxc_cmd} apt-cache policy | grep http | awk '{print $1" "$2" "$3}' | sort -u > "${WORKING_DIR}/logs/ubuntu-apt-repolist-${1}.txt" || true
        eval sudo ${lxc_cmd} apt list --installed > "${WORKING_DIR}/logs/ubuntu-apt-list-installed-${1}.txt" || true
    fi
}

function store_artifacts {
  # Store known artifacts only if they exist. If the target directory does
  # exist, it will be created.
  # USAGE: store_artifacts /src/to/artifacts /path/to/store
  if sudo test -e "${1}"; then
    if [[ ! -d "${2}" ]]; then
      mkdir -vp "${2}"
    fi
    echo "Running artifact sync for \"${1}\" to \"${2}\""
    sudo ${RSYNC_CMD} ${1} ${2} || true
  fi
}

function store_journal_artifacts {
  # Store lines from a known unit's journal as a plain-text log file.
  # USAGE: store_journal_artifacts UNIT_TO_MATCH /path/to/store
  if [ $? == 0 ]; then
    if [[ ! -d "${2}" ]]; then
      mkdir -vp "${2}"
    fi
    if [[ ${3:-false} != false ]]; then
      if [[ -f "/var/log/journal/${3}/system.journal" ]]; then
        SYSTEMD_UNITS=$(sudo journalctl --file="/var/log/journal/${3}/system.journal" \
                                        --output=json-pretty | grep -w UNIT | sort -u | awk -F'"' '{print $4}' | grep "${1}")
        for service_unit in $(echo -e "${SYSTEMD_UNITS}"); do
          echo "Pulling journal for ${service_unit}"
          sudo journalctl --file="/var/log/journal/${3}/system.journal" \
                          --since="1 hour ago" \
                          --unit="${service_unit}" | sudo tee "${2}/${service_unit}.journal.log" &>/dev/null
        done
      fi
    else
      SYSTEMD_UNITS=$(sudo journalctl --output=json-pretty | grep -w UNIT | sort -u | awk -F'"' '{print $4}' | grep "${1}")
      for service_unit in $(echo -e "${SYSTEMD_UNITS}"); do
        echo "Pulling journal for ${service_unit}"
        sudo journalctl --since="1 hour ago" \
                        --unit="${service_unit}" | sudo tee "${2}/${service_unit}.journal.log" &>/dev/null
      done
    fi
  fi
}

function find_files {
  find "${WORKING_DIR}/logs/" -type f \
    ! -name "*.gz" \
    ! -name '*.html' \
    ! -name '*.subunit' \
    ! -name "*.journal" \
    ! -name 'ansible.sqlite'
}

function rename_files {
  find_files |\
    while read filename; do \
      mv ${filename} ${filename}.txt || echo "WARNING: Could not rename ${filename}"; \
    done
}

## Main ----------------------------------------------------------------------

echo "#### BEGIN LOG COLLECTION ###"

mkdir -vp "${WORKING_DIR}/logs"

# Gather basic logs
store_artifacts /openstack/log/ansible-logging/ "${WORKING_DIR}/logs/ansible"
store_artifacts /openstack/log/ "${WORKING_DIR}/logs/openstack"
store_artifacts /var/log/ "${WORKING_DIR}/logs/host"

# Store the ara sqlite database in the openstack-ci expected path
store_artifacts "${TESTING_HOME}/.ara/ansible.sqlite" "${WORKING_DIR}/logs/ara-report/"

# Gather host etc artifacts
for service in ${COMMON_ETC_LOG_NAMES}; do
    store_artifacts "/etc/${service}" "${WORKING_DIR}/logs/etc/host/"
    store_journal_artifacts "${service}" "${WORKING_DIR}/logs/host"
done

# Gather container etc artifacts
if which lxc-ls &> /dev/null; then
 for CONTAINER_NAME in $(sudo lxc-ls -1); do
   CONTAINER_PID=$(sudo lxc-info -p -n ${CONTAINER_NAME} | awk '{print $2}')
   ETC_DIR="/proc/${CONTAINER_PID}/root/etc"
   MACHINE_ID="$(sudo cat ${ETC_DIR}/machine-id)"
   LOG_DIR="/proc/${CONTAINER_PID}/root/var/log"
   repo_information ${CONTAINER_NAME}
   for service in ${COMMON_ETC_LOG_NAMES}; do
      store_artifacts ${ETC_DIR}/${service} "${WORKING_DIR}/logs/etc/openstack/${CONTAINER_NAME}/"
      store_artifacts ${LOG_DIR}/${service} "${WORKING_DIR}/logs/openstack/${CONTAINER_NAME}/"
      store_journal_artifacts ${service} "${WORKING_DIR}/logs/openstack/${CONTAINER_NAME}" "${MACHINE_ID}"
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
rename_files

# Figure out the correct path for ARA
# As this script is not run through tox, and the tox envs are all
# different names, we need to try and find the right path to execute
# ARA from.
ARA_CMD="$(find ${WORKING_DIR}/.tox -path "*/bin/ara" -type f | head -n 1)"

# If we could not find ARA, assume it was not installed
# and skip all the related activities.
if [[ "${ARA_CMD}" != "" ]]; then
    # Generate the ARA subunit report so that the
    # results reflect in OpenStack-Health
    mkdir -vp "${WORKING_DIR}/logs/ara-data"
    echo "Generating ARA report subunit report."
    ${ARA_CMD} generate subunit "${WORKING_DIR}/logs/ara-data/testrepository.subunit" || true
fi

# Get a dmesg output so we can look for kernel failures
dmesg > "${WORKING_DIR}/logs/dmesg.log.txt" || true

# Collect job environment
env > "${WORKING_DIR}/logs/environment.txt"  || true

# output ram usage
free -m > "${WORKING_DIR}/logs/memory-available.txt" || true

# iptables
sudo iptables -nvL > "${WORKING_DIR}/logs/iptables.txt" || true
sudo iptables -t nat -nvL > "${WORKING_DIR}/logs/iptables-nat.txt" || true

repo_information host

# Record the active interface configs
for interface in $(ip -o link | awk -F':' '{print $2}'); do
    if which ethtool &> /dev/null; then
        ethtool -k ${interface} > "${WORKING_DIR}/logs/ethtool-${interface}-cfg.txt" || true
    else
        echo "No ethtool available" | tee -a "${WORKING_DIR}/logs/ethtool-${interface}-cfg.txt"
    fi
done

echo "#### END LOG COLLECTION ###"

