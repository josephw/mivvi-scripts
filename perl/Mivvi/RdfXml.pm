# Copyright (c) 2004-2010 Joseph Walton <joe@kafsemo.org>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

use strict;

package Mivvi::RdfXml;

use Exporter;
use Carp;

use vars qw(@ISA @EXPORT $RDF $MVI $DC $OWL %prefixMap);

our $RDF = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
our $MVI = 'http://mivvi.net/rdf#';
our $DC = 'http://purl.org/dc/elements/1.1/';
our $FOAF = 'http://xmlns.com/foaf/0.1/';
our $OWL = 'http://www.w3.org/2002/07/owl#';

our %prefixMap = ($RDF => 'rdf', $MVI => 'mvi', $DC => 'dc', $OWL => 'owl');

@ISA = ('Exporter');
@EXPORT = qw(@ISA @EXPORT $RDF $MVI $DC $FOAF $OWL %prefixMap);

my $overrides;
my $seriesShortName;

sub setOverrides($$)
{
	$overrides = shift;
	$seriesShortName = shift;
}

use XML::Writer v0.605;

sub newXmlWriter(@)
{
	my @forcedDecls = ($RDF, $MVI, $DC);
	if ($overrides) {
#		push @forcedDecls, $OWL;
	}
	return new XML::Writer(NAMESPACES => 1,
		PREFIX_MAP => \%prefixMap,
		FORCED_NS_DECLS => \@forcedDecls,
		DATA_MODE => 1,
		DATA_INDENT => 1,
		@_
	);
}

sub startDoc($$$$)
{
	my ($w, $uri, $title, $sourceHref) = @_;

	$w->startTag([$RDF, 'RDF']);

	if ($sourceHref) {
		$w->startTag([$RDF, 'Description'], [$RDF, 'about'] => '');
		$w->emptyTag([$DC, 'source'], [$RDF, 'resource'] => $sourceHref);
		$w->endTag([$RDF, 'Description']);
	}

	# Series URI overrides
	if ($overrides) {
		foreach ($overrides->getSourcesSameAs($uri)) {
			if ($_ =~ /^tag:kafsemo.org,2005:mtmp\//) {
				next;
			}
			$w->startTag([$RDF, 'Description'], [$RDF, 'about'] => $_);
			$w->emptyTag([$OWL, 'sameAs'], [$RDF, 'resource'] => $uri);
			$w->endTag([$RDF, 'Description']);
		}
	}

	$w->startTag([$MVI, 'Series'], [$RDF, 'about'] => $uri, [$DC, 'title'] => $title);

	if ($overrides) {
		for my $d ($overrides->getDescriptions($uri)) {
			$w->dataElement([$DC, 'description'], $d);
		}
	}
}

sub startSeasons($)
{
	my ($w) = @_;

	$w->startTag([$MVI, 'seasons']);
	$w->startTag([$RDF, 'Bag']);
}

sub endSeries($)
{
	my ($w) = @_;

	$w->endTag([$RDF, 'Bag']);
	$w->endTag([$MVI, 'seasons']);
	$w->endTag([$MVI, 'Series']);
}

sub endDoc($)
{
	my ($w) = @_;

	if ($overrides) {
		my %publishedOverrides = %{$overrides->getOverriddenPublishedUris()};

		my @mappedUris = keys(%publishedOverrides);
		if (@mappedUris) {
			foreach (sort @mappedUris) {
				$w->startTag([$RDF, 'Description'], [$RDF, 'about'] => $_);
				$w->emptyTag([$OWL, 'sameAs'], [$RDF, 'resource'] => $publishedOverrides{$_});
				$w->endTag([$RDF, 'Description']);
			}
		}
	}

	$w->endTag([$RDF, 'RDF']);
}

sub endSeason($)
{
	my ($w) = @_;

	$w->endTag([$RDF, 'Seq']);
	$w->endTag([$MVI, 'episodes']);
	$w->endTag([$MVI, 'Season']);
	$w->endTag([$RDF, 'li']);
}

