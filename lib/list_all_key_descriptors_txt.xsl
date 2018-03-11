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
	list_all_key_descriptors_txt.xsl
	
	This XSL transform takes a SAML V2.0 metadata file as input. The
	script matches on every md:EntityDescriptor element in the input. 
	It then flattens all key descriptors in the entity descriptor by returning 
	lines of output consisting of the following tab-separated fields:
	
	  roleDescriptor keyUse entityID registrarID
	
	where roleDescriptor is one of the following:
	
	  IDPSSODescriptor
	  SPSSODescriptor
	  AttributeAuthorityDescriptor
	
	and keyUse is either "signing", "encryption", or "multi-use".
	The latter indicates that there is no 'use' XML attribute on the
	corresponding md:KeyDescriptor element.
	
	Note: A KeyDescriptor with no 'use' XML attribute is equivalent to 
	two KeyDescriptors, one with use="signing" and the other with 
	use="encryption", both with exactly the same content. That is, one 
	key may be used for multiple purposes.
	
	Given a metadata file, the script is invoked as follows:
	
	$ md_path=/path/to/saml-metadata.xml
	$ xsl_path=/path/to/list_all_key_descriptors_txt.xsl
	$ xsltproc $xsl_path $md_path > /tmp/key_descriptors.txt
	
	The following command line lists the number of KeyDescriptors per
	role descriptor:
	
	$ cat /tmp/key_descriptors.txt \
	  | cut -f1 \
	  | sort | uniq -c
	
	The following command line gives the distribution of the number of
	KeyDescriptors per role descriptor:
	
	$ cat /tmp/key_descriptors.txt \
	  | cut -f1,3 \
	  | sort | uniq -c \
	  | sed -e 's/^ *//' \
	  | cut -f1,2 \
	  | sort | uniq -c
	
	The above command will identify those entities with excessive numbers
	of KeyDescriptors. For example, the following command line lists the
	entities that have 4 KeyDescriptors in a single role descriptor:
	
	$ cat /tmp/key_descriptors.txt \
	  | cut -f1,3 \
	  | sort | uniq -c \
	  | grep '^ *4 '
	
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi">

	<!-- output is plain text -->
	<xsl:output method="text"/>

	<xsl:template match="//md:EntityDescriptor">
	
		<xsl:variable name="entityID" select="./@entityID"/>
		<xsl:variable name="registrarID" select="./md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority"/>

		<xsl:for-each select="./md:IDPSSODescriptor">
			<xsl:for-each select="./md:KeyDescriptor">
				<xsl:text>IDPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				
				<xsl:choose>
					<xsl:when test="./@use='signing'">
						<xsl:text>signing</xsl:text>
					</xsl:when>
					<xsl:when test="./@use='encryption'">
						<xsl:text>encryption</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>multi-use</xsl:text>
					</xsl:otherwise>
				</xsl:choose>			
				<xsl:text>&#09;</xsl:text>
				
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

		<xsl:for-each select="./md:SPSSODescriptor">
			<xsl:for-each select="./md:KeyDescriptor">
				<xsl:text>SPSSODescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				
				<xsl:choose>
					<xsl:when test="./@use='signing'">
						<xsl:text>signing</xsl:text>
					</xsl:when>
					<xsl:when test="./@use='encryption'">
						<xsl:text>encryption</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>multi-use</xsl:text>
					</xsl:otherwise>
				</xsl:choose>			
				<xsl:text>&#09;</xsl:text>
				
				<xsl:value-of select="$entityID"/>
				<xsl:text>&#09;</xsl:text>
				<xsl:value-of select="$registrarID"/>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>

		<xsl:for-each select="./md:AttributeAuthorityDescriptor">
			<xsl:for-each select="./md:KeyDescriptor">
				<xsl:text>AttributeAuthorityDescriptor</xsl:text>
				<xsl:text>&#09;</xsl:text>
				
				<xsl:choose>
					<xsl:when test="./@use='signing'">
						<xsl:text>signing</xsl:text>
					</xsl:when>
					<xsl:when test="./@use='encryption'">
						<xsl:text>encryption</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>multi-use</xsl:text>
					</xsl:otherwise>
				</xsl:choose>			
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
