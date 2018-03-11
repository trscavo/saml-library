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
#######################################################################
#
# Every function in this library calls xsltproc at least once.
# In that sense, each function is a wrapper around one or more
# XSL stylesheets, which are opaque to the caller.
#
# The function applies the stylesheet to a SAML metadata document.
# The caller provides the absolute path to the metadata document
# on the command line.
#
# In each case, the output is a flat text file. The first line of
# the file is a label that indicates the top-level element of the
# metadata document:
#
#   EntityDescriptor|EntitiesDescriptor
#
# The remaining lines of the output are a list of name-value pairs
# specific to the function. On each line, the name and its value
# are separated by a tab character. Except for the first line, the
# order of the output lines is unspecified.
#
#######################################################################
#######################################################################

#######################################################################
#
# This script parses the given SAML metadata document.
#
# Usage: parse_saml_metadata [-q] MD_FILE
#
# If the given MD_FILE is NOT an XML document, or the top-level
# element of the XML document is neither md:EntityDescriptor nor
# md:EntitiesDescriptor, the script logs a warning and returns
# with status code 1. Otherwise the script produces one or more
# lines of output.
#
# Output:
# The output depends on the XSL stylesheet listed below. To see
# this, apply the stylesheet to various documents:
#
#  $ xsl_file=$LIB_DIR/parse_saml_md_document_txt.xsl
#  $ /usr/bin/xsltproc $xsl_file $xml_file
#
# Alternatively, you can run the bash script in a subshell:
#
#  $ (
#    source $LIB_DIR/core_lib.bash
#    source $LIB_DIR/xsl_wrappers.bash
#    parse_saml_metadata $xml_file
#  )
#
# This script is most useful as a helper script in other scripts.
#
# Options:
#  -q      Run quietly; suppress normal output
#
# If the -q option is specified on the command line, the script
# produces no output. This is Quiet Mode, similar to: grep -q.
# Use this feature to determine if the input file is a SAML
# metadata document. If not, the function will log a warning and
# return error code 1.
#
# Dependencies:
#   core_lib.bash
#   parse_saml_md_document_txt.xsl
#
# TODO: What if the top-level element is EntitiesDescriptor
#       and there are @validUntil attributes on the child elements?
#
#######################################################################
parse_saml_metadata () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ -z "$LIB_DIR" ]; then
		print_log_message -E "$FUNCNAME: env var LIB_DIR required"
		return 2
	fi
	if [ ! -d "$LIB_DIR" ]; then
		print_log_message -E "$FUNCNAME: directory does not exist: $LIB_DIR"
		return 2
	fi
	
	local quiet_mode
	local xml_file
	local xsl_file
	local doc_info
	local parsed_info
	local exit_status
	
	local opt
	local OPTARG
	local OPTIND
	
	quiet_mode=false
	while getopts ":q" opt; do
		case $opt in
			q)
				quiet_mode=true
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
	xml_file="$1"

	# check the input file
	if [ ! -f "$xml_file" ]; then
		print_log_message -E "$FUNCNAME: input file does not exist: $xml_file"
		return 2
	fi
	
	# check the stylesheet
	xsl_file="$LIB_DIR/parse_saml_md_document_txt.xsl"
	if [ ! -f "$xsl_file" ]; then
		print_log_message -E "$FUNCNAME: stylesheet does not exist: $xsl_file"
		return 2
	fi
	
	###################################################################
	# Parse the input document
	###################################################################
	
	# apply the stylesheet to the input document
	doc_info=$( /usr/bin/xsltproc $xsl_file $xml_file )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: xsltproc failed ($exit_status) on script: $xsl_file"
		return 3
	fi

	# no output indicates the input is not SAML metadata
	if [ -z "$doc_info" ]; then
		print_log_message -W "$FUNCNAME: input file is not SAML metadata: $xml_file"
		return 1
	else
		# log info
		print_log_message -I "$FUNCNAME: parsing input file: $xml_file"
		parsed_info=$( printf "%s/@ID=%s" \
			"$( echo "$doc_info" | $_GREP -E '^(EntityDescriptor|EntitiesDescriptor)$' )" \
			"$( echo "$doc_info" | $_GREP '^ID' | $_CUT -f2 )" 
		)
		print_log_message -I "$FUNCNAME: input file parsed: $parsed_info"
	fi
	
	$quiet_mode && return 0
	echo "$doc_info"
}

