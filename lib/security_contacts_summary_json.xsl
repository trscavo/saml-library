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
	security_contacts_summary_json.xsl
	
	This XSL transform takes a SAML metadata aggregate and produces 
	a JSON file that summarizes the security contacts in metadata.
	All entities are included in the summary, including entities
	registered by other federations.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:remd="http://refeds.org/metadata"
	xmlns:icmd="http://id.incommon.org/metadata">

	<!-- Output is plain text -->
	<xsl:output method="text"/>

	<xsl:template match="/">
	
		<!-- count the # of entities that contain at least one REFEDS security contact -->
		<xsl:variable name="numEntitiesStandardSecurityContact" select="
			count(
				/md:EntitiesDescriptor/md:EntityDescriptor[
					md:ContactPerson[
						@contactType = 'other' 
						and 
						@remd:contactType = 'http://refeds.org/metadata/contactType/security'
					]
				]
			)
		"/>
		
		<!-- count the # of entities that contain at least one InCommon security contact -->
		<xsl:variable name="numEntitiesLegacySecurityContact" select="
			count(
				/md:EntitiesDescriptor/md:EntityDescriptor[
					md:ContactPerson[
						@contactType = 'other' 
						and 
						@icmd:contactType = 'http://id.incommon.org/metadata/contactType/security'
					]
				]
			)
		"/>

		<!-- count the # of entities with at least one security contact (of any type) -->
		<xsl:variable name="totalNumEntitiesSecurityContact" select="
			count(
				/md:EntitiesDescriptor/md:EntityDescriptor[
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
		<xsl:text>    "heading": "Entities with a standard security contact",&#10;</xsl:text>
		<xsl:text>    "value": </xsl:text>
		<xsl:value-of select="$numEntitiesStandardSecurityContact"/>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>  }&#10;</xsl:text>
		
		<xsl:text>  ,&#10;</xsl:text>

		<xsl:text>  {&#10;</xsl:text>
		<xsl:text>    "heading": "Entities with a legacy security contact",&#10;</xsl:text>
		<xsl:text>    "value": </xsl:text>
		<xsl:value-of select="$numEntitiesLegacySecurityContact"/>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>  }&#10;</xsl:text>
		
		<xsl:text>  ,&#10;</xsl:text>

		<xsl:text>  {&#10;</xsl:text>
		<xsl:text>    "heading": "Total entities with a security contact",&#10;</xsl:text>
		<xsl:text>    "value": </xsl:text>
		<xsl:value-of select="$totalNumEntitiesSecurityContact"/>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>&#10;</xsl:text>
		<xsl:text>  }&#10;</xsl:text>
		
		<xsl:text>]&#10;</xsl:text>

	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
