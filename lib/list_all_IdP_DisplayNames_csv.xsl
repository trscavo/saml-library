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
	list_all_IdP_DisplayNames_csv.xsl
	
	This XSL transform takes a SAML metadata aggregate and produces a list of
	IdP DisplayNames as would be seen on a typical discovery interface. The script 
	matches on every entity descriptor with an IdP role and produces a CSV file 
	with the following fields:
	
	  1. IdP Display Name: mdui:DisplayName or md:OrganizationDisplayName (in that order)
	  2. IdP Entity ID: @entityID
	  3. IdP Discovery: "hide" or "show"
	  4. Registrar ID: @registrationAuthority
	
	The IdP Display Name field is set to "NONE" if neither mdui:DisplayName nor 
	md:OrganizationDisplayName exist in the entity descriptor. The IdP Discovery 
	field depends on the presence (resp., absence) of the hide-from-discovery 
	entity attribute.
	
	BUG: Incorrectly processes an entity with multiple IDPSSODescriptor elements
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdattr="urn:oasis:names:tc:SAML:metadata:attribute"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi"
	xmlns:mdui="urn:oasis:names:tc:SAML:metadata:ui"
	xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">
	
	<!-- search-and-replace constants -->
	<xsl:variable name="double_quote" select="'&quot;'"/>
	<xsl:variable name="double_double_quote" select="'&quot;&quot;'"/>

	<!-- output is plain text -->
	<xsl:output method="text"/>

	<!-- output the heading line -->
	<xsl:template match="/">
		<xsl:text>IdP Display Name,IdP Entity ID,IdP Discovery,Registrar ID</xsl:text>
		<xsl:text>&#x0a;</xsl:text>
		<xsl:apply-templates/>
	</xsl:template>

	<!-- match all entity descriptors with an IdP role -->
	<xsl:template match="//md:EntityDescriptor[md:IDPSSODescriptor]">
	
		<!-- compute the normalized values of mdui:DisplayName and md:OrganizationDisplayName -->
		<xsl:variable name="displayName" select="normalize-space(md:IDPSSODescriptor/md:Extensions/mdui:UIInfo/mdui:DisplayName[@xml:lang='en'])"/>
		<xsl:variable name="orgDisplayName" select="normalize-space(md:Organization/md:OrganizationDisplayName[@xml:lang='en'])"/>
		
		<!-- output either mdui:DisplayName or md:OrganizationDisplayName or "NONE" (in that order) -->
		<xsl:choose>
			<xsl:when test="$displayName != ''">
				<!-- escape literal double quotes in mdui:DisplayName -->
				<xsl:variable name="escapedDisplayName">
					<xsl:call-template name="string-replace-all">
						<xsl:with-param name="string" select="$displayName"/>
						<xsl:with-param name="search" select="$double_quote"/>
						<xsl:with-param name="replace" select="$double_double_quote"/>
					</xsl:call-template>
				</xsl:variable>
				<xsl:text>"</xsl:text>
				<xsl:value-of select="$escapedDisplayName"/>
				<xsl:text>"</xsl:text>
			</xsl:when>
			<xsl:when test="$orgDisplayName != ''">
				<!-- escape literal double quotes in md:OrganizationDisplayName -->
				<xsl:variable name="escapedOrgDisplayName">
					<xsl:call-template name="string-replace-all">
						<xsl:with-param name="string" select="$orgDisplayName"/>
						<xsl:with-param name="search" select="$double_quote"/>
						<xsl:with-param name="replace" select="$double_double_quote"/>
					</xsl:call-template>
				</xsl:variable>
				<xsl:text>"</xsl:text>
				<xsl:value-of select="$escapedOrgDisplayName"/>
				<xsl:text>"</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text>NONE</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
		
		<!-- output the IdP entityID -->
		<xsl:text>,</xsl:text>
		<xsl:value-of select="@entityID"/>
		
		<!-- output "hide" or "show" depending on the hide-from-discovery entity attribute -->
		<xsl:text>,</xsl:text>
		<xsl:choose>
			<xsl:when test="md:Extensions/mdattr:EntityAttributes/saml:Attribute[@Name='http://macedir.org/entity-category']/saml:AttributeValue[text()='http://refeds.org/category/hide-from-discovery']">
				<xsl:text>hide</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text>show</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
		
		<!-- output the registrar ID -->
		<xsl:text>,</xsl:text>
		<xsl:value-of select="md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority"/>
		
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
