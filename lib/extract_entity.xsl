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
	extract_entity.xsl
	
	An XSL transform that takes a SAML V2.0 metadata file and 
	a stringparam (entityID) on the command line. The metadata
	file is assumed to be an aggregate of entities, that is, 
	the root element is the md:EntitiesDescriptor element.
	The scripts then extracts the entity descriptor with the 
	given entityID from the aggregate.
	
	See md_tools.sh for a use of this stylesheet.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata">
	
	<xsl:param name="entityID" required="yes"/>
	
	<xsl:template match="/md:EntitiesDescriptor">
		<xsl:copy-of select="./md:EntityDescriptor[@entityID=$entityID]"/>
	</xsl:template>
</xsl:stylesheet>
