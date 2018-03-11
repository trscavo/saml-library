<?xml version="1.0" encoding="UTF-8"?>
<!--
	Copyright 2017-2018 Tom Scavo

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
-->
<!--
	security_contacts_summary_local_json.xsl
	
	This XSL transform takes a SAML metadata aggregate and produces 
	a JSON file that summarizes the security contacts in metadata.
	Only entities registered by InCommon are included in the summary.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:remd="http://refeds.org/metadata"
	xmlns:icmd="http://id.incommon.org/metadata"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi">

	<!-- Output is plain text -->
	<xsl:output method="text"/>

	<xsl:template match="/md:EntitiesDescriptor">
	
		<!-- count the # of IdPs registered by InCommon that contain at least one security contact (of any type) -->
		<xsl:variable name="numInCommonIdPsSecurityContact" select="
			count(
				./md:EntityDescriptor[
					md:IDPSSODescriptor
					and
					md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority = 'https://incommon.org'
					and
					md:ContactPerson[
						@contactType = 'other' 
						and (
							@remd:contactType = 'http://refeds.org/metadata/contactType/security'
							or
							@icmd:contactType = 'http://id.incommon.org/metadata/contactType/security'
						)
					]
				]
			)
		"/>
		
		<!-- count the # of SPs registered by InCommon that contain at least one security contact (of any type) -->
		<xsl:variable name="numInCommonSPsSecurityContact" select="
			count(
				./md:EntityDescriptor[
					md:SPSSODescriptor
					and
					md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority = 'https://incommon.org'
					and
					md:ContactPerson[
						@contactType = 'other' 
						and (
							@remd:contactType = 'http://refeds.org/metadata/contactType/security'
							or
							@icmd:contactType = 'http://id.incommon.org/metadata/contactType/security'
						)
					]
				]
			)
		"/>

		<!-- count the # of entities registered by InCommon with at least one security contact (of any type) -->
		<xsl:variable name="totalInCommonEntitiesSecurityContact" select="
			count(
				./md:EntityDescriptor[
					md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority = 'https://incommon.org'
					and
					md:ContactPerson[
						@contactType = 'other' 
						and (
							@remd:contactType = 'http://refeds.org/metadata/contactType/security'
							or
							@icmd:contactType = 'http://id.incommon.org/metadata/contactType/security'
						)
					]
				]
			)
		"/>
		
		<xsl:text>[&#10;</xsl:text>
		
		<xsl:text>  {&#10;</xsl:text>
		<xsl:text>    "heading": "IdPs registered by InCommon with a security contact",&#10;</xsl:text>
		<xsl:text>    "value": </xsl:text>
		<xsl:value-of select="$numInCommonIdPsSecurityContact"/>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>  }&#10;</xsl:text>
		
		<xsl:text>  ,&#10;</xsl:text>

		<xsl:text>  {&#10;</xsl:text>
		<xsl:text>    "heading": "SPs registered by InCommon with a security contact",&#10;</xsl:text>
		<xsl:text>    "value": </xsl:text>
		<xsl:value-of select="$numInCommonSPsSecurityContact"/>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>  }&#10;</xsl:text>
		
		<xsl:text>  ,&#10;</xsl:text>

		<xsl:text>  {&#10;</xsl:text>
		<xsl:text>    "heading": "Total entities registered by InCommon with a security contact",&#10;</xsl:text>
		<xsl:text>    "value": </xsl:text>
		<xsl:value-of select="$totalInCommonEntitiesSecurityContact"/>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>  }&#10;</xsl:text>
		
		<xsl:text>]&#10;</xsl:text>

	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
