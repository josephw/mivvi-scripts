#!/usr/bin/perl -w

# Generate a Mivvi RDF/XML file using the Mivvi::File class

use strict;

use Mivvi::File;

# URI for the series we're writing
my $seriesUri = 'http://www.example.com/#';

my $mf = Mivvi::File->new($seriesUri);
$mf->setTitle($seriesUri, 'Example Show');

# Add, and name, a season
$mf->addSeason('1', 'http://www.example.com/1/#');
$mf->setTitle('http://www.example.com/1/#', 'First Season');

# Generic data for each episode
for (1 .. 5) {
  my $uri = "http://www.example.com/1/$_#";
  $mf->addEpisode('1', $_, $uri);
  $mf->setTitle($uri, "Episode $_");
}

# Extra information about a specific episode
$mf->setDate('http://www.example.com/1/1#', '2010-05-10');

# Save the result
$mf->saveToRdfXml('output-example-show.rdf');