#######################################################################
#
# This script parses the XML signature on the given SAML metadata
# document.
#
# Usage: parse_ds_signature [-q] MD_FILE
#
# If the given MD_FILE is NOT an XML document, or the top-level
# element of the XML document is neither md:EntityDescriptor nor
# md:EntitiesDescriptor, the script logs an error and returns a
# nonzero status code. If the input document is an unsigned SAML
# metadata document, the script logs a warning and returns status
# code 1. Otherwise the script produces one or more lines of output.
#
# Output:
# The output depends on a pair of XSL stylesheets. The first
# stylesheet parses elements and attributes common to all XML
# signatures:
#
#  $ xsl_file1=$LIB_DIR/parse_ds_signature_txt.xsl
#  $ /usr/bin/xsltproc $xsl_file1 $xml_file
#
# The second stylesheet extracts the PEM-encoded signing
# certificate embedded in the signature (if any):
#
#  $ xsl_file2=$LIB_DIR/parse_signing_cert_pem.xsl
#  $ /usr/bin/xsltproc $xsl_file2 $xml_file
#
# The results of the two XSL stylesheets are concatenated
# into a single, comprehensive output file. To see this, you
# can run the bash script in a subshell:
#
#  $ (
#    source $LIB_DIR/core_lib.bash
#    source $LIB_DIR/xsl_wrappers.bash
#    parse_ds_signature $xml_file
#  )
#
# This script is most useful as a helper script in other scripts.
#
# Options:
#  -q      Run quietly; suppress normal output
#
# If the -q option is specified on the command line, the script
# produces no output. This is Quiet Mode, similar to: grep -q.
# Use this feature to determine if the input file is a signed
# SAML metadata document only. If not, the function will log a
# warning and return error code 1.
#
# Dependencies:
#   core_lib.bash
#   parse_ds_signature_txt.xsl
#   parse_signing_cert_pem.xsl
#
#######################################################################
parse_ds_signature () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ -z "$LIB_DIR" ]; then
		print_log_message -E "$FUNCNAME: env var LIB_DIR required"
		return 2
	fi
	if [ ! -d "$LIB_DIR" ]; then
		print_log_message -E "$FUNCNAME: directory does not exist: $LIB_DIR"
		return 2
	fi
	
	local quiet_mode
	local xml_file
	local xsl_file1
	local xsl_file2
	local exit_status
	
	local sig_info
	local parsed_info
	
	local encoded_cert
	local parsed_cert
	local serial
	local notBefore
	local notAfter
	local issuer
	local subject
	local CN
	local keySize
	local keySizeFormatted
	local fingerprint

	local opt
	local OPTARG
	local OPTIND
	
	quiet_mode=false
	while getopts ":q" opt; do
		case $opt in
			q)
				quiet_mode=true
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
	xml_file="$1"

	# check the input file
	if [ ! -f "$xml_file" ]; then
		print_log_message -E "$FUNCNAME: input file does not exist: $xml_file"
		return 2
	fi
	
	# check the first stylesheet
	xsl_file1="$LIB_DIR/parse_ds_signature_txt.xsl"
	if [ ! -f "$xsl_file1" ]; then
		print_log_message -E "$FUNCNAME: stylesheet does not exist: $xsl_file1"
		return 2
	fi
	
	# check the second stylesheet
	xsl_file2="$LIB_DIR/parse_signing_cert_pem.xsl"
	if [ ! -f "$xsl_file2" ]; then
		print_log_message -E "$FUNCNAME: stylesheet does not exist: $xsl_file2"
		return 2
	fi
	
	###################################################################
	# Parse the XML signature
	###################################################################
	
	sig_info=$( /usr/bin/xsltproc $xsl_file1 $xml_file )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: xsltproc failed ($exit_status) on script: $xsl_file1"
		return 3
	fi

	# no output indicates the input is not a SAML metadata document
	if [ -z "$sig_info" ]; then
		print_log_message -E "$FUNCNAME: input file is not a SAML metadata document: $xml_file"
		return 4
	fi
	
	# no reference URI indicates the SAML metadata document is not signed
	if ! echo "$sig_info" | $_GREP -q '^ReferenceURI'; then
		print_log_message -W "$FUNCNAME: SAML metadata document is not signed: $xml_file"
		return 1
	fi
	
	# log info
	print_log_message -I "$FUNCNAME: parsing input file: $xml_file"
	parsed_info=$( printf "%s/@ID=%s" \
		"$( echo "$sig_info" | $_GREP -E '^(EntityDescriptor|EntitiesDescriptor)$' )" \
		"$( echo "$sig_info" | $_GREP '^ID' | $_CUT -f2 )" 
	)
	print_log_message -I "$FUNCNAME: input file parsed: $parsed_info"
		
	$quiet_mode && return 0

	###################################################################
	# Parse the PEM-encoded signing cert embedded in the signature.
	# Note: The signature may or may not contain a cert.
	###################################################################
	
	encoded_cert=$( /usr/bin/xsltproc $xsl_file2 $xml_file )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: xsltproc failed ($exit_status) on script: $xsl_file2"
		return 3
	fi
	
	# the signing certificate may or may not be embedded in the signature
	if [ -z "$encoded_cert" ]; then
		print_log_message -I "$FUNCNAME: signing certificate not found"
		echo "$sig_info"
		return
	fi

	# parse the encoded cert with openssl
	parsed_cert=$( echo "$encoded_cert" \
		| /usr/bin/openssl x509 -modulus -sha1 -fingerprint -serial -dates -issuer -subject -noout
	)
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: openssl failed ($exit_status) on cert"
		return 3
	fi
	
	# compute the serial number
	serial=$( echo "$parsed_cert" | $_GREP "^serial=" | $_CUT -d= -f2  )
	sig_info=$( printf "%s\nserial\t%s\n" "$sig_info" "$serial" )
	print_log_message -D "$FUNCNAME: Cert serial number: $serial"
	
	# compute the start date
	notBefore=$( echo "$parsed_cert" | $_GREP "^notBefore=" | $_CUT -d= -f2  )
	sig_info=$( printf "%s\nnotBefore\t%s\n" "$sig_info" "$notBefore" )
	print_log_message -D "$FUNCNAME: Cert start date: $notBefore"
	
	# compute the expiration date
	notAfter=$( echo "$parsed_cert" | $_GREP "^notAfter=" | $_CUT -d= -f2  )
	sig_info=$( printf "%s\nnotAfter\t%s\n" "$sig_info" "$notAfter" )
	print_log_message -D "$FUNCNAME: Cert expiration date: $notAfter"
	
	# compute the Issuer DN
	issuer=$( echo "$parsed_cert" | $_GREP "^issuer=" | $_SED -e 's/^issuer= \(.*\)$/\1/' )
	sig_info=$( printf "%s\nissuer\t%s\n" "$sig_info" "$issuer" )
	print_log_message -D "$FUNCNAME: Cert issuer: $issuer"
	
	# compute the Subject DN
	subject=$( echo "$parsed_cert" | $_GREP "^subject=" | $_SED -e 's/^subject= \(.*\)$/\1/' )
	sig_info=$( printf "%s\nsubject\t%s\n" "$sig_info" "$subject" )
	print_log_message -D "$FUNCNAME: Cert subject: $subject"
	
	# compute the CN component of Subject DN
	CN=$( echo "$subject" | $_SED -e 's/^.*CN=\(.*\)$/\1/' )
	sig_info=$( printf "%s\ncommonName\t%s\n" "$sig_info" "$CN" )
	print_log_message -D "$FUNCNAME: Cert subject common name: $CN"
	
	# compute the key size
	keySize=$((
		4 * $( echo "$parsed_cert" | $_GREP "^Modulus=" \
			| $_CUT -d= -f2 | /usr/bin/tr -d "\r\n" | /usr/bin/wc -c )
	))
	sig_info=$( printf "%s\nkeySize\t%d\n" "$sig_info" $keySize )
	keySizeFormatted=$( printf "%d bits" "$keySize" )
	print_log_message -D "$FUNCNAME: Cert key size: $keySizeFormatted"
	
	# compute the SHA-1 fingerprint
	fingerprint=$( echo "$parsed_cert" | $_GREP "^SHA1 Fingerprint=" | $_CUT -d= -f2 )
	sig_info=$( printf "%s\nSHA1_fingerprint\t%s\n" "$sig_info" "$fingerprint" )
	print_log_message -D "$FUNCNAME: Cert SHA1 fingerprint: $fingerprint"
	
	echo "$sig_info"
}

