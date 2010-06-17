#!/bin/sh

# Tidying with intent to XSLT

tidy - --output-xhtml yes --output-encoding utf8 --force-output yes --add-xml-decl yes --doctype omit --numeric-entities yes 2>/dev/null
exit 0
