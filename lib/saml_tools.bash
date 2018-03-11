#!/bin/bash

#######################################################################
# Copyright 2013--2018 Tom Scavo
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
#
# This function probes a browser-facing IdP endpoint location. The 
# resulting HTTP exchange may include multiple round trips as the 
# server negotiates an initial session with the client. The exchange 
# usually terminates with the server presenting an HTML login form 
# to the client.
#
# Usage:
#   probe_saml_idp_endpoint \
#       -t CONNECT_TIME -m MAX_TIME \
#       -r MAX_REDIRS \
#       [-V CURL_TRACE_FILE] \
#       [-o RESPONSE_FILE] \
#       -T TMP_DIR \
#       IDP_ENDPOINT_LOCATION IDP_ENDPOINT_BINDING IDP_ENDPOINT_TYPE
# where
#   IDP_ENDPOINT_LOCATION and IDP_ENDPOINT_BINDING are the
#   Location and Binding XML attribute values of a browser-
#   facing SAML endpoint at the IdP. Any such endpoint has one 
#   of the following binding URIs:
#
#      urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect
#      urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST
#      urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign
#      urn:mace:shibboleth:1.0:profiles:AuthnRequest
#
#   The IDP_ENDPOINT_TYPE must be "SingleSignOnService", which is
#   the only endpoint type supported by the script at this time.
#
# The output of this script consists of a single line with four 
# space-separated fields:
#
#   1. curl error code
#   2. curl output string
#   3. IdP endpoint location
#   4. IdP endpoint binding
#
# The function records the details of the various processing steps
# and the resulting HTTP transaction in files stored in the given 
# temporary directory. If the -V option is specified on the command 
# line, a curl trace of the transaction is also provided.
#
#######################################################################
probe_saml_idp_endpoint () {

	# command-line options
	local connect_timeout
	local max_time
	local max_redirs
	local curl_trace_file
	local response_file
	local tmp_dir
	
	# command-line arguments
	local idp_endpoint_binding
	local idp_endpoint_location
	local idp_endpoint_type
	
	# other local vars
	local local_opts
	local saml_message
	local exit_status
	
	###################################################################
	# Process command-line options and arguments.
	###################################################################
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":t:m:r:V:o:T:" opt; do
		case $opt in
			t)
				connect_timeout="$OPTARG"
				local_opts="$local_opts -t $connect_timeout"
				;;
			m)
				max_time="$OPTARG"
				local_opts="$local_opts -m $max_time"
				;;
			r)
				max_redirs="$OPTARG"
				local_opts="$local_opts -r $max_redirs"
				;;
			V)
				curl_trace_file="$OPTARG"
				local_opts="$local_opts -V $curl_trace_file"
				;;
			o)
				response_file="$OPTARG"
				local_opts="$local_opts -o $response_file"
				;;
			T)
				tmp_dir="$OPTARG"
				local_opts="$local_opts -T $tmp_dir"
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

	if [ -z "$connect_timeout" ]; then
		echo "ERROR: $FUNCNAME: connection timeout (option -t) required" >&2
		return 2
	fi

	if [ -z "$max_time" ]; then
		echo "ERROR: $FUNCNAME: max time (option -m) required" >&2
		return 2
	fi

	if [ -z "$max_redirs" ]; then
		echo "ERROR: $FUNCNAME: max redirects (option -r) required" >&2
		return 2
	fi

	# check for a temporary directory
	if [ -z "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: temporary directory (option -T) required" >&2
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: temporary directory does not exist: $tmp_dir" >&2
		return 2
	fi

	# make sure there are the correct number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 3 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (3 required)" >&2
		return 2
	fi
	idp_endpoint_location="$1"
	idp_endpoint_binding="$2"
	idp_endpoint_type="$3"
	
	# SSO endpoints only
	if [ "$idp_endpoint_type" != "SingleSignOnService" ]; then
		echo "ERROR: $FUNCNAME: endpoint type not supported: $idp_endpoint_type" >&2
		return 2
	fi
	
	###################################################################
	# Probe the SAML endpoint.
	###################################################################
	
	# probe a browser-facing SAML2 SSO endpoint
	if [ "$idp_endpoint_binding" = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" ] || \
	   [ "$idp_endpoint_binding" = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" ] || \
	   [ "$idp_endpoint_binding" = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign" ]; then
		
		# construct an AuthnRequest message
		saml_message=$( construct_SAML2_AuthnRequest $idp_endpoint_location )
		exit_status=$?
		if [ "$exit_status" -ne 0 ]; then
			echo "ERROR: $FUNCNAME: construct_SAML2_AuthnRequest failed ($exit_status)" >&2
			return 3
		fi

		# probe the endpoint
		probe_saml2_idp_endpoint $local_opts $idp_endpoint_location $idp_endpoint_binding "$saml_message"
		exit_status=$?
		if [ "$exit_status" -ne 0 ]; then
			echo "ERROR: $FUNCNAME: probe_saml2_idp_endpoint failed ($exit_status)" >&2
			return 3
		fi

		return 0
	fi

	# probe a browser-facing SAML1 SSO endpoint
	if [ "$idp_endpoint_binding" = "urn:mace:shibboleth:1.0:profiles:AuthnRequest" ]; then
		
		# probe the endpoint
		probe_shibboleth_sso_endpoint $local_opts $idp_endpoint_location $idp_endpoint_binding
		exit_status=$?
		if [ "$exit_status" -ne 0 ]; then
			echo "ERROR: $FUNCNAME: probe_shibboleth_sso_endpoint failed ($exit_status)" >&2
			return 3
		fi

		return 0
	fi
	
	echo "ERROR: $FUNCNAME: endpoint binding not supported: $idp_endpoint_binding" >&2
	return 2
}

#######################################################################
#
# This function transmits a SAML V2.0 message to a browser-facing 
# IdP endpoint location. The resulting HTTP exchange may include
# multiple round trips as the server negotiates an initial session
# with the client. The exchange often terminates with the server
# presenting an HTML login form to the client.
#
# Usage:
#   probe_saml2_idp_endpoint \
#       -t CONNECT_TIME -m MAX_TIME \
#       -r MAX_REDIRS \
#       [-V CURL_TRACE_FILE] \
#       [-o RESPONSE_FILE] \
#       -T TMP_DIR \
#       IDP_ENDPOINT_LOCATION IDP_ENDPOINT_BINDING \
#       SAML_MESSAGE
# where
#   IDP_ENDPOINT_LOCATION and IDP_ENDPOINT_BINDING are the
#   Location and Binding XML attribute values of a browser-
#   facing SAML2 endpoint at the IdP. By definition, any 
#   such endpoint has one of the following bindings:
#
#      urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect
#      urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST
#      urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign
#
#   The SAML_MESSAGE is a plain text XML message, either a SAML2 
#   AuthnRequest or a SAML2 LogoutRequest.
#
# Before transmitting the SAML message to the IdP, a message
# binding is constructing as specified in the OASIS SAML2 Binding 
# specification. In the case of HTTP-Redirect, the message is
# DEFLATE-compressed, base64-encoded, and percent-encoded.
# In the case of HTTP-POST and HTTP-POST-SimpleSign, the message
# is base64-encoded and percent-encoded only (but not compressed).
#
# The output of this script consists of a single line with four 
# space-separated fields:
#
#   1. curl error code
#   2. curl output string
#   3. IdP endpoint location
#   4. IdP endpoint binding
#
# The function records the details of the various processing steps
# and the resulting HTTP transaction in files stored in the given 
# temporary directory. If the -V option is specified on the command 
# line, a curl trace of the transaction is also provided. In the
# temporary directory, see these log files for details:
#
#   deflate_log
#   probe_saml2_idp_endpoint_log
#
#######################################################################
probe_saml2_idp_endpoint () {

	# external dependency
	if [ "$(type -t percent_encode)" != function ]; then
		echo "ERROR: $FUNCNAME: function percent_encode not found" >&2
		return 2
	fi

	# user agent
	local script_version="0.6"
	local user_agent_string="SAML2 IdP Endpoint Probe ${script_version}"

	# command-line options
	local local_opts
	local connect_timeout
	local max_time
	local max_redirs
	local tmp_dir
	
	# command-line arguments
	local idp_endpoint_binding
	local idp_endpoint_location
	local saml_message
	
	# temporary files
	local tmp_log_file
	local header_file
	local response_file
	local cookie_jar_file
	local curl_trace_file
	local deflated_message_file
	local base64_encoded_message_file
	
	local exit_status
	local base64_encoded_message
	local percent_encoded_message
	local protocol_url
	
	local curl_opts
	local curl_output
	local curl_error_code
		
	###################################################################
	# Process command-line options and arguments.
	###################################################################
	
	# default curl options
	curl_opts="--silent --show-error"
	curl_opts="$curl_opts --insecure --tlsv1"
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":t:m:r:V:o:T:" opt; do
		case $opt in
			t)
				connect_timeout="$OPTARG"
				curl_opts="$curl_opts --connect-timeout $connect_timeout"
				;;
			m)
				max_time="$OPTARG"
				curl_opts="$curl_opts --max-time $max_time"
				;;
			r)
				max_redirs="$OPTARG"
				curl_opts="$curl_opts --location --max-redirs $max_redirs"
				;;
			V)
				curl_trace_file="$OPTARG"
				curl_opts="$curl_opts --trace-ascii $curl_trace_file"
				;;
			o)
				response_file="$OPTARG"
				curl_opts="$curl_opts --output $response_file"
				;;
			T)
				tmp_dir="$OPTARG"
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

	if [ -z "$connect_timeout" ]; then
		echo "ERROR: $FUNCNAME: connection timeout (option -t) required" >&2
		return 2
	fi

	if [ -z "$max_time" ]; then
		echo "ERROR: $FUNCNAME: max time (option -m) required" >&2
		return 2
	fi

	if [ -z "$max_redirs" ]; then
		echo "ERROR: $FUNCNAME: max redirects (option -r) required" >&2
		return 2
	fi

	# check for a temporary directory
	if [ -z "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: temporary directory (option -T) required" >&2
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: temporary directory does not exist: $tmp_dir" >&2
		return 2
	fi

	# make sure there are the correct number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 3 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (3 required)" >&2
		return 2
	fi
	idp_endpoint_location="$1"
	idp_endpoint_binding="$2"
	saml_message="$3"
	
	# check the binding
	if [ "$idp_endpoint_binding" != "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" ] && \
	   [ "$idp_endpoint_binding" != "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" ] && \
	   [ "$idp_endpoint_binding" != "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign" ]; then
		echo "ERROR: $FUNCNAME: unrecognized binding: $idp_endpoint_binding" >&2
		return 2
	fi

	###################################################################
	# Initialization complete.
	###################################################################
	
	# temporary log file
	tmp_log_file="$tmp_dir/${FUNCNAME}_log"
	echo "$FUNCNAME using temporary directory: $tmp_dir" > "$tmp_log_file"

	# temporary files
	cookie_jar_file="${tmp_dir}/idp_cookie_jar.txt"
	curl_opts="$curl_opts --cookie-jar $cookie_jar_file --cookie $cookie_jar_file"
	header_file="${tmp_dir}/idp_http_header.txt"
	curl_opts="$curl_opts --dump-header $header_file"
	[ -z "$response_file" ] && response_file=/dev/null
	curl_opts="$curl_opts --output $response_file"

	# log input data
	printf "$FUNCNAME using connection timeout (option -t): %d\n" "$connect_timeout" >> "$tmp_log_file"
	printf "$FUNCNAME using max time (option -m): %d\n" "$max_time" >> "$tmp_log_file"
	printf "$FUNCNAME using max redirects (option -r): %d\n" "$max_redirs" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP endpoint binding: %s\n" "$idp_endpoint_binding" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP endpoint location: %s\n" "$idp_endpoint_location" >> "$tmp_log_file"
	printf "$FUNCNAME using SAML message (flattened): %s\n" "$( echo $saml_message | /usr/bin/tr -d '\n\r' )" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP cookie file: %s\n" "$cookie_jar_file" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP header file: %s\n" "$header_file" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP response file: %s\n" "$response_file" >> "$tmp_log_file"
	
	###################################################################
	# Compute the protocol URL.
	###################################################################
	
	# HTTP-Redirect or HTTP-POST?
	if [ "$idp_endpoint_binding" = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" ]; then
	
		# Note: The deflated message is stored in a file. 
		# It is not stored in a variable since the echo
		# command does not operate safely on binary data.
	
		deflated_message_file="${tmp_dir}/saml_message.xml.deflate"
		printf "$FUNCNAME using deflated message file: %s\n" "$deflated_message_file" >> "$tmp_log_file"

		# deflate the SAML message
		deflate $local_opts -T $tmp_dir "$saml_message" > "$deflated_message_file"
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			echo "ERROR: $FUNCNAME: failed to deflate the message ($exit_status)" >&2
			return 3
		fi
	
		# base64-encode the deflated message
		base64_encoded_message=$( /usr/bin/base64 "$deflated_message_file" )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			echo "ERROR: $FUNCNAME: failed to base64-encode the deflated message ($exit_status)" >&2
			return 3
		fi
		printf "$FUNCNAME computed base64-encoded message: %s\n" "$base64_encoded_message" >> "$tmp_log_file"
	
		# percent-encode the base64-encoded, deflated SAML message
		percent_encoded_message=$( percent_encode "$base64_encoded_message" )
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			echo "ERROR: $FUNCNAME: failed to percent-encode message ($exit_status)" >&2
			return 3
		fi
		printf "$FUNCNAME computed percent-encoded message: %s\n" "$percent_encoded_message" >> "$tmp_log_file"

		# construct the URL subject to the SAML2 HTTP-Redirect binding
		protocol_url=${idp_endpoint_location}?SAMLRequest=$percent_encoded_message
		printf "$FUNCNAME computed protocol URL: %s\n" "$protocol_url" >> "$tmp_log_file"

	else
	
		base64_encoded_message_file="${tmp_dir}/saml_message.xml.base64"
		printf "$FUNCNAME using encoded message file: %s\n" "$base64_encoded_message_file" >> "$tmp_log_file"

		# base64-encode the SAML message
		echo -n "$saml_message" | /usr/bin/base64 > "$base64_encoded_message_file"
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			echo "ERROR: $FUNCNAME: failed to base64-encode the message ($exit_status)" >&2
			return 3
		fi
	
		# in the case of HTTP-POST, the protocol URL IS the endpoint location
		protocol_url=$idp_endpoint_location
		printf "$FUNCNAME computed protocol URL: %s\n" "$protocol_url" >> "$tmp_log_file"
	
		curl_opts="${curl_opts} --data-urlencode SAMLRequest@$base64_encoded_message_file"

	fi
	
	###################################################################
	# Probe the IdP endpoint.
	###################################################################
	
	printf "$FUNCNAME using curl opts: %s\n" "$curl_opts" >> "$tmp_log_file"

	# transmit the request to the IdP
	curl_output=$( /usr/bin/curl ${curl_opts} \
		--user-agent "$user_agent_string" \
		--write-out 'redirects:%{num_redirects};response:%{http_code};dns:%{time_namelookup};tcp:%{time_connect};ssl:%{time_appconnect};total:%{time_total}' \
		"$protocol_url"
	)
	curl_error_code=$?
	
	# only the last line of output is processed further
	curl_output=$(echo "$curl_output" | /usr/bin/tail -n 1)
	printf "$FUNCNAME output: %s %s %s %s\n" "$curl_error_code $curl_output $idp_endpoint_location $idp_endpoint_binding" >> "$tmp_log_file"
	echo "$curl_error_code $curl_output $idp_endpoint_location $idp_endpoint_binding"
	
	return 0
}

#######################################################################
#
# This function transmits a SAML message to an IdP endpoint location 
# via the Shibboleth 1.3 AuthnRequest protocol. The latter is a
# proprietary (but widely used) protocol for IdPs that support
# the SAML1 Web Browser SSO profile.
#
# Usage:
#   probe_shibboleth_sso_endpoint \
#       -t CONNECT_TIME -m MAX_TIME \
#       -r MAX_REDIRS \
#       [-V CURL_TRACE_FILE] \
#       [-o RESPONSE_FILE] \
#       -T TMP_DIR \
#       IDP_ENDPOINT_LOCATION [IDP_ENDPOINT_BINDING]
# where
#   IDP_ENDPOINT_LOCATION and IDP_ENDPOINT_BINDING are the
#   Location and Binding XML attribute values of a particular
#   browser-facing endpoint at the IdP. This script probes
#   an endpoint with binding URI:
#
#      urn:mace:shibboleth:1.0:profiles:AuthnRequest
#
#   Since only one binding is recognized by this script, the
#   binding URI is an optional command-line argument.
#
# The output of this script consists of a single line with four 
# space-separated fields:
#
#   1. curl error code
#   2. curl output string
#   3. IdP endpoint location
#   4. IdP endpoint binding
#
# The function records the details of the various processing steps
# and the resulting HTTP transaction in files stored in the given 
# temporary directory. If the -V option is specified on the command 
# line, a curl trace of the transaction is also provided. In the
# temporary directory, see this log file for details:
#
#   probe_shibboleth_sso_endpoint_log
#
#######################################################################
probe_shibboleth_sso_endpoint () {

	# check global env vars
	if [ -z "$SAML1_SP_ENTITY_ID" ]; then
		echo "ERROR: $FUNCNAME requires env var SAML1_SP_ENTITY_ID" >&2
		return 2
	fi
	if [ -z "$SAML1_SP_ACS_URL" ]; then
		echo "ERROR: $FUNCNAME requires env var SAML1_SP_ACS_URL" >&2
		return 2
	fi
	# make the binding optional
	if [ -z "$SAML1_SP_ACS_BINDING" ]; then
		echo "ERROR: $FUNCNAME requires env var SAML1_SP_ACS_BINDING" >&2
		return 2
	fi

	# external dependency
	if [ "$(type -t percent_encode)" != function ]; then
		echo "ERROR: $FUNCNAME: function percent_encode not found" >&2
		return 2
	fi

	# user agent
	local script_version="0.3"
	local user_agent_string="SAML1 IdP Endpoint Probe ${script_version}"

	# command-line options
	local local_opts
	local connect_timeout
	local max_time
	local max_redirs
	local tmp_dir
	
	# command-line arguments
	local idp_shibboleth_sso_binding
	local idp_shibboleth_sso_location
	
	# temporary files
	local tmp_log_file
	local header_file
	local response_file
	local cookie_jar_file
	local curl_trace_file
	
	local exit_status
	local encoded_entityid
	local encoded_acs_url
	local protocol_url
	
	local curl_opts
	local curl_output
	local curl_error_code
		
	###################################################################
	# Process command-line options and arguments.
	###################################################################
	
	# default curl options
	curl_opts="--silent --show-error"
	curl_opts="$curl_opts --insecure --tlsv1"
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":t:m:r:V:o:T:" opt; do
		case $opt in
			t)
				connect_timeout="$OPTARG"
				curl_opts="$curl_opts --connect-timeout $connect_timeout"
				;;
			m)
				max_time="$OPTARG"
				curl_opts="$curl_opts --max-time $max_time"
				;;
			r)
				max_redirs="$OPTARG"
				curl_opts="$curl_opts --location --max-redirs $max_redirs"
				;;
			V)
				curl_trace_file="$OPTARG"
				curl_opts="$curl_opts --trace-ascii $curl_trace_file"
				;;
			o)
				response_file="$OPTARG"
				curl_opts="$curl_opts --output $response_file"
				;;
			T)
				tmp_dir="$OPTARG"
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

	if [ -z "${connect_timeout}" ]; then
		echo "ERROR: $FUNCNAME: connection timeout (option -t) required" >&2
		return 2
	fi

	if [ -z "${max_time}" ]; then
		echo "ERROR: $FUNCNAME: max time (option -m) required" >&2
		return 2
	fi

	if [ -z "${max_redirs}" ]; then
		echo "ERROR: $FUNCNAME: max redirects (option -r) required" >&2
		return 2
	fi

	# check for a temporary directory
	if [ -z "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: temporary directory (option -T) required" >&2
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: temporary directory does not exist: $tmp_dir" >&2
		return 2
	fi
	
	# make sure there are the correct number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -lt 1 ]; then
		echo "ERROR: $FUNCNAME: too few arguments: $# (at least 1 required)" >&2
		return 2
	fi
	if [ $# -gt 2 ]; then
		echo "ERROR: $FUNCNAME: too many arguments: $# (at most 2 required)" >&2
		return 2
	fi
	
	# capture the command-line argument(s)
	if [ $# -eq 1 ]; then
		idp_shibboleth_sso_location="$1"
		idp_shibboleth_sso_binding=urn:mace:shibboleth:1.0:profiles:AuthnRequest
	else
		idp_shibboleth_sso_location="$1"
		idp_shibboleth_sso_binding="$2"
		# check the binding
		if [ "$idp_shibboleth_sso_binding" != "urn:mace:shibboleth:1.0:profiles:AuthnRequest" ]; then
			echo "ERROR: $FUNCNAME: unrecognized binding: $idp_shibboleth_sso_binding" >&2
			return 2
		fi
	fi

	###################################################################
	# Initialization complete.
	###################################################################
	
	# temporary log file
	tmp_log_file="$tmp_dir/${FUNCNAME}_log"
	echo "$FUNCNAME using temporary directory: $tmp_dir" > "$tmp_log_file"

	# temporary files
	cookie_jar_file="${tmp_dir}/idp_cookie_jar.txt"
	curl_opts="$curl_opts --cookie-jar $cookie_jar_file --cookie $cookie_jar_file"
	header_file="${tmp_dir}/idp_http_header.txt"
	curl_opts="$curl_opts --dump-header $header_file"
	[ -z "$response_file" ] && response_file=/dev/null
	curl_opts="$curl_opts --output $response_file"

	# log global env vars
	printf "$FUNCNAME using SP with entityID: %s\n" "$SAML1_SP_ENTITY_ID" >> "$tmp_log_file"
	printf "$FUNCNAME using SP ACS URL: %s\n" "$SAML1_SP_ACS_URL" >> "$tmp_log_file"
	printf "$FUNCNAME using SP ACS Binding: %s\n" "$SAML1_SP_ACS_BINDING" >> "$tmp_log_file"
	
	# log input data
	printf "$FUNCNAME using connection timeout (option -t): %d\n" "$connect_timeout" >> "$tmp_log_file"
	printf "$FUNCNAME using max time (option -m): %d\n" "$max_time" >> "$tmp_log_file"
	printf "$FUNCNAME using max redirects (option -r): %d\n" "$max_redirs" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP endpoint location: %s\n" "$idp_shibboleth_sso_location" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP endpoint binding: %s\n" "$idp_shibboleth_sso_binding" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP cookie file: %s\n" "$cookie_jar_file" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP header file: %s\n" "$header_file" >> "$tmp_log_file"
	printf "$FUNCNAME using IdP response file: %s\n" "$response_file" >> "$tmp_log_file"
	
	###################################################################
	# Compute the protocol URL.
	###################################################################
	
	# percent-encode the SP entityID
	encoded_entityid=$( percent_encode "$SAML1_SP_ENTITY_ID" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: failed to percent-encode SP entityID ($exit_status)" >&2
		return 3
	fi
	printf "$FUNCNAME encoded SP entityID: %s\n" "$encoded_entityid" >> "$tmp_log_file"

	# percent-encode the SP AssertionConsumerService location
	encoded_acs_url=$( percent_encode "$SAML1_SP_ACS_URL" )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: failed to percent-encode ACS location ($exit_status)" >&2
		return 3
	fi
	printf "$FUNCNAME encoded SP ACS URL: %s\n" "$encoded_acs_url" >> "$tmp_log_file"

	# construct the URL subject to the Shibboleth 1.3 AuthnRequest protocol
	protocol_url="${idp_shibboleth_sso_location}?providerId=${encoded_entityid}&shire=${encoded_acs_url}&target=cookie"
	printf "$FUNCNAME computed protocol URL: %s\n" "$protocol_url" >> "$tmp_log_file"
	
	###################################################################
	# Probe the IdP endpoint.
	###################################################################
	
	printf "$FUNCNAME using curl opts: %s\n" "$curl_opts" >> "$tmp_log_file"

	# transmit the request to the IdP
	curl_output=$( /usr/bin/curl ${curl_opts} \
		--user-agent "$user_agent_string" \
		--write-out 'redirects:%{num_redirects};response:%{http_code};dns:%{time_namelookup};tcp:%{time_connect};ssl:%{time_appconnect};total:%{time_total}' \
		"$protocol_url"
	)
	curl_error_code=$?
	
	# only the last line of output is processed further
	curl_output=$(echo "$curl_output" | /usr/bin/tail -n 1)
	printf "$FUNCNAME output: %s %s %s %s\n" "$curl_error_code $curl_output $idp_shibboleth_sso_location $idp_shibboleth_sso_binding" >> "$tmp_log_file"
	echo "$curl_error_code $curl_output $idp_shibboleth_sso_location $idp_shibboleth_sso_binding"
	
	return 0
}

#######################################################################
#
# A native BASH implementation of DEFLATE compression (RFC 1951)
#
# Usage:
#   deflate [-v] -T TMP_DIR STRING_TO_DEFLATE
# where
#   TMP_DIR is a temporary working directory
#   STRING_TO_DEFLATE is the actual string to be deflated
#
# This implementation leverages the fact that the popular tool gzip 
# relies on DEFLATE compression at its core. The trick is to invoke 
# 'gzip --no-name', which compresses its input without storing a 
# filename or timestamp in the output. This yields a (fixed) 10-byte
# header along with the usual 8-byte trailer, both of which are 
# stripped from the output of the gzip command by this function. The 
# end result is a DEFLATE compressed stream of bytes.
#
# See: http://stackoverflow.com/questions/27066133/how-to-create-bare-deflate-stream-from-file-in-linux
#
# Warning: This function outputs binary data. To use it interactively,
#          it's probably best to base64-encode the deflated string:
#          $ deflate -T $TMPDIR "hello world" | /usr/bin/base64
#          y0jNyclXKM8vykkBAA==
#
#######################################################################
deflate () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi

	local verbose_mode=false
	local tmp_dir
	local tmp_log_file
	local string_to_deflate
	local n

	# temporary files
	local zipfile
	local headerfile
	local trailerfile
	local noheaderfile
	local strippedfile
	
	local opt
	local OPTARG
	local OPTIND
	while getopts ":vT:" opt; do
		case $opt in
			v)
				verbose_mode=true
				;;
			T)
				tmp_dir="$OPTARG"
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
	
	# a temporary directory is required
	if [ -z "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: no temporary directory specified" >&2
		return 2
	fi
	if [ ! -d "$tmp_dir" ]; then
		echo "ERROR: $FUNCNAME: directory does not exist: $tmp_dir" >&2
		return 2
	fi
	tmp_log_file="$tmp_dir/${FUNCNAME}_log"
	$verbose_mode && echo "$FUNCNAME using temporary directory $tmp_dir" > "$tmp_log_file"

	# determine the URL location
	shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		echo "ERROR: $FUNCNAME: wrong number of arguments: $# (1 required)" >&2
		return 2
	fi
	string_to_deflate="$1"
	if [ -z "$string_to_deflate" ] ; then
		echo "ERROR: $FUNCNAME: empty string" >&2
		return 2
	fi
	$verbose_mode && echo "$FUNCNAME deflating string $string_to_deflate" >> "$tmp_log_file"
	
	zipfile=$tmp_dir/${FUNCNAME}_junk.gz
	headerfile=$tmp_dir/${FUNCNAME}_junk.gz.header
	trailerfile=$tmp_dir/${FUNCNAME}_junk.gz.trailer
	noheaderfile=$tmp_dir/${FUNCNAME}_junk.gz.no-header
	strippedfile=$tmp_dir/${FUNCNAME}_junk.gz.stripped
	if $verbose_mode; then
		echo "$FUNCNAME using temporary file $zipfile" >> "$tmp_log_file"
		echo "$FUNCNAME using temporary file $headerfile" >> "$tmp_log_file"
		echo "$FUNCNAME using temporary file $trailerfile" >> "$tmp_log_file"
		echo "$FUNCNAME using temporary file $noheaderfile" >> "$tmp_log_file"
		echo "$FUNCNAME using temporary file $strippedfile" >> "$tmp_log_file"
	fi
	
	# compress with no filename or timestamp stored in the output,
	# which yields a (fixed) 10-byte header and the usual 8-byte trailer.
	echo -n "$string_to_deflate" | $_GZIP -q --no-name > $zipfile
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: gzip failed ($exit_status)" >&2
		return 3
	fi
	
	# strip (and save) the 10-byte header
	/bin/cat $zipfile | ( /bin/dd of=$headerfile bs=1 count=10 2>/dev/null; /bin/cat > $noheaderfile )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: unable to strip header ($exit_status)" >&2
		return 3
	fi
	
	# compute the size (in bytes) of the remaining file
	n=$( /bin/cat $noheaderfile | /usr/bin/wc -c )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: unable to compute file size ($exit_status)" >&2
		return 3
	fi

	# strip (and save) the 8-byte trailer
	/bin/cat $noheaderfile | ( /bin/dd of=$strippedfile bs=1 count=$[ n - 8 ] 2>/dev/null; /bin/cat > $trailerfile )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: unable to strip trailer ($exit_status)" >&2
		return 3
	fi
	
	# sanity check
	/bin/cat $headerfile $strippedfile $trailerfile | /usr/bin/diff -q $zipfile - >&2
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: diff failed ($exit_status)" >&2
		return 3
	fi
	
	# return the DEFLATE-compressed input string
	/bin/cat $strippedfile
	
}

#######################################################################
# This function is intentionally not documented
#######################################################################
construct_SAML2_AuthnRequest () {

	# check global env vars
	if [ -z "$SAML2_SP_ENTITY_ID" ]; then
		echo "ERROR: $FUNCNAME requires env var SAML2_SP_ENTITY_ID" >&2
		return 2
	fi
	if [ -z "$SAML2_SP_ACS_URL" ]; then
		echo "ERROR: $FUNCNAME requires env var SAML2_SP_ACS_URL" >&2
		return 2
	fi
	if [ -z "$SAML2_SP_ACS_BINDING" ]; then
		echo "ERROR: $FUNCNAME requires env var SAML2_SP_ACS_BINDING" >&2
		return 2
	fi

	local message_id
	local exit_status
	local dateStr

	# input arguments
	local idp_sso_location

	# make sure there are the correct number of command-line arguments
	#shift $(( OPTIND - 1 ))
	if [ $# -ne 1 ]; then
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (1 required)" >&2
		return 2
	fi
	idp_sso_location="$1"

	# compute value of ID XML attribute
	# (40 bytes of pseudo-random alphanumeric characters)
	message_id=$( LC_CTYPE=C /usr/bin/tr -dc '[:alnum:]' < /dev/urandom \
		| /bin/dd bs=4 count=10 2>/dev/null 
	)
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: failed to produce message ID ($exit_status)" >&2
		return 3
	fi
	
	# compute value of IssueInstant XML attribute
	# (claim: use of /bin/date compatible on Mac OS and GNU/Linux)
	dateStr=$( /bin/date -u +%Y-%m-%dT%TZ )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: $FUNCNAME: failed to produce dateTime string ($exit_status)" >&2
		return 3
	fi
	
	/bin/cat <<- SAMLAuthnRequest
	<samlp:AuthnRequest
	    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
	    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
	    ID="_${message_id}"
	    Version="2.0"
	    IssueInstant="${dateStr}"
	    Destination="${idp_sso_location}"
	    AssertionConsumerServiceURL="${SAML2_SP_ACS_URL}"
	    ProtocolBinding="${SAML2_SP_ACS_BINDING}"
	    >
	  <saml:Issuer>${SAML2_SP_ENTITY_ID}</saml:Issuer>
	  <samlp:NameIDPolicy AllowCreate="true"/>
	</samlp:AuthnRequest>
	SAMLAuthnRequest
	
}
