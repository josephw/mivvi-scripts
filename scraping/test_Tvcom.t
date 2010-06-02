#!/usr/bin/perl -w

use strict;

use Test::More(tests => 14);

use Tvcom;

# URL reducing

is(Tvcom::reduce('http://www.tv.com/episode/420225/summary.html#'), 'http://www.tv.com/episode/420225/summary.html#', 'Already-reduced URIs are left unaffected');

is(Tvcom::reduce('http://www.tv.com/drawn-together/episode/420225/summary.html#'), 'http://www.tv.com/episode/420225/summary.html#', 'The series name is elided');
is(Tvcom::reduce('http://www.tv.com/drawn-together//episode/420225/summary.html#'), 'http://www.tv.com/episode/420225/summary.html#', 'Episode titles are elided even when empty');

is(Tvcom::reduce('http://www.tv.com/drawn-together/the-one-wherein-theres-a-big-twist-2/episode/420225/summary.html#'), 'http://www.tv.com/episode/420225/summary.html#', 'Full episode titles and series titles are elided');

is(Tvcom::reduce('http://www.tv.com/tom-goes-to-the-mayor/tom-goes-to-the-mayor/episode/374473/summary.html?tag=ep_list;title;0#'), 'http://www.tv.com/episode/374473/summary.html#', 'New URIs with parameters are reduced');


# Season URIs
is(Tvcom::seasonUriFor('http://www.tv.com/the-kids-in-the-hall/show/3142/episode.html?season=0', 3), 'http://www.tv.com/show/3142/episode.html?season=3#', 'Should be able to extract season URIs from show URIs and season number');

is(Tvcom::seasonUriFor('http://www.tv.com/the-kids-in-the-hall/show/3142/episode.html?season=0', '0'), undef, 'No season URI for pilots');
is(Tvcom::seasonUriFor('http://www.tv.com/the-kids-in-the-hall/show/3142/episode.html?season=0', 0), undef, 'No season URI for pilots');

is(Tvcom::seasonUriFor('http://www.tv.com/the-kids-in-the-hall/show/3142/episode.html?season=0', 'F'), undef, 'No season URI for pseudo-seasons');


# Season titles
is(Tvcom::seasonTitle(0), 'Pilot', 'Season zero is used for pilots');
is(Tvcom::seasonTitle('F'), 'Films', 'F is for films');
is(Tvcom::seasonTitle('2'), 'Season 2', 'Regular season titles are numbered');

# Season URIs by ID
is(Tvcom::seasonUriFor('3142', '0'), undef, 'No season URI for pilots');
is(Tvcom::seasonUriFor('3142', '1'), 'http://www.tv.com/show/3142/episode.html?season=1#', 'Getting season URIs by TV.com ID should work');
