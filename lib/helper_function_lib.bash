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
#######################################################################
#
# Every function in this library is a helper function for one
# or more executable bash scripts. Thus the output of each
# function varies according to the needs of the caller.
#
# Each function takes its input from an XSL wrapper (and hence
# the caller is dependent on xsl_wrappers.bash).
#
#######################################################################
#######################################################################

#######################################################################
#
# Pretty-print general document info for the given SAML metadata document.
#
# Usage: output=$( parse_saml_metadata MD_FILE | printf_doc_info FORMAT )
#
# Call this function if (and only if) the document is a SAML metadata
# document.
#
# Dependencies:
#   core_lib.bash
#   xsl_wrappers.bash
#
# Used by:
#   md_printf.bash
#
#######################################################################
printf_doc_info () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	local f_spec
	
	local doc_info
	local local_name
	local doc_id
	local publisher
	local creationInstant
	local validUntil
	local cacheDuration

	# check the number of command-line arguments
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	f_spec="$1"

	# capture stdin
	doc_info=$( /bin/cat - )

	# determine the top-level element
	local_name=$( echo "$doc_info" | $_GREP -E '^(EntityDescriptor|EntitiesDescriptor)$' )
	if [ -z "$local_name" ]; then
		print_log_message -E "$FUNCNAME: no input found"
		return 4
	fi

	doc_id=$( echo "$doc_info" | $_GREP '^ID' | $_CUT -f2 )
	if [ -z "$doc_id" ]; then
		print_log_message -I "$FUNCNAME: $local_name (@ID not found)"
	else
		printf "$f_spec" "Document ID" "$doc_id"
		print_log_message -I "$FUNCNAME: $local_name @ID=$doc_id"
	fi

	publisher=$( echo "$doc_info" | $_GREP '^publisher' | $_CUT -f2 )
	if [ -n "$publisher" ]; then
		printf "$f_spec" "Document publisher" "$publisher"
		print_log_message -D "$FUNCNAME: document publisher: $publisher"
	fi

	creationInstant=$( echo "$doc_info" | $_GREP '^creationInstant' | $_CUT -f2 )
	if [ -n "$creationInstant" ]; then
		printf "$f_spec" "Document creationInstant" "$creationInstant"
		print_log_message -D "$FUNCNAME: document creationInstant: $creationInstant"
	fi

	validUntil=$( echo "$doc_info" | $_GREP '^validUntil' | $_CUT -f2 )
	if [ -n "$validUntil" ]; then
		printf "$f_spec" "Document validUntil" "$validUntil"
		print_log_message -D "$FUNCNAME: document validUntil: $validUntil"
	fi

	cacheDuration=$( echo "$doc_info" | $_GREP '^cacheDuration' | $_CUT -f2 )
	if [ -n "$cacheDuration" ]; then
		printf "$f_spec" "Document cacheDuration" "$cacheDuration"
		print_log_message -D "$FUNCNAME: document cacheDuration: $cacheDuration"
	fi

	return 0
}

#######################################################################
#
# Pretty-print signature info for the given SAML metadata document.
#
# Usage: output=$( parse_ds_signature MD_FILE | printf_sig_info FORMAT )
#
# Call this function if (and only if) the metadata is signed.
#
# Dependencies:
#   core_lib.bash
#   xsl_wrappers.bash
#
# Used by:
#   md_printf.bash
#
#######################################################################
printf_sig_info () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	local f_spec
	
	local sig_info
	local local_name
	local doc_id
	local referenceURI
	local canonicalizationMethod
	local signatureMethod
	local digestMethod
	
	local serial
	local notBefore
	local notAfter
	local CN
	local keySize
	local fingerprint

	# check the number of command-line arguments
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	f_spec="$1"

	###################################################################
	# Capture stdin and format the output
	###################################################################
	
	sig_info=$( /bin/cat - )

	# determine the top-level element
	local_name=$( echo "$sig_info" | $_GREP -E '^(EntityDescriptor|EntitiesDescriptor)$' )
	if [ -z "$local_name" ]; then
		print_log_message -E "$FUNCNAME: no input found"
		return 4
	fi

	doc_id=$( echo "$sig_info" | $_GREP '^ID' | $_CUT -f2 )
	if [ -z "$doc_id" ]; then
		print_log_message -E "$FUNCNAME: document ID not found"
		return 4
	fi
	print_log_message -I "$FUNCNAME: $local_name @ID=$doc_id"

	referenceURI=$( echo "$sig_info" | $_GREP '^ReferenceURI' | $_CUT -f2 )
	if [ -z "$referenceURI" ]; then
		print_log_message -E "$FUNCNAME: Reference URI not found"
		return 4
	fi
	printf "$f_spec" "Reference URI" "$referenceURI"
	print_log_message -D "$FUNCNAME: Reference URI: $referenceURI"

	canonicalizationMethod=$( echo "$sig_info" | $_GREP '^CanonicalizationMethod' | $_CUT -f2 )
	if [ -z "$canonicalizationMethod" ]; then
		print_log_message -E "$FUNCNAME: CanonicalizationMethod Algorithm not found"
		return 4
	fi
	printf "$f_spec" "CanonicalizationMethod" "$canonicalizationMethod"
	print_log_message -D "$FUNCNAME: CanonicalizationMethod: $canonicalizationMethod"

	signatureMethod=$( echo "$sig_info" | $_GREP '^SignatureMethod' | $_CUT -f2 )
	if [ -z "$signatureMethod" ]; then
		print_log_message -E "$FUNCNAME: SignatureMethod Algorithm not found"
		return 4
	fi
	printf "$f_spec" "SignatureMethod" "$signatureMethod"
	print_log_message -D "$FUNCNAME: SignatureMethod: $signatureMethod"

	digestMethod=$( echo "$sig_info" | $_GREP '^DigestMethod' | $_CUT -f2 )
	if [ -z "$digestMethod" ]; then
		print_log_message -E "$FUNCNAME: DigestMethod Algorithm not found"
		return 4
	fi
	printf "$f_spec" "DigestMethod" "$digestMethod"
	print_log_message -D "$FUNCNAME: DigestMethod: $digestMethod"
	
	serial=$( echo "$sig_info" | $_GREP '^serial' | $_CUT -f2 )
	if [ -n "$serial" ]; then
		printf "$f_spec" "Cert serial number" "$serial"
		print_log_message -D "$FUNCNAME: Cert serial number: $serial"
	fi
	
	notBefore=$( echo "$sig_info" | $_GREP '^notBefore' | $_CUT -f2 )
	if [ -n "$notBefore" ]; then
		printf "$f_spec" "Cert start date" "$notBefore"
		print_log_message -D "$FUNCNAME: Cert start date: $notBefore"
	fi
	
	notAfter=$( echo "$sig_info" | $_GREP '^notAfter' | $_CUT -f2 )
	if [ -n "$notAfter" ]; then
		printf "$f_spec" "Cert expiration date" "$notAfter"
		print_log_message -D "$FUNCNAME: Cert expiration date: $notAfter"
	fi
	
	CN=$( echo "$sig_info" | $_GREP '^commonName' | $_CUT -f2 )
	if [ -n "$CN" ]; then
		printf "$f_spec" "Cert subject common name" "$CN"
		print_log_message -D "$FUNCNAME: Cert subject common name: $CN"
	fi
	
	keySize=$( echo "$sig_info" | $_GREP '^keySize' | $_CUT -f2 )
	if [ -n "$keySize" ]; then
		printf "$f_spec" "Cert key size (bits)" "$keySize"
		print_log_message -D "$FUNCNAME: Cert key size: $keySize"
	fi
	
	fingerprint=$( echo "$sig_info" | $_GREP '^SHA1_fingerprint' | $_CUT -f2 )
	if [ -n "$fingerprint" ]; then
		printf "$f_spec" "Cert SHA1 fingerprint" "$fingerprint"
		print_log_message -D "$FUNCNAME: Cert SHA1 fingerprint: $fingerprint"
	fi
	
	return 0
}

