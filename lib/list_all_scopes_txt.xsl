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
	list_all_scopes_txt.xsl
	
	This XSL transform takes a SAML V2.0 metadata file as input. The
	script matches on every md:EntityDescriptor element and iterates
	over any role descriptor that might contain an shibmd:Scope element.
	It then flattens all shibmd:Scope elements by returning lines of output 
	consisting of the following tab-separated fields:
	
	  roleDescriptor regexp scope entityID registrarID
	
	where roleDescriptor is one of the following:
	
	  IDPSSODescriptor
	  AttributeAuthorityDescriptor
	
	and regexp is the value (i.e., true or false) of the shibmd:Scope/@regexp 
	attribute and scope is a normalized value of the shibmd:Scope element.
	
	The content of the shibmd:Scope element is normalized by removing 
	leading and trailing whitespace. Consecutive spaces are collapsed into 
	a single space.
	
	Given a metadata file, the script is invoked as follows:
	
	$ md_path=/path/to/saml-metadata.xml
	$ xsl_path=/path/to/list_all_scopes_txt.xsl
	$ xsltproc $xsl_path $md_path > /tmp/metadata-scopes.txt
	
	The following command line lists all regex scope patterns:
	
	$ cat /tmp/metadata-scopes.txt \
	   | grep '\ttrue\t' \
	   | cut -f1,3-5
	
	From the SP's point of view, a regex scope is dangerous and should 
	be avoided.
	
	The following command line lists all invalid literal scope values:
	
	$ cat /tmp/metadata-scopes.txt \
	   | grep '\tfalse\t' \
	   | cut -f3-5 \
	   | sort | uniq \
	   | grep -Ev '^[[:alnum:]][[:alnum:]\.-]{0,126}\t'
	
	Simply remove the -v option on the previous grep command to obtain 
	the list of all valid literal scope values.
	
	The following command line lists all valid literal scope values with 
	an upper case letter:
	
	$ cat /tmp/metadata-scopes.txt \
	   | grep '\tfalse\t' \
	   | cut -f3-5 \
	   | sort | uniq \
	   | grep -E '^[[:alnum:]][[:alnum:]\.-]{0,126}\t' \
	   | grep -Ev '^[[:digit:][:lower:]][[:digit:][:lower:]\.-]{0,126}\t'
	
	Note that two scope values that differ by case only are equivalent,
	which may lead to access control errors at the SP.
	
	The following command line lists all literal scope values shared by
	two or more entities:
	
	$ cat /tmp/metadata-scopes.txt \
	   | grep '\tfalse\t' \
	   | cut -f3,4 \
	   | sort | uniq \
	   | cut -f1 \
	   | tr '[:upper:]' '[:lower:]' \
	   | sort | uniq -c \
	   | grep -v '^ *1 ' \
	   | sort
	
	It is legal for two entities to share a scope but every such case
	increases the risk of impersonation.
	
	The following command lists the entity (or entities) that contain
	the given literal scope value:
	
	$ scope=example.com
	$ cat /tmp/metadata-scopes.txt \
	   | grep '\tfalse\t' \
	   | cut -f3-5 \
	   | sort | uniq \
	   | grep "^$scope\t"

	In the very least, two entities with the same scope should be 
	registered by the same federation.
	
	The following command computes the distribution of the number of 
	literal scope values per entity (invalid scopes included):
	
	$ cat /tmp/metadata-scopes.txt \
	   | grep '\tfalse\t' \
	   | cut -f3-5 \
	   | sort | uniq \
	   | cut -f2 \
	   | sort | uniq -c \
	   | sed -e 's/^ *//' \
	   | cut -f1 -d" " \
	   | sort | uniq -c \
	   | sort -n -k 2
	
	In practice, the number of scope values per entity varies widely.
	
	Note: Inside a character class, a period (.) does not need to be escaped,
	and so technically the backslash (\.) inside some of the above character
	classes is superfluous. It is included for readability only.
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi"
	xmlns:shibmd="urn:mace:shibboleth:metadata:1.0">

	<!-- output is plain text -->
	<xsl:output method="text"/>

	<xsl:template match="//md:EntityDescriptor">
	
		<xsl:variable name="entityID" select="./@entityID"/>
		<xsl:variable name="registrarID" select="./md:Extensions/mdrpi:RegistrationInfo/@registrationAuthority"/>

		<xsl:for-each select="./md:IDPSSODescriptor/md:Extensions/shibmd:Scope">
			<xsl:text>IDPSSODescriptor</xsl:text>
			<xsl:text>&#09;</xsl:text>
			
			<xsl:choose>
				<xsl:when test="./@regexp='true' or ./@regexp='1'">
					<xsl:text>true</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>false</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:text>&#09;</xsl:text>
			
			<!-- output the normalized Scope value -->
			<xsl:value-of select="normalize-space(./text())"/>
			<xsl:text>&#09;</xsl:text>
			
			<!-- output the other values -->
			<xsl:value-of select="$entityID"/>
			<xsl:text>&#09;</xsl:text>
			<xsl:value-of select="$registrarID"/>
			<xsl:text>&#10;</xsl:text>
		</xsl:for-each>
		
		<xsl:for-each select="./md:AttributeAuthorityDescriptor/md:Extensions/shibmd:Scope">
			<xsl:text>AttributeAuthorityDescriptor</xsl:text>
			<xsl:text>&#09;</xsl:text>
			
			<xsl:choose>
				<xsl:when test="./@regexp='true' or ./@regexp='1'">
					<xsl:text>true</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>false</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:text>&#09;</xsl:text>
						
			<!-- output the normalized Scope value -->
			<xsl:value-of select="normalize-space(./text())"/>
			<xsl:text>&#09;</xsl:text>
			
			<!-- output the other values -->
			<xsl:value-of select="$entityID"/>
			<xsl:text>&#09;</xsl:text>
			<xsl:value-of select="$registrarID"/>
			<xsl:text>&#10;</xsl:text>
		</xsl:for-each>
		
	</xsl:template>

	<xsl:template match="text()">
		<!-- do nothing -->
	</xsl:template>
</xsl:stylesheet>
