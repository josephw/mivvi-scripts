#!/usr/bin/perl -w

use strict;

use lib('../perl');

use XML::LibXML;
use URI::URL;

use Scraping;
use Tvcom;
use ScrapingUtil qw(trim);
use Mivvi::File;

my $seriesUri = shift or die "Usage: ${0} <series URI>";

my $res = Scraping::getResource($seriesUri, 'tvcom') or die "No definition found for $seriesUri";

Mivvi::RdfXml::setOverrides(Scraping::loadOverrides($seriesUri, @ARGV), $res->{name});

sub toDcDate($)
{
	$_ = shift;

	$_ = trim($_);

	my ($d, $m, $y) = /^(\d+)\/(\d+)\/(\d{4})$/ or return undef;

	return sprintf("%04d-%02d-%02d", $y, $m, $d);
}

use YAML;

sub numOrZero($)
{
	my $s = shift;

	if ($s =~ /^\d+$/) {
		return $s;
	} else {
		return 0;
	}
}

sub updateSeasonRecord($@)
{
	my $filename = 'tvcom-seasons';

	my $series = shift;
	
	my %seasonSet;
	foreach (@_) {
		$seasonSet{$_} = 1;
	}

	my @seasons = sort { (numOrZero($a) <=> numOrZero($b)) || ($a cmp $b) } (keys(%seasonSet));

	my $record = YAML::LoadFile($filename) || {};

	my $before = $record->{$series};
	if ($before)
	{
		if (join(',', @{$before}) eq join(',', @seasons))
		{
			return;
		}
	}

	$record->{$series} = \@seasons;

	YAML::Bless($record->{$series});
	YAML::ynode(YAML::Blessed($record->{$series}))->keys(sort(keys(%{$record})));

	YAML::DumpFile($filename, $record) or die "Unable to save $filename: $!";
}

my %seasons;

my $sourceTitle;

# Collect all seasons
my %knownSeasons;

foreach my $f (@{$res->{dataFiles}}) {
my ($dataUrl, $dataFile) = @{$f};

# print STDERR $dataUrl, "\n";

my ($season) = $dataUrl =~ /season=([^&]+)/;

print STDERR "Processing ${dataFile}...\n";

my $d = ScrapingUtil::loadAsXml($dataFile);

sub snFor($)
{
	my $url = shift;

	my ($season) = $url =~ /season=([^&]+)/;

	$season =~ s/%20/ /g;
	$season = trim($season);

	return $season;
}

my $xpc = ScrapingUtil::newXPathContext();

my ($minSeason, $maxSeason);

# List the seasons linked in this page
for my $s ($xpc->findnodes('//x:div[@class="PAGINATOR"]/x:ul/x:li/x:a/@href', $d)) {
	$s = trim($s->findvalue('.'));

	my $sn = snFor($s);

	next if ($sn eq 'All' or $sn eq 'Top Episodes' or $sn eq 'other');
	if ($sn eq '0') {
		$sn = 'other';
	}

	if (!$knownSeasons{$sn}) {
		print STDERR "Discovered season: $sn\n";
	}

	# Check for numeric ranges
	if ($sn =~ /^\d+$/) {
		if (!defined($minSeason)) {
			$minSeason = $sn;
			$maxSeason = $sn;
		} else {
			if ($sn < $minSeason) {
				$minSeason = $sn;
			}

			if ($sn > $maxSeason) {
				$maxSeason = $sn;
			}
		}
	}

	$knownSeasons{$sn} = 1;
}

foreach ($minSeason .. $maxSeason) {
	if (!$knownSeasons{$_}) {
		$knownSeasons{$_} = 1;
		print STDERR "Inferred season: $_\n";
	}
}

$knownSeasons{$season} = 1;

print STDERR "Season: $season\n";

# updateSeasonRecord($res->{name}, keys(%knownSeasons));

# my $episode = 0;

for my $t ($xpc->findnodes('//x:tr[count(x:td) >= 7]', $d)) {
	my @columns = $xpc->findnodes('x:td', $t);

	my ($num, $title, $video, $usDate, $code, $score, $revCount) = map {trim($_->findvalue('.'))} @columns;

#	print STDERR join(',', $num, $title, $video, $usDate, $code, $score, $revCount), "\n";

#	$episode++;
	$num = trim($num);
	$title = trim($title);

	my @altDescs;
	($title, @altDescs) = ScrapingUtil::parseAkas($title);

	$code = trim($code);

	my $uri = $xpc->findvalue('./x:td[2]/x:a/@href', $t);

	$uri = new URI::URL($uri, $res->{dataUrl})->abs;

	if ($uri !~ /\#/) {
		$uri .= '#';
	}

	$uri = Tvcom::reduce($uri);

	$title =~ s/\s+/ /g;

	my $thisSeason = $season;
	my $thisEpisode; # = $episode;
	my $dcDate = toDcDate($usDate);
	
	if ($res->{localName} eq 'tom-goes-to-the-mayor') {
		if ($uri eq 'http://www.tv.com/episode/374473/summary.html#')
		{
			if ($season ne 'Special') {
				next;
			}
			$thisSeason = '0';
			$thisEpisode = 1;
			$num = undef;
		} elsif ($uri eq 'http://www.tv.com/episode/374474/summary.html#')
		{
			if ($season ne 'Special') {
				next;
			}
			$thisSeason = '0';
			$thisEpisode = 2;
			$num = undef;
		} elsif ($uri eq 'http://www.tv.com/episode/1146104/summary.html#')
		{
			if ($season eq 'Special') {
				next;
			}
#			$thisEpisode = '14';
#			$num = undef;
		} else {
			if ($season eq '1') {
				$num -= 2;
#				$thisEpisode-=2;
			}
		}
	}

	if ($res->{localName} eq 'rome') {
		if ($uri eq 'http://www.tv.com/episode/465431/summary.html#')
		{
			if ($thisSeason eq '1') {
				next;
			}
		}
	}

	if ($res->{localName} eq 'shameless-uk') {
		if ($title =~ /^Season \d+ - Episode \d+$/
			|| $title =~ /^Episode \w+$/
			|| $uri eq 'http://www.tv.com/episode/388517/summary.html#')
		{
			$title = undef;
		}

		if ($uri eq 'http://www.tv.com/episode/348375/summary.html#')
		{
			$thisSeason = 'S';
			$thisEpisode = '1';
		}
	}

	if ($res->{localName} eq 'look-around-you') {
		if ($uri eq 'http://www.tv.com/episode/400193/summary.html#') {
#			$thisEpisode = 6;
		} elsif ($uri eq 'http://www.tv.com/episode/258064/summary.html#') {
			next if ($season eq '1');

			$thisSeason = '0';
			$dcDate = undef;
			$num = undef;
		} elsif ($season eq '1') {
#			$thisEpisode--;
		}
	}

	if ($res->{localName} eq 'good-eats') {
	}

	if ($res->{localName} eq 'time-gentlemen-please') {
		if ($uri eq 'http://www.tv.com/episode/351896/summary.html#'
			and $thisSeason eq '1')
		{
			next;
		}
	}

	if ($num && $num !~ /^\d+$/) {
		$num = undef;
	}

	if ($thisSeason eq 'Special') {
		$thisSeason = 'S';
	}

	push @{$seasons{$thisSeason}}, {
		sepNum => $thisEpisode,
		altTitles => \@altDescs,
		title => $title,
		href => $uri,
		date => $dcDate,
		prodCode => $code,
		epNum => $num
	};
}

if (!$sourceTitle) {
	$sourceTitle = $xpc->findvalue('/x:html/x:head/x:title', $d);
}
}

