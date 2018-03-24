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
	This SAML metadata filter ensures that the metadata is valid.
	
	$usage_string
	
	The script takes a SAML metadata file on stdin. It outputs the 
	input file (unchanged) on stdout if the metadata is valid. If 
	the metadata is invalid, the script logs an error and returns 
	a nonzero exit code. No metadata is output if the metadata is
	invalid.
	
	For details, see the section on Metadata Validity below.
	
	Options:
	   -h      Display this help message
	   -L      Length of the Expiration Warning Interval
	   -M      Length of the Freshness Interval

	Option -h is mutually exclusive of all other options.
	
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
	
	  TBD
	  
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
	lib_file="$LIB_DIR/$lib_filename"
	if [ ! -f "$lib_file" ]; then
		echo "ERROR: $script_name: file does not exist: $lib_file" >&2
		exit 2
	fi
done

#######################################################################
# Process command-line options and arguments
#######################################################################

usage_string="Usage: $script_name [-h] [-L DURATION] [-M DURATION]"

# defaults
help_mode=false
expirationWarningInterval=P2D

while getopts ":hL:M:" opt; do
	case $opt in
		h)
			help_mode=true
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

# specify a temporary file
md_file="${tmp_dir}/saml-metadata-in.xml"

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#####################################################################
#
# Main processing
#
# 0. Read the input on stdin
# 1. Parse the metadata
# 2. Ensure the metadata is valid
# 3. If valid, output the metadata on stdout
# 4. Check for soon-to-be expired metadata
# 5. Check for stale metadata
#
#####################################################################

/bin/cat - > "$md_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: input failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" 2
fi

print_log_message -I "$initial_log_message"

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
# return code 1 indicates invalid metadata
if [ $status_code -eq 1 ]; then
	print_log_message -E "$script_name removing invalid metadata from the pipeline"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 4
elif [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name: require_valid_metadata failed ($status_code)"
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

# from here on out, exit with code 0 no matter what happens

#######################################################################
# check for soon-to-be expired metadata
#######################################################################

echo "$doc_info" | check_expiration_warning_interval -t $currentTime $expirationWarningInterval
status_code=$?
# return code 1 indicates a warning message was logged
if [ $status_code -eq 1 ]; then
	# at most one warning should be logged
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
elif [ $status_code -gt 1 ]; then
	print_log_message -W "$script_name: check_expiration_warning_interval failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
fi

#######################################################################
# check for stale metadata
#######################################################################

# short-circuit if no freshness interval
[ -z "$freshnessInterval" ] && clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0

echo "$doc_info" | check_freshness_interval -t $currentTime $freshnessInterval $expirationWarningInterval
status_code=$?
# return code 1 indicates a warning message was logged
if [ $status_code -gt 1 ]; then
	print_log_message -W "$script_name: check_freshness_interval failed ($status_code)"
fi

clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
