#!/bin/bash

# Copyright 2017, SUSE LINUX GmbH.
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

# This script will sync $files_to_sync files across all supported repositories as
# returned by the gen-projects-list.sh script. The goal here is to try and sync
# all these files at regular intervals so the code in the repositories is
# tested in the same way on both the OpenStack CI and the Vagrant platforms.
# This script will open reviews in the OpenStack gerrit so make sure your system is
# configured properly to submit upstream reviews. Use ./sync-test-repos.sh -h
# to get more information on how to use this script. Bugs about this script
# should be submitted to the openstack-ansible project on launchpad as usual.

# This script has a partner which is executed by the proposal bot here:
# https://opendev.org/openstack/project-config/src/playbooks/proposal/sync_openstack_ansible_common_files.sh
# Changes made to this file should be mirrored there when applicable.

set -eu

usage() {
    cat <<EOF

    ${0} [options]

    Valid options are:

    -h, --help:        This message
    -i, --interactive: Shows git diffs and requires user confirmation before
                       submitting reviews
    -n, --dry-run:     Shows git diffs and executes 'git-review -n' to show
                       what will happen on a normal run

EOF
}

exclude_project() {
    excluded_projects+="${1} "
}

cleanup() {
    [[ -d ${tempdir} ]] && { echo "Cleaning up ${tempdir}"; rm -rf ${tempdir}; }
}

process_changes() {
    local project=${1}
    local review=${2}

    (
        cd ${project}
        # if nothing changed just return
        git diff --quiet && echo "No new changes to commit" && return 0

        ${dry_run} || ${interactive} && git diff
        if ${interactive}; then
            read -p 'Submit review? [y/N] ' review
            ! [[ ${review} =~ ^(Y|y) ]] && return 0
        fi

        # Prepare gerrit
        git review -s

        # Commit changes
        git add .
        git commit $([[ ${review} == "__no_review__" ]] || printf %s '--amend') -m 'Updated from OpenStack Ansible Tests'
        git review $(${dry_run} && printf %s '-n')
    )
}

check_and_ignore() {
    for z in $(echo ${excluded_projects} | tr ' ' '\n'); do
        [[ ${1} == ${z} ]] && return 0
    done
    return 1
}

copy_files() {
    local osa_project=${1}

    # Copy files
    for src_path in ${files_to_sync[@]}; do
        # If the source repo does not have the file to copy
        # then skip to the next file. This covers the situation
        # where this script runs against old branches which
        # do not have the same set of files. If the src_path
        # is 'sync/tasks/*' because the folder does not exist
        # then it will fail this test too.
        [[ ! -e ${src_path} ]] && continue

        # For the sync/* files in the array, the destination
        # path is different to the source path. To work out
        # the destination path we remove the 'sync/' prefix.
        dst_path=${src_path#sync/}

        # If the target repo does not have such a file already
        # then it's probably best to leave it alone.
        [[ ! -e ${osa_project}/${dst_path} ]] && continue

        # We don't preserve anything from the target repo.
        # We simply assume that all OSA projects need the same
        # $files_to_sync
        cp ${src_path} ${osa_project}/${dst_path}
    done
}

# Do not change these files unless you know what you are doing
declare -ra files_to_sync=(run_tests.sh bindep.txt Vagrantfile tests/tests-repo-clone.sh .gitignore sync/doc/* sync/tasks/*)
declare -r  openstack_git_url="https://opendev.org"

excluded_projects=
dry_run=false
interactive=false

OPTS=$(getopt -o hin --long help,interactive,dry-run -n '$(basename ${0}' -- "$@")
eval set -- "${OPTS}"

while true; do
    case "${1}" in
        -i|--interactive) interactive=true; shift ;;
        -n|--dry-run) dry_run=true; shift ;;
        --) shift; break ;;
        -h|--help) usage; exit 1 ;;
    esac
done

# Always exclude openstack-ansible-tests repository. This is not
# necessary because osa_projects should never include "openstack-ansible-tests"
# but it can serve as an example for users who may add more
# projects in the future.
exclude_project "openstack-ansible-tests"

############################# ZUUL SYNCING ###################################
# If we running in the OpenStack CI then the first argument is going to be the
# project directory and all we need to do is to simply copy files. The
# environment is already prepared.
if env | grep -q ^ZUUL; then
    # Some debug information.
    echo "Running in a Zuul environment"
    echo "Current directory: $(pwd)"
    echo "OSA project: '${1}'"

    # Do we need to skip that repo?
    check_and_ignore ${1} && exit 0

    # This should never happen if Zuul is working properly
    [[ ! -d ${1} ]] && { echo "${1} does not exit! Refusing to proceed"; exit 1; }

    copy_files ${1}

    # Return back to zuul. No furher processing is required.
    exit 0
else
    declare -ra osa_projects=($(./gen-projects-list.sh))
fi

# Make sure interactive and dry run can't be used together
${dry_run} && ${interactive} && \
    echo "Can't use interactive and dry-run at the same time. Disabling interactive mode..." && \
    interactive=false

# Create a temporary directory
tempdir=$(mktemp -d -q || { echo "Failed to create temporary directory"; exit 1; })

trap cleanup EXIT

# make sure this is brand new
cleanup

echo "=> Temporary directory for OSA repositories: ${tempdir}"
mkdir ${tempdir}

pushd ${tempdir} &> /dev/null

echo "=> Cloning openstack-ansible-tests repository"
eval git clone ${openstack_git_url}/openstack/openstack-ansible-tests
echo -e "\n---------------------------------------------\n"

for proj in ${osa_projects[@]}; do
    proj_dir=$(basename ${proj})

    # Skip the project if it is in the excluded list
    check_and_ignore ${proj_dir} && continue

    echo "=> ##### ${proj} #####"
    eval git clone ${openstack_git_url}/$proj

    pushd $proj_dir &> /dev/null

    git checkout -b openstack/openstack-ansible-tests/sync-tests
    # if there an open review, re-use it
    open_review=$(git review --no-color -l | \
        grep -v "^Found" | \
        grep "Updated from OpenStack Ansible Tests" | \
        tail -n1 | awk '{print $1}')
    [[ -n ${open_review} ]] && \
        echo "Using existing review #${open_review} for ${proj_dir}" && \
        git review -x ${open_review}

    popd &> /dev/null

    # Copy files
    pushd openstack-ansible-tests &> /dev/null
    copy_files ${proj_dir}
    popd &> /dev/null

    process_changes ${proj_dir} ${open_review:="__no_review__"}
    # Clean up the directory
    rm -rf ${proj_dir}
    echo -e "=> ##################################################\n"
done

popd &> /dev/null

echo "All OpenStack Ansible repositories have been synced successfully!"
echo "Happy testing ;-)"

exit 0
