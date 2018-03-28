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
	This SAML metadata filter ensures that the top-level element of 
	the metadata file is associated with both a @creationInstant
	attribute and a @validUntil attribute.
	
	$usage_string
	
	The script takes a SAML metadata file on stdin. It outputs the 
	input file (unchanged) on stdout if the top-level element of 
	the metadata file is associated with the required attributes.
	The script also checks that the actual length of the validity 
	interval does not exceed the maximum length given on the command
	line. If it does, the metadata is not output and an error message
	is logged.
	
	The latter is an
	important security feature.
	
	This filter rejects metadata that never expires or has too long a validity period, both of which undermine the usual trust model
	expiring metadata is how trust revocation is enforced
	
	Options:
	   -h      Display this help message
	   -L      Maximum length of the validity interval

	Option -h is mutually exclusive of all other options.
	
	The -L option specifies the maximum length of the validity 
	interval as an ISO 8601 duration. The default value of this 
	parameter is P14D, that is, two weeks. 
	
	The validity interval is the time between the creation and
	expiration of a metadata document. This script puts a bound
	on the length of the actual validity interval, which prevents 
	the metadata publisher from publishing documents having 
	arbitrary validity intervals (or none at all).
	
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
lib_filenames[2]=compatible_date.bash
lib_filenames[3]=xsl_wrappers.bash
lib_filenames[4]=helper_function_lib.bash

# check lib files
for lib_filename in ${lib_filenames[*]}; do
	lib_file="${LIB_DIR%%/}/$lib_filename"
	if [ ! -f "$lib_file" ]; then
		echo "ERROR: $script_name: file does not exist: $lib_file" >&2
		exit 2
	fi
done

#######################################################################
# Process command-line options and arguments
#######################################################################

usage_string="Usage: $script_name [-h] [-L DURATION] [-f LOG_FILE]"

# defaults
help_mode=false; maxValidityInterval=P14D

while getopts ":hL:f:" opt; do
	case $opt in
		h)
			help_mode=true
			;;
		L)
			maxValidityInterval="$OPTARG"
			;;
		f)
			timestamp_log_file="$OPTARG"
			local_opts="$local_opts -$opt $OPTARG"
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

# check the log file
if [ -n "$timestamp_log_file" ] && [ ! -f "$timestamp_log_file" ]; then
	echo "ERROR: $script_name: file does not exist: $timestamp_log_file" >&2
	exit 2
fi

# check the number of command-line arguments
shift $(( OPTIND - 1 ))
if [ $# -ne 0 ]; then
	echo "ERROR: $script_name: incorrect number of arguments: $# (0 required)" >&2
	exit 2
fi

#######################################################################
# Initialization
#######################################################################

# source lib files
for lib_filename in ${lib_filenames[*]}; do
	[[ ! $lib_filename =~ \.bash$ ]] && continue
	lib_file="${LIB_DIR%%/}/$lib_filename"
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

#####################################################################
# Main processing
#####################################################################

print_log_message -I "$initial_log_message"

# parse the metadata
doc_info=$( parse_saml_metadata "$in_file" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: parse_saml_metadata failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# check for @creationInstant and @validUntil timestamps
echo "$doc_info" | require_timestamps $local_opts $maxValidityInterval
status_code=$?
# return code 1 indicates either @creationInstant or @validUntil (or both) are missing,
# or the actual length of the validity interval exceeds the maximum interval length
if [ $status_code -eq 1 ]; then
	print_log_message -E "$script_name removing metadata from the pipeline (one or more timestamps missing)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 4
elif [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name: require_timestamps failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

/bin/cat "$in_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: /bin/cat failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# from here on out, exit 0 no matter what happens

clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
