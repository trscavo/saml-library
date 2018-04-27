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
	list_all_entity_attributes_txt.xsl
	
	An XSL transform that takes a SAML V2.0 metadata file and 
	produces a flattened list of all entity attributes in plain text.
	
	Usage:
	$ md_path=/path/to/saml-metadata.xml
	$ xsl_path=/path/to/list_all_entity_attributes_txt.xsl
	$ xsltproc $xsl_path $md_path > /tmp/entity-attributes.txt
	
	The output is a text file with lines consisting of the following 
	tab-separated fields:
	
	  entityAttributeName entityAttributeNameFormat entityAttributeValue entityID registrarID
	
	Note that an entity attribute may be multi-valued, in which case
	there is one line of output for each entity attribute value with
	the given name.
	
	Note: According to the Entity Attributes specification, [1] any 
	given entity descriptor may have at most one mdattr:EntityAttributes
	element and therefore this script processes the first such element
	(if any) and simply ignores any redundant mdattr:EntityAttributes 
	elements.

	For example, the following command line summarizes the entity 
	attributes in metadata, taken over all possible combinations of
	Name and NameFormat:
	
	$ cat /tmp/entity-attributes.txt | cut -f1,2 | sort | uniq -c
	
	One can drill down further as desired. For example, the following 
	command line gives the distribution of all possible entity attribute 
	values for a particular pair of Name and NameFormat values, namely,
	the so-called SAML entity category [2]:
	
	$ entityAttributeName=http://macedir.org/entity-category
	$ entityAttributeNameFormat=urn:oasis:names:tc:SAML:2.0:attrname-format:uri
	$ cat /tmp/entity-attributes.txt \
	   | grep "^$entityAttributeName\t$entityAttributeNameFormat\t" \
	   | cut -f3 \
	   | sort | uniq -c \
	   | sort -nr -k 1
	
	Similarly, the following command gives the distribution of a
	particular entity attribute value (i.e., the REFEDS Research and
	Scholarship entity category [3]) across all federations:
	
	$ entityAttributeValue=http://refeds.org/category/research-and-scholarship
	$ cat /tmp/entity-attributes.txt \
	   | grep "^$entityAttributeName\t$entityAttributeNameFormat\t" \
	   | grep "\t$entityAttributeValue\t" \
	   | cut -f5 \
	   | sort | uniq -c \
	   | sort -nr -k 1
	
	References:
	[1] https://wiki.oasis-open.org/security/SAML2MetadataAttr
	[2] https://datatracker.ietf.org/doc/draft-young-entity-category/
	[3] http://refeds.org/category/research-and-scholarship
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdattr="urn:oasis:names:tc:SAML:metadata:attribute"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi"
	xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">

	<!-- Output is plain text -->
	<xsl:output method="text"/>

	<!-- match on every entity descriptor -->
	<xsl:template match="//md:EntityDescriptor">
	
		<xsl:variable name="entityID" select="./@entityID"/>
		<xsl:variable name="registrarID" select="./md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority"/>

		<!-- for each entity attribute -->
		<xsl:for-each select="./md:Extensions/mdattr:EntityAttributes[position() = 1]/saml:Attribute">
		
			<xsl:variable name="entityAttributeName" select="./@Name"/>
			<xsl:variable name="entityAttributeNameFormat" select="./@NameFormat"/>
			
			<!-- for each entity attribute value -->
			<xsl:for-each select="./saml:AttributeValue">
				<xsl:value-of select="$entityAttributeName"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$entityAttributeNameFormat"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="."/>
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
