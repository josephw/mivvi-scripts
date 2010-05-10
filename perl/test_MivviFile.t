#!/usr/bin/perl -w

use strict;

use Test::More(tests => 12);
use Mivvi::File;

# Season order comparison
is(Mivvi::File::_seasonOrderCompare(1, 1), 0, 'Season codes should compare numerically');
is(Mivvi::File::_seasonOrderCompare(1, 2), -1, 'Season codes should compare numerically');
is(Mivvi::File::_seasonOrderCompare(2, 1), 1, 'Season codes should compare numerically');

is(Mivvi::File::_seasonOrderCompare(1, 'X'), -1, 'Non-numeric seasons should come last');
is(Mivvi::File::_seasonOrderCompare('X', 1), 1, 'Non-numeric seasons should come last');

is(Mivvi::File::_seasonOrderCompare('X', 'X'), 0, 'Non-numeric seasons should compare lexically');
is(Mivvi::File::_seasonOrderCompare('A', 'X'), -1, 'Non-numeric seasons should compare lexically');
is(Mivvi::File::_seasonOrderCompare('X', 'A'), 1, 'Non-numeric seasons should compare lexically');

my $mf = Mivvi::File->new('http://www.example.com/#');

# Failing on duplicated episodes
$mf->addEpisode('1', 1, 'http://www.example.com/episode-a#');
eval {
 $mf->addEpisode('1', 1, 'http://www.example.com/episode-b#');
};
like($@, qr/^Duplicate episode:/, 'Duplicate episodes should croak');


# Failing on duplicated seasons
$mf->addSeason('1', 'http://www.example.com/season-a#');
eval {
 $mf->addSeason('1', 'http://www.example.com/season-b#');
};
like($@, qr/^Duplicate season:/, 'Duplicate episodes should croak');


# An undef season URI should give us a temporary blank URI to use
my $blankUri = $mf->addSeason('2', undef);

isnt($blankUri, undef, 'Internal URIs for seasons without');


# A defined URI should pass back the original
my $origUri = $mf->addSeason('3', 'http://www.example.com/3/#');
is($origUri, 'http://www.example.com/3/#', 'Original URI returned when defined');