#######################################################################
#
# Pretty-print a summary of roles for entities in the given SAML
# metadata document.
#
# Usage: output=$( parse_entity_roles -T TMP_FILE MD_FILE | printf_entity_counts )
#
# Call this function if the top-level element of the document is
# md:EntitiesDescriptor. (There is little value in calling this
# function on a single entity descriptor.)
#
# Dependencies:
#   core_lib.bash
#   xsl_wrappers.bash
#
# Used by:
#   md_printf.bash
#
#######################################################################
printf_entity_counts () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	local num_registrars
	local num_entities
	local role_info
	local s
	local roles
	local role
	local num_roles
	
	# check the number of command-line arguments
	#shift $(( OPTIND - 1 ))
	if [ $# -ne 0 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (0 required)"
		return 2
	fi
	
	###################################################################
	# Capture stdin and format the output
	###################################################################
	
	role_info=$( /bin/cat - )

	# How many registrars?
	num_registrars=$( echo "$role_info" | $_GREP '^numRegistrars' | $_CUT -f2 )

	# How many entity descriptors?
	num_entities=$( echo "$role_info" | $_GREP -E '^numEntities\t' | $_CUT -f2 )

	s=$( printf "%4d entities total, spread over %d registrars" $num_entities $num_registrars )
	print_log_message -I "$FUNCNAME: $s"
	echo "$s"

	# How many roles of each type?
	roles="SPSSODescriptor IDPSSODescriptor AttributeAuthorityDescriptor AuthnAuthorityDescriptor PDPDescriptor"
	for role in $roles; do
		num_roles=$( echo "$role_info" | $_GREP "^numEntitiesWith$role" | $_CUT -f2 )
		if [ "$num_roles" -gt 0 ]; then
			s=$( printf "%4d entities with at least one %s" $num_roles $role )
			print_log_message -D "$FUNCNAME: $s"
			echo "$s"
		fi
	done
	
	return 0
}

#######################################################################
#
# This script ensures that the given SAML metadata file is valid, as
# indicated by the @validUntil and @creationInstant XML attributes.
#
# This script takes its input from the parse_saml_metadata function:
#
#  $ parse_saml_metadata MD_FILE \
#      | require_valid_metadata [-t DATE_TIME]
#
# The script logs a warning and returns error code 1 if either of 
# the following conditions are true:
#
#   - The @validUntil attribute exists in metadata but its
#     value is NOT in the future.
#
#   - The @creationInstant attribute exists in metadata but its
#     value is in the future.
#
# Options:
#  -t      ISO 6801 dateTime for the current time
#
# If the caller supplies a dateTime value using the -t option, the
# script uses that to determine metadata validity. If no -t option
# is given on the command line, the script computes its own value
# for the current time.
#
# Dependencies:
#   core_lib.bash
#   compatible_date.bash
#
# Used by:
#   md_require_valid_metadata.bash
#   md_sweep.bash
#
# TODO: What if the top-level element is EntitiesDescriptor
#       and there are @validUntil attributes on the child elements?
#
#######################################################################
require_valid_metadata () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ "$(type -t secsBetween)" != function ]; then
		print_log_message -E "$FUNCNAME: function secsBetween not found"
		return 2
	fi
	
	local doc_info
	local validUntil
	local validUntilSecs
	local currentTime
	local currentTimeSecs
	local secsUntilExpiration
	local untilExpiration
	local sinceExpiration
	local creationInstant
	local secsSinceCreation
	local sinceCreation
	local untilCreation
	local exit_status
	
	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":t:" opt; do
		case $opt in
			t)
				currentTime=$OPTARG
				;;
			\?)
				print_log_message -E "$FUNCNAME: Unrecognized option: -$OPTARG"
				return 2
				;;
			:)
				print_log_message -E "$FUNCNAME: Option -$OPTARG requires an argument"
				return 2
				;;
		esac
	done
	
	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 0 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (0 required)"
		return 2
	fi

	# compute current dateTime (if necessary)
	if [ -z "$currentTime" ]; then
		currentTime=$( dateTime_now_canonical )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: dateTime_now_canonical failed ($exit_status) to compute currentTime"
			return 3
		fi
	fi
	print_log_message -D "$FUNCNAME: currentTime: $currentTime"

	###################################################################
	# Check both @creationInstant and @validUntil
	###################################################################

	doc_info=$( /bin/cat - | $_GREP -E '^(creationInstant|validUntil)' )
	
	# if @validUntil exists, check it
	validUntil=$( echo "$doc_info" | $_GREP '^validUntil' | $_CUT -f2 )
	if [ -z "$validUntil" ]; then
		print_log_message -I "$FUNCNAME: metadata has no @validUntil attribute"
	else
		print_log_message -I "$FUNCNAME: validUntil: $validUntil"
		
		# compute secsUntilExpiration (which may be negative)
		secsUntilExpiration=$( secsBetween $currentTime $validUntil )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: secsBetween failed ($exit_status) to compute secsUntilExpiration"
			return 3
		fi
		print_log_message -D "$FUNCNAME: secsUntilExpiration: $secsUntilExpiration"
	
		# if the metadata has already expired, compute sinceExpiration (for logging)
		if [ "$secsUntilExpiration" -le 0 ]; then
			# compute sinceExpiration (for logging) but first strip the minus sign
			sinceExpiration=$( secs2duration "${secsUntilExpiration#-}" )
			exit_status=$?
			if [ $exit_status -eq 0 ]; then
				print_log_message -W "$FUNCNAME: invalid metadata: time since expiration: $sinceExpiration"
			else
				print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute sinceExpiration"
				print_log_message -W "$FUNCNAME: invalid metadata: seconds since expiration: ${secsUntilExpiration#-}"
			fi
			return 1
		fi
	
		# compute untilExpiration (for logging)
		untilExpiration=$( secs2duration "$secsUntilExpiration" )
		exit_status=$?
		if [ $exit_status -eq 0 ]; then
			print_log_message -I "$FUNCNAME: time until expiration: $untilExpiration"
		else
			print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute untilExpiration"
			print_log_message -I "$FUNCNAME: seconds until expiration: $secsUntilExpiration"
		fi
	fi
	
	# if @creationInstant exists, check it
	creationInstant=$( echo "$doc_info" | $_GREP '^creationInstant' | $_CUT -f2 )
	if [ -z "$creationInstant" ]; then
		print_log_message -I "$FUNCNAME: metadata has no @creationInstant attribute"
	else
		print_log_message -I "$FUNCNAME: creationInstant: $creationInstant"
		
		# compute secsSinceCreation (which may be negative)
		secsSinceCreation=$( secsBetween $creationInstant $currentTime )
		status_code=$?
		if [ $status_code -ne 0 ]; then
			print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) to compute secsSinceCreation"
			return 3
		fi
		print_log_message -D "$FUNCNAME: secsSinceCreation: $secsSinceCreation"
	
		# this is a sanity check
		# if the metadata hasn't yet been created, compute untilCreation (for logging)
		if [ "$secsSinceCreation" -lt 0 ]; then
			# compute untilCreation (for logging) but first strip the minus sign
			untilCreation=$( secs2duration "${secsSinceCreation#-}" )
			exit_status=$?
			if [ $exit_status -eq 0 ]; then
				print_log_message -W "$FUNCNAME: invalid metadata: time until creation: $untilCreation"
			else
				print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute untilCreation"
				print_log_message -W "$FUNCNAME: invalid metadata: seconds until creation: ${secsSinceCreation#-}"
			fi
			return 1
		fi
	
		# compute sinceCreation (for logging)
		sinceCreation=$( secs2duration "$secsSinceCreation" )
		exit_status=$?
		if [ $exit_status -eq 0 ]; then
			print_log_message -I "$FUNCNAME: time since creation: $sinceCreation"
		else
			print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute sinceCreation"
			print_log_message -I "$FUNCNAME: seconds since creation: $secsSinceCreation"
		fi
	fi
	
	return 0
}

