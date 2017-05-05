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
        git commit $([[ ${review} == "__no_review__" ]] || printf %s '--amend') -m '[auto] Syncing common OSA files'
        git review $(${dry_run} && printf %s '-n')
    )
}

check_and_ignore() {
    for z in $(echo ${excluded_projects} | tr ' ' '\n'); do
        [[ ${1} == ${z} ]] && return 0
    done
    return 1
}

# Do not change these files unless you know what you are doing
declare -ra files_to_sync=(run_tests.sh bindep.txt Vagrantfile tests/tests-repo-clone.sh)
declare -r  openstack_git_url="git://git.openstack.org"

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
        -h|--help|*) usage; exit 1 ;;
    esac
done

declare -ra osa_projects=($(./gen-projects-list.sh))

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

# Always exclude openstack-ansible-tests repository. This is not
# necessary because osa_projects should never include "openstack-ansible-tests"
# but it can serve as an example for users who may add more
# projects in the future.
exclude_project "openstack-ansible-tests"

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

    git checkout -b osa-auto-sync-test-files
    # if there an open review, re-use it
    open_review=$(git review --no-color -l | \
        grep -v "^Found" | \
        grep "\[auto\] Syncing common OSA files" | \
        tail -n1 | awk '{print $1}')
    [[ -n ${open_review} ]] && \
        echo "Using existing review #${open_review} for ${proj_dir}" && \
        git review -x ${open_review}

    popd &> /dev/null

    # Copy files
    for f in ${files_to_sync[@]}; do
        cp openstack-ansible-tests/$f ${proj_dir}/$f
    done
    process_changes ${proj_dir} ${open_review:="__no_review__"}
    # Clean up the directory
    rm -rf ${proj_dir}
    echo -e "=> ##################################################\n"
done

popd &> /dev/null

echo "All OpenStack Ansible repositories have been synced successfully!"
echo "Happy testing ;-)"

exit 0
