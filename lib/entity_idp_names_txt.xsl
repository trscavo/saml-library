<?xml version="1.0" encoding="UTF-8"?>
<!--
	Copyright 2016-2018 Tom Scavo

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
	entity_idp_names_txt.xsl
	
	This XSL stylesheet takes a SAML 2.0 entity descriptor as input, and then
	outputs the following tab-delimited text:
	
	  entityID DisplayName OrganizationName OrganizationDisplayName registrarID

	where the registrarID is the value of the @registrationAuthority
	XML attribute on the mdrpi:RegistrationInfo element. Since the
	latter is an optional element, the registrarID may be null.
	
	The whitespace in each name is normalized using the XSLT normalize-space 
	function.
	
	See md_tools.sh for a use of this stylesheet.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi"
	xmlns:mdui="urn:oasis:names:tc:SAML:metadata:ui">

	<!-- Output is plain text -->
	<xsl:output method="text"/>

	<xsl:template match="/md:EntityDescriptor">
	
		<!-- the entityID -->
		<xsl:value-of select="./@entityID"/>	
		<xsl:text>&#x09;</xsl:text>
		
		<!-- the MDUI DisplayName -->
		<xsl:value-of select="normalize-space(./md:IDPSSODescriptor/md:Extensions/mdui:UIInfo/mdui:DisplayName[@xml:lang='en'])"/>
		<xsl:text>&#x09;</xsl:text>
		
		<!-- the OrganizationName and OrganizationDisplayName -->
		<xsl:value-of select="normalize-space(./md:Organization/md:OrganizationName[@xml:lang='en'])"/>
		<xsl:text>&#x09;</xsl:text>
		<xsl:value-of select="normalize-space(./md:Organization/md:OrganizationDisplayName[@xml:lang='en'])"/>
		<xsl:text>&#x09;</xsl:text>
		
		<!-- the registrationAuthority (aka registrarID) -->
		<xsl:value-of select="./md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority"/>
		<xsl:text>&#x0a;</xsl:text>
		
	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
