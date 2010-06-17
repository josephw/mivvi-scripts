#!/usr/bin/perl -w

use strict;

use lib('../perl');
use Mivvi::File;

use URI::URL;
use HTML::Entities;

use Scraping;
use ScrapingUtil qw(trim withFragment);

my $seriesUri = $ARGV[0] or die "Usage: ${0} <series URI>";

my $res = Scraping::getResource($seriesUri, 'hbo') or die "No definition found for $seriesUri";

Mivvi::RdfXml::setOverrides(Scraping::loadOverrides($seriesUri), $res->{name});

my $d = ScrapingUtil::loadAsXml($res->{dataFile});

my $xpc = ScrapingUtil::newXPathContext();

my $mf = Mivvi::File->new($seriesUri);

$mf->setTitle($seriesUri, $res->{title});

my %seasons;

my %seasonFirstEpNum;

# Get the first episode of each season, to offset later on
foreach my $a ($xpc->findnodes('//x:div[@id="episodes"]/x:a/@href', $d)) {
	my $href = $a->findvalue('.');
	if (my ($season, $sepNum) = $href =~ /episodes\/(\d+)\/(\d+)-/) {
		my $n = $seasonFirstEpNum{$season};
		if (!defined($n) || $n > $sepNum) {
			$seasonFirstEpNum{$season} = $sepNum;
		}
	}
}

foreach my $a ($xpc->findnodes('//x:div[@id="episodes"]/x:a', $d)) {
	my $href = $a->findvalue('@href');
	$href =~ s/\/index.html$/\//;
	my $img = $xpc->findvalue('x:img/@src', $a);
	my $numAndTitle = $a->findvalue('.');
	$numAndTitle = trim($numAndTitle);

	my $uri = new URI::URL($href, $res->{dataUrl})->abs;
	$uri = withFragment($uri);

	my ($num, $title) = $numAndTitle =~ /^(\d+):\s+(.*)$/ or die "Bad number and title: $numAndTitle";
	$num = 0 + $num;

	my ($season, $sepNum) = $href =~ /episodes\/(\d+)\/(\d+)-/ or die "Unable to get season and episode from URI: $href";

	$sepNum -= ($seasonFirstEpNum{$season} - 1);

	$mf->addEpisode($season, $sepNum, $uri);
	$mf->setTitle($uri, $title);
	$mf->setEpisodeNumber($uri, $num);
	$mf->setUri($uri, 'tag:kafsemo.org,2004:mivvi#thumbnail', $img);
}

$mf->setSource($res->{dataUrl});

my $sourceTitle = $xpc->findvalue('/x:html/x:head/x:title', $d);
if ($sourceTitle) {
	$mf->setTitle($res->{dataUrl}, $sourceTitle);
}

$mf->saveToRdfXml($res->{output},
 COMMENT => "Generated from HBO.com's episode listing",
 FORCED_NS_DECLS => ['tag:kafsemo.org,2004:mivvi#']);