#######################################################################
#
# This script checks the expiration warning interval, which is
# determined by the @validUntil attribute in metadata.
#
# This script takes its input from the parse_saml_metadata function:
#
#  $ parse_saml_metadata MD_FILE \
#      | check_expiration_warning_interval [-t DATE_TIME] DURATION
#
# The DURATION argument specifies the length of the expiration
# warning interval as an ISO 8601 duration. For more info, see:
# https://en.wikipedia.org/wiki/ISO_8601#Durations
#
# Options:
#  -t      ISO 6801 dateTime for the current time (NOW)
#
# If the caller supplies a dateTime value using the -t option, the
# script uses that to determine whether a warning message should be
# logged. If no -t option is given on the command line, the script
# computes the current time on-the-fly and uses that instead.
#
# This script is a wrapper around the check_validity_subintervals()
# function. Consult the inline documentation on the latter function
# for more info.
#
# Dependencies:
#   core_lib.bash
#   compatible_date.bash
#
# Used by:
#   md_sweep.bash
#
#######################################################################
check_expiration_warning_interval () {
	
	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	local local_opt
	local expirationWarningInterval

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":t:" opt; do
		case $opt in
			t)
				local_opt="-$opt $OPTARG"
				;;
			\?)
				print_log_message -E "$FUNCNAME: Unrecognized option: -$OPTARG"
				return 2
				;;
			:)
				print_log_message -E "$FUNCNAME: Option -$OPTARG requires an argument"
				return 2
				;;
		esac
	done
	
	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	expirationWarningInterval=$1
	
	check_validity_subintervals $local_opt $expirationWarningInterval
}

