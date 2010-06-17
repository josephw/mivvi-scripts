#!/usr/bin/perl -w

use strict;

use lib('../perl');
# use Kafsemo::Mivvi;

use URI::URL;

use Scraping;
use Tvcom;
use Epguides;
use ScrapingUtil;
use Mivvi::File;

my $seriesUri = shift or die "Usage: ${0} <series URI>";

my $res = Scraping::getResource($seriesUri, 'epguides') or die "No definition found for $seriesUri";

Mivvi::RdfXml::setOverrides(Scraping::loadOverrides($seriesUri, @ARGV), $res->{name});

sub epCode($)
{
	my ($c) = @_;

	if ($c =~ /^\s*$/) {
		return '';
	} else {
		if (my ($ssn, $ep) = $c =~ /^\s*([0-9A-Z]+)-\s*(\d+)$/) {
			return sprintf('%sx%02d', $ssn, $ep);
		} else {
			return '';
		}
	}
}

sub splitCode($)
{
	my ($c) = @_;

	if ($c =~ /^\s*$/) {
		die "Bad season/episode code: $c";
	} else {
		if (my ($ssn, $ep) = $c =~ /^\s*([0-9A-Z]+)-\s*(\d+)$/) {
			return ($ssn, $ep);
		} else {
			die "Bad season/number code: $c";
		}
	}
}

sub epNum($)
{
	my ($n) = @_;

	if (my ($rn) = $n =~ /^\s*(\d+)\./) {
		return $rn;
	} else {
		return '';
	}
}

open(INPUT, '-|', 'tr "\r" "\n" <'.$res->{dataFile}) or die "Unable to open $res->{dataFile}: $!";

my $epguidesName = $res->{localName};


# print "$epguidesName\n";

my %seasons;

#if ($epguidesName eq 'MalcolmintheMiddle') {
#	push @{$seasons{'1'}}, {epNum => 1, prodCode => '10012-99-179',
#		date => '2000-01-09', href => 'http://www.tv.com/episode/3855/summary.html#',
#		title => 'Pilot', sepNum => 1, altTitles => []
#	};
#}

my $tvcomId;

$tvcomId = {
}->{$res->{uri}} || $res->{tvcomId};

