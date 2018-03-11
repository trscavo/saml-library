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
# Get entity metadata from a local file.
#
# Usage: getEntityFromFile -f MD_PATH ID
#
# A return code > 1 is a fatal error.
#######################################################################
getEntityFromFile () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	local md_path
	local entityID
	local entityDescriptor
	local exit_code
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":f:" opt; do
		case $opt in
			f)
				md_path="$OPTARG"
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

	# a metadata file is REQUIRED
	if [ -z "$md_path" ]; then
		echo "ERROR: $FUNCNAME: MD_PATH (option -f) does not exist" >&2
		return 2
	fi
	if [ ! -f "$md_path" ]; then
		echo "ERROR: $FUNCNAME: file does not exist: $md_path" >&2
		return 2
	fi

	# make sure there is one (and only one) command-line argument
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (1 required)" >&2
		return 2
	fi
	entityID=$1

	# get the entity descriptor from the metadata file using sed
	#entityDescriptor=$( /bin/cat $md_path \
	#	| $_SED -n -e '\;<\(md:\)\{0,1\}EntityDescriptor.* entityID="'${entityID}'";,\;EntityDescriptor>;p'
	#)

	# determine the source lib directory
	if [ -z "$LIB_DIR" ]; then
		echo "ERROR: $FUNCNAME requires env var LIB_DIR" >&2
		return 2
	fi
	if [ ! -d "$LIB_DIR" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $LIB_DIR" >&2
		return 2
	fi
	if [ ! -f "$LIB_DIR/extract_entity.xsl" ]; then
		echo "ERROR: $FUNCNAME: stylesheet does not exist: $LIB_DIR/extract_entity.xsl" >&2
		return 2
	fi
	
	# get the entity descriptor from the metadata file using parameterized xslt
	entityDescriptor=$( \
		/usr/bin/xsltproc --stringparam entityID $entityID $LIB_DIR/extract_entity.xsl $md_path
	)
	exit_code=$?
	if [ "$exit_code" -ne 0 ]; then
		echo "ERROR: $FUNCNAME: xsltproc failed (exit code $exit_code): $entityID" >&2
		return 3
	fi
	
	if [ -z "$entityDescriptor" ]; then
		echo "ERROR: $FUNCNAME: no entity descriptor for entityID: $entityID" >&2
		return 1
	fi

	echo "$entityDescriptor"
}

#######################################################################
# Get entity metadata from a metadata query server, that is, 
# a server that conforms to the Metadata Query Protocol.
#
# Usage: getEntityFromServer -T TMP_DIR -u MDQ_BASE_URL ID
#
# A temporary file containing the HTTP response is created in TMP_DIR.
#
# A return code > 1 is a fatal error.
#######################################################################
getEntityFromServer () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	# external dependency
	if [ "$(type -t percent_encode)" != function ]; then
		echo "ERROR: $FUNCNAME: function percent_encode not found" >&2
		return 2
	fi

	local tmp_dir
	local mdq_base_url
	local tmp_response_file
	local entityID
	local encoded_id
	local return_status
	local mdq_request_url
	local output
	local exit_code
	local response_code

	local opt
	local OPTARG
	local OPTIND
	while getopts ":T:u:" opt; do
		case $opt in
			T)
				tmp_dir="$OPTARG"
				;;
			u)
				mdq_base_url="$OPTARG"
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

	if [ -z "$mdq_base_url" ]; then
		echo "ERROR: $FUNCNAME: MDQ_BASE_URL (option -u) does not exist" >&2
		return 2
	fi

	if [ -z "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: TMP_DIR (option -T) does not exist" >&2
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: temporary directory does not exist: $tmp_dir" >&2
		return 2
	fi
	tmp_response_file="$tmp_dir/mdq_response.txt"
	tmp_log_file="$tmp_dir/mdq_log.txt"
	
	# make sure there is one (and only one) command-line argument
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (1 required)" >&2
		return 2
	fi
	entityID=$1

	# percent-encode the identifier
	encoded_id=$( percent_encode $entityID )
	return_status=$?
	if [ "$return_status" -ne 0 ]; then
		echo "ERROR: $FUNCNAME: failed to percent-encode the entityID: $entityID" >&2
		return 3
	fi

	# compute the MDQ protocol request URL
	mdq_request_url=$( construct_mdq_url $mdq_base_url $encoded_id )
	return_status=$?
	if [ "$return_status" -ne 0 ]; then
		echo "ERROR: $FUNCNAME: failed to construct the request URL from the encoded entityID: $encoded_id" >&2
		return 3
	fi

	# get a single entity descriptor via the MDQ protocol
	output=$( /usr/bin/curl --silent \
		--output "$tmp_response_file" \
		--write-out 'response:%{http_code};dns:%{time_namelookup};tcp:%{time_connect};pre-start:%{time_pretransfer};start:%{time_starttransfer};total:%{time_total};size:%{size_download}' \
		"$mdq_request_url"
	)
	exit_code=$?
	if [ "$exit_code" -ne 0 ]; then
		echo "ERROR: $FUNCNAME: curl failed (exit code $exit_code $output): $mdq_request_url" >&2
		return 3
	fi
	
	# log timings
	echo "$exit_code $output $entityID" >> "$tmp_log_file"

	# check the HTTP response code
	response_code=$( echo "$output" | $_SED -e 's/^response:\([^;]*\).*$/\1/' )
	if [[ "$response_code" != 200 ]]; then
		echo "ERROR: $FUNCNAME: query failed (response code $response_code): $mdq_request_url" >&2
		return 1
	fi
	
	/bin/cat "$tmp_response_file"
}