#######################################################################
#
# This script checks the subintervals of the validity interval,
# that is, it checks the expiration warning interval (for soon-to-be
# expired metadata) and/or the freshness interval (for stale metadata).
#
# This script logs an expiration warning message if the metadata is
# soon-to-be expired. Failing that, if the metadata was created too
# far in the past, the scripts logs a stale metadata warning instead.
#
# This script takes its input from the parse_saml_metadata function:
#
#  $ parse_saml_metadata MD_FILE \
#      | check_validity_subintervals [-t DATE_TIME] DURATION1 [DURATION2]
#
# The DURATION1 and DURATION2 arguments specify the lengths of
# the expiration warning interval and the freshness interval,
# respectively. Both arguments are given as ISO 8601 durations.
# See: https://en.wikipedia.org/wiki/ISO_8601#Durations
#
# If specified, the length of the freshness interval (DURATION2)
# must be strictly positive. If the length of the freshness interval
# is zero, the script logs an error message and returns with an error
# code >1.
#
# The input metadata must be valid (i.e., not expired). Otherwise
# the script logs an error message and returns with an error code >1.
#
# Options:
#  -t      ISO 6801 dateTime for the current time (NOW)
#
# If the caller supplies a dateTime value using the -t option, the
# script uses that to determine whether a warning message should be
# logged. If no -t option is given on the command line, the script
# computes the current time on-the-fly and uses that instead.
#
# EXPIRATION WARNING INTERVAL
#
# By definition, the right-hand endpoint of the expiration warning
# interval is the value of the @validUntil attribute in metadata.
# The left-hand endpoint is called the expiration warning threshold,
# whose value is determined by the interval length given by the
# DURATION1 argument on the command line. If the current time
# exceeds the expiration warning threshold, the script logs a
# warning message and returns with code 1.
#
# For example, suppose the length of the expiration warning
# interval is two days (P2D). In that case, a warning message is
# logged if the current time is within two days of @validUntil.
#
# FRESHNESS INTERVAL
#
# By definition, the left-hand endpoint of the freshness interval
# is the value of the @creationInstant attribute in metadata.
# The right-hand endpoint is determined by the interval length,
# given by DURATION2 argument on the command line. If the current
# time exceeds the right-hand endpoint of the freshness interval, 
# the script logs a warning message and returns with code 1.
#
# For example, suppose the length of the freshness interval is
# two days (P2D). In that case, the metadata is stale if the
# @creationInstant attribute indicates the age of the metadata
# (which is a function of the current time) is more than two days.
#
# VALIDITY INTERVAL
#
# By definition, the endpoints of the validity interval are the
# values of the @creationInstant and @validUntil attributes,
# respectively. If the sum of the lengths of the freshness
# interval and the expiration warning interval exceed the actual
# length of the validity interval, the two subintervals necessarily
# overlap, in which case the script logs an error message and
# returns with code >1.
#
# For example, suppose the lengths of the freshness interval and
# the expiration warning interval are five days (P5D) and three
# days (P3D), respectively. If the script computes the actual
# validity interval to be one week, the script logs an error
# message and returns with code >1 since 5 + 3 > 7. In this
# particular case, more appropriate subinterval lengths might
# be 3 and 2 (resp.).
#
# ALGORITHM
#
# The script tests the following conditions in sequence. If a
# particular condition is false, the script terminates immediately.
#
#   1. The top-level element of the metadata is decorated with
#      a @validUntil attribute (otherwise return normally)
#
#   2. The metadata is not expired (otherwise log an error and
#      return with an error code >1)
#
#   3. The time until expiration is greater than the given
#      expiration warning interval (otherwise log an expiration
#      warning message and return with code 1)
#
#   4. The length of the freshness interval is specified on the
#      command line (otherwise return normally)
#
#   5. The top-level element of the metadata is associated with
#      a @creationInstant attribute (otherwise return normally)
#
#   6. The value of the @creationInstant attribute is not in the
#      future (otherwise log an error and return with an error 
#      code >1)
#
#   7. The expiration warning interval and the freshness interval
#      do not overlap (otherwise log an error and return with an 
#      error code >1)
#
#   8. The time since creation is less than the given freshness
#      interval (otherwise log a stale metadata warning message
#      and return with code >1)
#
# Note that an expiration warning message is logged if both
# conditions 1 and 2 are true while condition 3 is false.
# Similarly a stale metadata warning message is logged if
# conditions 1--7 are true while condition 8 is false.
#
# Return codes:
#   0: Success
#   1: Warning message logged
#   2: Initialization failed
#   3: Unexpected failure
#   4: Invalid (expired) metadata
#   5: @creationInstant is in the future
#   6: Subintervals overlap
#
# Dependencies:
#   core_lib.bash
#   compatible_date.bash
#
# Used by:
#   md_require_valid_metadata.bash
#
#######################################################################
check_validity_subintervals () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ "$(type -t dateTime_now_canonical)" != function ]; then
		print_log_message -E "$FUNCNAME: function dateTime_now_canonical not found"
		return 2
	fi
	
	local currentTime
	local doc_info
	local log_message
	local exit_status
	
	local validUntil
	local expirationWarningInterval
	local expirationWarningIntervalSecs
	local expirationWarningThreshold
	local untilExpiration
	local secsUntilExpiration
	local sinceExpiration
	local untilFirstWarning
	local secsUntilFirstWarning
	
	local creationInstant
	local freshnessInterval
	local freshnessIntervalSecs
	local sinceCreation
	local secsSinceCreation
	local untilCreation
	local actualValidityIntervalSecs
	local actualValidityInterval
	local freshUntil
	local untilFirstWarning
	local secsUntilFirstWarning

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":t:" opt; do
		case $opt in
			t)
				currentTime=$OPTARG
				;;
			\?)
				print_log_message -E "$FUNCNAME: Unrecognized option: -$OPTARG"
				return 2
				;;
			:)
				print_log_message -E "$FUNCNAME: Option -$OPTARG requires an argument"
				return 2
				;;
		esac
	done
	
	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ] && [ $# -ne 2 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 or 2 required)"
		return 2
	fi
	expirationWarningInterval=$1
	
	# compute the length of the expiration warning interval (in secs)
	expirationWarningIntervalSecs=$( duration2secs "$expirationWarningInterval" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: duration2secs failed ($exit_status) to compute expirationWarningIntervalSecs"
		return 3
	fi
	print_log_message -I "$FUNCNAME: length of expiration warning interval: $expirationWarningIntervalSecs ($expirationWarningInterval)"
	
	if [ $# -eq 2 ]; then
		freshnessInterval=$2
		
		# compute the length of the freshness interval (in secs)
		freshnessIntervalSecs=$( duration2secs "$freshnessInterval" )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: duration2secs failed ($exit_status) to compute freshnessIntervalSecs"
			return 3
		fi
	
		# log an error if the length of the freshness interval is zero
		if [ "$freshnessIntervalSecs" -eq 0 ]; then
			print_log_message -E "$FUNCNAME: length of freshness interval: 0 ($freshnessInterval)"
			return 2
		fi
		print_log_message -I "$FUNCNAME: length of freshness interval: $freshnessIntervalSecs ($freshnessInterval)"
	fi

	###################################################################
	# Does @validUntil exist? If not, return normally.
	###################################################################

	doc_info=$( /bin/cat - | $_GREP -E '^(creationInstant|validUntil)' )
	
	# return normally if @validUntil does not exist
	validUntil=$( echo "$doc_info" | $_GREP '^validUntil' | $_CUT -f2 )
	if [ -z "$validUntil" ]; then
		print_log_message -I "$FUNCNAME: validUntil not found"
		return 0
	fi
	print_log_message -D "$FUNCNAME: validUntil: $validUntil"
	
	###################################################################
	# Is the metadata expired? If so, return abnormally.
	###################################################################

	# compute current dateTime (if necessary)
	if [ -z "$currentTime" ]; then
		currentTime=$( dateTime_now_canonical )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: dateTime_now_canonical failed ($exit_status) to compute currentTime"
			return 3
		fi
	fi
	print_log_message -D "$FUNCNAME: currentTime: $currentTime"

	# compute secsUntilExpiration (which may be negative)
	secsUntilExpiration=$( secsBetween $currentTime $validUntil )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($exit_status) to compute secsUntilExpiration"
		return 3
	fi
	print_log_message -D "$FUNCNAME: secsUntilExpiration: $secsUntilExpiration"

	# log an error if the metadata has already expired
	if [ "$secsUntilExpiration" -le 0 ]; then
		# compute sinceExpiration (for logging) but first strip the minus sign
		sinceExpiration=$( secs2duration "${secsUntilExpiration#-}" )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute sinceExpiration"
			return 3
		fi
		print_log_message -E "$FUNCNAME: time since expiration: $sinceExpiration"
		return 4
	fi

	###################################################################
	# Log an expiration warning message? If so, return with code 1.
	###################################################################

	# compute expirationWarningThreshold (for logging)
	expirationWarningThreshold=$( dateTime_delta -e $validUntil "$expirationWarningInterval" )
	exit_status=$?
	if [ $exit_status -eq 0 ]; then
		print_log_message -D "$FUNCNAME: expirationWarningThreshold: $expirationWarningThreshold"
	else
		print_log_message -E "$FUNCNAME: dateTime_delta failed ($exit_status) to compute expirationWarningThreshold"
	fi

	# compute untilExpiration (for logging)
	untilExpiration=$( secs2duration "$secsUntilExpiration" )
	exit_status=$?
	if [ $exit_status -eq 0 ]; then
		log_message="seconds until expiration: $secsUntilExpiration ($untilExpiration)"
	else
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute untilExpiration"
		log_message="seconds until expiration: $secsUntilExpiration"
	fi

	# log warning if an expiration event is imminent
	if [ "$secsUntilExpiration" -le "$expirationWarningIntervalSecs" ]; then
		print_log_message -W "$FUNCNAME: $log_message"
		return 1
	fi
	print_log_message -I "$FUNCNAME: $log_message"
	
	# compute time until first warning (for logging)
	secsUntilFirstWarning=$(( secsUntilExpiration - expirationWarningIntervalSecs ))
	untilFirstWarning=$( secs2duration $secsUntilFirstWarning )
	exit_status=$?
	if [ $exit_status -eq 0 ]; then
		print_log_message -I "$FUNCNAME: seconds until first expiration warning: $secsUntilFirstWarning ($untilFirstWarning)"
	else
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute untilFirstWarning"
		print_log_message -I "$FUNCNAME: seconds until first expiration warning: $secsUntilFirstWarning"
	fi
	
	###################################################################
	# Is freshnessInterval null? If so, return normally.
	###################################################################

	[ -z "$freshnessInterval" ] && return 0

	###################################################################
	# Does @creationInstant exist? If not, return normally.
	###################################################################

	# return normally if @creationInstant does not exist
	creationInstant=$( echo "$doc_info" | $_GREP '^creationInstant' | $_CUT -f2 )
	if [ -z "$creationInstant" ]; then
		print_log_message -I "$FUNCNAME: creationInstant not found"
		return 0
	fi
	print_log_message -D "$FUNCNAME: creationInstant: $creationInstant"
		
	###################################################################
	# Is @creationInstant in the future? If so, return abnormally.
	###################################################################

	# compute secsSinceCreation (which may be negative)
	secsSinceCreation=$( secsBetween $creationInstant $currentTime )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) to compute secsSinceCreation"
		return 3
	fi
	print_log_message -D "$FUNCNAME: secsSinceCreation: $secsSinceCreation"

	# log an error if @creationInstant is in the future
	if [ "$secsSinceCreation" -lt 0 ]; then
		# compute untilCreation (for logging) but first strip the minus sign
		untilCreation=$( secs2duration "${secsSinceCreation#-}" )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute untilCreation"
			return 3
		fi
		print_log_message -E "$FUNCNAME: time until creation: $untilCreation"
		return 5
	fi
	
	###################################################################
	# Do the subintervals overlap? If so, return abnormally.
	###################################################################

	# compute the actual length of the validity interval (in secs)
	actualValidityIntervalSecs=$( secsBetween $creationInstant $validUntil )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($exit_status) to compute actualValidityIntervalSecs"
		return 3
	fi
	
	# sanity check (if the metadata is valid and @creationInstant is NOT in the future, this is impossible)
	if [ "$actualValidityIntervalSecs" -lt 0 ]; then
		print_log_message -E "$FUNCNAME: validity interval has negative length: $actualValidityIntervalSecs"
		return 3
	fi
	
	# compute actualValidityInterval (for logging)
	actualValidityInterval=$( secs2duration "$actualValidityIntervalSecs" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute actualValidityInterval"
		print_log_message -I "$FUNCNAME: length of validity interval: $actualValidityIntervalSecs"
	else
		print_log_message -I "$FUNCNAME: length of validity interval: $actualValidityIntervalSecs ($actualValidityInterval)"
	fi

	# log an error if the subintervals overlap
	if (( freshnessIntervalSecs + expirationWarningIntervalSecs > actualValidityIntervalSecs )); then
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: subintervals overlap"
		else
			print_log_message -E "$FUNCNAME: subintervals overlap: '$freshnessInterval' + '$expirationWarningInterval' > '$actualValidityInterval'"
		fi
		return 6
	fi
	
	###################################################################
	# Log stale metadata warning message? If so, return with code 1.
	###################################################################

	# compute freshUntil (for logging)
	freshUntil=$( dateTime_delta -b $creationInstant "$freshnessInterval" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_delta failed ($exit_status) to compute freshUntil"
	else
		print_log_message -D "$FUNCNAME: freshUntil: $freshUntil"
	fi

	# compute sinceCreation (for logging)
	sinceCreation=$( secs2duration "$secsSinceCreation" )
	exit_status=$?
	if [ $exit_status -eq 0 ]; then
		log_message="seconds since creation: $secsSinceCreation ($sinceCreation)"
	else
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute sinceCreation"
		log_message="seconds since creation: $secsSinceCreation"
	fi

	# log warning if beyond the stale warning threshold
	if [ "$secsSinceCreation" -ge "$freshnessIntervalSecs" ]; then
		print_log_message -W "$FUNCNAME: $log_message"
		return 1
	fi
	print_log_message -I "$FUNCNAME: $log_message"
	
	###################################################################
	# Return normally.
	###################################################################

	# compute time until first stale metadata warning (for logging)
	secsUntilFirstWarning=$(( freshnessIntervalSecs - secsSinceCreation ))
	untilFirstWarning=$( secs2duration $secsUntilFirstWarning )
	exit_status=$?
	if [ $exit_status -eq 0 ]; then
		print_log_message -I "$FUNCNAME: seconds until first stale metadata warning: $secsUntilFirstWarning ($untilFirstWarning)"
	else
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute untilFirstWarning"
		print_log_message -I "$FUNCNAME: seconds until first stale metadata warning: $secsUntilFirstWarning"
	fi
	
	return 0
}

#######################################################################
#
# This function is DEPRECATED. Use check_validity_subintervals instead.
#
# This script checks the freshness interval, which is determined by
# the @creationInstant attribute in metadata.
#
# This script takes its input from the parse_saml_metadata function:
#
#  $ parse_saml_metadata MD_FILE \
#      | check_freshness_interval [-t DATE_TIME] DURATION1 DURATION2
#
# The DURATION1 and DURATION2 arguments specify the lengths of the 
# freshness interval and the expiration warning interval, respectively.
# Each of these arguments is formatted as an ISO 8601 duration.
#
# The script logs an error and returns an error code >1 if either
# of the following conditions is true:
#
#  - The @creationInstant attribute exists in metadata but its
#    value is in the future.
#
#  - The value of the @creationInstant attribute is greater than
#    the value of the @validUntil attribute
#
# The script logs a warning and returns error code 1 if either
# of the following conditions is true:
#
#  - The freshness interval overlaps with the expiration
#    warning interval
#
#  - The value of the @creationInstant attribute exceeds 
#    the right-hand endpoint of the freshness interval 
#
# By definition, the endpoints of the validity interval
# are the values of the @creationInstant and @validUntil
# attributes, respectively. If the sum of the lengths of the
# freshness interval and the expiration warning interval
# exceed the actual length of the validity interval, the
# two subintervals necessarily overlap, in which case the
# script logs a warning message and exits with code 1.
#
# For example, suppose the lengths of the freshness interval
# and the expiration warning interval are five days (P5D) and
# three days (P3D), respectively. If the script computes the
# actual validity interval to be one week, the script logs a
# warning message and exits since 5 + 3 > 7. More appropriate
# subinterval lengths might be 3 and 2 (resp.) in this case.
#
# By definition, the value of the @creationInstant attribute
# determines the left-hand endpoint of the freshness interval.
# The right-hand endpoint is determined by the interval length,
# given by DURATION1 argument on the command line. If the current
# time exceeds the right-hand endpoint of the freshness interval, 
# the script logs a warning message and exits with code 1.
#
# For example, suppose the length of the freshness interval is
# two days (P2D). In that case, the metadata is stale if the
# @creationInstant attribute indicates the age of the metadata
# (which is a function of the current time) is more than two days.
#
# Options:
#  -t      ISO 6801 dateTime for the current time (NOW)
#
# If the caller supplies a dateTime value using the -t option, the
# script uses that to determine whether a warning message should be
# logged. If no -t option is given on the command line, the script
# computes the current time on-the-fly and uses that instead.
#
# Dependencies:
#   core_lib.bash
#   compatible_date.bash
#
# Used by:
#   UNUSED
#
# See also: https://en.wikipedia.org/wiki/ISO_8601#Durations
#
#######################################################################
check_freshness_interval () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ "$(type -t dateTime_now_canonical)" != function ]; then
		print_log_message -E "$FUNCNAME: function dateTime_now_canonical not found"
		return 2
	fi
	
	local currentTime
	local freshnessInterval
	local freshnessIntervalSecs
	local expirationWarningInterval
	local expirationWarningIntervalSecs
	local doc_info
	local creationInstant
	local validUntil
	local actualValidityIntervalSecs
	local actualValidityInterval
	local secsSinceCreation
	local untilCreation
	local freshUntil
	local sinceCreation
	local log_message
	local secsUntilFirstWarning
	local untilFirstWarning
	local exit_status

	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":t:" opt; do
		case $opt in
			t)
				currentTime=$OPTARG
				;;
			\?)
				print_log_message -E "$FUNCNAME: Unrecognized option: -$OPTARG"
				return 2
				;;
			:)
				print_log_message -E "$FUNCNAME: Option -$OPTARG requires an argument"
				return 2
				;;
		esac
	done
	
	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 2 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (2 required)"
		return 2
	fi
	freshnessInterval=$1
	expirationWarningInterval=$2

	###################################################################
	# Do both @creationInstant and @validUntil exist?
	###################################################################

	doc_info=$( /bin/cat - | $_GREP -E '^(creationInstant|validUntil)' )
	
	# return normally if @creationInstant does not exist
	creationInstant=$( echo "$doc_info" | $_GREP '^creationInstant' | $_CUT -f2 )
	if [ -z "$creationInstant" ]; then
		print_log_message -I "$FUNCNAME: creationInstant not found"
		return 0
	fi
	
	# return normally if @validUntil does not exist
	validUntil=$( echo "$doc_info" | $_GREP '^validUntil' | $_CUT -f2 )
	if [ -z "$validUntil" ]; then
		print_log_message -I "$FUNCNAME: validUntil not found"
		return 0
	fi

	# both exist
	print_log_message -D "$FUNCNAME: creationInstant: $creationInstant"
	print_log_message -D "$FUNCNAME: validUntil: $validUntil"
		
	###################################################################
	# Is @creationInstant in the future?
	###################################################################

	# compute current dateTime (if necessary)
	if [ -z "$currentTime" ]; then
		currentTime=$( dateTime_now_canonical )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: dateTime_now_canonical failed ($exit_status) to compute currentTime"
			return 3
		fi
	fi
	print_log_message -D "$FUNCNAME: currentTime: $currentTime"

	# compute secsSinceCreation (which may be negative)
	secsSinceCreation=$( secsBetween $creationInstant $currentTime )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) to compute secsSinceCreation"
		return 3
	fi
	print_log_message -D "$FUNCNAME: secsSinceCreation: $secsSinceCreation"

	# this is mostly a sanity check
	if [ "$secsSinceCreation" -lt 0 ]; then
		# compute untilCreation (for logging) but first strip the minus sign
		untilCreation=$( secs2duration "${secsSinceCreation#-}" )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute untilCreation"
			return 3
		fi
		print_log_message -E "$FUNCNAME: time until creation: $untilCreation"
		return 5
	fi
	
	###################################################################
	# Log a warning message if the subintervals overlap
	###################################################################

	# compute the length of the freshness interval (in secs)
	freshnessIntervalSecs=$( duration2secs "$freshnessInterval" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: duration2secs failed ($exit_status) to compute freshnessIntervalSecs"
		return 3
	fi
	
	# short-circuit if the length of the freshness interval is zero
	if [ "$freshnessIntervalSecs" -eq 0 ]; then
		print_log_message -I "$FUNCNAME: length of freshness interval: 0 ($freshnessInterval)"
		return 0
	fi
	print_log_message -I "$FUNCNAME: length of freshness interval: $freshnessIntervalSecs ($freshnessInterval)"

	# compute the length of the expiration warning interval (in secs) (which may be zero)
	expirationWarningIntervalSecs=$( duration2secs "$expirationWarningInterval" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: duration2secs failed ($exit_status) to compute expirationWarningIntervalSecs"
		return 3
	fi
	print_log_message -I "$FUNCNAME: length of expiration warning interval: $expirationWarningIntervalSecs ($expirationWarningInterval)"
	
	# compute the actual length of the validity interval (in secs)
	actualValidityIntervalSecs=$( secsBetween $creationInstant $validUntil )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($exit_status) to compute actualValidityIntervalSecs"
		return 3
	fi
	
	# sanity check
	if [ "$actualValidityIntervalSecs" -lt 0 ]; then
		print_log_message -E "$FUNCNAME: validity interval has negative length: $actualValidityIntervalSecs"
		return 4
	fi
	
	# compute actualValidityInterval (for logging)
	actualValidityInterval=$( secs2duration "$actualValidityIntervalSecs" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute actualValidityInterval"
		print_log_message -I "$FUNCNAME: length of validity interval: $actualValidityIntervalSecs"
	else
		print_log_message -I "$FUNCNAME: length of validity interval: $actualValidityIntervalSecs ($actualValidityInterval)"
	fi

	# log a warning if the subintervals overlap
	if (( freshnessIntervalSecs + expirationWarningIntervalSecs > actualValidityIntervalSecs )); then
		if [ $exit_status -ne 0 ]; then
			print_log_message -W "$FUNCNAME: subintervals overlap"
		else
			print_log_message -W "$FUNCNAME: subintervals overlap: '$freshnessInterval' + '$expirationWarningInterval' > '$actualValidityInterval'"
		fi
		return 1
	fi
	
	###################################################################
	# Log a warning message if the metadata is stale
	###################################################################

	# compute freshUntil (for logging)
	freshUntil=$( dateTime_delta -b $creationInstant "$freshnessInterval" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_delta failed ($exit_status) to compute freshUntil"
	else
		print_log_message -D "$FUNCNAME: freshUntil: $freshUntil"
	fi

	# compute sinceCreation (for logging)
	sinceCreation=$( secs2duration "$secsSinceCreation" )
	exit_status=$?
	if [ $exit_status -eq 0 ]; then
		log_message="seconds since creation: $secsSinceCreation ($sinceCreation)"
	else
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute sinceCreation"
		log_message="seconds since creation: $secsSinceCreation"
	fi

	# log warning if beyond the stale warning threshold
	if [ "$secsSinceCreation" -ge "$freshnessIntervalSecs" ]; then
		print_log_message -W "$FUNCNAME: $log_message"
		return 1
	fi
	print_log_message -I "$FUNCNAME: $log_message"
	
	# compute time until first warning (for logging)
	secsUntilFirstWarning=$(( freshnessIntervalSecs - secsSinceCreation ))
	untilFirstWarning=$( secs2duration $secsUntilFirstWarning )
	exit_status=$?
	if [ $exit_status -eq 0 ]; then
		print_log_message -I "$FUNCNAME: seconds until first stale warning: $secsUntilFirstWarning ($untilFirstWarning)"
	else
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute untilFirstWarning"
		print_log_message -I "$FUNCNAME: seconds until first stale warning: $secsUntilFirstWarning"
	fi
	
	return 0
}

#######################################################################
#
# This script checks the validity interval, which is determined by
# the @creationInstant and @validUntil attributes in metadata. If
# these attributes exist, and the actual length of the validity
# interval is unexpected, a warning message is logged.
#
# This script takes its input from the parse_saml_metadata function:
#
#  $ parse_saml_metadata MD_FILE | check_validity_interval DURATION
#
# The DURATION argument specifies the expected length of the
# validity interval as an ISO 8601 duration.
#
# By definition, the dateTime values of the @creationInstant attribute
# and the @validUntil attribute are the respective endpoints of the
# validity interval. If the actual length of the validity interval is
# different than the expected length, the script logs a warning message.
#
# Dependencies:
#   core_lib.bash
#   compatible_date.bash
#
# Used by:
#   UNUSED
#
# See also: https://en.wikipedia.org/wiki/ISO_8601#Durations
#
#######################################################################
check_validity_interval () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ "$(type -t secsBetween)" != function ]; then
		print_log_message -E "$FUNCNAME: function secsBetween not found"
		return 2
	fi
	
	local doc_info
	local creationInstant
	local validUntil
	local expectedValidityInterval
	local expectedValidityIntervalSecs
	local actualValidityIntervalSecs
	local actualValidityInterval
	local exit_status

	# check the number of command-line arguments
	#shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	expectedValidityInterval=$1

	###################################################################
	# Do both @creationInstant and @validUntil exist?
	###################################################################

	doc_info=$( /bin/cat - | $_GREP -E '^(creationInstant|validUntil)' )
	
	# return normally if @creationInstant does not exist
	creationInstant=$( echo "$doc_info" | $_GREP '^creationInstant' | $_CUT -f2 )
	if [ -z "$creationInstant" ]; then
		print_log_message -I "$FUNCNAME: creationInstant not found"
		return 0
	fi
	
	# return normally if @validUntil does not exist
	validUntil=$( echo "$doc_info" | $_GREP '^validUntil' | $_CUT -f2 )
	if [ -z "$validUntil" ]; then
		print_log_message -I "$FUNCNAME: validUntil not found"
		return 0
	fi

	# both exist
	print_log_message -I "$FUNCNAME: creationInstant: $creationInstant"
	print_log_message -I "$FUNCNAME: validUntil: $validUntil"
	
	###################################################################
	# Ensure that the validity interval has the expected length.
	###################################################################

	# log the expected length of the validity interval
	print_log_message -I "$FUNCNAME: expectedValidityInterval: $expectedValidityInterval"
	
	# convert duration to secs
	expectedValidityIntervalSecs=$( duration2secs "$expectedValidityInterval" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: duration2secs failed ($exit_status) to compute expectedValidityIntervalSecs"
		return 3
	fi
	print_log_message -D "$FUNCNAME: expectedValidityIntervalSecs: $expectedValidityIntervalSecs"

	# compute the actual length of the validity interval
	actualValidityIntervalSecs=$( secsBetween $creationInstant $validUntil )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($exit_status) to compute actualValidityIntervalSecs"
		return 3
	fi
	print_log_message -D "$FUNCNAME: actualValidityIntervalSecs: $actualValidityIntervalSecs"
	
	# sanity check
	if [ "$actualValidityIntervalSecs" -lt 0 ]; then
		print_log_message -E "$FUNCNAME: validity interval has negative length: $actualValidityIntervalSecs"
		return 4
	fi
	
	# convert secs to duration
	actualValidityInterval=$( secs2duration "$actualValidityIntervalSecs" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute actualValidityInterval"
		return 3
	fi

	# log warning if the actual length of the validity interval is unexpected
	if [ "$expectedValidityIntervalSecs" -ne "$actualValidityIntervalSecs" ]; then
		print_log_message -W "$FUNCNAME: unexpected validity interval: $actualValidityInterval"
		return 1
	fi
	print_log_message -I "$FUNCNAME: actualValidityInterval: $actualValidityInterval"
	
	return 0
}

#######################################################################
#
# This script ensures that there is @validUntil attribute on the
# top-level element of the given SAML metadata file.
#
# This script takes its input from the parse_saml_metadata function:
#
#  $ parse_saml_metadata MD_FILE | require_validUntil DURATION
#
# The DURATION argument specifies the maximum length of the
# validity interval as an ISO 8601 duration.
#
# The script logs a warning and returns error code 1 if either of 
# the following conditions are true:
#
#   - The top-level element of the metadata file is not 
#     decorated with a @validUntil attribute
#
#   - The value of the @validUntil attribute is too far 
#     into the future
#
# Technically, the left-hand endpoint of the validity interval is the
# dateTime value of the @creationInstant attribute but this script 
# intentionally avoids the use of the @creationInstant attribute. 
# Instead the current time is used as the left-hand endpoint of the 
# validity interval.
#
# By definition, the right-hand endpoint of the validity interval is 
# the dateTime value of the @validUntil attribute (which this script 
# requires). Thus the length of the validity interval is the difference 
# between @validUntil and the current time. If the length of the validity 
# interval computed in this manner exceeds the maximum value specified on 
# the command line, the value of the @validUntil attribute is deemed too 
# far into the future, in which case the script logs a warning message 
# and returns error code 1.
#
# This script does not require valid metadata. In particular, if the 
# value of the @validUntil attribute is in the past, the script logs 
# a warning but the error code is unaffected.
#
# Dependencies:
#   core_lib.bash
#   compatible_date.bash
#
# Used by:
#   md_require_validUntil.bash
#
# See also: https://en.wikipedia.org/wiki/ISO_8601#Durations
#
#######################################################################
require_validUntil () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ "$(type -t dateTime_canonical2secs)" != function ]; then
		print_log_message -E "$FUNCNAME: function dateTime_canonical2secs not found"
		return 2
	fi
	if [ "$(type -t duration2secs)" != function ]; then
		print_log_message -E "$FUNCNAME: function duration2secs not found"
		return 2
	fi
	if [ "$(type -t dateTime_now_canonical)" != function ]; then
		print_log_message -E "$FUNCNAME: function dateTime_now_canonical not found"
		return 2
	fi
	
	local validUntil
	local validUntilSecs
	local maxValidityInterval
	local maxValidityIntervalSecs
	local currentTime
	local currentTimeSecs
	local maxValidUntilSecs
	local exit_status

	# check the number of command-line arguments
	#shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	maxValidityInterval=$1

	###################################################################
	# Does @validUntil exist?
	###################################################################

	validUntil=$( /bin/cat - | $_GREP '^validUntil' | $_CUT -f2 )
	if [ -z "$validUntil" ]; then
		print_log_message -W "$FUNCNAME: validUntil not found"
		return 1
	fi
	print_log_message -I "$FUNCNAME: validUntil: $validUntil"
	
	# convert @validUntil to secs past the Epoch
	validUntilSecs=$( dateTime_canonical2secs $validUntil )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) to compute validUntilSecs"
		return 3
	fi
	print_log_message -D "$FUNCNAME: validUntilSecs: $validUntilSecs"
	
	###################################################################
	# Ensure that @validUntil is not too far into the future.
	###################################################################

	print_log_message -I "$FUNCNAME: maxValidityInterval: $maxValidityInterval"
	
	# convert duration to secs
	maxValidityIntervalSecs=$( duration2secs "$maxValidityInterval" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: duration2secs failed ($exit_status) to compute maxValidityIntervalSecs"
		return 3
	fi
	print_log_message -D "$FUNCNAME: maxValidityIntervalSecs: $maxValidityIntervalSecs"

	# compute current dateTime
	currentTime=$( dateTime_now_canonical )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_now_canonical failed ($exit_status) to compute currentTime"
		return 3
	fi
	print_log_message -D "$FUNCNAME: currentTime: $currentTime"

	# convert current dateTime to secs
	currentTimeSecs=$( dateTime_canonical2secs $currentTime )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) to compute currentTimeSecs"
		return 3
	fi
	print_log_message -D "$FUNCNAME: currentTimeSecs: $currentTimeSecs"
	
	maxValidUntilSecs=$(( currentTimeSecs + maxValidityIntervalSecs ))
	print_log_message -D "$FUNCNAME: maxValidUntilSecs: $maxValidUntilSecs"

	if [ "$validUntilSecs" -gt "$maxValidUntilSecs" ]; then
		print_log_message -W "$FUNCNAME: @validUntil is too far into the future"
		return 1
	fi
	
	# from here on out, return error code 0 no matter what happens

	###################################################################
	# Check that @validUntil is not in the past.
	###################################################################

	if [ "$currentTimeSecs" -ge "$validUntilSecs" ]; then
		print_log_message -W "$FUNCNAME: @validUntil is in the past"
	fi
	
	return 0
}

