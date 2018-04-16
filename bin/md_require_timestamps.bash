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
	
	The script inputs a SAML metadata file on stdin. It outputs the 
	input file (unchanged) on stdout if the top-level element of 
	the metadata file is associated with the required attributes.
	
	The script ensures that the actual length of the validity interval 
	does not exceed the maximum length given on the command line. If 
	it does, the metadata is not output and an error message is logged.
	See the -M option below for details.
	
	Overall this filter rejects metadata that never expires or has 
	too long of a validity period, both of which undermine the usual 
	trust model.
	
	The script takes one or two optional command-line arguments.
	The first argument causes the values of the @creationInstant and 
	@validUntil attributes to be logged. The second argument causes 
	a portion of the log file to be output in JSON format. See the 
	TIMESTAMP LOG FILE section below for more information.
	
	Options:
	   -h      Display this help message
	   -D      Enable DEBUG logging
	   -W      Enable WARN logging
	   -M      Maximum length of the validity interval
	   -n      Specify the number of JSON objects to output

	Option -h is mutually exclusive of all other options.
	Options -D and -W are mutually exclusive of each other.
	
	Options -D or -W enable DEBUG or WARN logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable,
	whatever it may be.
		
	The -M option specifies the maximum length of the validity 
	interval as an ISO 8601 duration. The default value of this 
	parameter is P14D, that is, 14 days. The latter is common
	but certainly not universal. Adjust the option argument
	accordingly.
	
	The validity interval is the time between the creation and
	expiration of a metadata document, that is, the length of
	the time interval having @creationInstant and @validUntil as
	endpoints, respectively. This script puts a bound on the 
	length of the actual validity interval, which prevents 
	the metadata publisher from publishing documents with 
	arbitrary validity intervals (or none at all).
	
	TIMESTAMP LOG FILE
	
	The script takes one or two optional command-line arguments.
	The first argument is the absolute path to a timestamp log
	file. If the log file exists, a line is appended to the file
	when the script runs. 
	
	The second argument is the absolute path of an output file. 
	If present, a portion of the log file is converted to JSON 
	and written to the output file. If the output file does not 
	exist, one is created on-the-fly. In any case, the output 
	file is overwritten every time the script runs.
	
	Option -n determines how many lines of the log file are
	processed. The default value is 10, and so by default, the 
	last 10 lines of the log file are used to produce a JSON 
	array of 10 elements. Adjust the option argument to produce
	an arrays of the desired size.
	
	Note that option -n is ignored unless the OUT_FILE argument 
	is present.
	
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
	      "friendlyDate": "February 3, 2018"
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
	an ISO 8601 dateTime string. The friendlyDate is just that, a
	human-readable date without a time instant.
	
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
	
	The following command refreshes the metadata at the given 
	location and ensures metadata validity while requiring both
	the @creationInstant attribute and the @validUntil attribute:
	
	  \$ \$BIN_DIR/md_refresh.bash \$location \\
	      | \$BIN_DIR/md_require_valid_metadata.bash -E P4D -F P6D \\
	      | \$BIN_DIR/md_require_timestamps.bash -M P14D
	
	The metadata is output on stdout if (and only if) all of the
	following are true: (1) the metadata is valid, (2) the metadata
	is decorated with the required attributes, and (3) the actual
	validity interval is no more than 14 days in length. If the 
	metadata is set to expire within the next 4 days, or the metadata 
	is more than 6 days old, a warning message is logged.
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
lib_filenames[5]=http_log_tools.bash
lib_filenames[6]=json_tools.bash

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

usage_string="Usage: $script_name [-hDW] [-M DURATION] [-n NUM_OBJECTS] [LOG_FILE [OUT_FILE]]"

# defaults
help_mode=false; maxValidityInterval=P14D
numObjects=10

while getopts ":hDWM:n:" opt; do
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
		M)
			maxValidityInterval="$OPTARG"
			;;
		n)
			numObjects="$OPTARG"
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

# check the numnber of command-line arguments
shift $(( OPTIND - 1 ))
if [ $# -lt 0 ] || [ $# -gt 2 ]; then
	echo "ERROR: $script_name: incorrect number of arguments: $# (0, 1, or 2 required)" >&2
	exit 2
fi

# check the log file
if [ $# -gt 0 ]; then
	timestamp_log_file=$1
	if [ ! -f "$timestamp_log_file" ]; then
		echo "ERROR: $script_name: file does not exist: $timestamp_log_file" >&2
		exit 2
	fi
	# set up option to helper function
	log_file_opt="-f $timestamp_log_file"
fi

# check the output file
if [ $# -eq 2 ]; then
	out_file=$2
	# sanity check
	if [ -z "$out_file" ]; then
		echo "ERROR: $script_name: output file argument is null" >&2
		exit 2
	fi
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
#
# Main processing
#
# 0. Read the input on stdin
# 1. Parse the metadata
# 2. Ensure the attributes exist
# 3. If so, update the timestamp log file and output the metadata on stdout
# 4. Print a tail of the timestamp log file in JSON format
#
# The last step is best effort. It does not affect the
# success or failure of the script.
#
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
# (and update the timestamp log file as a side effect)
echo "$doc_info" | require_timestamps $log_file_opt $maxValidityInterval
status_code=$?
# return code 1 indicates either @creationInstant or @validUntil (or both) are missing,
# or the actual length of the validity interval exceeds the maximum interval length
if [ $status_code -eq 1 ]; then
	print_log_message -E "$script_name removing metadata from the pipeline: one or more timestamps missing, or the actual validity interval exceeds the maximum length: $maxValidityInterval"
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

#######################################################################
#
# Print a tail of the timestamp log file in JSON format
#
#######################################################################

[ -z "$out_file" ] && clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
print_log_message -I "$script_name using log file: $timestamp_log_file"

# compute the desired tail of the timestamp log file
tmp_log_file="$tmp_dir/timestamp_log_tail.txt"
/usr/bin/tail -n $numObjects "$timestamp_log_file" > "$tmp_log_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: /usr/bin/tail failed ($status_code)"
	print_log_message -W "$script_name: unable to write to output file: $out_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
fi

print_log_message -I "$script_name writing to output file: $out_file"

# print JSON to the output file
print_json_array "$tmp_log_file" append_timestamp_object > "$out_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: print_json_array failed ($status_code)"
	print_log_message -W "$script_name: unable to write to output file: $out_file"
fi
clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0
