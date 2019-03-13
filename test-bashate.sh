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
# This script executes bashate against all the files it find that match
# the search pattern. The search pattern is meant to find any shell
# scripts present in the role.
#
# The test ignores the following rules:
#
# E003: Indent not multiple of 4 (we prefer to use multiples of 2)
#
# E006: Line longer than 79 columns (as many scripts use jinja
#       templating, this is very difficult)
#
# E040: Syntax error determined using `bash -n` (as many scripts
#       use jinja templating, this will often fail and the syntax
#       error will be discovered in execution anyway)

## Shell Opts ----------------------------------------------------------------

set -e

## Vars ----------------------------------------------------------------------

export WORKING_DIR=${WORKING_DIR:-$(pwd)}

## Main ----------------------------------------------------------------------

grep --recursive --binary-files=without-match \
     --files-with-match '^.!.*\(ba\)\?sh$' \
     --exclude-dir .tox \
     --exclude-dir .git \
     "${WORKING_DIR}" | xargs -n1 bashate --error . --verbose --ignore=E003,E006,E040
