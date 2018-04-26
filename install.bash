#!/bin/bash

#######################################################################
# Copyright 2017--2018 Tom Scavo
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
#######################################################################

################################################################
#
# Usage: install.sh BIN_DIR LIB_DIR
#
# Example: Install in /tmp
#
#   $ export BIN_DIR=/tmp/bin
#   $ export LIB_DIR=/tmp/lib
#   $ install.sh $BIN_DIR $LIB_DIR
#
# Example: Install in $HOME
#
#   $ export BIN_DIR=$HOME/dev/bin
#   $ export LIB_DIR=$HOME/dev/lib
#   $ install.sh $BIN_DIR $LIB_DIR
#
################################################################

script_bin=${0%/*}  # equivalent to dirname $0
script_name=${0##*/}  # equivalent to basename $0

# generalize
verbose_mode=true

# get command-line args
if [ $# -ne 2 ]; then
	echo "ERROR: $script_name: wrong number of arguments: $# (2 required)" >&2
	exit 2
fi
bin_dir=$1
lib_dir=$2

# check bin dir
if [ -z "$bin_dir" ]; then
	echo "ERROR: $script_name requires bin directory (BIN_DIR)" >&2
	exit 2
fi
if [ -d "$bin_dir" ]; then
	$verbose_mode && echo "$script_name using bin dir: $bin_dir"
else
	$verbose_mode && echo "$script_name creating bin dir: $bin_dir"
	/bin/mkdir "$bin_dir"
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $script_name failed to create bin dir: $bin_dir" >&2
		exit $exit_status
	fi
fi

# check lib dir
if [ -z "$lib_dir" ]; then
	echo "ERROR: $script_name requires lib directory (LIB_DIR)" >&2
	exit 2
fi
if [ -d "$lib_dir" ]; then
	$verbose_mode && echo "$script_name using lib dir: $lib_dir"
else
	$verbose_mode && echo "$script_name creating lib dir: $lib_dir"
	/bin/mkdir "$lib_dir"
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $script_name failed to create lib dir: $lib_dir" >&2
		exit $exit_status
	fi
fi

# initialize bin dir
while read -r script_file; do
	$verbose_mode && echo "$script_name copying executable file: $script_file"
	/bin/cp $script_file $bin_dir
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $script_name failed to copy script: $script_file" >&2
		exit $exit_status
	fi
done <<SCRIPTS
$script_bin/bin/http_xsltproc.bash
$script_bin/bin/md_parse.bash
$script_bin/bin/md_printf.bash
$script_bin/bin/md_query.bash
$script_bin/bin/md_refresh.bash
$script_bin/bin/md_require_creationInstant.bash
$script_bin/bin/md_require_timestamps.bash
$script_bin/bin/md_require_valid_metadata.bash
$script_bin/bin/md_require_validUntil.bash
$script_bin/bin/md_retain_entities_with_role.bash
$script_bin/bin/md_sweep.bash
$script_bin/bin/md_tee.bash
$script_bin/bin/md_vital_stats.bash
$script_bin/bin/mdq_url.bash
SCRIPTS

# initialize lib dir
while read -r source_file; do
	echo "$script_name copying source file: $source_file"
	/bin/cp $source_file $lib_dir
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $script_name failed to copy source file: $source_file" >&2
		exit $exit_status
	fi
done <<SOURCES
$script_bin/lib/add_validUntil_attribute.xsl
$script_bin/lib/entity_endpoints_txt.xsl
$script_bin/lib/entity_identifiers_txt.xsl
$script_bin/lib/entity_idp_names_txt.xsl
$script_bin/lib/entity_role_descriptors_txt.xsl
$script_bin/lib/extract_entity.xsl
$script_bin/lib/extract_entities_registered_by.xsl
$script_bin/lib/helper_function_lib.bash
$script_bin/lib/list_all_entity_attributes_txt.xsl
$script_bin/lib/list_all_entity_endpoints_txt.xsl
$script_bin/lib/list_all_IdP_DisplayNames_csv.xsl
$script_bin/lib/list_all_IdPs_csv.xsl
$script_bin/lib/list_all_key_descriptors_txt.xsl
$script_bin/lib/list_all_RandS_IdPs_csv.xsl
$script_bin/lib/list_all_RandS_SPs_csv.xsl
$script_bin/lib/list_all_role_descriptors_txt.xsl
$script_bin/lib/list_all_scopes_txt.xsl
$script_bin/lib/list_all_SPs_csv.xsl
$script_bin/lib/md_tools.bash
$script_bin/lib/parse_ds_signature_txt.xsl
$script_bin/lib/parse_saml_md_document_txt.xsl
$script_bin/lib/parse_signing_cert_pem.xsl
$script_bin/lib/remove_NameIDFormat.xsl
$script_bin/lib/retain_entities_with_idp_role.xsl
$script_bin/lib/retain_entities_with_sp_role.xsl
$script_bin/lib/saml_tools.bash
$script_bin/lib/security_contacts_legacy_list_csv.xsl
$script_bin/lib/security_contacts_summary_json.xsl
$script_bin/lib/security_contacts_summary_local_json.xsl
$script_bin/lib/xsl_wrappers.bash
SOURCES

$verbose_mode && echo "$script_name: installation complete"
exit 0