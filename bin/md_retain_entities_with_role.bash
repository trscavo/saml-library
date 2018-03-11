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

#######################################################################
# Help message
#######################################################################

display_help () {
/bin/cat <<- HELP_MSG
	Inspect a SAML metadata file and summarize its contents.
	
	Usage: ${0##*/} [-hvs] [MD_FILE]
	
	The metadata file may be an aggregate (md:EntitiesDescriptor)
	or a single entity (md:EntityDescriptor). In the case of an aggregate,
	the script will tally the number of entities that contain various
	roles, such as SPSSODescriptor, IDPSSODescriptor, and so forth.
	
	Optionally takes the path to the metadata file as a command-line 
	parameter. If none is given, takes its input from stdin instead.
	
	Options:
	   -h      Display this help message
	   -D      Enable DEBUG logging
	   -W      Enable WARN logging

	Option -h is mutually exclusive of all other options.
	
	Options -D or -W enable DEBUG or WARN logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable.
	
	ENVIRONMENT
	
	This script leverages a handful of environment variables:
	
	  LIB_DIR    A source library directory
	  TMPDIR     A temporary directory
	  LOG_FILE   A persistent log file
	  LOG_LEVEL  The global log level [0..5]
	
	The following environment variables are REQUIRED:
	
	$( printf "  %s\n" ${env_vars[*]} )
	
	The optional LOG_LEVEL variable defaults to LOG_LEVEL=3.
	
	The following directories will be used:
	
	$( printf "  %s\n" ${dir_paths[*]} )
	
	The following log file will be used:
	
	$( printf "  %s\n" $LOG_FILE )
	
	INSTALLATION
	
	At least the following source library files MUST be installed 
	in LIB_DIR:
	
	$( printf "  %s\n" ${lib_filenames[*]} )
	
	EXAMPLES
	
	  \$ url=http://md.example.org/some-metadata.xml
	  \$ curl --remote-name \$url
	  \$ ${0##*/} some-metadata.xml
	  \$ cat some-metadata.xml | ./${0##*/} -s
	  
HELP_MSG
}

#######################################################################
# Bootstrap
#######################################################################

script_name=${0##*/}  # equivalent to basename $0

# required environment variables
env_vars[1]="LIB_DIR"
env_vars[2]="TMPDIR"
env_vars[3]="LOG_FILE"

# check environment variables
for env_var in ${env_vars[*]}; do
	eval "env_var_val=\${$env_var}"
	if [ -z "$env_var_val" ]; then
		echo "ERROR: $script_name requires env var $env_var" >&2
		exit 2
	fi
done

# required directories
dir_paths[1]="$LIB_DIR"
dir_paths[2]="$TMPDIR"

# check required directories
for dir_path in ${dir_paths[*]}; do
	if [ ! -d "$dir_path" ]; then
		echo "ERROR: $script_name: directory does not exist: $dir_path" >&2
		exit 2
	fi
done

# check the log file
if [ ! -f "$LOG_FILE" ]; then
	echo "ERROR: $script_name: file does not exist: $LOG_FILE" >&2
	exit 2
fi

# default to INFO logging
if [ -z "$LOG_LEVEL" ]; then
	LOG_LEVEL=3
fi

# library filenames
lib_filenames[1]=core_lib.bash
lib_filenames[2]=xsl_wrappers.bash

# check lib files
for lib_filename in ${lib_filenames[*]}; do
	lib_file="$LIB_DIR/$lib_filename"
	if [ ! -f "$lib_file" ]; then
		echo "ERROR: $script_name: file does not exist: $lib_file" >&2
		exit 2
	fi
done

#######################################################################
# Process command-line options and arguments
#######################################################################

usage_string="Usage: $script_name [-hDW] ROLE_DESCRIPTOR"

help_mode=false
while getopts ":hDW" opt; do
	case $opt in
		h)
			help_mode=true
			;;
		D)
			LOG_LEVEL=4  # DEBUG
			;;
		W)
			LOG_LEVEL=2  # WARN
			;;
		\?)
			echo "ERROR: $script_name: Unrecognized option: -$OPTARG" >&2
			exit 2
			;;
	esac
done

if $help_mode; then
	display_help
	exit 0
fi

