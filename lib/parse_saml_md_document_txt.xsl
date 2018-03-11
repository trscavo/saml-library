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
	parse_saml_md_document_txt.xsl
	
	An XSL transform that takes a SAML V2.0 metadata document as input. 
	IF the top-level element of the XML document is either an 
	md:EntityDescriptor element or an md:EntitiesDescriptor element, 
	the script parses the input and returns one or more lines of output
	as described below. If the input document is not a well-formed XML 
	document, or the document has an unexpected top-level element, 
	this script returns no output whatsoever.
	
	The result of calling fn:local-name() on the top-level element is 
	always included in the output:
	
	  EntityDescriptor|EntitiesDescriptor
	
	If the top-level element is an md:EntityDescriptor element, the
	following lines are included in the output:
	
	  entityID @entityID
	  registrarID @registrationAuthority
	
	If the top-level element is an md:EntitiesDescriptor element, 
	the following line is included in the output:
	
	  EntitiesName @Name
	
	Likewise the following lines may be included:
	
	  ID @ID
	  publisher @publisher
	  creationInstant @creationInstant
	  validUntil @validUntil
	  cacheDuration @cacheDuration
	
	Name-value pairs on a line are tab-separated. In all cases, if 
	the value is null, the entire line is omitted. The order of output 
	lines is unspecified.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi">
	
	<!-- output is plain text -->
	<xsl:output method="text"/>

	<!-- match one of the desired top-level elements -->
	<xsl:template match="/md:EntitiesDescriptor | /md:EntityDescriptor">
	
		<!-- indicate the local-name of the actual top-level element -->
		<xsl:value-of select="local-name(.)"/>			
		<xsl:text>&#x0a;</xsl:text>
		
		<xsl:if test="local-name(.) = 'EntityDescriptor'">
			<!-- @entityID is a REQUIRED attribute -->
			<xsl:text>entityID</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="./@entityID"/>
			<xsl:text>&#x0a;</xsl:text>
			
			<!-- the mdrpi:RegistrationInfo element is optional -->
			<xsl:variable name="registrarID" select="md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority"/>
			<xsl:if test="$registrarID != ''">
				<xsl:text>registrarID</xsl:text>
				<xsl:text>&#x09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#x0a;</xsl:text>
			</xsl:if>
		</xsl:if>

		<xsl:if test="local-name(.) = 'EntitiesDescriptor'">
			<!-- the @Name attribute is optional -->
			<xsl:variable name="groupName" select="./@Name"/>
			<xsl:if test="$groupName != ''">
				<xsl:text>EntitiesName</xsl:text>
				<xsl:text>&#x09;</xsl:text>
				<xsl:value-of select="$groupName"/>
				<xsl:text>&#x0a;</xsl:text>
			</xsl:if>
		</xsl:if>

		<!-- the @ID attribute is optional -->
		<xsl:variable name="docID" select="./@ID"/>
		<xsl:if test="$docID != ''">
			<xsl:text>ID</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="$docID"/>
			<xsl:text>&#x0a;</xsl:text>
		</xsl:if>

		<!-- the mdrpi:PublicationInfo element is optional -->
		<xsl:variable name="publisher" select="./md:Extensions/mdrpi:PublicationInfo/@publisher"/>
		<xsl:if test="$publisher != ''">
			<xsl:text>publisher</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="$publisher"/>
			<xsl:text>&#x0a;</xsl:text>
		</xsl:if>

		<!-- the mdrpi:PublicationInfo element is optional -->
		<xsl:variable name="creationInstant" select="./md:Extensions/mdrpi:PublicationInfo/@creationInstant"/>
		<xsl:if test="$creationInstant != ''">
			<xsl:text>creationInstant</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="$creationInstant"/>
			<xsl:text>&#x0a;</xsl:text>
		</xsl:if>

		<!-- the @validUntil attribute is optional -->
		<xsl:variable name="validUntil" select="./@validUntil"/>
		<xsl:if test="$validUntil != ''">
			<xsl:text>validUntil</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="$validUntil"/>
			<xsl:text>&#x0a;</xsl:text>
		</xsl:if>

		<!-- the @cacheDuration attribute is optional -->
		<xsl:variable name="cacheDuration" select="./@cacheDuration"/>
		<xsl:if test="$cacheDuration != ''">
			<xsl:text>cacheDuration</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="$cacheDuration"/>
			<xsl:text>&#x0a;</xsl:text>
		</xsl:if>

	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
