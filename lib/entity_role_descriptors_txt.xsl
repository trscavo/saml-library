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
	entity_role_descriptors_txt.xsl
	
	This XSL transform takes a SAML V2.0 metadata file as input. The script
	matches on the top-level md:EntityDescriptor element assumed to be in
	the input. It then flattens all role descriptors in the entity descriptor by 
	returning lines of output consisting of the following tab-separated fields:
	
	  RoleDescriptorType DisplayName lang
	
	where RoleDescriptorType is one of the following:
	
	  IDPSSODescriptor
	  SPSSODescriptor
	  AttributeAuthorityDescriptor
	  AuthnAuthorityDescriptor
	  PDPDescriptor
	
	The IDPSSODescriptor or the SPSSODescriptor may have multiple 
	DisplayNames, in multiple languages. The use of mdui:DisplayName
	with the other role descriptors is unspecified.
	
	TODO: Capture additional MDUI Info?
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdui="urn:oasis:names:tc:SAML:metadata:ui">

	<!-- output is plain text -->
	<xsl:output method="text"/>

	<xsl:template match="/md:EntityDescriptor">
	
		<xsl:for-each select="./md:IDPSSODescriptor">
			<xsl:for-each select="./md:Extensions/mdui:UIInfo/mdui:DisplayName">
				<xsl:text>IDPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="normalize-space(.)"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@xml:lang"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

		<xsl:for-each select="./md:SPSSODescriptor">
			<xsl:for-each select="./md:Extensions/mdui:UIInfo/mdui:DisplayName">
				<xsl:text>SPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="normalize-space(.)"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@xml:lang"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

		<xsl:for-each select="./md:AttributeAuthorityDescriptor">
			<xsl:text>AttributeAuthorityDescriptor</xsl:text>
			<xsl:text>&#09;</xsl:text>
			<xsl:text>&#09;</xsl:text>
			<xsl:text>&#10;</xsl:text>
		</xsl:for-each>

		<xsl:for-each select="./md:AuthnAuthorityDescriptor">
			<xsl:text>AuthnAuthorityDescriptor</xsl:text>
			<xsl:text>&#09;</xsl:text>
			<xsl:text>&#09;</xsl:text>
			<xsl:text>&#10;</xsl:text>
		</xsl:for-each>

		<xsl:for-each select="./md:PDPDescriptor">
			<xsl:text>PDPDescriptor</xsl:text>
			<xsl:text>&#09;</xsl:text>
			<xsl:text>&#09;</xsl:text>
			<xsl:text>&#10;</xsl:text>
		</xsl:for-each>

	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
