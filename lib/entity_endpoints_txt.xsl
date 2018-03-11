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
	entity_endpoints_txt.xsl
	
	An XSL transform that takes a SAML V2.0 metadata file as input.
	The root element of the metadata file is an md:EntityDescriptor 
	element. The script flattens entity endpoints by returning one 
	or more lines of output of the form:
	
	  roleDescriptor endpointType binding location
	
	where roleDescriptor is one of the following:
	
	  IDPSSODescriptor
	  SPSSODescriptor
	  AttributeAuthorityDescriptor
	
	and endpointType indicates the type of endpoint:
	
	  SingleSignOnService
	  SingleLogoutService
	  ArtifactResolutionService
	  AssertionConsumerService
	  DiscoveryResponse
	  RequestInitiator
	  AttributeService
	
	For example, the roleDescriptor and the endpointType might be 
	'IDPSSODescriptor' and 'SingleSignOnService', respectively, in 
	which case the endpoint is a so-called IdP SSO endpoint.
	
	See md_tools.sh for a use of this stylesheet.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi"
	xmlns:idpdisc="urn:oasis:names:tc:SAML:profiles:SSO:idp-discovery-protocol"
	xmlns:init="urn:oasis:names:tc:SAML:profiles:SSO:request-init">

	<!-- output is plain text -->
	<xsl:output method="text"/>

	<xsl:template match="/md:EntityDescriptor">
	
		<xsl:for-each select="./md:IDPSSODescriptor">
			<xsl:for-each select="./md:SingleSignOnService">
				<xsl:text>IDPSSODescriptor SingleSignOnService </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:SingleLogoutService">
				<xsl:text>IDPSSODescriptor SingleLogoutService </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:ArtifactResolutionService">
				<xsl:text>IDPSSODescriptor ArtifactResolutionService </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

		<xsl:for-each select="./md:SPSSODescriptor">
			<xsl:for-each select="./md:AssertionConsumerService">
				<xsl:text>SPSSODescriptor AssertionConsumerService </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:SingleLogoutService">
				<xsl:text>SPSSODescriptor SingleLogoutService </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:ArtifactResolutionService">
				<xsl:text>SPSSODescriptor ArtifactResolutionService </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:Extensions/idpdisc:DiscoveryResponse">
				<xsl:text>SPSSODescriptor DiscoveryResponse </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:Extensions/init:RequestInitiator">
				<xsl:text>SPSSODescriptor RequestInitiator </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

		<xsl:for-each select="./md:AttributeAuthorityDescriptor">
			<xsl:for-each select="./md:AttributeService">
				<xsl:text>AttributeAuthorityDescriptor AttributeService </xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text> </xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