# check the number of command-line arguments
shift $(( OPTIND - 1 ))
if [ $# -ne 1 ]; then
	echo "ERROR: $script_name: incorrect number of arguments: $# (1 required)" >&2
	exit 2
fi
role_descriptor=$1

#######################################################################
# Initialization
#######################################################################

# source lib files
for lib_filename in ${lib_filenames[*]}; do
	lib_file="$LIB_DIR/$lib_filename"
	source "$lib_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		echo "ERROR: $script_name failed ($status_code) to source lib file $lib_file" >&2
		exit 2
	fi
done

# create a temporary subdirectory
tmp_dir="${TMPDIR%%/}/${script_name%%.*}_$$"
/bin/mkdir "$tmp_dir"
status_code=$?
if [ $status_code -ne 0 ]; then
	echo "ERROR: $script_name failed ($status_code) to create tmp dir $tmp_dir" >&2
	exit 2
fi

# read the input into a temporary file
in_file="${tmp_dir}/saml-metadata-in.xml"
/bin/cat - > "$in_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: input failed (status code: ${status_code})"
	clean_up_and_exit -d "$tmp_dir" 2
fi

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#######################################################################
# Functions
#######################################################################

#######################################################################
#
# Takes a SAML metadata file as input; produces a SAML metadata file as output.
# The top-level element of the input file is assumed to be an md:EntitiesDescriptor element.
# The top-level element of the output file is also an md:EntitiesDescriptor element.
# Filters the input depending on the given role descriptor.
# Retains any entity with the given role descriptor in the output.
# If a particular entity in the input does not contain the given role descriptor,
# the entire entity is filtered.
#
# Usage: retain_entities_with_role ROLE_DESCRIPTOR MD_FILE
#
# where ROLE_DESCRIPTOR is one of the following:
#
#   IDPSSODescriptor
#   SPSSODescriptor
#
# Call this function if (and only if) the top-level element
# of the metadata document is an md:EntitiesDescriptor element.
#
# Dependencies:
#   core_lib.bash
#   retain_entities_with_idp_role.xsl
#   retain_entities_with_sp_role.xsl
#
#######################################################################
retain_entities_with_role () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ -z "$LIB_DIR" ]; then
		print_log_message -E "$FUNCNAME: env var LIB_DIR required"
		return 2
	fi
	if [ ! -d "$LIB_DIR" ]; then
		print_log_message -E "$FUNCNAME: directory does not exist: $LIB_DIR"
		return 2
	fi
	
	local role_descriptor
	local xml_file
	local xsl_file
	local exit_status
	
	# check the number of command-line arguments
	if [ $# -ne 2 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (2 required)"
		return 2
	fi
	role_descriptor="$1"
	xml_file="$2"

	# check the input file
	if [ ! -f "$xml_file" ]; then
		print_log_message -E "$FUNCNAME: input file does not exist: $xml_file"
		return 2
	fi
	
	# determine the stylesheet
	if [ "$role_descriptor" = IDPSSODescriptor ]; then
		xsl_file="$LIB_DIR/retain_entities_with_idp_role.xsl"
	elif [ "$role_descriptor" = SPSSODescriptor ]; then
		xsl_file="$LIB_DIR/retain_entities_with_sp_role.xsl"
	else
		print_log_message -E "$FUNCNAME: unsupported role descriptor: $role_descriptor"
		return 2
	fi

	# check the stylesheet
	if [ ! -f "$xsl_file" ]; then
		print_log_message -E "$FUNCNAME: stylesheet does not exist: $xsl_file"
		return 2
	fi
	
	# filter the input
	/usr/bin/xsltproc $xsl_file $xml_file
}

#######################################################################
# Main processing
#######################################################################

print_log_message -I "$initial_log_message"

# parse the metadata
doc_info=$( parse_saml_metadata "$in_file" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: parse_saml_metadata failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# If the top-level element of the metadata file is an md:EntitiesDescriptor
# element, filter the entities in the metadata. OTOH, if the top-level
# element is an md:EntityDescriptor element, exit with an error code.
if echo "$doc_info" | $_GREP -q '^EntitiesDescriptor$'; then
	# filter entities
	out_file="${tmp_dir}/saml-metadata-out.xml"
	retain_entities_with_role $role_descriptor $in_file > $out_file
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$script_name: retain_entities_with_role failed ($status_code)"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
	fi
	/bin/cat $out_file
	exit_status=$?
else
	exit_status=1
fi

clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $exit_status
