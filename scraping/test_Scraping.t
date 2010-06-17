#!/usr/bin/perl -w

use strict;

use Test::More(tests => 6);

use Scraping;

# Resource getting
my $res;

$ENV{'MIVVI_DATA_DIR'} = '.';

$res = Scraping::getResource('http://www.adultswim.com/shows/athf/#', undef);
ok($res);
is($res->{localName}, 'AquaTeenHungerForce');

# Per-scraper resource getting
$res = Scraping::getResource('http://www.hbo.com/the-sopranos/#', 'hbo');
ok($res);
is($res->{dataUrl}, 'http://www.hbo.com/the-sopranos/episodes');

$res = Scraping::getResource('http://www.hbo.com/the-sopranos/#', 'epguides');
ok($res);
is($res->{dataUrl}, 'http://epguides.com/Sopranos/');