#######################################################################
#
# This script ensures that there is a @creationInstant attribute
# associated with the top-level element of the SAML metadata file.
#
# This script takes its input from the parse_saml_metadata function:
#
#  $ parse_saml_metadata MD_FILE | require_creationInstant
#
# The script logs a warning and returns error code 1 if the 
# following condition is true:
#
#   - The top-level element of the metadata file does not have
#     an md:Extensions/mdrpi:PublicationInfo child element or
#     the child element is not decorated with a @creationInstant 
#     attribute
#
# This script does not require valid metadata. In particular, if 
# the value of the @creationInstant attribute is in the future, 
# the script logs a warning but the error code is unaffected.
#
# Dependencies:
#   core_lib.bash
#
# Used by:
#   md_require_creationInstant.bash
#
#######################################################################
require_creationInstant () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ "$(type -t dateTime_canonical2secs)" != function ]; then
		print_log_message -E "$FUNCNAME: function dateTime_canonical2secs not found"
		return 2
	fi
	if [ "$(type -t dateTime_now_canonical)" != function ]; then
		print_log_message -E "$FUNCNAME: function dateTime_now_canonical not found"
		return 2
	fi

	local creationInstant
	local creationInstantSecs
	local currentTime
	local currentTimeSecs
	local exit_status

	# check the number of command-line arguments
	#shift $(( OPTIND - 1 ))
	if [ $# -ne 0 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (0 required)"
		return 2
	fi

	###################################################################
	# Does @creationInstant exist?
	###################################################################

	# get the value of @creationInstant
	creationInstant=$( /bin/cat - | $_GREP '^creationInstant' | $_CUT -f2 )
	if [ -z "$creationInstant" ]; then
		print_log_message -W "$FUNCNAME: creationInstant not found"
		return 1
	fi
	print_log_message -I "$FUNCNAME: creationInstant: $creationInstant"
	
	# from here on out, return error code 0 no matter what happens
	
	###################################################################
	# Check that @creationInstant is not in the future.
	###################################################################

	# convert @creationInstant to secs past the Epoch
	creationInstantSecs=$( dateTime_canonical2secs $creationInstant )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) to compute creationInstantSecs"
		print_log_message -W "$FUNCNAME unable to confirm metadata validity"
		return 0
	fi
	print_log_message -D "$FUNCNAME: creationInstantSecs: $creationInstantSecs"
	
	# compute current dateTime
	currentTime=$( dateTime_now_canonical )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_now_canonical failed ($exit_status) to compute currentTime"
		print_log_message -W "$FUNCNAME unable to confirm metadata validity"
		return 0
	fi
	print_log_message -D "$FUNCNAME: currentTime: $currentTime"

	# convert current dateTime to secs
	currentTimeSecs=$( dateTime_canonical2secs $currentTime )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) to compute currentTimeSecs"
		print_log_message -W "$FUNCNAME unable to confirm metadata validity"
		return 0
	fi
	print_log_message -D "$FUNCNAME: currentTimeSecs: $currentTimeSecs"
	
	if [ "$creationInstantSecs" -gt "$currentTimeSecs" ]; then
		print_log_message -W "$FUNCNAME: @creationInstant is in the future"
	fi
	
	return 0
}

