#!/bin/bash

#######################################################################
# Copyright 2016--2018 Tom Scavo
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
	This script is a wrapper around the xsltproc command-line tool.
	Like xsltproc, this script applies an XSL stylesheet to an XML
	document and outputs the resulting transformed document on stdout.
	Unlike xsltproc, this script fetches the target XML document
	from an HTTP server. 
	
	$usage_string
	
	This script takes two command-line arguments. The STYLESHEET
	argument is the absolute path to an XSL document in the local
	file system. The URL argument is the absolute URL of an XML 
	document. The script fetches the XML document at the given 
	URL using HTTP Conditional GET [RFC 7232]. If the server 
	responds with 200, the document in the response body is used. 
	If the server responds with 304, it uses the document in the 
	cache (if any).
	
	Options:
	   -h      Display this help message
	   -D      Enable DEBUG level logging
	   -W      Enable WARN level logging
	   -z      Enable HTTP Compression
	   -F      Enable "Force Output Mode"
	   -C      Enable "Cache Only Mode"
	   -o      Output the transformed document to OUT_FILE

	Option -h is mutually exclusive of all other options.
	
	Options -D or -W enable DEBUG or WARN level logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable,
	whatever it may be.
		
	Option -z enables HTTP Compression by adding an Accept-Encoding 
	header to the HTTP request; that is, if option -z is enabled, the 
	client indicates its support for HTTP Compression in the request. 
	The server may or may not compress the response.
	
	Important! This implementation treats compressed and uncompressed 
	resources as two distinct resources.
	
	The default behavior of the script may be modified by using 
	option -F or -C, which are mutually exclusive. Force Output 
	Mode (option -F) forces the return of a fresh resource. The 
	resource is output on stdout if and only if the server 
	responds with 200. If the response is 304, the script silently
	fails with exit code 1.
	 
	Cache Only Mode (option -C) bypasses the GET request altogether 
	and goes directly to cache. If the resource resides in cache, 
	it is output on stdout, otherwise the script silently fails
	with exit code 1.
	
	Option -o specifies an output file in the local file system.
	If option -o is omitted, the transformed document is written
	to stdout.

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

	  stylesheet=/path/to/stylesheets/style.xsl
	  url=http://md.incommon.org/InCommon/InCommon-metadata.xml
	  out_file=/tmp/output.txt
	  ${0##*/} \$stylesheet \$url
	  ${0##*/} -o \$out_file \$stylesheet \$url
	  ${0##*/} -F \$stylesheet \$url
	  ${0##*/} -C \$stylesheet \$url
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
[ -z "$LOG_LEVEL" ] && LOG_LEVEL=3

# library filenames
lib_filenames[1]=core_lib.bash
lib_filenames[2]=http_tools.bash
lib_filenames[3]=http_cache_tools.bash
#lib_filenames[4]=compatible_date.bash

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

usage_string="Usage: $script_name [-hDWz] [-F | -C] [-o OUT_FILE] STYLESHEET URL"

# defaults
help_mode=false

while getopts ":hDWzFCo:" opt; do
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
		z)
			get_opts="$get_opts -$opt"
			;;
		F)
			get_opts="$get_opts -$opt"
			;;
		C)
			get_opts="$get_opts -$opt"
			;;
		o)
			out_file="$OPTARG"
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
if [ "$#" -ne 2 ]; then
	echo "ERROR: $script_name found $# command-line arguments (2 required)" >&2
	exit 2
fi
xsl_file=$1
xml_location=$2

# check the stylesheet
if [ ! -f "$xsl_file" ]; then
	echo "ERROR: $script_name: file does not exist: $xsl_file" >&2
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

# temporary files
xml_file="${tmp_dir}/http_resource.xml"
xsltproc_out_file="${tmp_dir}/xsltproc_output"

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#######################################################################
#
# Main processing
#
# 1. Fetch the XML document using HTTP Conditional GET
# 2. Apply the XSL stylesheet to the XML document
# 3. Output the transformed document
#
#######################################################################

print_log_message -I "$initial_log_message"

# Fetch the XML document
print_log_message -I "$script_name fetching XML resource $xml_location"
http_conditional_get $get_opts -d "$CACHE_DIR" -T "$tmp_dir" "$xml_location" > "$xml_file"
status_code=$?
if [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name http_conditional_get failed ($status_code) on location: $xml_location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
# Quiet Failure Mode
[ $status_code -eq 1 ] && clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 1

# Apply the XSL stylesheet to the XML document
print_log_message -I "$script_name applying XSL stylesheet $xsl_file"
/usr/bin/xsltproc --output "$xsltproc_out_file" "$xsl_file" "$xml_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: xsltproc failed ($status_code) on stylesheet $xsl_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# Output the transformed document
if [ -z "$out_file" ]; then
	/bin/cat "$xsltproc_out_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$script_name: cat failed ($status_code) on document $xsltproc_out_file"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
	fi
else
	print_log_message -I "$script_name using output file $out_file"
	/bin/cp "$xsltproc_out_file" "$out_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$script_name: cp failed ($status_code) on document  $xsltproc_out_file"
		clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
	fi
fi

clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
