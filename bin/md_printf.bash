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
	
	$usage_string
	
	The metadata file may be an aggregate (md:EntitiesDescriptor)
	or a single entity (md:EntityDescriptor). In the case of an aggregate,
	the script will tally the number of entities that contain various
	roles, such as SPSSODescriptor, IDPSSODescriptor, and so forth.
	
	Optionally takes the path to the metadata file as a command-line 
	parameter. If none is given, takes its input from stdin instead.
	
	Options:
	   -h      Display this help message
	   -v      Log verbose messages
	   -s      Output detailed security info

	Option -h is mutually exclusive of all other options.
	
	The -s option enables an advanced "Security Reporting Mode." 
	When enabled, the script reports advanced security-related 
	aspects of the metadata, including details about the 
	signing certificate, the key size, the SignatureMethod, the 
	DigestMethod, and so forth.
	
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
lib_filenames[3]=helper_function_lib.bash

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

usage_string="Usage: $script_name [-hvs] [MD_FILE]"

help_mode=false; verbose_mode=false; security_reporting_mode=false
while getopts ":hvs" opt; do
	case $opt in
		h)
			help_mode=true
			;;
		v)
			verbose_mode=true
			;;
		s)
			security_reporting_mode=true
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

# make sure there is at most one command-line argument
shift $(( OPTIND - 1 ))
if [ $# -gt 1 ]; then
	echo "ERROR: $script_name: too many arguments: $# (0 or 1 required)" >&2
	exit 2
fi
if [ $# -eq 1 ]; then
	if [ ! -f "$1" ] ; then
		printf "ERROR: The metadata file does not exist: %s\n" "$1" >&2
		exit 2
	fi
	md_file="$1"
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
in_file="${tmp_dir}/saml-metadata.xml"
if [ -z "$md_file" ]; then
	# read input from stdin into the temp file
	/bin/cat - > "$in_file"
else
	# copy input file into the temp file
	/bin/cat "$md_file" > "$in_file"
fi
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: input failed (status code: ${status_code})"
	clean_up_and_exit -d "$tmp_dir" 2
fi

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

# common format specifications
f_spec='%-25s: %s\n'
f_spec_indented=' %-24s: %s\n'

#####################################################################
# Main processing
#####################################################################

print_log_message -I "$initial_log_message"

# parse the metadata
doc_info=$( parse_saml_metadata "$in_file" )
status_code=$?
if [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name: parse_saml_metadata failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
if [ $status_code -eq 1 ]; then
	print_log_message -E "$script_name: not a SAML metadata document: $in_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 1
fi

# What is the name of the metadata file (if any)?
[ -n "$md_file" ] && printf "$f_spec" "Metadata file name" "$md_file"

# How large is the metadata file?
file_size=$( /bin/cat "$in_file" | /usr/bin/wc -c )
printf "$f_spec" "Metadata file size" "$( printf "%d bytes" "$file_size" )"

# pretty-print document info
output=$( echo "$doc_info" | printf_doc_info "$f_spec" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: printf_doc_info failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
echo "$output"

# optionally pretty-print signature info
if $security_reporting_mode; then
	# parse the signature
	sig_info=$( parse_ds_signature "$in_file" )
	status_code=$?
	if [ $status_code -gt 1 ]; then
		print_log_message -E "$script_name: parse_ds_signature failed ($status_code)"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
	fi
	
	# if the status code is 1, the document is not signed
	if [ $status_code -eq 1 ]; then
		printf "(the metadata document is NOT signed)\n"
	else
		output=$( echo "$sig_info" | printf_sig_info "$f_spec_indented" )
		status_code=$?
		if [ $status_code -ne 0 ]; then
			print_log_message -E "$script_name: printf_sig_info failed ($status_code)"
			clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
		fi
		printf "Document signature---\n"
		echo "$output"
	fi
	
fi

# If the top-level element of the metadata file is an md:EntitiesDescriptor
# element, summarize all the entities in the metadata.
if echo "$doc_info" | $_GREP -q '^EntitiesDescriptor$'; then
	# parse the roles
	entity_info=$( parse_entity_roles -T $tmp_dir "$in_file" )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$script_name: parse_entity_roles failed ($status_code)"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
	fi
	
	# print entities summary
	output=$( echo "$entity_info" | printf_entity_counts )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$script_name: printf_entity_counts failed ($status_code)"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
	fi
	printf "Entities summary---\n"
	echo "$output"
fi

clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
