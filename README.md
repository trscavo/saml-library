# SAML Library

Useful scripts for SAML developers

## Overview

The SAML Library includes the following features:

* implements an HTTP conditional request ([RFC 7232](https://tools.ietf.org/html/rfc7232)) client for SAML metadata
* implements various filters that can be used to build a SAML metadata pipeline
* implements a client for the [Metadata Query Protocol](https://github.com/iay/md-query)
* implements an HTTP extension to the bash xsltproc command-line tool
* provides numerous XSLT scripts for SAML metadata
* provides tools that support the Shibboleth [LocalDynamicMetadataProvider](https://wiki.shibboleth.net/confluence/x/hYGNAQ)
* monitors the life cycle of a SAML metadata resource

## Installation

Install the [Bash Library](https://github.com/trscavo/bash-library) before installing the scripts in this repository.

Download the SAML Library source, change directory to the source directory, and install the source on top of the Bash Library as follows:

```Shell
$ ./install.sh $BIN_DIR $LIB_DIR
```

The following commands confirm that the files were installed:

```Shell
$ ls -1 $BIN_DIR | head -n 5
cget.bash
chead.bash
http_cache_check.bash
http_cache_diff.bash
http_cache_file.bash

$ ls -1 $LIB_DIR | head -n 5
add_validUntil_attribute.xsl
compatible_date.bash
config_tools.bash
core_lib.bash
entity_endpoints_txt.xsl
```

The `BIN_DIR` and `LIB_DIR` directories will contain files from both libraries.

## Environment

The SAML Library requires the same environment variables as the [Bash Library](https://github.com/trscavo/bash-library).

## Compatibility

The shell scripts are compatible with both GNU/Linux and Mac OS. The XSLT scripts are written in XSLT 1.0.

## Dependencies

The SAML Library depends on the [Bash Library](https://github.com/trscavo/bash-library).
