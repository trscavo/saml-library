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
	This SAML metadata filter writes a copy of the metadata in
	the pipeline to the given target directory.
	
	$usage_string
	
	The script takes a SAML metadata file on stdin, writes a copy 
	of the metadata into the given TARGET_DIR, and then outputs 
	the input file (unchanged) on stdout.
	
	The top-level element of the XML file MUST be an 
	md:EntityDescriptor element. If not, the script logs an error
	message and exits with a nonzero exit code.
	
	The name of the file written to the TARGET_DIR is computed
	deterministically by inspecting the metadata. Specifically, 
	the filename is of the form hash.xml where hash is the SHA-1 
	hash of the entityID. Thus the filename is unique (insofar 
	as every SHA-1 hash value has a unique pre-image).
	
	For example, suppose the entityID is https://example.com/idp.
	Then the corresponding filename is 
	
	  9f246b6fb6c37ac8ccf8a39f9dd6d8ac5a0fdc9f.xml
	
	since
	
	  \$ echo -n https://example.com/idp | openssl sha1
	  9f246b6fb6c37ac8ccf8a39f9dd6d8ac5a0fdc9f
	
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
lib_filenames[2]=http_tools.bash
lib_filenames[3]=compatible_date.bash
lib_filenames[4]=xsl_wrappers.bash

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

# option -e is experimental and therefore unadvertised
usage_string="Usage: $script_name [-hDW] TARGET_DIR"

help_mode=false; percent_encoding_mode=false

while getopts ":hDWe" opt; do
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
		e)
			percent_encoding_mode=true
			;;
		\?)
			echo "ERROR: $script_name: Unrecognized option: -$OPTARG" >&2
			exit 2
			;;
		:)
			echo "ERROR: $script_name: Option -$OPTARG requires an argument" >&2
			exit 2
			;;
	esac
done

if $help_mode; then
	display_help
	exit 0
fi

# determine the target directory
shift $(( OPTIND - 1 ))
if [ $# -ne 1 ]; then
	echo "ERROR: $script_name: wrong number of arguments: $# (1 required)" >&2
	exit 2
fi
target_dir="$1"
if [ ! -d "$target_dir" ]; then
	echo "ERROR: $script_name: directory does not exist: $target_dir" >&2
	exit 2
fi

#######################################################################
# Initialization
#######################################################################

# source lib files
for lib_filename in ${lib_filenames[*]}; do
	[[ ! $lib_filename =~ \.bash$ ]] && continue
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
xml_file="${tmp_dir}/saml-metadata-in.xml"
/bin/cat - > "$xml_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: input failed (${status_code})"
	clean_up_and_exit -d "$tmp_dir" 2
fi

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#####################################################################
#
# Main processing
#
# 1. parse the metadata
# 2. ensure the top-level element is an md:EntityDescriptor element
# 3. compute the desired filename
# 4. write a copy of the metadata to the target directory
#
# Note: Support for md:EntitiesDescriptor is anticipated
#
#####################################################################

print_log_message -I "$initial_log_message"

# parse the metadata
doc_info=$( parse_saml_metadata "$xml_file" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: parse_saml_metadata failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# ensure the top-level element is an md:EntityDescriptor element
if ! echo "$doc_info" | $_GREP -q '^EntityDescriptor$'; then
	print_log_message -E "$script_name: EntityDescriptor expected"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 4
fi

# compute the desired filename
entityID=$( echo "$doc_info" | $_GREP '^entityID' | $_CUT -f2 )
if $percent_encoding_mode; then
	# an experimental feature
	out_filename=$( percent_encode $entityID )
else
	out_filename=$( echo -n $entityID | /usr/bin/openssl sha1 ).xml
fi
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: computation of out_filename failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
out_file="${target_dir}/$out_filename"
print_log_message -I "$script_name writing file: $out_file"

# write a copy of the metadata to the target directory
/bin/cat $xml_file | /usr/bin/tee "$out_file"
clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $?
