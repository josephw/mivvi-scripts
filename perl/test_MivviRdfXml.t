#!/usr/bin/perl -w

use strict;

use Test::More(tests => 3);
use Mivvi::RdfXml;

# We should split namespaces for RDF/XML
is_deeply([Mivvi::RdfXml::splitNsUri('a:b')], ['a:', 'b'], 'Opaque URIs should be split');
is_deeply([Mivvi::RdfXml::splitNsUri('http://a/#x')], ['http://a/#', 'x'], 'Fragment URIs should be split');
is_deeply([Mivvi::RdfXml::splitNsUri('http://a/x')], ['http://a/', 'x'], 'Path URIs should be split');
