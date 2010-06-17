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

package Scraping;

use strict;

sub loadResources()
{
	my @resources;

	defined($ENV{'MIVVI_DATA_DIR'}) or die "MIVVI_DATA_DIR should point at the target directory";

	open(RESOURCES, '<:encoding(utf-8)', 'resources') or die "Unable to open show definition: $!";

use YAML;

my $tvcomSeasons = ( -f 'tvcom-seasons' && YAML::LoadFile('tvcom-seasons')) || {};

while (<RESOURCES>) {
	chomp;

	next if /^\s*#/;

	my ($u, $t, $n, $d, @extra) = split(/\t/, $_);

	defined($d) or die "Unable to parse line";

	$t =~ s/^(['"])(.*)\1$/$2/;

	my %resource = (uri => $u, title => $t, name => $n, dataUrl => $d);

	my ($scraperName, @dataFiles, $localName);

	if (my ($tvcomName, $showid) = $d =~ /^http:\/\/www.tv.com\/(.*)\/show\/(\d+)\/episode\.html(?:\?.*)?$/) {
		$scraperName = 'tvcom';

		my @seasons = @{$tvcomSeasons->{$n} || ['1']};

		foreach (@seasons) {
			my $dataFile;
			$dataFile = "tvcom-${tvcomName}-${_}.html";
			my $dataUrl = $d;
			$dataUrl = "http://www.tv.com/${tvcomName}/show/${showid}/episode.html?season=${_}&shv=list";

			push @dataFiles, [$dataUrl, $dataFile];
		}

		$localName = $tvcomName;
	} elsif (my ($filename2) = $d =~ /^http:\/\/epguides\.com\/(.*)\/$/) {
		$scraperName = 'epguides';
		push @dataFiles, [$d, "epguides-${filename2}.html"];
		$localName = $filename2;
		if ($extra[0]) {
			$resource{tvcomId} = $extra[0];
		}
	} elsif (my ($trek) = $d =~ /^http:\/\/www\.startrek\.com\/startrek\/view\/series\/(\w+)\/episodes\/$/)
	{
		$extra[0] or die "No season count defined for Trek series";
		$scraperName = 'startrek';
		for my $ssn (1 .. $extra[0]) {
			my $dataFile = "startrek-${trek}-${ssn}.html";
			my $dataUrl = "http://www.startrek.com/startrek/view/series/${trek}/episodes/index.html?season=${ssn}";

			push @dataFiles, [$dataUrl, $dataFile];
		}
		$localName = $trek;
	} elsif (my ($hbo) = $d =~ /^http:\/\/www\.hbo\.com\/([^\/]+)\/episodes$/)
	{
		$scraperName = 'hbo';
		push @dataFiles, [$d, "hbo-${hbo}.html"];
		$localName = $hbo;
	} elsif (my ($imdbNum) = $d =~ /^http:\/\/www\.imdb\.com\/title\/(tt\d+)\/episodes$/)
	{
		$scraperName = 'imdb';
		$localName = $imdbNum;
		push @dataFiles, [$d, "imdb-episodes-${n}-${imdbNum}.html"];
	}


	if (@dataFiles && defined($scraperName) && defined($localName)) {
		# Good to go
	} else {
		print STDERR "Unable to figure filename, scraper or local name for ${d}\n";
		next;
	}

	$resource{scraperName} = $scraperName;
	$resource{scraper} = "./scrape-${scraperName}.pl";
	$resource{dataFiles} = [map {[$_->[0], 'fetched/'.$_->[1]]} @dataFiles];
	$resource{localName} = $localName;

	if (@{$resource{dataFiles}} == 1) {
		$resource{dataFile} = $resource{dataFiles}->[0]->[1];
	}

	my $outputFile;
	if ($n =~ /\//) {
		$outputFile = $n.'.rdf';
	} else {
		$outputFile = $ENV{'MIVVI_DATA_DIR'}.'/'.$scraperName.'/'.$n.'.rdf';
	}

	$resource{output} = $outputFile;

	push @resources, \%resource;
}

close(RESOURCES) or die "Unable to close resources: $!";

return @resources;
}

sub getResource($$)
{
	my $uri = shift;
	my $scraperName = shift;

	foreach (loadResources()) {
		if ($scraperName && ($_->{scraperName} ne $scraperName)) {
			next;
		}

		if ($_->{uri} eq $uri) {
			return $_;
		}
	}

	return undef;
}

sub loadOverrides(@)
{
	use Mivvi::Overrides;

	my $seriesUri = shift;

	my $o = Mivvi::Overrides->new();

	$o->load('overrides');

	foreach (@_) {
		$o->loadRdfXml($_);
	}

	return $o;
}

1;