#######################################################################
#
# This script ensures that the top-level element of the given SAML
# metadata file is associated with both a @creationInstant attribute
# and a @validUntil attribute.
#
# This script takes its input from the output of the parse_saml_metadata
# function:
#
#  $ parse_saml_metadata MD_FILE | require_timestamps [-f LOG_FILE] DURATION
#
# The DURATION argument specifies the maximum length of the
# validity interval as an ISO 8601 duration.
#
# By definition, the endpoints of the validity interval are the
# dateTime values of the @creationInstant attribute and the
# @validUntil attribute, respectively. If the actual length of
# the validity interval is NOT positive, or the actual length is
# greater than the maximum length given on the command line, the
# script logs a warning message and returns error code 1.
#
# Specifically, the script executes successfully (with error
# code 0) if all of the following conditions are true:
#
#   - The top-level element of the metadata file is decorated 
#     with a @validUntil attribute
#
#   - The top-level element of the metadata file has an
#     md:Extensions/mdrpi:PublicationInfo child element
#     and the child element is decorated with a 
#     @creationInstant attribute
#
#   - The actual length of the validity interval is positive
#
#   - The actual length of the validity interval does not 
#     exceed the given maximum length
#
# Although this script does not require valid metadata, it
# attempts to check each of the following: 
#
#   - The value of the @validUntil attribute is in the future
#
#   - The value of the @creationInstant attribute is in the past
#
#   - The actual length of the validity interval is equal to 
#     the maximum length
#
# If any of the above conditions are false, a warning message is
# logged but the error code returned by the script is unaffected.
#
# When option -f is specified on the command line, the script
# appends a line to the given LOG_FILE. Each row of the file
# consists of the following three tab-delimited fields:
#
#   currentTime
#   creationInstant
#   validUntil
#
# The currentTime field records the time instant this function
# executes. The other two values (creationInstant and validUntil)
# are taken directly from the metadata. All three fields consist
# of a timestamp whose value format is the canonical form of an
# ISO 8601 dateTime string.
#
# Dependencies:
#   core_lib.bash
#   compatible_date.bash
#
# Used by:
#   md_require_timestamps.bash
#
# See also: https://en.wikipedia.org/wiki/ISO_8601#Durations
#
#######################################################################
require_timestamps () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ "$(type -t duration2secs)" != function ]; then
		print_log_message -E "$FUNCNAME: function duration2secs not found"
		return 2
	fi
	if [ "$(type -t secsBetween)" != function ]; then
		print_log_message -E "$FUNCNAME: function secsBetween not found"
		return 2
	fi
	if [ "$(type -t secs2duration)" != function ]; then
		print_log_message -E "$FUNCNAME: function secs2duration not found"
		return 2
	fi
	
	local doc_info
	local creationInstant
	local creationInstantSecs
	local validUntil
	local validUntilSecs
	local maxValidityInterval
	local maxValidityIntervalSecs
	local actualValidityIntervalSecs
	local actualValidityInterval
	local currentTime
	local currentTimeSecs
	
	local exit_status
	
	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":f:" opt; do
		case $opt in
			f)
				timestamp_log_file="$OPTARG"
				;;
			\?)
				echo "ERROR: $FUNCNAME: Unrecognized option: -$OPTARG" >&2
				return 2
				;;
			:)
				echo "ERROR: $FUNCNAME: Option -$OPTARG requires an argument" >&2
				return 2
				;;
		esac
	done
		
	# check the log file
	if [ -n "$timestamp_log_file" ] && [ ! -f "$timestamp_log_file" ]; then
		echo "ERROR: $FUNCNAME: file does not exist: $timestamp_log_file" >&2
		return 2
	fi

	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	maxValidityInterval=$1

	###################################################################
	# Do both @creationInstant and @validUntil exist?
	###################################################################

	doc_info=$( /bin/cat - | $_GREP -E '^(creationInstant|validUntil)' )
	
	# does @creationInstant exist?
	creationInstant=$( echo "$doc_info" | $_GREP '^creationInstant' | $_CUT -f2 )
	if [ -z "$creationInstant" ]; then
		print_log_message -W "$FUNCNAME: creationInstant not found"
		return 1
	fi
	
	# does @validUntil exist?
	validUntil=$( echo "$doc_info" | $_GREP '^validUntil' | $_CUT -f2 )
	if [ -z "$validUntil" ]; then
		print_log_message -W "$FUNCNAME: validUntil not found"
		return 1
	fi

	# both exist
	print_log_message -I "$FUNCNAME: creationInstant: $creationInstant"
	print_log_message -I "$FUNCNAME: validUntil: $validUntil"
		
	###################################################################
	# Ensure that the validity interval has the expected length.
	###################################################################

	# log the max length of the validity interval
	print_log_message -I "$FUNCNAME: maxValidityInterval: $maxValidityInterval"
	
	# convert duration to secs
	maxValidityIntervalSecs=$( duration2secs "$maxValidityInterval" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: duration2secs failed ($exit_status) to compute maxValidityIntervalSecs"
		return 3
	fi
	print_log_message -D "$FUNCNAME: maxValidityIntervalSecs: $maxValidityIntervalSecs"

	# compute the actual length of the validity interval
	actualValidityIntervalSecs=$( secsBetween $creationInstant $validUntil )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secsBetween failed ($exit_status) to compute actualValidityIntervalSecs"
		return 3
	fi
	print_log_message -D "$FUNCNAME: actualValidityIntervalSecs: $actualValidityIntervalSecs"

	# if the metadata is valid, then
	#   @creationInstant <= NOW < @validUntil
	# which implies that
	#   @creationInstant < @validUntil
	# in other words, the actual length of the validity interval is positive
	#
	# since this script does not require valid metadata,
	# we must ensure the following condition is true:
	if [ "$actualValidityIntervalSecs" -le 0 ]; then
		print_log_message -W "$FUNCNAME: the actual length of the validity interval is NOT positive: $actualValidityIntervalSecs"
		return 1
	fi
	
	# convert secs to duration (for logging)
	actualValidityInterval=$( secs2duration "$actualValidityIntervalSecs" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: secs2duration failed ($exit_status) to compute actualValidityInterval"
		return 3
	fi

	# log warning if the actual length exceeds the expected length
	if [ "$actualValidityIntervalSecs" -gt "$maxValidityIntervalSecs" ]; then
		print_log_message -W "$FUNCNAME: actual validity interval is too large: $actualValidityInterval"
		return 1
	fi
	
	# from here on out, return error code 0 no matter what happens
	
	# log warning if the actual length differs from the expected length
	if [ "$actualValidityIntervalSecs" -lt "$maxValidityIntervalSecs" ]; then
		print_log_message -W "$FUNCNAME: actual validity interval is too small: $actualValidityInterval"
	else
		print_log_message -I "$FUNCNAME: actualValidityInterval: $actualValidityInterval"
	fi

	###################################################################
	# Check that @validUntil is not in the past.
	###################################################################

	# convert @validUntil to secs past the Epoch
	validUntilSecs=$( dateTime_canonical2secs $validUntil )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) to compute validUntilSecs"
		print_log_message -W "$FUNCNAME unable to confirm metadata validity"
		return 0
	fi
	print_log_message -D "$FUNCNAME: validUntilSecs: $validUntilSecs"
	
	# compute current dateTime
	currentTime=$( dateTime_now_canonical )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_now_canonical failed ($exit_status) to compute currentTime"
		print_log_message -W "$FUNCNAME unable to confirm metadata validity"
		return 0
	fi
	print_log_message -D "$FUNCNAME: currentTime: $currentTime"

	# convert current dateTime to secs
	currentTimeSecs=$( dateTime_canonical2secs $currentTime )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) to compute currentTimeSecs"
		print_log_message -W "$FUNCNAME unable to confirm metadata validity"
		return 0
	fi
	print_log_message -D "$FUNCNAME: currentTimeSecs: $currentTimeSecs"
	
	if [ "$currentTimeSecs" -ge "$validUntilSecs" ]; then
		print_log_message -W "$FUNCNAME: @validUntil is in the past"
	fi
	
	###################################################################
	# Check that @creationInstant is not in the future.
	###################################################################

	# convert @creationInstant to secs past the Epoch
	creationInstantSecs=$( dateTime_canonical2secs $creationInstant )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) to compute creationInstantSecs"
		print_log_message -W "$FUNCNAME unable to confirm metadata validity"
		return 0
	fi
	print_log_message -D "$FUNCNAME: creationInstantSecs: $creationInstantSecs"
	
	if [ "$creationInstantSecs" -gt "$currentTimeSecs" ]; then
		print_log_message -W "$FUNCNAME: @creationInstant is in the future"
	fi
	
	###################################################################
	# Update the timestamp log file (if there is one).
	###################################################################

	[ -z "$timestamp_log_file" ] && return 0
	
	print_log_message -I "$FUNCNAME updating timestamp log file: $timestamp_log_file"
	printf "%s\t%s\t%s\n" $currentTime $creationInstant $validUntil  >> "$timestamp_log_file"
	return 0
}
