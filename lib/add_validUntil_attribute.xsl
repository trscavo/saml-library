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
	add_validUntil_attribute.xsl
	
	TBD
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata">
	
	<xsl:param name="validUntil" required="yes"/>

	<!-- the identity transformation -->
	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()"/>
		</xsl:copy>
	</xsl:template>
	<!-- Does order matter?
	<xsl:template match="node()|@*">
		<xsl:copy>
			<xsl:apply-templates select="node()|@*"/>
		</xsl:copy>
	</xsl:template>
	-->

	<!-- match one of the desired top-level elements -->
	<xsl:template match="/md:EntitiesDescriptor | /md:EntityDescriptor">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
			<xsl:attribute name="validUntil">
				<xsl:value-of select="$validUntil"/>
			</xsl:attribute>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
	</xsl:template>

</xsl:stylesheet>