# Write an entire season, given a seasonNumber and a list of hashes representing
#  episodes
sub writeSeason($$$$@)
{
	my ($w, $season, $seasonTitle, $seasonUri, @episodeList) = @_;

	$w->startTag([$RDF, 'li']);
	my @attrs;

	push @attrs, ([$DC, 'title'] => $seasonTitle) if defined($seasonTitle);

	if ($overrides) {
		my $u = $overrides->bestUriFor($seasonUri, $seriesShortName, $season);
		if ($u) {
			$seasonUri = $u;
		}
	}

	if ($seasonUri) {
		push @attrs, ([$RDF, 'about'] => $seasonUri);
	}

	$w->startTag([$MVI, 'Season'], @attrs, [$MVI, 'seasonNumber'] => $season);

	$w->startTag([$MVI, 'episodes']);
	$w->startTag([$RDF, 'Seq']);

	my $epSeq = 1;

	foreach my $episode (@episodeList) {
		if ($episode->{sepNum} != $epSeq) {
			die "Expected episode $epSeq, but got $episode->{sepNum} (season ${season}, $episode->{title})";
		}

		$w->startTag([$RDF, 'li']);

		my @attrs = ();

		my $uri = $episode->{href} || die "Episode with no URI";

		my $title = $episode->{title};

		my @tDesc;

		my $uriToUse;

		if ($overrides) {
			$uriToUse = $overrides->bestUriFor($uri, $seriesShortName, $season, $epSeq);
			if ($uriToUse) {
				my $titleForBetterUri = $overrides->getTitle($uriToUse);
				if ($titleForBetterUri) {
					$title = $titleForBetterUri;
				}
			}
		}

		$uriToUse ||= $uri;

		if ($overrides) {
			my $t = $overrides->getTitle($uri);
			if ($t) {
				$title = $t;
			}
		}

		$epSeq++;

		my $date = $episode->{date};
		if ($overrides) {
			my $d = $overrides->getDate($uri);
			if (defined($d)) {
				$date = $d;
			}
		}

		push @attrs, ([$DC, 'date'] => $date) if $date;
		push @attrs, ([$MVI, 'episodeNumber'] => $episode->{epNum}) if $episode->{epNum};
		push @attrs, ([$MVI, 'productionCode'] => $episode->{prodCode}) if $episode->{prodCode};

		unshift @attrs, ([$DC, 'title'] => $title) if defined($title);
		unshift @attrs, ([$RDF, 'about'] => $uriToUse);

		if ($episode->{extra}) {
			push @attrs, @{$episode->{extra}};
		}

		
		if ($episode->{altTitles}) {
			push @tDesc, @{$episode->{altTitles}};
		}
		
		if ($overrides) {
			push @tDesc, $overrides->getDescriptions($uri);
		}

		if (@tDesc) {
			# Throw away duplicates
			my %tmp;
			foreach (@tDesc) {
				$tmp{$_} = 1;
			}
			@tDesc = sort(keys(%tmp));

			$w->startTag([$MVI, 'Episode'], @attrs);
			foreach (@tDesc) {
				$w->dataElement([$DC, 'description'], $_);
			}
			$w->endTag([$MVI, 'Episode']);
		} else {
			$w->emptyTag([$MVI, 'Episode'], @attrs);
		}
		$w->endTag([$RDF, 'li']);
	}

	endSeason($w);
}

# Ensure that a URI has a fragment identifier, even if empty,
#  so that it's treated as a resource rather than a web page
sub withFragment($)
{
	my $uri = shift;

	if ($uri !~ /\#/) {
		$uri .= '#';
	}

	return $uri;
}

# Split a namespace URI for RDF/XML
sub splitNsUri($)
{
	my $_ = shift;

	if (my ($b1, $h) = /^(.*\#)(\w*)$/) {
		return ($b1, $h);
	} elsif (my ($b2, $d) = /^(.*\/)(\w*)$/) {
		return ($b2, $d);
	} elsif (my ($b3, $c) = /^(.*:)(\w+)$/) {
		return ($b3, $c);
	} else {
		croak "Unable to split URI into namespace and element: $_";
	}
}

1;
