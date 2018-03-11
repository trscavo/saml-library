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
	parse_ds_signature_txt.xsl
	
	An XSL transform that takes certain types of SAML V2.0 documents as
	input, namely, documents with an optional ds:Signature child element.
	IF the top-level element of the XML document is either an 
	md:EntityDescriptor element or an md:EntitiesDescriptor element, the 
	script parses the input and returns one or more lines of output as 
	described below. If the input document is not a well-formed XML document, 
	or the document has an unexpected top-level element, this script returns 
	no output whatsoever.
	
	The result of calling fn:local-name() on the top-level element is 
	always included in the output:
	
	  EntityDescriptor|EntitiesDescriptor|Assertion
	
	The following line will be included in the output if the input document 
	is signed:
	
	  ID ./@ID
	
	The following lines will be included in the output if (and only if)
	the input document is signed:
	
	  ReferenceURI ./ds:Signature/ds:SignedInfo/ds:Reference/@URI
	  CanonicalizationMethod ./ds:Signature/ds:SignedInfo/ds:CanonicalizationMethod/@Algorithm
	  SignatureMethod ./ds:Signature/ds:SignedInfo/ds:SignatureMethod/@Algorithm
	  DigestMethod ./ds:Signature/ds:SignedInfo/ds:Reference/ds:DigestMethod/@Algorithm
	
	Name-value pairs on a line are tab-separated. The order of output 
	lines is unspecified.
	
	TODO: Other SAML documents (such as saml:Assertion) have an
	      optional ds:Signature child element
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
	xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
	
	<!-- output is plain text -->
	<xsl:output method="text"/>

	<!-- match one of the desired top-level elements -->
	<xsl:template match="/md:EntitiesDescriptor | /md:EntityDescriptor">
	
		<!-- indicate the local-name of the actual top-level element -->
		<xsl:value-of select="local-name(.)"/>			
		<xsl:text>&#x0a;</xsl:text>
		
		<!-- if the document is signed, the @ID will be non-null -->
		<xsl:variable name="docID" select="./@ID"/>
		<xsl:if test="$docID != ''">
			<xsl:text>ID</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="$docID"/>
			<xsl:text>&#x0a;</xsl:text>
		</xsl:if>

		<!-- if the document is signed, the @URI will be bound to the @ID -->
		<xsl:variable name="referenceURI" select="./ds:Signature/ds:SignedInfo/ds:Reference/@URI"/>
		<xsl:if test="$referenceURI = concat('#', $docID)">
			<xsl:text>ReferenceURI</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="$referenceURI"/>
			<xsl:text>&#x0a;</xsl:text>

			<xsl:text>CanonicalizationMethod</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="./ds:Signature/ds:SignedInfo/ds:CanonicalizationMethod/@Algorithm"/>
			<xsl:text>&#x0a;</xsl:text>

			<xsl:text>SignatureMethod</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="./ds:Signature/ds:SignedInfo/ds:SignatureMethod/@Algorithm"/>
			<xsl:text>&#x0a;</xsl:text>

			<xsl:text>DigestMethod</xsl:text>
			<xsl:text>&#x09;</xsl:text>
			<xsl:value-of select="./ds:Signature/ds:SignedInfo/ds:Reference/ds:DigestMethod/@Algorithm"/>
			<xsl:text>&#x0a;</xsl:text>
		</xsl:if>
		
	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
