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
	Given the location of a web-based SAML metadata resource, 
	this script fetches the resource, extracts certain timestamps 
	from the metadata, and then logs the timestamps for future 
	reference.
	
	$usage_string
	
	If the resource is cached, the script requests the resource
	using HTTP Conditional GET [RFC 7232], otherwise the script
	issues an ordinary GET request for the resource. In either
	case, if the server responds with 200, the resource is cached. 
	If the server responds with 304, nothing is written to cache.
	
	The script parses the values of @creationInstant and @validUntil 
	from cached metadata. If either of these attributes is missing 
	from metadata, the script logs an error message and returns with 
	a nonzero error code. Otherwise the two attribute values along 
	with the current time are appended to a log file in the cache
	directory.
	
	By default the script outputs a JSON array of 10 elements to 
	stdout. The elements in the array correspond to the last 10 
	lines in the log file of timestamps. See the OUTPUT section
	below for details.
	
	The script is intended to be run as a cron job. Each run of
	the script appends a line to the log file and outputs a new 
	JSON file. In this way, the JSON file always contains the 
	latest information.
	
	Options:
	   -h      Display this help message
	   -q      Enable Quiet Mode; suppress normal output
	   -D      Enable DEBUG logging
	   -W      Enable WARN logging
	   -x      Enable HTTP Compression
	   -n      Specify the number of JSON objects to output
	   -d      Specify the directory to hold an output file

	Option -h is mutually exclusive of all other options.
	
	Option -q enables Quiet Mode. In this case, the log file is
	updated as usual but normal output is suppressed, that is, no 
	JSON file is produced when the script is run in Quiet Mode.
	
	Options -D or -W enable DEBUG or WARN logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable,
	whatever it may be.
		
	Option -x enables HTTP Compression by adding an Accept-Encoding 
	header to the HTTP request; that is, if option -x is enabled, the 
	client indicates its support for HTTP Compression in the request. 
	The server may or may not compress the response.
	
	Important! This implementation treats compressed and uncompressed 
	resources as two distinct resources.
	
	By default, the JSON array has 10 elements. Use the -n option to
	specify the desired number of objects in the JSON array. If the
	log file has fewer lines than the specified number of objects, the
	script outputs as many objects as possible.
	
	By default, the JSON array is output to stdout. Use the -d option
	to specify a directory in which to write the JSON file. Typically 
	the output directory is a web directory.
	
	When using the -d option, the actual filename is computed by the
	script. Specifically, the filename is the SHA-1 hash of the 
	location argument appended with "_vital_stats_z.json" or 
	"_vital_stats.json", depending on whether HTTP Compression is 
	enabled or not (resp.). Thus each resource gives rise to a unique 
	filename.
	
	Note: in Quiet Mode, both the -n and -d options are ignored.
	
	TIMESTAMP LOG FILE
	
	The timestamp log file is a flat text file where each row of the
	text file consists of the following three tab-delimited fields:
	
	  currentTime
	  creationInstant
	  validUntil
	
	All three fields contain a timestamp whose value format is the
	canonical form of an ISO 8601 dateTime string:
	
	  YYYY-MM-DDThh:mm:ssZ
	
	where 'T' and 'Z' are literals.
	
	The currentTime field records the time instant the data were 
	collected. The latter two values (creationInstant and validUntil)
	are taken directly from SAML metadata.
	
	OUTPUT
	
	Here is the simplest example of a JSON array with one element:
	
	  [
	    {
	      "currentDateTime": "2018-02-03T21:01:20Z"
	      ,
	      "creationInstant": "2018-02-03T20:32:53Z"
	      ,
	      "validUntil": "2018-02-07T20:32:53Z"
	      ,
	      "sinceEpoch": {
	        "secs": 1517691680,
	        "hours": 421581.02,
	        "days": 17565.88
	      }
	      ,
	      "sinceCreation": {
	        "secs": 1707,
	        "hours": 0.47,
	        "days": 0.02
	      }
	      ,
	      "untilExpiration": {
	        "secs": 343893,
	        "hours": 95.53,
	        "days": 3.98
	      }
	      ,
	      "validityInterval": {
	        "secs": 345600,
	        "hours": 96.00,
	        "days": 4.00
	      }
	    }
	  ]

	As you can see, an array element is a complex JSON object 
	consisting of timestamps and numerous computed values.
	
	The value of the currentDateTime field indicates the actual time 
	instant the script was run. Its value has the canonical form of 
	an ISO 8601 dateTime string.
	
	The values of the creationInstant and validUntil fields are taken
	directly from the metadata. They too have the canonical form of 
	an ISO 8601 dateTime string (as specified by the SAML Standard). 
	
	The sinceEpoch object is directly related to the currentDateTime. 
	For example, the sinceEpoch.secs field is the number of seconds 
	past the Epoch. The sinceEpoch.hours and sinceEpoch.days fields 
	are similarly defined.
	
	The sinceCreation object is a function of both creationInstant 
	and currentDateTime. The sinceCreation.secs field is the number 
	of seconds since the metadata was created, that is, the number 
	of seconds between the creationInstant and currentDateTime time
	instants.
	
	The untilExpiration object is computed from the currentDateTime 
	and validUntil. For instance, untilExpiration.secs is the numnber 
	of seconds until the metadata expires (relative to the 
	currentDateTime).
	
	The validityInterval object is the only object that does NOT 
	depend on the currentDateTime. The former is a function of 
	creationInstant and validUntil only. Note that the values in the
	validityInterval object are the sum of the values in the
	sinceCreation and untilExpiration objects.
	
	The computed data are sufficient to construct a time-series plot. 
	The sinceEpoch object is intended to be the independent variable 
	while the sinceCreation and untilExpiration objects are dependent 
	variables. Note that the validityInterval puts a bound on the 
	values of the dependent variables.
	
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
	
	  \$ url=https://md.incommon.org/InCommon/InCommon-metadata.xml
	  \$ ${0##*/} \$url
	  \$ ${0##*/} -n 1 \$url
	  
	The latter would produce a JSON array with one element, as shown
	in the OUTPUT section above.
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
lib_filenames[2]=compatible_date.bash
lib_filenames[3]=http_tools.bash
lib_filenames[4]=http_cache_tools.bash
lib_filenames[5]=http_log_tools.bash
lib_filenames[6]=json_tools.bash
lib_filenames[7]=xsl_wrappers.bash

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

usage_string="Usage: $script_name [-hqDWz] [-n NUM_OBJECTS] [-d OUT_DIR] LOCATION"

# defaults
help_mode=false; quiet_mode=false; compressed_mode=false
numObjects=10

while getopts ":hqDWzn:d:" opt; do
	case $opt in
		h)
			help_mode=true
			;;
		q)
			quiet_mode=true
			;;
		D)
			LOG_LEVEL=4  # DEBUG
			;;
		W)
			LOG_LEVEL=2  # WARN
			;;
		z)
			compressed_mode=true
			compression_opt="$compression_opt -$opt"
			;;
		n)
			numObjects="$OPTARG"
			;;
		d)
			out_dir="$OPTARG"
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

