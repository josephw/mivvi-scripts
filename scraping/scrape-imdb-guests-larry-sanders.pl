#!/usr/bin/perl -w

use strict;

use lib('../perl');

use Mivvi::RdfXml;
use Mivvi::Overrides;

use ScrapingUtil qw(trim month2Num);

my $ICON_NS = 'http://xmlns.com/foaf/0.1/';
my $ICON_PRED = 'img';

my ($idFile) = @ARGV or die "Give path of ID RDF";

my $overrides = Mivvi::Overrides->new();

$overrides->loadRdfXml($idFile);

my $dataFile = 'fetched/imdb-guests-larry-sanders.html';

my $d = ScrapingUtil::loadAsXml($dataFile);
my $xpc = ScrapingUtil::newXPathContext();

my $w = Mivvi::RdfXml::newXmlWriter(ENCODING => 'utf-8',
	FORCED_NS_DECLS => [$RDF, $MVI, $DC, $ICON_NS]);

$w->addPrefix($ICON_NS, 'foaf');

$w->xmlDecl();

$w->startTag([$RDF, 'RDF']);

$w->startTag([$RDF, 'Description'], [$RDF, 'about'] => '');
$w->emptyTag([$DC, 'source'], [$RDF, 'resource'] => 'http://www.imdb.com/title/tt0103466/epcast');
$w->endTag([$RDF, 'Description']);


my @episodes;

my %episodeMeta;
my %episodeAppearances;

my %uris;

my $episode;

for my $s ($xpc->findnodes('//x:h4', $d)) {
	my $numberAndTitle = trim($s->findvalue('.'));
	my $uri = $xpc->findvalue('x:td/x:span/x:a/@href', $s);
	my $dateString = $xpc->findvalue('following-sibling::x:b[1]', $s);

	my ($season, $num, $title) = ($numberAndTitle =~ /Season (\d+), Episode (\d+):\s+(.*)$/) or die "Bad episode and title line: $numberAndTitle";

	my ($day, $monthName, $year) = ($dateString =~ /^(\d+)\s+(\w+)\s+(\d{4})$/) or die "Bad date: $dateString";
	$monthName = substr($monthName, 0, 3);
	my $isodate = sprintf('%04d-%02d-%02d', $year, month2Num($monthName), $day);

	my $episode;

	my $properUri = $overrides->bestUriFor(undef, 'the-larry-sanders-show', $season, $num);
	if ($properUri) {
		$episode = $properUri;
	} else {
		$episode = $overrides->tempUri('the-larry-sanders-show', $season, $num);
	}


	$w->startTag([$MVI, 'Episode'], [$RDF, 'about'] => $episode,
		[$DC, 'title'] => $title,
		[$DC, 'date'] => $isodate);

	for my $t ($xpc->findnodes('following-sibling::x:div[1]/x:table[@class="cast"]/x:tr', $s)) {
		my $pic = $xpc->findvalue('x:td[@class="hs"]//x:img/@src', $t);
		my $actorUri = $xpc->findvalue('x:td[@class="nm"]/x:a/@href', $t);
		my $actorName = $xpc->findvalue('x:td[@class="nm"]/x:a', $t);
		my $part = $xpc->findvalue('x:td[@class="char"]', $t);

		# Normalise parts
		if ($part eq 'Himself (uncredited)') {
			$part = 'Himself';
		}

		$part =~ s/\s+\(archive footage\)$//;

		$part =~ s/\s+\(as .+\)$//;
		$part =~ s/\s+\(voice\)$//;
		$part =~ s/\s+- Singer$//;

		# Throw away missing picture URLs
		if ($pic =~ /no_photo\.png$/) {
			$pic = undef;
		}

		if ($part =~ /sel(f|ves)/) {
			if ($part ne 'Himself' && $part ne 'Herself' && $part ne 'Themselves') {
				die "Bad self: $part";
			}

			$actorName = trim($actorName);

			my $uri = 'http://www.imdb.com' . $actorUri;

			if ($pic) {
				$w->startTag([$DC, 'contributor']);
				$w->startTag([$RDF, 'Description'], [$RDF, 'about'] => $uri,
					[$DC, 'title'] => $actorName);
				$w->emptyTag([$ICON_NS, $ICON_PRED],
					[$RDF, 'resource'] => $pic);
				$w->endTag([$RDF, 'Description']);
				$w->endTag([$DC, 'contributor']);
			} else {
				$w->emptyTag([$DC, 'contributor'], [$RDF, 'resource'] => $uri,
					[$DC, 'title'] => $actorName);
			}
		}
	}

	$w->endTag([$MVI, 'Episode']);
}
$w->endTag([$RDF, 'RDF']);
$w->end();
