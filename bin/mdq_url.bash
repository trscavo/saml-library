#!/bin/bash

#######################################################################
# Copyright 2018 Tom Scavo
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
	Compute a Metadata Query protocol request URL.
	
	$usage_string
	
	This script takes a pair of command-line arguments.
	Given the base URL of a Metadata Query (MDQ) server, 
	and an arbitrary identifier, the script computes the
	corresponding MDQ protocol request URL.
	
	ENVIRONMENT
	
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
	
	EXAMPLE
	
	  \$ mdq_base_url=http://mdq-beta.incommon.org/global
	  \$ id=urn:mace:incommon:internet2.edu
	  \$ url=\$( ${0##*/} \$mdq_base_url \$id )
	  \$ /usr/bin/curl --silent \$url
	  
HELP_MSG
}

#######################################################################
# Bootstrap
#######################################################################

script_name=${0##*/}  # equivalent to basename $0

# required environment variables
env_vars[1]="LIB_DIR"
env_vars[2]="LOG_FILE"

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
lib_filenames[3]=md_tools.bash

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

usage_string="Usage: $script_name [-hDW] MDQ_BASE_URL IDENTIFIER"

# defaults
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

# check the number of remaining arguments
shift $(( OPTIND - 1 ))
if [ $# -ne 2 ]; then
	echo "ERROR: $script_name: wrong number of arguments: $# (2 required)" >&2
	exit 2
fi
mdq_base_url="$1"
identifier="$2"  # usually an entityID

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

# no temporary directory needed

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#######################################################################
# Main processing
#
# Function percent_encode() is defined in http_tools.bash
# Function construct_mdq_url() is defined in md_tools.bash
#######################################################################

print_log_message -I "$initial_log_message"

# percent-encode the identifier
encoded_id=$( percent_encode $identifier )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: percent_encode failed ($status_code) to compute encoded_id"
	print_log_message -I "$final_log_message"
	exit 3
fi
print_log_message -D "$script_name: encoded_id: $encoded_id"

# compute the MDQ protocol request URL
mdq_request_url=$( construct_mdq_url $mdq_base_url $encoded_id )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: construct_mdq_url failed ($status_code) to compute mdq_request_url"
	print_log_message -I "$final_log_message"
	exit 3
fi

echo $mdq_request_url
print_log_message -I "$final_log_message"
exit 0
