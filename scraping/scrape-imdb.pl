#!/usr/bin/perl -w

use strict;

use XML::LibXML;

use lib('../perl');

use URI::URL;

use Scraping;
use ScrapingUtil qw(trim withFragment month2Num);
use Mivvi::File;

my $seriesUri = shift or die "Usage: ${0} <series URI>";

my $res = Scraping::getResource($seriesUri, 'imdb') or die "No definition found for $seriesUri";

Mivvi::RdfXml::setOverrides(Scraping::loadOverrides($seriesUri, @ARGV), $res->{name});

my $d = ScrapingUtil::loadAsXml($res->{dataFile});

my $xpc = ScrapingUtil::newXPathContext();

my $mf = Mivvi::File->new($seriesUri);

$mf->setTitle($seriesUri, $res->{title});

$mf->setSource($res->{dataUrl});

my $sourceTitle;
$sourceTitle = $xpc->findvalue('x:html/x:head/x:title', $d);
if ($sourceTitle) {
	$mf->setTitle($res->{dataUrl}, $sourceTitle);
}

for my $a ($xpc->findnodes('//x:a[@name]', $d)) {
	my $name = $a->findvalue('@name');
	if (my ($s) = $name =~ /^season-(\d+)/) {
		my $uri = new URI::URL("#$name", $res->{dataUrl})->abs;
		
		$mf->addSeason($s, $uri);
		$mf->setTitle($uri, $a->findvalue('.'));
	}
}

for my $epTable ($xpc->findnodes('//x:table/x:tr/x:td[x:h3]', $d)) {
	$xpc->setContextNode($epTable);
	my $href = $xpc->findvalue('x:h3/x:a/@href');
	my $title = $xpc->findvalue('.//x:a');

	my $h = $xpc->findvalue('x:h3');

	my $bcast = $xpc->findvalue('.//x:strong');

	my ($season, $sepNum, $isoDate, $uri);

	$title = trim($title);

	my $ssnEp = $h;
	($season, $sepNum) = $ssnEp =~ /^Season\s+(\d+),\s+Episode\s+(\d+):/;
	$uri = new URI::URL($href, $res->{dataUrl})->abs;
	$uri = withFragment($uri);

	if (my ($d, $m, $y) = $bcast =~ /(\d+)\s+(\w{3})\w*\s+(\d+)$/) {
		my $mn = month2Num($m);
		$isoDate = sprintf('%04d-%02d-%02d', $y, $mn, $d);
	}

	$mf->addEpisode($season, $sepNum, $uri);

	$mf->setTitle($uri, $title);
	$mf->setDate($uri, $isoDate);
}

$mf->saveToRdfXml($res->{output}, COMMENT => "Generated from the IMDb's episode guide");
