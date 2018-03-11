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
	retain_entities_with_idp_role.xsl
	
	An XSL transform that takes a SAML V2.0 metadata file as input.
	The metadata file is assumed to be an aggregate of entities, that is, 
	the root element of the document is an md:EntitiesDescriptor element.
	The script then filters the input, retaining any entity that contains
	an md:IDPSSODescriptor child element in the output. If a particular 
	entity in the input does not contain an md:IDPSSODescriptor, the 
	entire entity is filtered.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
	
	<!-- the identity transformation -->
	<xsl:template match="@* | node()">
		<xsl:copy>
			<xsl:apply-templates select="@* | node()"/>
		</xsl:copy>
	</xsl:template>

	<!-- remove the ds.signature -->
	<xsl:template match="md:EntitiesDescriptor/ds:Signature"/>

	<!-- remove all entities that do not contain an md:IDPSSODescriptor -->
	<xsl:template match="md:EntityDescriptor[not(md:IDPSSODescriptor)]"/>
</xsl:stylesheet>
