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
	
	The script checks for valid metadata. If the metadata is invalid 
	(see below for details), the script logs an error and returns a 
	nonzero exit code. No metadata is output in this case.
	
	Options:
	   -h      Display this help message
	   -D      Enable DEBUG logging
	   -W      Enable WARN logging
	   -F      Enable "Force Refresh Mode"
	   -C      Enable "Check Cache Mode"
	   -z      Enable "Compressed Mode"
	   -L      Length of the Expiration Warning Interval
	   -M      Length of the Freshness Interval

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
	
	METADATA VALIDITY
	
	The validity of SAML metadata (not to be confused with signature 
	verification) depends on two optional XML attributes in the metadata:
	
	  1. @validUntil
	  2. @creationInstant

	The metadata is invalid if either of the following is true:

	  * The @validUntil attribute exists and its value is in the past
	  * The @creationInstant attribute exists and its value is in the future

	The latter is a sanity check but the former is critical: 
	If @validUntil is in the past, the metadata is expired. A 
	conforming implementation MUST reject expired metadata and so
	expired metadata is effectively the same as no metadata.

	To avoid surprises, an early warning system has been implemented 
	by defining two time intervals, the Expiration Warning Interval 
	and the Freshness Interval.

	The right-hand endpoint of the Expiration Warning Interval is the 
	value of the @validUntil attribute. If the current time is captured 
	by this interval, a warning message is logged, indicating that the 
	metadata will soon expire. If no expiration warning occurred, the
	system also checks the Freshness Interval.

	The left-hand endpoint of the Freshness Interval is the value of 
	the @creationInstant attribute. If the current time exceeds this 
	interval, a warning message is logged, indicating that the metadata 
	is stale.
	
	Note that the early warning system issues at most one warning 
	message. In any case, the metadata is not rejected as it is in the 
	case of invalid metadata. The metadata is output to stdout even if
	a warning message is logged.
	
	The length of the Expiration Warning Interval is configurable. The 
	default length is P2D, that is, the script logs a warning message 
	if the metadata is set to expire in two (2) days or less.
	
	(The notation 'P2D' is an ISO 8601 duration. See this article for 
	details: https://en.wikipedia.org/wiki/ISO_8601#Durations)
	
	To change the length of the Expiration Warning Interval, use the 
	-L option. For example, specify -L PT36H to set the length of the 
	interval to 36 hours. To turn off this feature, set the length of 
	the interval to zero (-L PT0S).
	
	Similarly, the length of the Freshness Interval is configurable. 
	However, the length of this interval has no default value. To 
	check for metadata freshness, use the -M option. For example, if 
	-M is set to five days (-M P5D) and the metadata is more than 5 
	days old, a warning message will be logged.
	
	For any given metadata source, reasonable values for -L and -M 
	depend on the actual Validity Interval of the metadata in question. 
	By definition, the Validity Interval has endpoints @creationInstant 
	and @validUntil, respectively. In practice, the length of the 
	Validity Interval will vary from a few days to a few weeks. 
	
	The actual Validity Interval may not be known in advance and so the
	script checks the -L and -M option arguments for reasonableness.
	If the two subintervals overlap, the script logs a warning message
	and skips the freshness check (since the result would have been
	misleading anyway). If this happens, adjust the -L and -M option 
	arguments to be consistent with the actual Validity Interval.
	
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
lib_filenames[2]=compatible_date.bash
lib_filenames[3]=http_tools.bash
lib_filenames[4]=http_cache_tools.bash
lib_filenames[5]=xsl_wrappers.bash
lib_filenames[6]=helper_function_lib.bash

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

usage_string="Usage: $script_name [-hDWFCz] [-L DURATION] [-M DURATION] MD_LOCATION"

# defaults
help_mode=false
requireValidMetadata=true; expirationWarningInterval='P2D'

while getopts ":hDWFCzL:M:" opt; do
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
		L)
			expirationWarningInterval="$OPTARG"
			;;
		M)
			freshnessInterval="$OPTARG"
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

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

# temporary file
md_file="${tmp_dir}/md_resource.xml"

#######################################################################
# Main processing
#
# 1. Issue a conditional request for the metadata resource
# 2. Parse the metadata
# 3. Ensure the metadata is valid
# 4. Check for soon-to-be expired metadata
# 5. Check for stale metadata
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
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: parse_saml_metadata failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

#######################################################################
# short-circuit if valid metadata is not required
# (this feature is not configurable; it is reserved for future use)
#######################################################################

if ! $requireValidMetadata; then
	/bin/cat "$md_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
fi

# all further computations utilize the same current time value (for consistency)
currentTime=$( dateTime_now_canonical )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: dateTime_now_canonical failed ($status_code) to compute currentTime"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
print_log_message -D "$script_name: currentTime: $currentTime"

#######################################################################
# reject invalid metadata
#######################################################################

echo "$doc_info" | require_valid_metadata -t $currentTime
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: require_valid_metadata failed ($status_code) to validate metadata"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 9
fi

#######################################################################
# at most one warning is logged but the metadata is output in any case
#######################################################################

# check for soon-to-be expired metadata
echo "$doc_info" | check_expiration_warning_interval -t $currentTime $expirationWarningInterval
status_code=$?
# return code 1 indicates a warning message was logged
if [ $status_code -eq 1 ]; then
	/bin/cat "$md_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
elif [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name: check_expiration_warning_interval failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# short-circuit if no freshness interval
if [ -z "$freshnessInterval" ]; then
	/bin/cat "$md_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
fi

# check for stale metadata
echo "$doc_info" | check_freshness_interval -t $currentTime $freshnessInterval $expirationWarningInterval
status_code=$?
# return code 1 indicates a warning message was logged
if [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name: check_freshness_interval failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

/bin/cat "$md_file"
clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $status_code