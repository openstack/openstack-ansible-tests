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
export RSYNC_CMD="rsync --archive --safe-links --ignore-errors --quiet --no-perms --no-owner --no-group"
export RSYNC_ETC_CMD="${RSYNC_CMD} --no-links --exclude selinux/"

## Main ----------------------------------------------------------------------

echo "#### BEGIN LOG COLLECTION ###"

mkdir -vp \
    "${WORKING_DIR}/logs/host" \
    "${WORKING_DIR}/logs/openstack" \
    "${WORKING_DIR}/logs/etc/host" \
    "${WORKING_DIR}/logs/etc/openstack" \

# NOTE(mhayden): We use sudo here to ensure that all logs are copied.
sudo ${RSYNC_CMD} /var/log/ "${WORKING_DIR}/logs/host" || true
if [ -d "/openstack/log" ]; then
    sudo ${RSYNC_CMD} /openstack/log/ "${WORKING_DIR}/logs/openstack" || true
fi

# NOTE(cloudnull): This is collection thousands of files resulting in infra upload
#                  issues. To remove immediate pressure this is being stopped and
#                  we can circle back on this to make the etc file collection more
#                  focused.
#  # Archive host's /etc directory
#  sudo ${RSYNC_ETC_CMD} /etc/ "${WORKING_DIR}/logs/etc/host/" || true
#
#  # Loop over each container and archive its /etc directory
#  if which lxc-ls &> /dev/null; then
#    for CONTAINER_NAME in `sudo lxc-ls -1`; do
#      CONTAINER_PID=$(sudo lxc-info -p -n ${CONTAINER_NAME} | awk '{print $2}')
#      ETC_DIR="/proc/${CONTAINER_PID}/root/etc/"
#      sudo ${RSYNC_ETC_CMD} ${ETC_DIR} "${WORKING_DIR}/logs/etc/openstack/${CONTAINER_NAME}/" || true
#    done
#  fi

# NOTE(mhayden): All of the files must be world-readable so that the log
# pickup jobs will work properly. Without this, you get a "File not found"
# when trying to read the files in the job results.
# NOTE(odyssey4me): Using '--chown $(whoami) --chmod=ugo+rX' in the rsync
# CMD to achieve this would be optimal, but the CentOS version of rsync
# (3.0.x) does not support that option.
sudo chmod -R ugo+rX "${WORKING_DIR}/logs/"
sudo chown -R $(whoami) "${WORKING_DIR}/logs/"

if [ ! -z "${ANSIBLE_LOG_DIR}" ]; then
    mkdir -p "${WORKING_DIR}/logs/ansible"
    ${RSYNC_CMD} "${ANSIBLE_LOG_DIR}/" "${WORKING_DIR}/logs/ansible" || true
fi

# Rename all files gathered to have a .txt suffix so that the compressed
# files are viewable via a web browser in OpenStack-CI.
find "${WORKING_DIR}/logs/" -type f ! -name '*.html' -exec mv {} {}.txt \;

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
fi

# Compress the files gathered so that they do not take up too much space.
# We use 'command' to ensure that we're not executing with some sort of alias.
command gzip --force --best --recursive "${WORKING_DIR}/logs/" || echo 'Note: gzip log files failed'

echo "#### END LOG COLLECTION ###"
