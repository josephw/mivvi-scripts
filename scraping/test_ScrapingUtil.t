#!/usr/bin/perl -w

use strict;

use Test::More(tests => 25);

use ScrapingUtil qw(trim month2Num withFragment);

is(trim(''), '');
is(trim(' '), '');
is(trim('a'), 'a');
is(trim(' a '), 'a');
is(trim(' a  a '), 'a a', 'Multiple runs of spaces should be trimmed');
is(trim(' a  a  a '), 'a a a', 'Multiple runs of spaces should be trimmed');

is(trim("A\x{A}B"), 'A B', 'Newlines should be trimmed');

# Lots of things should be picked up as months
is(month2Num('Jan'), 1, 'Jan -> 1');
is(month2Num('jan'), 1, 'jan -> 1');
is(month2Num('January'), 1, 'January -> 1');
is(month2Num('December'), 12, 'December -> 1');


ok(eq_array([ScrapingUtil::parseAkas("O'Grady Idol (aka Cat People)")], ["O'Grady Idol", "Cat People"]), 'AKA parsing should recognise lowercase akas');

ok(eq_array([ScrapingUtil::parseAkas("Signs (AKA Sign Language)")], ['Signs', 'Sign Language']), 'AKA parsing should recognise uppercase akas');

is([ScrapingUtil::parseAkas("Nothing to extract")]->[0], 'Nothing to extract', 'A string with no AKAs should be returned as passed');

ok(eq_array([ScrapingUtil::parseAkas("Collision (a.k.a.Old Habits)")], ['Collision', 'Old Habits']), 'AKA parsing should recognise akas with bad spacing');

ok(eq_array([ScrapingUtil::parseAkas("Pickled Pink (a.k.a Corn the Beef)")],
['Pickled Pink', 'Corn the Beef']), 'AKA parsing should be lenient with dots');

# AKA tests from old code
ok(eq_array([ScrapingUtil::parseAkas("Plain Episode Title")],
['Plain Episode Title']),
'A plain episode title should be left unaffected');

ok(eq_array([ScrapingUtil::parseAkas("Coach (a.k.a. Tennis Coach)")],
['Coach', 'Tennis Coach']),
'One AKA should be recognised');

ok(eq_array([ScrapingUtil::parseAkas("Episode 1 (aka The Pilot)")],
['Episode 1', 'The Pilot']),
'AKAs should be recognised without dots');

ok(eq_array([ScrapingUtil::parseAkas("The One With All The Other Ones (2) (a.k.a. The One Before The Last One: 10 Years of Friends (2))")],
['The One With All The Other Ones (2)', 'The One Before The Last One: 10 Years of Friends (2)']),
'A complex title with one AKA');

ok(eq_array([ScrapingUtil::parseAkas("Where the Heart Is (a.k.a. Taking Care, a.k.a. Mea Culpa)")],
['Where the Heart Is', 'Taking Care', 'Mea Culpa']),
'Multiple AKAs');

ok(eq_array([ScrapingUtil::parseAkas("Missing (a.k.a. Mistaken Identity, a.k.a. Identity Crisis)")],
['Missing', 'Mistaken Identity', 'Identity Crisis']),
'Multiple AKAs');

# Ensure there is a fragment
is(withFragment('http://example.com/'), 'http://example.com/#');
is(withFragment('http://example.com/#'), 'http://example.com/#');
is(withFragment('http://example.com/#frag'), 'http://example.com/#frag');
