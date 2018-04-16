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
	This script retrieves and caches metadata resources via HTTP. 
	A previously cached metadata resource is retrieved via HTTP 
	Conditional GET [RFC 7232]. If the web server responds with 
	HTTP 200 OK, the new metadata resource is cached and written 
	to stdout. If the web server responds with 304 Not Modified, 
	the cached metadata resource is output instead.
	
	$usage_string
	
	This script takes a single command-line argument. The MD_LOCATION 
	argument is the absolute URL of a metadata resource. The script 
	requests the metadata resource at the given URL using the curl 
	command-line tool.
	
	By definition, the top-level element of a SAML metadata document 
	is either md:EntityDescriptor or md:EntitiesDescriptor. If the 
	document is not an XML document, or the actual top-level element 
	is something else, the script logs an error and returns a nonzero
	exit code.
	
	Options:
	   -h      Display this help message
	   -D      Enable DEBUG logging
	   -W      Enable WARN logging
	   -F      Enable "Force Refresh Mode"
	   -C      Enable "Check Cache Mode"
	   -z      Enable "Compressed Mode"

	Option -h is mutually exclusive of all other options. Options -F 
	and -C are mutually exclusive of each other.
	
	Options -D or -W enable DEBUG or WARN logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable.
	
	Force Refresh Mode (option -F) forces the return of a fresh resource. 
	The resource is output on stdout if and only if the server responds 
	with 200. If the response is 304, the script logs a warning and fails 
	with status code 1.
	 
	Check Cache Mode (option -C) ensures that the resource is cached 
	and that the cache is up-to-date. If so, the resource is output on 
	stdout, otherwise the script logs a warning and fails with exit code 1.
	
	Compressed Mode (option -z) enables HTTP Compression by adding an 
	Accept-Encoding header to the request; that is, if option -z is 
	enabled, the client merely indicates its support for HTTP Compression 
	in the request. The server may or may not compress the response.
	
	Important! This implementation treats compressed and uncompressed 
	requests for the same resource as two distinct cachable resources.
	
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
	
	  \$ url=http://md.incommon.org/InCommon/InCommon-metadata.xml
	  \$ ${0##*/} \$url      # Retrieve the resource using HTTP conditional GET
	  \$ ${0##*/} -F \$url   # Enable Force Refresh Mode
	  \$ ${0##*/} -C \$url   # Enable Check Cache Mode
	  \$ ${0##*/} -z \$url   # Enable Compressed Mode
	  
	Note that the first and last examples result in distinct cached
	resources. The content of a compressed resource will be the 
	same as the content of an uncompressed resource but the headers 
	will be different. In particular, a compressed header will include
	a Content-Encoding header.
HELP_MSG
}

#######################################################################
# Bootstrap
#######################################################################

script_name=${0##*/}  # equivalent to basename $0

# required environment variables
env_vars[1]="LIB_DIR"
env_vars[2]="CACHE_DIR"
env_vars[3]="TMPDIR"
env_vars[4]="LOG_FILE"

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
dir_paths[2]="$CACHE_DIR"
dir_paths[3]="$TMPDIR"

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
lib_filenames[3]=http_cache_tools.bash
lib_filenames[4]=xsl_wrappers.bash

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

usage_string="Usage: $script_name [-hDWFCz] MD_LOCATION"

# defaults
help_mode=false

while getopts ":hDWFCz" opt; do
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
		[FCz])
			local_opts="$local_opts -$opt"
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
if [ $# -ne 1 ]; then
	echo "ERROR: $script_name: wrong number of arguments: $# (1 required)" >&2
	exit 2
fi
md_location="$1"

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

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

# temporary file
md_file="${tmp_dir}/md_resource.xml"

#######################################################################
# Main processing
#
# 1. Issue a conditional request for the resource
# 2. Ensure the resource is a SAML metadata document
# 3. Output the metadata on stdout
#
#######################################################################

print_log_message -I "$initial_log_message"

#######################################################################
# get the resource
#######################################################################

print_log_message -I "$script_name requesting metadata resource: $md_location"
http_conditional_get $local_opts -d "$CACHE_DIR" -T "$tmp_dir" "$md_location" > "$md_file"
status_code=$?
if [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name http_conditional_get failed ($status_code) on location: $md_location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
# Quiet Failure Mode
[ $status_code -eq 1 ] && clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 1

#######################################################################
# parse the metadata
#######################################################################

doc_info=$( parse_saml_metadata "$md_file" )
status_code=$?
if [ $status_code -eq 1 ]; then
	print_log_message -E "$script_name: not a SAML metadata document: $md_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 1
elif [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name: parse_saml_metadata failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

#######################################################################
# output the valid metadata
#######################################################################

/bin/cat "$md_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: /bin/cat failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
