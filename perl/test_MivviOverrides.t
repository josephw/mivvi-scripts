#!/usr/bin/perl -w

use strict;

use Test::More(tests => 33);
use Mivvi::Overrides;

my ($o, @l);

# Empty overrides behave
$o = Mivvi::Overrides->new();

@l = $o->getSourcesSameAs('http://www.example.com/#');
is_deeply(\@l, [], 'No sources sameAs in an empty Overrides');

@l = $o->getDescriptions('http://www.example.com/#');
is_deeply(\@l, [], 'No descriptions in an empty Overrides');

is($o->getTitle('http://www.example.com/#'), undef, 'No titles in an empty Overrides');
is($o->getDate('http://www.example.com/#'), undef, 'No dates in an empty Overrides');


# Load some data
$o->load('test_MivviOverrides_data.txt');

@l = $o->getSourcesSameAs('http://www.example.com/#');
is_deeply(\@l, ['http://www.example.com/old-uri#'], 'Sources sameAs taken from loaded file');

@l = $o->getDescriptions('http://www.example.com/#');
is_deeply(\@l, ['Alternate Description'], 'Single description taken from loaded file');

is($o->getTitle('http://www.example.com/#'), 'Overridden Title', 'Title taken from loaded file');
is($o->getDate('http://www.example.com/#'), '2000-01-01', 'Date taken from loaded file');


# Check for published URI loading
ok(not($o->isPublished('http://www.example.com/published#')), 'A published URI should not be known before loading URIs');
ok(not($o->isPublished('http://www.example.com/unpublished#')), 'An unpublished URI should not be known');

$o->loadPublishedUris('test_MivviOverrides_published.txt');

ok($o->isPublished('http://www.example.com/published#'), 'A published URI should be known after loading URIs');
ok(not($o->isPublished('http://www.example.com/unpublished#')), 'An unpublished URI should not be known');


# Load data from an XML file
$o->loadRdfXml('test_MivviOverrides_rdfxmlsample.rdf');
is($o->getTitle('http://www.example.com/3/#'), 'Title in RDF/XML', 'Title should be taken from parsed RDF/XML');


# Best URI overrides
$o = Mivvi::Overrides->new();
is($o->tempUriFor('series', '1'), 'tag:kafsemo.org,2005:mtmp/series/1', 'Temporary season URIs are correct');
is($o->tempUriFor('series', '1', 2), 'tag:kafsemo.org,2005:mtmp/series/1x2', 'Temporary episode URIs are correct');

is($o->bestUriFor('http://www.example.com/1/#', 'example', 1), undef, 'No season override with empty Overrides');
is($o->bestUriFor('http://www.example.com/1/2#', 'example', 1, 2), undef, 'No episode override with empty Overrides');

$o->loadRdfXml('test_MivviOverrides_alternativeUris.rdf');
is($o->bestUriFor('http://www.example.com/1/#', 'example', 1), 'http://www.example.com/alt-1/#', 'An alternative season URI should be picked up');
is($o->bestUriFor('http://www.example.com/1/2#', 'example', 1, 2), 'http://www.example.com/alt-1/2#', 'An alternative episode URI should be picked up');

$o->loadRdfXml('test_MivviOverrides_specificOverriddenUris.rdf');
is($o->bestUriFor('http://www.example.com/1/#', 'example', 1), 'http://www.example.com/overridden-1/#', 'An overridden season URI should be picked up');
is($o->bestUriFor('http://www.example.com/1/2#', 'example', 1, 2), 'http://www.example.com/overridden-1/2#', 'An overridden episode URI should be picked up');


# Catch warnings
my $warning;

$SIG{__WARN__} = sub {
        ($warning) = @_ unless ($warning);
};

is($o->tempUriFor('series', 'S'), 'tag:kafsemo.org,2005:mtmp/series/S', 'Characters are valid season IDs');
is($warning, undef, 'There should be no warning for character season IDs');
is($o->tempUriFor('series', '01'), 'tag:kafsemo.org,2005:mtmp/series/1', 'Numeric seasons should have no leading zeros');


# Blank dates are permitted
$o = Mivvi::Overrides->new();
$o->load('test_MivviOverrides_blankDate.txt');
is($o->getDate('http://www.example.com/1/1#'), '', 'Blank dates should be passed through');


# Store overrides of published URIs
$o = Mivvi::Overrides->new();
$o->loadRdfXml('test_MivviOverrides_overriddenPublishedUris.rdf');
$o->loadPublishedUris('test_MivviOverrides_publishedOriginalUris.txt');

is($o->bestUriFor('http://www.example.com/published-1#', 'series', '1'), 'http://www.example.com/1/#');
is($o->bestUriFor('http://www.example.com/published-1x2#', 'series', '1', '2'), 'http://www.example.com/1/2#');
is($o->bestUriFor('http://www.example.com/unknown#'), undef);

is($o->bestUriFor('http://www.example.com/unpublished-1#', 'series', '1'), 'http://www.example.com/1/#');
is($o->bestUriFor('http://www.example.com/unpublished-1x2#', 'series', '1', '2'), 'http://www.example.com/1/2#');
is($o->bestUriFor('http://www.example.com/unpublished-unknown#'), undef);

is($o->bestUriFor(undef, 'series', '1', '2'), 'http://www.example.com/1/2#');

my $expected = {
  'http://www.example.com/published-1#' => 'http://www.example.com/1/#',
  'http://www.example.com/published-1x2#' => 'http://www.example.com/1/2#'
};

is_deeply($o->getOverriddenPublishedUris(), $expected, 'Overridden published URIs should be tracked');