updateSeasonRecord($res->{name}, keys(%knownSeasons));

my $tempFileName = Scraping::outputFileTempname();

my $mf = Mivvi::File->new($res->{uri});
$mf->setTitle($res->{uri}, $res->{title});
$mf->setSource($res->{dataUrl});

if ($sourceTitle) {
	$mf->setTitle($res->{dataUrl}, $sourceTitle);
}

my @seasonsWithSpecialsLast = grep { $_ ne 'S' } keys(%seasons);

if ($seasons{'S'}) {
	push @seasonsWithSpecialsLast, 'S';
}

my %episodesInExistingSeasons;

foreach my $season (@seasonsWithSpecialsLast) {
	my $seasonTitle = Tvcom::seasonTitle($season);

	my @eps = @{$seasons{$season}};

	# TV.com has some things out of order
	@eps = sort {
		# Order by sepNum, defined comes before undefined.
		# Fall back on epNum
		if (defined($a->{sepNum})) {
			if (defined($b->{sepNum})) {
				return $a->{sepNum} <=> $b->{sepNum};
			} else {
				return -1;
			}
		} elsif (defined($b->{sepNum})) {
			return 1;
		} else {
			return $a->{epNum} <=> $b->{epNum};
		}
	} @eps;

	# Drop duplicated specials; drop the season if it's left empty
	if ($season eq 'S') {
		@eps = grep {!$episodesInExistingSeasons{$_->{href}}} @eps;

		if (!@eps) {
			next;
		}
	}

	my $thisEpisode = 1;
	for my $ep (@eps) {
		$ep->{sepNum} = $thisEpisode++;
	}

#	print STDERR "Eps: ", $season, " ", join(',', @eps), "\n";

	my $seasonUri = Tvcom::seasonUriFor($res->{dataUrl}, $season);

	$seasonUri = $mf->addSeason($season, $seasonUri);
	$mf->setTitle($seasonUri, $seasonTitle);

	for my $ep (@eps) {
		my $u = $ep->{href};

		$episodesInExistingSeasons{$u} = 1;

		$mf->addEpisode($season, $ep->{sepNum}, $u);
		$mf->setTitle($u, $ep->{title});
		$mf->setDate($u, $ep->{date});
		$mf->setProductionCode($u, $ep->{prodCode});
		$mf->setEpisodeNumber($u, $ep->{epNum});
		if (@{$ep->{altTitles}}) {
			$mf->setDescription($u, $ep->{altTitles}->[0]);
		}
	}
}


$mf->saveToRdfXml($res->{output});