#######################################################################
#
# This script summarizes the various roles of entities in the
# given SAML metadata document.
#
# Usage: parse_entity_roles -T TMP_DIR MD_FILE
#
# If the given MD_FILE is NOT an XML document, or the top-level
# element of the XML document is neither md:EntityDescriptor nor
# md:EntitiesDescriptor, the script logs an error and returns a
# nonzero status code. Otherwise the script produces multiple
# lines of output that summarize the roles of entities in the
# metadata.
#
# The script does not distinguish between EntityDescriptor and
# EntitiesDescriptor. In the latter case, the total number of
# entities (numEntities) is guaranteed to be more than one.
#
# Output:
# The output depends on the XSL stylesheet listed below. The
# stylesheet lists each role in the metadata. (Note: A single
# entity may declare multiple roles.) To see this, apply the
# stylesheet to various documents:
#
#  $ xsl_file=$LIB_DIR/list_all_role_descriptors_txt.xsl
#  $ /usr/bin/xsltproc $xsl_file $xml_file | more
#
# Alternatively, you can run the bash script in a subshell:
#
#  $ (
#    source $LIB_DIR/core_lib.bash
#    source $LIB_DIR/xsl_wrappers.bash
#    parse_entity_roles -T /tmp $xml_file
#  )
#
# This script is most useful as a helper script in other scripts.
#
# Dependencies:
#   core_lib.bash
#   list_all_role_descriptors_txt.xsl
#
# BUG: The @registrationAuthority attribute is optional.
#
#######################################################################
parse_entity_roles () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	# other dependencies
	if [ -z "$LIB_DIR" ]; then
		print_log_message -E "$FUNCNAME: env var LIB_DIR required"
		return 2
	fi
	if [ ! -d "$LIB_DIR" ]; then
		print_log_message -E "$FUNCNAME: directory does not exist: $LIB_DIR"
		return 2
	fi
	
	local tmp_dir
	local xml_file
	local xsl_file
	local out_file
	local exit_status
	
	local num_registrars
	local num_entities
	local role_info
	local roles
	local role
	local num_roles
	
	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":T:" opt; do
		case $opt in
			T)
				tmp_dir="$OPTARG"
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
	
	if [ -z "$tmp_dir" ]; then
		print_log_message -E "$FUNCNAME: a temporary directory (option -T) is required"
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		print_log_message -E "$FUNCNAME: temporary directory does not exist: $tmp_dir"
		return 2
	fi
	
	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (1 required)"
		return 2
	fi
	xml_file="$1"

	# check the input file
	if [ ! -f "$xml_file" ]; then
		print_log_message -E "$FUNCNAME: input file does not exist: $xml_file"
		return 2
	fi
	
	# check the stylesheet
	xsl_file="$LIB_DIR/list_all_role_descriptors_txt.xsl"
	if [ ! -f "$xsl_file" ]; then
		print_log_message -E "$FUNCNAME: stylesheet does not exist: $xsl_file"
		return 2
	fi
	
	# list role descriptors
	out_file="$tmp_dir/all_role_descriptors.txt"
	/usr/bin/xsltproc $xsl_file $xml_file > $out_file
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: xsltproc failed ($exit_status) on script: $xsl_file"
		return 3
	fi
	
	# check if the file is empty

	# How many registrars?
	num_registrars=$( /bin/cat "$out_file" \
		| $_CUT -f3 \
		| $_SORT | /usr/bin/uniq \
		| /usr/bin/wc -l
	)

	# How many entity descriptors?
	num_entities=$( /bin/cat "$out_file" \
		| $_CUT -f2 \
		| $_SORT | /usr/bin/uniq \
		| /usr/bin/wc -l
	)

	# init role info
	[ "$num_entities" -gt 1 ] && role_info="EntitiesDescriptor" || role_info="EntityDescriptor"
	role_info=$( printf "%s\nnumRegistrars\t%d\n" "$role_info" $num_registrars )
	role_info=$( printf "%s\nnumEntities\t%d\n" "$role_info" $num_entities )
	
	# How many roles of each type?
	roles="SPSSODescriptor IDPSSODescriptor AttributeAuthorityDescriptor AuthnAuthorityDescriptor PDPDescriptor"
	for role in $roles; do
		num_roles=$( /bin/cat "$out_file" \
			| $_GREP -E "^$role\t" \
			| $_CUT -f1-2 \
			| $_SORT | /usr/bin/uniq \
			| /usr/bin/wc -l
		)
		role_info=$( printf "%s\nnumEntitiesWith%s\t%d\n" "$role_info" $role $num_roles )
	done
	
	echo "$role_info"
}