# check numObjects
if [ "$numObjects" -lt 1 ]; then
	echo "ERROR: $script_name: option -n arg must be positive integer: $numObjects" >&2
	exit 2
fi

# determine the location of the metadata resource
shift $(( OPTIND - 1 ))
if [ $# -ne 1 ]; then
	echo "ERROR: $script_name: wrong number of arguments: $# (1 required)" >&2
	exit 2
fi
md_location="$1"

# check output directory
if [ -n "$out_dir" ] && [ ! -d "$out_dir" ]; then
	echo "ERROR: $script_name: output directory does not exist: $out_dir" >&2
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

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#######################################################################
#
# Main processing
#
# 1. Issue an HTTP Conditional GET request (with or without compression)
# 2. Update the corresponding timestamp log file
# 3. Print the tail of the timestamp log file in JSON format
#
#######################################################################

print_log_message -I "$initial_log_message"

# compute currentTime (NOW)
currentTime=$( dateTime_now_canonical )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: dateTime_now_canonical failed ($status_code) to compute currentTime"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
print_log_message -I "$script_name: currentTime: $currentTime"

#######################################################################
#
# Issue an HTTP Conditional GET request (with or without compression)
#
#######################################################################

# get the metadata resource
http_conditional_get $compression_opt -d "$CACHE_DIR" -T "$tmp_dir" "$md_location" > /dev/null
http_status_code=$?

#######################################################################
#
# Update the corresponding timestamp log file
#
#######################################################################

# update the timestamp log
timestamp_log_file_path=$( update_timestamp_log $compression_opt -d $CACHE_DIR -T "$tmp_dir" $md_location $currentTime )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: update_timestamp_log failed ($status_code) on location: $md_location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# delayed error handling
if [ $http_status_code -ne 0 ]; then
	print_log_message -E "$script_name http_conditional_get failed ($http_status_code) on location: $md_location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# short-circuit if necessary
$quiet_mode && clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0

#######################################################################
#
# Print the tail of the timestamp log file in JSON format
#
#######################################################################

# compute the desired tail of the timestamp log file
print_log_message -I "$script_name using log file: $timestamp_log_file_path"
tmp_log_file="$tmp_dir/timestamp_log_tail.txt"
/usr/bin/tail -n $numObjects "$timestamp_log_file_path" > "$tmp_log_file"

# print JSON to stdout
if [ -z "$out_dir" ]; then
	print_json_array "$tmp_log_file" append_timestamp_object
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $?
fi

# compute the output file path
out_file=$( opaque_file_path $compression_opt -e json -d "$out_dir" $md_location vital_stats )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name opaque_file_path failed ($status_code) to compute out_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
print_log_message -I "$script_name using output file: $out_file"

# print JSON to the file
print_json_array "$tmp_log_file" append_timestamp_object > "$out_file"
clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $?
