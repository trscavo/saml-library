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
	parse_signing_cert_pem.xsl
	
	An XSL transform that takes a SAML V2.0 metadata file as input. 
	As mandated by the SAML V2.0 Metadata specifcation, the top-level
	element of the document is either an md:EntitiesDescriptor element 
	or an md:EntityDescriptor element. In either case, if the top-level 
	element is signed, the script parses and returns the signing certificate 
	embedded in the XML signature.
	
	Note: If there is no signature on the top-level element, the script
	returns null. Even if there is a signature on the top-level element, 
	a certificate may or may not be embedded in the signature, in
	which case this script returns null.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
	
	<xsl:variable name="whitespace" select="'&#09;&#10;&#13; '" />

	<!-- output is plain text -->
	<xsl:output method="text"/>

	<!-- match one of the desired top-level elements -->
	<xsl:template match="/md:EntitiesDescriptor | /md:EntityDescriptor">
	
		<xsl:variable name="documentID" select="./@ID"/>
		<xsl:variable name="referenceURI" select="./ds:Signature/ds:SignedInfo/ds:Reference/@URI"/>
		
		<!-- the @URI must be bound to the @ID -->
		<xsl:if test="$referenceURI = concat('#', $documentID)">
		
			<xsl:variable name="cert" select="./ds:Signature/ds:KeyInfo/ds:X509Data/ds:X509Certificate"/>
			<xsl:if test="$cert != ''">
		
				<!-- PEM-encode the certificate -->
				<xsl:text>-----BEGIN CERTIFICATE-----</xsl:text>
				<xsl:text>&#x0a;</xsl:text>

				<!-- trim leading and trailing whitespace -->
				<xsl:call-template name="string-trim">
					<xsl:with-param name="string" select="$cert"/>
				</xsl:call-template>
				<xsl:text>&#x0a;</xsl:text>
			
				<xsl:text>-----END CERTIFICATE-----</xsl:text>
				<xsl:text>&#x0a;</xsl:text>
			</xsl:if>
		</xsl:if>
		
	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>

	<!-- 
		Trim whitespace functions for XSLT 1.0
		https://stackoverflow.com/questions/13974247/how-can-i-trim-space-in-xslt-without-replacing-repating-whitespaces-by-single-on
		
		Each of the templates below is recursive.
		The third template is dependent upon the previous two.
	-->

	<!-- Strips trailing whitespace characters from 'string' -->
	<xsl:template name="string-rtrim">
		<xsl:param name="string" />
		<xsl:param name="trim" select="$whitespace" />

		<xsl:variable name="length" select="string-length($string)" />

		<xsl:if test="$length &gt; 0">
			<xsl:choose>
				<xsl:when test="contains($trim, substring($string, $length, 1))">
					<xsl:call-template name="string-rtrim">
						<xsl:with-param name="string" select="substring($string, 1, $length - 1)" />
						<xsl:with-param name="trim"   select="$trim" />
					</xsl:call-template>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="$string" />
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>

	<!-- Strips leading whitespace characters from 'string' -->
	<xsl:template name="string-ltrim">
		<xsl:param name="string" />
		<xsl:param name="trim" select="$whitespace" />

		<xsl:if test="string-length($string) &gt; 0">
			<xsl:choose>
				<xsl:when test="contains($trim, substring($string, 1, 1))">
					<xsl:call-template name="string-ltrim">
						<xsl:with-param name="string" select="substring($string, 2)" />
						<xsl:with-param name="trim"   select="$trim" />
					</xsl:call-template>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="$string" />
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>

	<!-- Strips leading and trailing whitespace characters from 'string' -->
	<xsl:template name="string-trim">
		<xsl:param name="string" />
		<xsl:param name="trim" select="$whitespace" />
		<xsl:call-template name="string-rtrim">
			<xsl:with-param name="string">
				<xsl:call-template name="string-ltrim">
					<xsl:with-param name="string" select="$string" />
					<xsl:with-param name="trim"   select="$trim" />
				</xsl:call-template>
			</xsl:with-param>
			<xsl:with-param name="trim"   select="$trim" />
		</xsl:call-template>
	</xsl:template>

</xsl:stylesheet>
