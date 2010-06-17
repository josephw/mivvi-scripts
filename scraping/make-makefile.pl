#!/usr/bin/perl -w

use strict;

use Scraping;

my %onhold;

open ONHOLD,'<','on-hold' or die "Unable to open on-hold: $!";
while (<ONHOLD>) {
	chomp;
	if ($_ !~ /^\s*#/) {
		$onhold{$_} = 1;
	}
}
close ONHOLD or die;

print "all: dirs allfiles\n\n";

my %dirs;

my %filesByScraper;

my @transientFiles;

my @resources = Scraping::loadResources();

my %extraMetadata;
my @extractIdentifiers;

# First pass: check for extra metadata
foreach (@resources) {
	my %res = %{$_};

	if (my ($fn) = $res{output} =~ /^transient\/(.*\.rdf)$/) {
		push @{$extraMetadata{$res{uri}}}, $res{output};

		if ($fn =~ /_hbo\.rdf$/) {
			my $ifn = $fn;
			$ifn =~ s/\.rdf$/_identifiers.rdf/;
			$ifn = 'transient/'.$ifn;

			push @extractIdentifiers, [$ifn, $res{output}];
			push @{$extraMetadata{$res{uri}}}, ${ifn};
		}
	}
}

foreach (@resources) {
	my %res = %{$_};

#	my ($title, $token);

	my ($scraperName) = $res{scraper} =~ /^\.\/scrape-(.*)(?:\.\w+)$/ or die "Unable to figure filename or scraper for $res{d}";

	if (!$onhold{$res{name}}) {
		push @{$filesByScraper{$scraperName."files"}}, $res{output};
	}

	my ($dir) = $res{output} =~ /(^.*)\/[^\/]+$/;
	$dirs{$dir} = 1;

	my @xm;

	if ($res{output} =~ /^transient\//) {
		push @transientFiles, $res{output};
	} else {
		if ($extraMetadata{$res{uri}}) {
			@xm = @{$extraMetadata{$res{uri}}};
		}
	}

	if (-f "overrides-$res{localName}.rdf") {
		push @xm, "overrides-$res{localName}.rdf";
	}

	print "$res{output}: $res{scraper} ",join(' ', (map {$_->[1]} @{$res{dataFiles}}), @xm, 'dirs'),"\n";
	print "\t", join(' ', $res{scraper},  "\"$res{uri}\"", @xm),"\n";
	print "\n";

	foreach (@{$res{dataFiles}}) {
		my ($dataUrl, $dataFile) = @{$_};
		print "${dataFile}:\n";
		print "\tsleep 5\n";
		print "\twget -O fetched/fetching.tmp '${dataUrl}' && mv fetched/fetching.tmp \$\@\n";
		print "\n";

		$dirs{'fetched'} = 1;
	}
}

print ".PHONY: dirs\n\n";

print "dirs:\n"; #, join(' ', keys(%dirs)), "\n";

foreach (keys(%dirs)) {
#	print "$_:\n";
	print "\tmkdir -p $_\n";
}
print "\n";

my @allfiles = keys(%filesByScraper);

while (my ($k, $v) = each %filesByScraper) {
	print "${k}: ",join(' ', @{$v}),"\n\n";
}

my @targets;
foreach (@extractIdentifiers) {
	my ($id, $orig) = @{$_};
	print "${id}: ${orig}\n";
	print "\t../python/show-local-identifiers.py \$< >\$\@\n\n";

	push @targets, $id;
}

if (@targets) {
	print "transientfiles: ",join(' ', @targets),"\n\n";

	unshift @allfiles, 'transientfiles';
}

print 'allfiles: ', join(' ', @allfiles),"\n\n";
