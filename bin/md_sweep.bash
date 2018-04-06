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
	Given a directory, this utility script sweeps the directory 
	for expired metadata. All expired metadata documents in the 
	target directory are removed.
	
	$usage_string
	
	This script takes a single command-line argument, that is,
	the directory to be swept clean of expired metadata. Note
	that this script does not descend into subdirectories or
	follow symlinks. This script acts on regular files only.
	
	If a file in the directory is not a SAML metadata documnt,
	a warning is logged and the file is skipped. OTOH, if the
	top-level element of the metadata document carries a
	@validUntil attribute, and the value of the @validUntil
	attribute indicates the metadata is expired, the file is
	permanently removed from the directory.
	
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
	
	  \$ sourceDirectory=/etc/shibboleth/metadata/hash
	  \$ ${0##*/} \$sourceDirectory
	  
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

usage_string="Usage: $script_name [-hDW] [-E DURATION] TARGET_DIR"

# defaults
help_mode=false
expirationWarningInterval='P2D'

while getopts ":hDWE:" opt; do
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
		E)
			expirationWarningInterval="$OPTARG"
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
	lib_file="${LIB_DIR%%/}/$lib_filename"
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
# Given a directory, sweep the directory for expired and
# soon-to-be-expired metadata.
# 
# for each file in the target directory
#
#   if the file is not a regular file
#   or the file is not a SAML metadata document
#   then log a warning and skip the file
#
#   if a @validUntil attribute exists on the top-level element
#   and its value is less than or equal to the current time
#   then log a warning and remove the file
#
#   if a @validUntil attribute exists on the top-level element
#   and its value is greater than or equal to the expiration warning threshold
#   then log a warning
#
# end
#
#######################################################################

print_log_message -I "$initial_log_message"

# compute current time
currentTime=$( dateTime_now_canonical )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: dateTime_now_canonical failed ($status_code)"
	clean_up_and_exit -I "$final_log_message" 3
fi
print_log_message -D "$script_name: currentTime: $currentTime"

print_log_message -I "$script_name sweeping directory: $target_dir"

# iterate over the files in the target directory
filenames=$( /bin/ls -1 "$target_dir" )
for filename in $filenames; do

	# compute the absolute file path
	md_file="${target_dir%%/}/$filename"
	if [ ! -f "$md_file" ]; then
		print_log_message -W "$script_name: not a regular file: $md_file"
		continue
	fi
	print_log_message -I "$script_name checking file: $md_file"

	# parse the metadata
	doc_info=$( parse_saml_metadata "$md_file" )
	status_code=$?
	# if status code is 1, the file is not SAML metadata
	if [ $status_code -eq 1 ]; then
		print_log_message -W "$script_name: not a SAML metadata file: $md_file"
		continue
	elif [ $status_code -gt 1 ]; then
		print_log_message -E "$script_name: parse_saml_metadata failed ($status_code)"
		clean_up_and_exit -I "$final_log_message" 3
	fi
	
	# check for invalid metadata
	echo "$doc_info" | require_valid_metadata -t $currentTime
	status_code=$?
	# return code 1 indicates invalid metadata
	if [ $status_code -eq 1 ]; then
		print_log_message -W "$script_name removing invalid metadata: $md_file"
		/bin/rm -f "$md_file"
		continue
	elif [ $status_code -gt 1 ]; then
		print_log_message -E "$script_name: require_valid_metadata failed ($status_code)"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
	fi
	
	# check for soon-to-be expired metadata
	echo "$doc_info" | check_expiration_warning_interval -t $currentTime $expirationWarningInterval
	status_code=$?
	# return code 1 indicates a warning message was logged
	if [ $status_code -gt 1 ]; then
		print_log_message -E "$script_name: check_expiration_warning_interval failed ($status_code)"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
	fi
done

clean_up_and_exit -I "$final_log_message" 0
