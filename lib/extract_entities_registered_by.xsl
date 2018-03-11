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
	extract_entities_registered_by.xsl
	
	An XSL transform that takes a SAML V2.0 metadata file and 
	a stringparam (registrarID) on the command line. The metadata
	file is assumed to be an aggregate of entities, that is, 
	the root element is the md:EntitiesDescriptor element.
	The scripts then extracts all entities registered by the given
	registrar from the aggregate.
	
	See md_tools.sh for a use of this stylesheet.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi"
	xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
	
	<xsl:param name="registrarID" required="yes"/>

	<!-- the identity transformation -->
	<xsl:template match="@* | node()">
		<xsl:copy>
			<xsl:apply-templates select="@* | node()"/>
		</xsl:copy>
	</xsl:template>

	<!-- remove the ds.signature -->
	<xsl:template match="md:EntitiesDescriptor/ds:Signature"/>

	<xsl:template match="md:EntitiesDescriptor/md:EntityDescriptor">
		<xsl:copy-of select="[md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority=$registrarID]"/>
	</xsl:template>

</xsl:stylesheet>
