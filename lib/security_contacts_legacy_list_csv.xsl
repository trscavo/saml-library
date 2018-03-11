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
	security_contacts_legacy_list_csv.xsl
	
	This XSL transform takes a SAML metadata aggregate, matches on every 
	entity descriptor containing a legacy security contact, and produces 
	a CSV file with the following fields:
	
	  1. Organization Name: md:OrganizationName[@xml:lang='en']
	  2. Display Name: mdui:DisplayName[@xml:lang='en']
	  3. Entity ID: @entityID
	  4. Role: "IdP" or "SP"
	
	Since all entities are registered by InCommon, all fields are nonempty
	and well defined. In particular, every entity has either an IdP role 
	or an SP role but not both.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdui="urn:oasis:names:tc:SAML:metadata:ui"
	xmlns:icmd="http://id.incommon.org/metadata">

	<!-- search-and-replace constants -->
	<xsl:variable name="double_quote" select="'&quot;'"/>
	<xsl:variable name="double_double_quote" select="'&quot;&quot;'"/>

	<!-- output is plain text -->
	<xsl:output method="text"/>

	<!-- output the heading line -->
	<xsl:template match="/">
	  <xsl:text>Organization Name,Display Name,Entity ID,Role</xsl:text>
	  <xsl:text>&#x0a;</xsl:text>
	  <xsl:apply-templates/>
	</xsl:template>

	<!-- match all entity descriptors with a legacy security contact -->
	<xsl:template match="
		/md:EntitiesDescriptor/md:EntityDescriptor[
			md:ContactPerson[
				@contactType='other' 
				and 
				@icmd:contactType='http://id.incommon.org/metadata/contactType/security'
			]
		]
	">
		
		<!-- compute the normalized value of md:OrganizationName -->
		<xsl:variable name="orgName" select="normalize-space(md:Organization/md:OrganizationName[@xml:lang='en'])"/>
		
		<!-- escape literal double quotes in md:OrganizationName -->
		<xsl:variable name="escapedOrgName">
			<xsl:call-template name="string-replace-all">
				<xsl:with-param name="string" select="$orgName"/>
				<xsl:with-param name="search" select="$double_quote"/>
				<xsl:with-param name="replace" select="$double_double_quote"/>
			</xsl:call-template>
		</xsl:variable>
		
		<!-- output md:OrganizationName -->
		<xsl:text>"</xsl:text>
		<xsl:value-of select="$escapedOrgName"/>
		<xsl:text>"</xsl:text>
		
		<!-- compute the normalized value of mdui:DisplayName -->
		<xsl:variable name="displayName" select="normalize-space(descendant::mdui:UIInfo/mdui:DisplayName[@xml:lang='en'])"/>

		<!-- escape literal double quotes in mdui:DisplayName -->
		<xsl:variable name="escapedDisplayName">
			<xsl:call-template name="string-replace-all">
				<xsl:with-param name="string" select="$displayName"/>
				<xsl:with-param name="search" select="$double_quote"/>
				<xsl:with-param name="replace" select="$double_double_quote"/>
			</xsl:call-template>
		</xsl:variable>
		
		<!-- output mdui:DisplayName -->
		<xsl:text>,"</xsl:text>
		<xsl:value-of select="$escapedDisplayName"/>
		<xsl:text>"</xsl:text>

		<!-- output the entityID -->
		<xsl:text>,</xsl:text>
		<xsl:value-of select="@entityID"/>

		<!-- output the role -->
		<xsl:text>,</xsl:text>
		<xsl:choose>
			<xsl:when test="md:IDPSSODescriptor">
				<xsl:text>IdP</xsl:text>
			</xsl:when>
			<xsl:when test="md:SPSSODescriptor">
				<xsl:text>SP</xsl:text>
			</xsl:when>
		</xsl:choose>
		
		<xsl:text>&#x0a;</xsl:text>
	</xsl:template>
	
	<!-- 
		A named template that performs global (recursive) search-and-replace on a string
		(similar to fn:replace(string, pattern, replace) in XSLT 2.0).
		See: http://stackoverflow.com/questions/3067113/xslt-string-replace/3067130#3067130
	-->
	<xsl:template name="string-replace-all">
		<xsl:param name="string"/>
		<xsl:param name="search"/>
		<xsl:param name="replace"/>
		<xsl:choose>
			<xsl:when test="$string = '' or $search = '' or not($search)">
				<!-- Prevent this routine from hanging -->
				<xsl:value-of select="$string"/>
			</xsl:when>
			<xsl:when test="contains($string, $search)">
				<xsl:value-of select="substring-before($string, $search)"/>
				<xsl:value-of select="$replace"/>
				<xsl:call-template name="string-replace-all">
					<xsl:with-param name="string" select="substring-after($string, $search)"/>
					<xsl:with-param name="search" select="$search"/>
					<xsl:with-param name="replace" select="$replace"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$string"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
