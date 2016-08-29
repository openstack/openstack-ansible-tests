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

# Simple script to generate a new ansible role requirements file.

BRANCH="${BRANCH:-master}"
CURRENT_DIR="$(pwd)"
WORKSPACE=${WORKSPACE:-$(mktmp --directory)}

function role_entry {
    cat >> "${CURRENT_DIR}/ansible-role-requirements.yaml" <<EOF
- name: "$1"
  src: "$2"
  scm: git
  version: "${BRANCH}"
EOF
}

# Create a workspace and clone project-config
mkdir -p "${WORKSPACE}"
git clone https://github.com/openstack-infra/project-config "${WORKSPACE}/project-config"

# Move into the project-config workspace
pushd "${WORKSPACE}/project-config"

# Store information about all of our known repos
PROJECTS=$(python <<EOR
import yaml
with open('gerrit/projects.yaml') as f:
    projects = yaml.load(f.read())
for project in projects:
    if project['project'].startswith('openstack/openstack-ansible'):
        project_name = project['project'].split('/')[-1].split('openstack-ansible-')[-1]
        project_github = 'https://git.openstack.org/%s' % project['project']
        print('%s|%s' % (project_name, project_github))
EOR
)

# If an existing role requirements file exists it'll be removed.
echo '---' > "${CURRENT_DIR}/ansible-role-requirements.yaml"

# Generate the ansible role requirements file.
for project in ${PROJECTS}; do
    git clone ${project#*'|'} "${WORKSPACE}/${project%%'|'*}"
    pushd "${WORKSPACE}/${project%%'|'*}"
      git fetch --all
      git checkout "${BRANCH}"
    popd
    if [[ -f "${WORKSPACE}/${project%%'|'*}/meta/main.yml" ]];then
        role_entry "${project%%'|'*}" "${project#*'|'}"
    fi
done

popd

# Cleanup the workspace directory if "true"
[[ "${WORKSPACE_CLEANUP:-true}" = true ]] && rm -rf "${WORKSPACE}"