#######################################################################
# Construct a request URL per the MDQ Protocol specification.
# See: https://github.com/iay/md-query
#
# Usage: construct_mdq_url <base_url> <percent_encoded_id>
#
# To construct a reference to ALL entities served by the 
# metadata query server, simply omit the second argument.
# (Note: Not all MDQ servers serve such an aggregate.)
#######################################################################
construct_mdq_url () {

	# make sure there are one or two command-line arguments
	if [ $# -lt 1 -o $# -gt 2 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (1 or 2 required)" >&2
		return 2
	fi
	local base_url=$1
	
	# strip the trailing slash from the base URL if necessary
	#local length="${#1}"
	#if [[ "${base_url:length-1:1}" == '/' ]]; then
	#	base_url="${base_url:0:length-1}"
	#fi
	
	# append the identifier if there is one
	if [ $# -eq 2 ]; then
		echo "${base_url%%/}/entities/$2"
	else
		echo "${base_url%%/}/entities"
	fi
}

#######################################################################
# Extract a pair of identifiers from the given entity metadata.
#
# Usage: extractIdentifiers [-f MD_FILE]
#
# The optional MD_FILE argument is the path to a local metadata file.
# If the MD_FILE argument is omitted on the command line, the input is 
# taken from stdin. In any case, the root element of the metadata file 
# is assumed to be an md:EntityDescriptor element.
#
# This function outputs the following tab-delimited text fields:
#
#   entityID registrarID
#
# where entityID is the value of the ./@entityID XML attribute. 
# Assuming the XML is schema-valid, the entityID is guaranteed to 
# be non-null.
#
# The registrarID is the value of the following XML attribute:
#
#   ./md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority
#
# Since the mdrpi:RegistrationInfo element is an optional element,
# the registrarID may be null.
#
# Environment Variables
#
# Two environment variables are required. The LIB_DIR environment
# variable points to a source code library containing bash scripts,
# XSLT scripts, and other source files. The TMPDIR environment 
# variable points to a temporary directory used by this function.
#
#######################################################################
extractIdentifiers () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	# determine the source lib directory
	if [ -z "$LIB_DIR" ]; then
		echo "ERROR: $FUNCNAME requires env var LIB_DIR" >&2
		return 2
	fi
	if [ ! -d "$LIB_DIR" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $LIB_DIR" >&2
		return 2
	fi
	
	# TODO: Take temp dir on the command line
	
	# check the temporary directory
	if [ -z "$TMPDIR" ]; then
		echo "ERROR: $FUNCNAME requires env var TMPDIR" >&2
		return 2
	fi
	if [ ! -d "$TMPDIR" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $TMPDIR" >&2
		return 2
	fi
	
	local xml_file
	local xsl_file
	local tmp_file
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":f:" opt; do
		case $opt in
			f)
				xml_file="$OPTARG"
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

	# make sure there are no command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 0 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (0 required)" >&2
		return 2
	fi
		
	# read the input into a temporary file
	tmp_file="${TMPDIR}/tmp_metadata_in_$$.xml"
	if [ -z "$xml_file" ]; then
		# read input from stdin
		/bin/cat - > "$tmp_file"
	else
		if [ ! -f "$xml_file" ]; then
			echo "ERROR: $FUNCNAME: file does not exist: $xml_file" >&2
			return 2
		fi
		/bin/cp "$xml_file" "$tmp_file"
	fi
	
	# check the stylesheet
	xsl_file="$LIB_DIR/entity_identifiers_txt.xsl"
	if [ ! -f "$xsl_file" ]; then
		echo "ERROR: $FUNCNAME: stylesheet does not exist: $xsl_file" >&2
		return 2
	fi
	
	/usr/bin/xsltproc "$xsl_file" "$tmp_file"
}	

#######################################################################
# Extract a list of names from the given IdP entity descriptor.
#
# Usage: extractIdPNames [-f MD_FILE]
#
# The optional MD_FILE argument is the path to a local metadata file.
# If the MD_FILE argument is omitted on the command line, the input is 
# taken from stdin. In any case, the root element of the metadata file 
# is assumed to be an md:EntityDescriptor element containing an
# md:IDPSSODescriptor child element, that is, an IdP role.
#
# This function outputs the following tab-delimited text fields:
#
#   entityID DisplayName OrganizationName OrganizationDisplayName registrarID
#
# where entityID is the value of the ./@entityID XML attribute. 
# Assuming the XML is schema-valid, the entityID is guaranteed to 
# be non-null.
#
# The DisplayName field is the value of the following XML element:
#
#   ./md:IDPSSODescriptor/md:Extensions/mdui:UIInfo/mdui:DisplayName[@xml:lang='en']
#
# If the entity descriptor contains no IdP role, or there is no English-
# language version of the mdui:DisplayName, the DisplayName field is null.
#
# The OrganizationName and OrganizationDisplayName fields are the values 
# of the following XML elements (resp.):
#
#   ./md:Organization/md:OrganizationName[@xml:lang='en']
#   ./md:Organization/md:OrganizationDisplayName[@xml:lang='en']
#
# If the entity descriptor contains no such elements, the corresponding
# output fields are null.
#
# Finally, the registrarID is the value of the following XML attribute:
#
#   ./md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority
#
# Since the mdrpi:RegistrationInfo element is an optional element,
# the registrarID may be null.
#
# Environment Variables
#
# Two environment variables are required. The LIB_DIR environment
# variable points to a source code library containing bash scripts,
# XSLT scripts, and other source files. The TMPDIR environment 
# variable points to a temporary directory used by this function.
#
#######################################################################
extractIdPNames () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	# determine the source lib directory
	if [ -z "$LIB_DIR" ]; then
		echo "ERROR: $FUNCNAME requires env var LIB_DIR" >&2
		return 2
	fi
	if [ ! -d "$LIB_DIR" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $LIB_DIR" >&2
		return 2
	fi
	
	# TODO: Take temp dir on the command line
	
	# check the temporary directory
	if [ -z "$TMPDIR" ]; then
		echo "ERROR: $FUNCNAME requires env var TMPDIR" >&2
		return 2
	fi
	if [ ! -d "$TMPDIR" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $TMPDIR" >&2
		return 2
	fi
	
	local xml_file
	local xsl_file
	local tmp_file
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":f:" opt; do
		case $opt in
			f)
				xml_file="$OPTARG"
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

	# make sure there are no command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 0 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (0 required)" >&2
		return 2
	fi
		
	# read the input into a temporary file
	tmp_file="${TMPDIR}/tmp_metadata_in_$$.xml"
	if [ -z "$xml_file" ]; then
		# read input from stdin
		/bin/cat - > "$tmp_file"
	else
		if [ ! -f "$xml_file" ]; then
			echo "ERROR: $FUNCNAME: file does not exist: $xml_file" >&2
			return 2
		fi
		/bin/cp "$xml_file" "$tmp_file"
	fi
	
	# check the stylesheet
	xsl_file="$LIB_DIR/entity_idp_names_txt.xsl"
	if [ ! -f "$xsl_file" ]; then
		echo "ERROR: $FUNCNAME: stylesheet does not exist: $xsl_file" >&2
		return 2
	fi
	
	/usr/bin/xsltproc "$xsl_file" "$tmp_file"
}	

#######################################################################
# List the endpoints in the given metadata file. 
#
# Usage: listEndpoints [-f MD_FILE]
#
# The optional MD_FILE argument is the path to a local metadata file.
# The root element of the metadata file is an md:EntityDescriptor
# element. If the MD_FILE argument is omitted on the command line,
# the input is taken from stdin. In any case, each line of output 
# consists of the following space-separated fields:
#
#   roleDescriptor endpointType binding location
#
# where roleDescriptor is one of the following:
#
#   IDPSSODescriptor
#   SPSSODescriptor
#   AttributeAuthorityDescriptor
#
# and endpointType indicates the type of endpoint:
#
#   SingleSignOnService
#   SingleLogoutService
#   ArtifactResolutionService
#   AssertionConsumerService
#   DiscoveryResponse
#   RequestInitiator
#   AttributeService
#
# For example, the roleDescriptor and the endpointType might be 
# 'IDPSSODescriptor' and 'SingleSignOnService', respectively, in 
# which case the endpoint is a so-called IdP SSO endpoint.
#
# A return code > 1 is a fatal error.
#
# Environment Variables
#
# Two environment variables are required. The LIB_DIR environment
# variable points to a source code library containing bash scripts,
# XSLT scripts, and other source files. The TMPDIR environment 
# variable points to a temporary directory used by this function.
#
#######################################################################
listEndpoints () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	# determine the source lib directory
	if [ -z "$LIB_DIR" ]; then
		echo "ERROR: $FUNCNAME requires env var LIB_DIR" >&2
		return 2
	fi
	if [ ! -d "$LIB_DIR" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $LIB_DIR" >&2
		return 2
	fi
	
	# TODO: Take temp dir on the command line
	
	# check the temporary directory
	if [ -z "$TMPDIR" ]; then
		echo "ERROR: $FUNCNAME requires env var TMPDIR" >&2
		return 2
	fi
	if [ ! -d "$TMPDIR" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $TMPDIR" >&2
		return 2
	fi
	
	local xml_file
	local xsl_file
	local tmp_file
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":f:" opt; do
		case $opt in
			f)
				xml_file="$OPTARG"
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

	# make sure there are no command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 0 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (0 required)" >&2
		return 2
	fi
		
	# read the input into a temporary file
	tmp_file="${TMPDIR}/tmp_metadata_in_$$.xml"
	if [ -z "$xml_file" ]; then
		# read input from stdin
		/bin/cat - > "$tmp_file"
	else
		if [ ! -f "$xml_file" ]; then
			echo "ERROR: $FUNCNAME: file does not exist: $xml_file" >&2
			return 2
		fi
		/bin/cp "$xml_file" "$tmp_file"
	fi
	
	# check the stylesheet
	xsl_file="$LIB_DIR/entity_endpoints_txt.xsl"
	if [ ! -f "$xsl_file" ]; then
		echo "ERROR: $FUNCNAME: stylesheet does not exist: $xsl_file" >&2
		return 2
	fi
	
	/usr/bin/xsltproc "$xsl_file" "$tmp_file"
}	

#######################################################################
# A convenience function that filters the output of the listEndpoints 
# function.
#
# Usage: listEndpoints [-f MD_FILE] | filterEndpoints [-r ROLE] [-t TYPE] [-b BINDING]
#
# The ROLE argument of the -r option is a roleDescriptor.
# The TYPE argument of the -t option is an endpointType.
# The BINDING argument of the -b option is a binding URI.
#
# For example:
#
# $ echo "$entityDescriptor" | listEndpoints | filterEndpoints -r IDPSSODescriptor
#
# The above command lists only those endpoints contained in the
# IDPSSODescriptor element (if any).
#
# Here's another example:
#
# $ echo "$entityDescriptor" | listEndpoints | filterEndpoints -t SingleSignOnService -b $binding
#
# This command lists SSO endpoints with a particular binding.
#######################################################################
filterEndpoints () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	# filter nothing by default
	local role='[^ ]+'
	local type='[^ ]+'
	local binding='[^ ]+'
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":r:t:b:" opt; do
		case $opt in
			r)
				role="$OPTARG"
				;;
			t)
				type="$OPTARG"
				;;
			b)
				binding="$OPTARG"
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

	# make sure there are no command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 0 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (0 required)" >&2
		return 2
	fi
		
	# filter all endpoints except those with the given role, type, and binding
	/bin/cat - | $_GREP -E "^$role $type $binding "
}

#######################################################################
# A convenience function that takes the output of the listEndpoints 
# function and returns a list of the corresponding endpoint locations
# only.
#
# Usage: listEndpoints [-f MD_FILE] | listEndpointLocations
# 
# For example:
#
#	location=$( echo "$entityDescriptor" | listEndpoints \
#		| filterEndpoints -t SingleSignOnService -b $binding \
#		| listEndpointLocations \
#		| /usr/bin/head -n 1
#	)
#
# The above command captures a single SSO endpoint with a particular 
# binding.
#
# WARNING. The SingleSignOnService endpoint is non-indexed and 
# therefore one would expect at most one endpoint for any given
# binding. Schema validators are unable to detect such an anomaly,
# however, so the listEndpointLocations function may return 
# multiple values when just one is expected.
#######################################################################
listEndpointLocations () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	# make sure there are no command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 0 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (0 required)" >&2
		return 2
	fi
		
	# cut the location column
	/bin/cat - | $_CUT -f4 -d" "
}
