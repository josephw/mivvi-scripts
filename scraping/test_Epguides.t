#!/usr/bin/perl -w

use strict;

use Test::More(tests => 16);


use Epguides;

is(Epguides::scrapeline(''), undef);

is(Epguides::epguidesToIsoDate(''), '');
is(Epguides::epguidesToIsoDate(' 7 Jun 90'), '1990-06-07');
is(Epguides::epguidesToIsoDate('14 Sep 05'), '2005-09-14');
is(Epguides::epguidesToIsoDate('03/Feb/01'), '2001-02-03');

my $l;

$l = <<EOQ;
  1.   1- 1     1AFF79      6 Nov 01   <a target="_blank" href="http://www.tv.com/24/1200-a.m.-100-a.m./episode/85396/summary.html">12:00 A.M.-1:00 A.M.</a>
EOQ
chomp($l);

is(join(',',@{Epguides::scrapeline($l)}),
'1,1,1,1AFF79,2001-11-06,http://www.tv.com/24/1200-a.m.-100-a.m./episode/85396/summary.html,12:00 A.M.-1:00 A.M.');

# A broken line
$l = <<EOQ;
115.5952-19     5AFF19     24 Apr 06   <a target="_blank" href="http://www.tv.com/24/day-5-100-am---200-am/episode/664095/summary.html">Day 5: 1:00 AM - 2:00 AM</a>
EOQ
chomp($l);

is(join(',',@{Epguides::scrapeline($l)}),
'115,5952,19,5AFF19,2006-04-24,http://www.tv.com/24/day-5-100-am---200-am/episode/664095/summary.html,Day 5: 1:00 AM - 2:00 AM');

# A line we want to ignore
my $sl = Epguides::scrapeline(<<EOQ);
  0.    - 1                            <a target="_blank" href="http://www.tv.com/reno-911!/episode-206/episode/399063/summary.html">Episode 206</a>
EOQ

is($sl, undef);

# Another escaped character
$l = <<EOQ;
 26.   2- 3        203      9 Oct 05   <a target="_blank" href="http://www.tv.com/desperate-housewives/youand039ll-never-get-away-from-me/episode/451826/summary.html">You&#039;ll Never Get Away From Me</a>
EOQ

is(join(',', @{Epguides::scrapeline($l)}),
"26,2,3,203,2005-10-09,http://www.tv.com/desperate-housewives/youand039ll-never-get-away-from-me/episode/451826/summary.html,You'll Never Get Away From Me");

# More escaped characters
# Decode lsquo, rsquo as simple apostrophes for now. Leave URLs unescaped
$l = <<EOQ;
119.   6-10     2T6310     22 Nov 05   <a target="_blank" href="http://www.tv.com/gilmore-girls/hes-slippin&rsquo;-&lsquo;em-bread...-dig/episode/543801/summary.html">He's Slippin&rsquo; &lsquo;Em Bread... Dig?</a>
EOQ

is(join(',', @{Epguides::scrapeline($l)}),
"119,6,10,2T6310,2005-11-22,http://www.tv.com/gilmore-girls/hes-slippin&rsquo;-&lsquo;em-bread...-dig/episode/543801/summary.html,He's Slippin' 'Em Bread... Dig?");

# A new-style TVRage line
$l = <<EOQ;
1      1-01      225301    23/Sep/99   <a href='http://www.tvrage.com/shows/id-6330/episodes/218825/01x01?epguides=1'>Welcome to Camelot</a>
EOQ

is(join(',', @{Epguides::scrapeline($l)}),
"1,1,01,225301,1999-09-23,http://www.tvrage.com/shows/id-6330/episodes/218825/01x01?epguides=1,Welcome to Camelot");

# A TVRage line with a trailer
$l = <<EOQ;
51     3-03      3AFF03    11/Nov/03   <a href='http://www.tvrage.com/24/episodes/640/?trailer=1&epguides=1#trailer'><img src='http://www.tvrage.com/_layout_v3/misc/film.gif' border='0' height='13' ></a> <a href='http://www.tvrage.com/24/episodes/640/03x03?epguides=1'>Day 3: 3:00 P.M.-4:00 P.M.</a>
EOQ

is(join(',', @{Epguides::scrapeline($l)}),
"51,3,03,3AFF03,2003-11-11,http://www.tvrage.com/24/episodes/640/03x03?epguides=1,Day 3: 3:00 P.M.-4:00 P.M.",
'Lines with trailers should be parsed correctly');

# Reduce Tvrage URLs
is(Epguides::reduce('http://www.tvrage.com/24/episodes/590/01x01?epguides=1#'),
'http://www.tvrage.com/24/episodes/590/#', 'URLs should be as short as possible');
is(Epguides::reduce('http://www.tvrage.com/shows/id-6330/episodes/218825/01x01?epguides=1'),
'http://www.tvrage.com/shows/id-6330/episodes/218825/#', 'URLs should be as short as possible with empty fragments');

# A TVRage line with no production code
$l = <<EOQ;
1      1-01                06/Oct/00   <a href='http://www.tvrage.com/CSI/episodes/40390/01x01?epguides=1'>Pilot</a>
EOQ

is(join(',', @{Epguides::scrapeline($l)}),
"1,1,01,,2000-10-06,http://www.tvrage.com/CSI/episodes/40390/01x01?epguides=1,Pilot",
"Lines with no production code should parse");

# An episode with no visible title should be ignored
$l = <<EOQ;
  0.   6- 0                            <a target="_blank" href="http://www.tv.com/entourage//episode/1283569/summary.html"></a>
EOQ

is(Epguides::scrapeline($l), undef, 'An episode with no visible title should be ignored');
