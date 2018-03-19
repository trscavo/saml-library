<?xml version="1.0" encoding="UTF-8"?>
<!--
	Copyright 2018 Tom Scavo

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
	remove_NameIDFormat.xsl
	
	This XSL transform takes a SAML V2.0 metadata document as input.
	If the top-level element is md:EntityDescriptor, the script 
	removes all descendant md:NameIDFormat elements from the entity
	descriptor.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata">
	
	<!-- the identity transformation -->
	<xsl:template match="@* | node()">
		<xsl:copy>
			<xsl:apply-templates select="@* | node()"/>
		</xsl:copy>
	</xsl:template>

	<!-- remove all md:NameIDFormat elements from the top-level md:EntityDescriptor element -->
	<xsl:template match="/md:EntityDescriptor[md:SPSSODescriptor | md:IDPSSODescriptor | md:AttributeAuthorityDescriptor | md:AuthnAuthorityDescriptor | md:PDPDescriptor]//md:NameIDFormat"/>
</xsl:stylesheet>