while (<INPUT>) {
	chomp;

	# Check for a charset declaration
	if (my ($charset) = /<meta[^>]*charset=([-a-zA-Z0-9]+)/) {
		$charset = lc($charset);
#		print STDERR "Declared charset is: $charset\n";
		if ($charset ne 'utf-8' && $charset ne 'iso-8859-1') {
			die "Unexpected charset: $charset";
		}
		if ($charset eq 'iso-8859-1') {
			$charset = 'windows-1252';
		}
		binmode(INPUT, ":encoding($charset)") or die "Unable to set encoding to $charset: $!";
	}

	# Hack for windows-1252
	if(/[\x{91}\x{92}]/) {
#		print STDERR "Error with: $_\n";
		s/[\x{91}\x{92}]/'/g;
#		print STDERR "Okay as: $_\n";
	}

	# Check for tvcom ID
	if (my ($tvi) = /http:\/\/www\.tv\.com\/(?:[^\/]+\/)?show\/(\d+)\/(?:summary|contribute|episode_guide).html/)
	{
		$tvcomId = $tvi;
	} elsif (my ($tv2) = /http:\/\/www\.tvtome\.com\/tvtome\/servlet\/ShowMainServlet\/showid-(\d+)\//)
	{
		$tvcomId = $tv2;
	}

	if (my $lineScrapeRef = Epguides::scrapeline($_)) {
		my ($epNum, $season, $sepNum, $prodcode, $isoDate, $url, $title) = @{$lineScrapeRef};

		my $uri = new URI::URL($url, $res->{dataUrl})->abs;

		if ($uri !~ /\#/) {
			$uri .= '#';
		}

		if ($uri =~ /^http:\/\/www\.tvrage\.com\//) {
			$uri = Epguides::reduce($uri);
		} elsif ($uri =~ /^http:\/\/www\.tv\.com\//) {
			$uri = Tvcom::reduce($uri);
		} else {
			die "Unexpected URI: $uri";
		}

		my @altDescs;

		($title, @altDescs) = ScrapingUtil::parseAkas($title);

		my $isGapped;

		# Is this episode out of sequence?
		if (!$seasons{$season}) {
			$isGapped = ($sepNum > 1);
		} else {
			$isGapped = (@{$seasons{$season}} != $sepNum - 1);
		}

		
		my $renumberNumberedSpecials;

		# Special cases
		if ($epguidesName eq 'Daria') {
			if ($season eq '1') {
				$sepNum -= 1;
			} elsif ($season eq 'S' || $season eq 'T') {
				$season = 'S';
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'CSI') {
		} elsif ($epguidesName eq '24') {
		} elsif ($epguidesName eq 'SouthPark') {
			if ($epNum == 0 || $uri eq 'http://www.tvrage.com/South_Park/episodes/159587/#') {
				$season = 'S';
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'Summerland') {
		} elsif ($epguidesName eq 'BrakShow') {
			if ($season eq '1') {
				$sepNum -= 1;
			}
		} elsif ($epguidesName eq 'ThirdWatch') {
		} elsif ($epguidesName eq 'Survivor') {
			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
			if ($season eq '3' || $season eq '20') {
				$sepNum -= 1;
			}
		} elsif ($epguidesName eq 'Seinfeld') {
		} elsif ($epguidesName eq 'XFiles') {
		} elsif ($epguidesName eq 'CurbYourEnthusiasm') {
		} elsif ($epguidesName eq 'Friends') {
		} elsif ($epguidesName eq 'Fastlane') {
		} elsif ($epguidesName eq 'OC') {
			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'Smallville') {
		} elsif ($epguidesName eq 'Lost') {
		} elsif ($epguidesName eq 'MontyPythonsFlyingCircus') {
			if ($uri eq 'http://www.tv.com/episode/57267/summary.html#')
			{
				$sepNum = 13;
			}
		} elsif ($epguidesName eq 'AmericanDad') {
		} elsif ($epguidesName eq 'DoctorWho_2005') {
		} elsif ($epguidesName eq 'ColdCase') {
		} elsif ($epguidesName eq 'WestWing') {
			if ($uri eq 'http://www.tv.com/episode/548097/summary.html#')
			{
				# Two versions of a live episode? skip one.
				next;
			}

			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'MalcolmintheMiddle') {
		} elsif ($epguidesName eq 'Sopranos') {
		} elsif ($epguidesName eq 'FamilyGuy') {
			if ($uri eq 'http://www.tv.com/episode/17634/summary.html#')
			{
				$season = 1;
				$sepNum = 1;
			}
			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'BattlestarGalactica') {
			if ($sepNum == 0) {
				if ($uri eq 'http://www.tvrage.com/Battlestar_Galactica/episodes/18376/#') {
					$season = '0';
				} else {
					$season = 'S';
				}
			}

			if ($uri eq 'http://www.tvrage.com/Battlestar_Galactica/episodes/562667/#') {
				$season = 'S';
			}

			if ($season eq '4' && $sepNum == 22) {
				$sepNum = 21;
			}

			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'ER') {
		} elsif ($epguidesName eq 'House') {
		} elsif ($epguidesName eq 'StargateSG1') {
			if ($uri eq 'http://www.tv.com/episode/54238/summary.html#')
			{
				$season = 'F';
			}
		} elsif ($epguidesName eq 'Scrubs') {
		} elsif ($epguidesName eq 'GilmoreGirls') {
		} elsif ($epguidesName eq 'Alias') {
		} elsif ($epguidesName eq 'StargateAtlantis') {
			if ($season eq '5') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'Wire') {
			if ($season eq '5') {
				$sepNum -= 2;
			}
		} elsif ($epguidesName eq 'HomeMovies') {
			if ($uri eq 'http://www.tv.com/episode/74940/summary.html#')
			{
				$season = '1';
				$epNum = 1;
			}

			if ($season eq '4' && $sepNum <= 7) {
				my @inOrder = ('Camp', 'Bye Bye Greasy', 'The Heart Smashers',
					"Everyone's Entitled To My Opinion", "The Wizard's Baker",
					'Psycho-Delicate', 'Curses');

				my %n2i;
				@n2i{@inOrder} = 1 .. @inOrder;

				$sepNum = $n2i{$title} or die;
			}
		} elsif ($epguidesName eq 'DesperateHousewives') {
		} elsif ($epguidesName eq 'AquaTeenHungerForce') {
			if ($uri eq 'http://www.tv.com/episode/80371/summary.html#')
			{
				$epNum = 1;
			}
			if ($season eq '1') {
				$sepNum--;
			}
			if ($season eq '7') {
				$sepNum--;
			}
		} elsif ($epguidesName eq 'Metalocalypse') {
		} elsif ($epguidesName eq 'PrisonBreak')
		{
			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'SexandtheCity') {
			if ($uri eq 'http://www.tv.com/episode/16903/summary.html#') {
				$season = 1;
			}
		} elsif ($epguidesName eq 'GreenWing')
		{
			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'Reno911') {
			if ($uri eq 'http://www.tv.com/episode/239747/summary.html#') {
				$season = '1';
			} elsif ($uri eq 'http://www.tv.com/episode/1202616/summary.html#')
			{
				$sepNum = 9;
			}

			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'beavisandbutthead') {
			if($season eq '6' && $sepNum >= 9) {
				$sepNum--;
			}
			if ($season eq 'S') {
				$renumberNumberedSpecials = 1;
			}
		} elsif ($epguidesName eq 'DeadLikeMe') {
			if ($uri eq 'http://www.tv.com/episode/426159/summary.html#') {
				$season = 1;
				$sepNum = 1;
			} elsif ($uri eq 'http://www.tv.com/episode/1309883/summary.html#') {
				$season = 1;
				$sepNum = 2;
			} elsif ($season eq '1') {
				$sepNum++;
			}
			if ($season eq 'T') {
				$season = 'S';
				$renumberNumberedSpecials = 1;
			}
		}

		if ($sepNum == 0 || $renumberNumberedSpecials
			&& ($season eq '0' || $season eq 'F'
			|| $season eq 'S'))
		{
			if ($seasons{$season}) {
				$sepNum = @{$seasons{$season}} + 1;
			} else {
				$sepNum = 1;
			}

			$epNum = undef;
		}

		my $episode = {epNum => $epNum,
			prodCode => $prodcode,
			date => $isoDate,
			href => $uri,
			title => $title,
			sepNum => $sepNum,
			altTitles => \@altDescs
		};

		push @{$seasons{$season}}, $episode;
	}
}

if ($epguidesName eq 'BattlestarGalactica') {
	push @{$seasons{'M'}}, { title => 'Mini Series (1)', date => '2003-12-08', href => 'http://www.tv.com/episode/291740/summary.html#', epNum => 1, sepNum => 1};
	push @{$seasons{'M'}}, { title => 'Mini Series (2)', date => '2003-12-09', href => 'http://www.tv.com/episode/291741/summary.html#', epNum => 2, sepNum => 2};
}

if ($epguidesName eq 'HomeMovies') {
	@{$seasons{'4'}} = sort {$a->{sepNum} <=> $b->{sepNum}} @{$seasons{'4'}};
}

close(INPUT) or die "Unable to close input: $!";

# die "No TV.com ID :-(" unless $tvcomId;

my $mf = Mivvi::File->new($seriesUri);

$mf->setTitle($seriesUri, $res->{title});
$mf->setSource($res->{dataUrl});


for my $season (keys(%seasons)) {
	my $seasonTitle = Tvcom::seasonTitle($season);

	my @episodes = @{$seasons{$season}};

	@episodes = sort {$a->{sepNum} <=> $b->{sepNum}} @episodes;

	my $seasonUri;
	if ($tvcomId) {
 		$seasonUri = Tvcom::seasonUriFor($tvcomId, $season);
	}

	$seasonUri = $mf->addSeason($season, $seasonUri);
	$mf->setTitle($seasonUri, $seasonTitle);

	for my $ep (@episodes) {
		my $u = $ep->{href};
		$mf->addEpisode($season, $ep->{sepNum}, $u);
		$mf->setTitle($u, $ep->{title});
		$mf->setDate($u, $ep->{date});
		$mf->setEpisodeNumber($u, $ep->{epNum});
		if ($ep->{prodCode}) {
			$mf->setProductionCode($u, $ep->{prodCode});
		}
		if ($ep->{altTitles} && @{$ep->{altTitles}}) {
			$mf->setDescription($u, $ep->{altTitles}->[0]);
		}
	}
}

$mf->saveToRdfXml($res->{output}, COMMENT => " Generated from EpGuides.com's episode guide ");
