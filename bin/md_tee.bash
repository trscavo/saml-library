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
	A SAML metadata filter that ensures the top-level element of 
	the metadata file is decorated with a @validUntil attribute.
	
	$usage_string
	
	The script takes a SAML metadata file on stdin. It outputs
	the input file (unchanged) on stdout if the top-level element 
	of the metadata file is decorated with a @validUntil attribute.
	The script also checks that the value of the @validUntil 
	attribute is not too far into the future. The latter is an
	important security feature.
	
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
	arbitrary validity intervals, intentionally or otherwise.
	
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
	
	  \$ url=https://md.example.org/some-metadata.xml
	  \$ curl --remote-name \$url
	  \$ ${0##*/} some-metadata.xml
	  \$ cat some-metadata.xml | ./${0##*/}
	  
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
usage_string="Usage: $script_name [-h] [-DW] [-L DURATION] TARGET_DIR"

help_mode=false; percent_encoding_mode=false
validityInterval='P14D'

while getopts ":hDWeL:" opt; do
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
		L)
			validityInterval="$OPTARG"
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

# If the top-level element of the metadata document is an md:EntityDescriptor
# element, copy the entity descriptor to the target directory with the
# desired filename. OTOH, if the top-level element of the document is an
# md:EntitiesDescriptor element, log an error message and exit with an error code.
if echo "$doc_info" | $_GREP -q '^EntityDescriptor$'; then

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
		clean_up_and_exit -I "$final_log_message" 3
	fi
	print_log_message -D "$script_name: out_filename: $out_filename"

	# compute current time
	currentTime=$( dateTime_now_canonical )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$script_name: dateTime_now_canonical failed ($status_code) to compute currentTime"
		clean_up_and_exit -I "$final_log_message" 3
	fi
	print_log_message -D "$script_name: currentTime: $currentTime"

	# compute validUntil
	print_log_message -D "$script_name: validityInterval: $validityInterval"
	validUntil=$( dateTime_delta -b $currentTime "$validityInterval" )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$script_name: dateTime_delta failed ($status_code) to compute validUntil"
		clean_up_and_exit -I "$final_log_message" 3
	fi
	print_log_message -D "$script_name: validUntil: $validUntil"
	
	/bin/cat $in_file \
		| xsltproc --stringparam validUntil $validUntil $LIB_DIR/add_validUntil_attribute.xsl - \
		| /usr/bin/tee "${target_dir}/$out_filename"
	exit_status=$?
else
	print_log_message -E "$script_name: EntityDescriptor expected"
	exit_status=1
fi

clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $exit_status
