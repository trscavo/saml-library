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
	list_all_entity_endpoints_txt.xsl
	
	This XSL transform takes a SAML V2.0 metadata file as input. The
	script matches on every md:EntityDescriptor element in the input. 
	It then flattens all endpoints in the metadata file by returning lines 
	of output consisting of the following tab-separated fields:
	
	  roleDescriptor endpointType binding location entityID registrarID
	
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
	which case the endpoint is a so-called IdP SSO Service endpoint.
	
	Given a metadata file, the script is invoked as follows:
	
	$ md_path=/path/to/saml-metadata.xml
	$ xsl_path=/path/to/list_all_entity_endpoints_txt.xsl
	$ xsltproc $xsl_path $md_path > /tmp/metadata-endpoints.txt
	
	To illustrate usage, the output of the script may be used to produce a list 
	of redundant endpoints. The following command checks the non-indexed 
	endpoints in the output file for duplicates:
	
	$ cat /tmp/metadata-endpoints.txt \
	   | grep -E ' (SingleSignOnService|SingleLogoutService|AttributeService) ' \
	   | cut -f2,3,5,6 \
	   | sort | uniq -d
	
	Every tuple in the above list indicates a redundant endpoint type but 
	some entities have more than one type of redundant endpoint. To count 
	the number of entities with at least one redundant endpoint, we take the 
	previous computation one step further:
	
	$ cat /tmp/metadata-endpoints.txt \
	   | grep -E ' (SingleSignOnService|SingleLogoutService|AttributeService) ' \
	   | cut -f2,3,5,6 \
	   | sort | uniq -d \
	   | cut -f3 \
	   | sort | uniq \
	   | wc -l
	
	Finally, the following command lists the number of entities (per registrar) 
	with at least one redundant endpoint:

	$ cat /tmp/metadata-endpoints.txt \
	   | grep -E ' (SingleSignOnService|SingleLogoutService|AttributeService) ' \
	   | cut -f2,3,5,6 \
	   | sort | uniq -d \
	   | cut -f3,4 \
	   | sort | uniq \
	   | cut -f2 \
	   | sort | uniq -c
	
	Another type of redundant endpoint is the SAML2 AttributeService
	endpoint. If an IdP always pushes attributes on the front channel, which
	is typical, a back-channel AttributeService endpoint is redundant and
	often leads to usability or interoperability issues. 
	
	The first endpoint below is redundant in the presence of either of the 
	other two:
		
	$ e1='AttributeAuthorityDescriptor AttributeService urn:oasis:names:tc:SAML:2.0:bindings:SOAP'
	$ e2='IDPSSODescriptor SingleSignOnService urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'
	$ e3='IDPSSODescriptor SingleSignOnService urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST'
	
	The following command assembles all the necessary endpoints, removes 
	duplicates, and then counts the number of entities with a redundant 
	SAML2 AttributeService endpoint:
	
	$ cat /tmp/edugain-endpoints.txt \
	  | grep -E "^($e1|$e2|$e3) " \
	  | cut -f1,5 \
	  | sort | uniq \
	  | cut -f2 \
	  | sort | uniq -d \
	  | wc -l
	
	Note that this script lists both indexed and non-indexed endpoints.
	To list indexed endpoints only, and to include the index value in
	the output, use: list_all_entity_endpoints_indexed_txt.xsl
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi"
	xmlns:idpdisc="urn:oasis:names:tc:SAML:profiles:SSO:idp-discovery-protocol"
	xmlns:init="urn:oasis:names:tc:SAML:profiles:SSO:request-init">

	<!-- output is plain text -->
	<xsl:output method="text"/>

	<xsl:template match="//md:EntityDescriptor">
	
		<xsl:variable name="entityID" select="./@entityID"/>
		<xsl:variable name="registrarID" select="./md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority"/>

		<xsl:for-each select="./md:IDPSSODescriptor">
			<xsl:for-each select="./md:SingleSignOnService">
				<xsl:text>IDPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>SingleSignOnService</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:SingleLogoutService">
				<xsl:text>IDPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>SingleLogoutService</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:ArtifactResolutionService">
				<xsl:text>IDPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>ArtifactResolutionService</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

		<xsl:for-each select="./md:SPSSODescriptor">
			<xsl:for-each select="./md:AssertionConsumerService">
				<xsl:text>SPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>AssertionConsumerService</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:SingleLogoutService">
				<xsl:text>SPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>SingleLogoutService</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:ArtifactResolutionService">
				<xsl:text>SPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>ArtifactResolutionService</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:Extensions/idpdisc:DiscoveryResponse">
				<xsl:text>SPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>DiscoveryResponse</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
			<xsl:for-each select="./md:Extensions/init:RequestInitiator">
				<xsl:text>SPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>RequestInitiator</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

		<xsl:for-each select="./md:AttributeAuthorityDescriptor">
			<xsl:for-each select="./md:AttributeService">
				<xsl:text>AttributeAuthorityDescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:text>AttributeService</xsl:text>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Binding"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="./@Location"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
