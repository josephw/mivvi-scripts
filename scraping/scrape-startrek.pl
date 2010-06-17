#!/usr/bin/perl -w

use strict;

use lib('../perl');

use XML::LibXML;
use URI::URL;

use Scraping;
use ScrapingUtil qw(trim withFragment toDcDateMMDDYY);
use Mivvi::File;

my $seriesUri = $ARGV[0] or die "Usage: ${0} <series URI>";

my $res = Scraping::getResource($seriesUri, 'startrek') or die "No definition found for $seriesUri";

Mivvi::RdfXml::setOverrides(Scraping::loadOverrides($seriesUri), $res->{name});

sub toDcDate($)
{
	$_ = shift;

	$_ = trim($_);

	my ($m, $d, $y) = /^(\d+)\/(\d+)\/(\d{4})$/ or return undef;

	return sprintf("%04d-%02d-%02d", $y, $m, $d);
}

my $mf = Mivvi::File->new($res->{uri});

$mf->setTitle($res->{uri}, $res->{title});

$mf->setSource($res->{dataUrl});

my %seasons;

my $sourcePageTitle;

foreach (@{$res->{dataFiles}}) {
	my ($dataUrl, $dataFile) = @{$_};

	my $d = ScrapingUtil::loadAsXml($dataFile);
	my $xpc = ScrapingUtil::newXPathContext();

	my $seasonTitle = $xpc->findvalue('//x:img[contains(@src, "_on.gif") and starts-with(@alt, "Season ")]/@alt', $d);

	if ($dataUrl eq 'http://www.startrek.com/startrek/view/series/ANI/episodes/index.html?season=1')
	{
		$seasonTitle = 'Season 1';
	}

	my ($season) = $seasonTitle =~ /^Season (\d+)$/ or die "Unable to detect season for ${dataUrl}";

	print STDERR "Season is: $season\n";

	my $seasonUri;

	if ($season eq '0') {
		$seasonTitle = 'Pilot';
		$seasonUri = undef;
	} else {
		$seasonTitle = "Season ${season}";
		$seasonUri = "http://www.startrek.com/startrek/view/series/$res->{localName}/episodes/index.html?season=${season}#";
	}

	$mf->addSeason($season, $seasonUri);
	$mf->setTitle($seasonUri, $seasonTitle);

	if (!$sourcePageTitle) {
		$sourcePageTitle = $xpc->findvalue('/x:html/x:head/x:title', $d);
	}

	my $useGregorian;
	{
		my ($sd, $md) = (
			$xpc->findvalue('//x:tr/x:td[6 and contains(., "Stardate")]', $d),
			$xpc->findvalue('//x:tr/x:td[6 and contains(., "Mission Date")]', $d)
		);

		if (($sd && $md) || (!$sd && !$md)) {
			die "Unexpected combination of stardate and mission date";
		}

		$useGregorian = $md;
	}

	my $sepNum = 0;

	for my $t ($xpc->findnodes('//x:tr[count(x:td) = 8]', $d)) {
		my ($uri, $airDate, $title, $prodNum, $dvdNum, $stardate, $summary);

		$xpc->setContextNode($t);

		$uri = $xpc->findvalue('x:td[5]/x:a/@href');

		$airDate = $xpc->findvalue('x:td[4]');

		$title = $xpc->findvalue('x:td[5]');

		$prodNum = $xpc->findvalue('x:td[6]');

		$dvdNum = $xpc->findvalue('x:td[7]');
		$stardate = $xpc->findvalue('x:td[8]');

		$uri = new URI::URL($uri, $dataUrl)->abs;

		$uri = withFragment($uri);

#		print STDERR join(' ', $uri, $airDate, $title, $prodNum, $dvdNum, $stardate);

		my @extra;
			
		$stardate = trim($stardate);

		if ($stardate eq 'Unknown' || $stardate eq '') {
			$stardate = undef;
		} else {
			if (!$useGregorian) {
				$stardate =~ /^\d+(?:\.\d+)?$/ or die "Bad stardate for ${uri}: $stardate";
				$mf->setLiteral($uri, 'http://en.wikipedia.org/wiki/Stardate#top', $stardate);
			} else {
				my $missionDate;

				if (my ($m, $y) = $stardate =~ /^(\w+)\s+(\d{4})$/) {
					$m = substr($m, 0, 3);
					$m = Kafsemo::Mivvi::month2Num($m);
					$missionDate = sprintf('%04d-%02d', $y, $m);
				} else {
					my ($m, $d, $y) = $stardate =~ /^(\w{3,})\.?\s+(\d+),\s+(\d{4})$/ or die "Unable to parse $stardate";

					$m = substr($m, 0, 3);
					$m = Kafsemo::Mivvi::month2Num($m);
					$missionDate = sprintf('%04d-%02d-%02d', $y, $m, $d);
				}

				$mf->setLiteral($uri, 'http://en.wikipedia.org/wiki/Stardate#ent', $missionDate);
			}
		}

		my $episode = ++$sepNum;

		my $thisEpSeason = $season;

		if ($res->{localName} eq 'TOS') {
			if ($uri eq 'http://www.startrek.com/startrek/view/series/TOS/episode/68662.html#')
			{
				$thisEpSeason = '0';
				$episode = 1;
				$sepNum = 0;
			}
		}

		my $dcDate;
		$airDate = trim($airDate);
		if ($airDate eq 'none') {
			# Do nothing
		} else {
			$dcDate = toDcDateMMDDYY($airDate);
		}

		$mf->addEpisode($thisEpSeason, $episode, $uri);
		$mf->setTitle($uri, trim($title));
		$mf->setDate($uri, $dcDate);
		$mf->setProductionCode($uri, trim($prodNum));
	}
}

$mf->setTitle($res->{dataUrl}, $sourcePageTitle);

$mf->saveToRdfXml($res->{output},
 PREFIX_MAP => {'http://en.wikipedia.org/wiki/Stardate#' => 'wpsd'},
 FORCED_NS_DECLS => ['http://en.wikipedia.org/wiki/Stardate#']);
