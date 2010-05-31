# Copyright (c) 2010 Joseph Walton <joe@kafsemo.org>
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

package Mivvi::File;

use strict;

use Carp;

use Mivvi::RdfXml;

my $RDF = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
my $DC = 'http://purl.org/dc/elements/1.1/';
my $DC_TITLE = "${DC}title";
my $DC_DESCRIPTION = "${DC}description";
my $DC_SOURCE = "${DC}source";
my $DC_DATE = "${DC}date";
my $MVI_EPISODENUMBER = 'http://mivvi.net/rdf#episodeNumber';
my $MVI_PRODUCTIONCODE = 'http://mivvi.net/rdf#productionCode';

my $BLANK_PREFIX = '_blank:';

sub new($$)
{
 my ($class, $uri) = @_;

 my $self = {
  URI => $uri,
  SEASONS => {},
  SEASON_URIS => {},
  PROPS_URI => {},
  PROPS_LIT => {}
 };

 return bless($self, $class);
}

sub _checkSeason($)
{
 my $season = shift;

 if ($season !~ /^([A-Z]|\d+)$/) {
  croak "Bad season ID: $season";
 }
}

sub _unique(@)
{
 my %m;

 foreach (@_) {
  $m{$_} = 1;
 }

 return keys(%m);
}

sub _uniqueSorted(@)
{
 return sort(_unique(@_));
}

sub addEpisode($$$$)
{
 my ($self, $season, $ep, $uri) = @_;

 _checkSeason($season);

 $ep = (0 + $ep);

 my $oldEp = $self->{SEASONS}->{$season}->{$ep};
 if ($oldEp) {
  croak 'Duplicate episode: '.sprintf('%dx%02d', $season,$ep);
 }

 $self->{SEASONS}->{$season}->{$ep} = $uri;
}

sub addSeason($$$)
{
 my ($self, $season, $uri) = @_;

 _checkSeason($season);

 my $oldSeason = $self->{SEASON_URIS}->{$season};
 if ($oldSeason) {
  croak "Duplicate season: $season";
 }

 if (not($uri)) {
  $uri = $BLANK_PREFIX.($self->{NEXT_BLANK_ID}++);
 }
 $self->{SEASON_URIS}->{$season} = $uri;

 return $uri;
}

sub setTitle($$$)
{
 my ($self, $uri, $title) = @_;

 $self->setLiteral($uri, $DC_TITLE, $title);
}

sub setDescription($$$)
{
 my ($self, $uri, $description) = @_;

 $self->setLiteral($uri, $DC_DESCRIPTION, $description);
}

sub setEpisodeNumber($$$)
{
 my ($self, $uri, $episodeNumber) = @_;

 $self->setLiteral($uri, $MVI_EPISODENUMBER, $episodeNumber);
}

sub setProductionCode($$$)
{
 my ($self, $uri, $productionCode) = @_;

 $self->setLiteral($uri, $MVI_PRODUCTIONCODE, $productionCode);
}

sub setDate($$$)
{
 my ($self, $uri, $date) = @_;

 $self->setLiteral($uri, $DC_DATE, $date);
}

sub setUri($$$$)
{
 my ($self, $uri, $pred, $object) = @_;

 $self->{PROPS_URI}->{$uri}->{$pred} = $object;
}

sub setLiteral($$$$)
{
 my ($self, $uri, $pred, $object) = @_;

 $self->{PROPS_LIT}->{$uri}->{$pred} = $object;
}

sub setSource($$)
{
 my ($self, $source) = @_;

 $self->setUri('', $DC_SOURCE, $source);
}

sub _consumeUri($$$)
{
 my ($self, $uri, $pred) = @_;

 return delete($self->{PROPS_URI}->{$uri}->{$pred});
}

sub _consumeLiteral($$$)
{
 my ($self, $uri, $pred) = @_;

 return delete $self->{PROPS_LIT}->{$uri}->{$pred};
}

sub _seasonOrderCompare($$)
{
 my ($a, $b) = @_;
 if (($a =~ /\d+/) && ($b =~ /\d+/)) {
  return $a <=> $b;
 } elsif ($a !~ /\d+/) {
  if ($b !~ /\d+/) {
   return $a cmp $b;
  } else {
   return 1;
  }
 } else {
  return -1;
 }
}

sub saveToRdfXml
{
 my $self = shift;
 my $outputFilename = shift;

 my %params = @_;

 my $comment = $params{COMMENT};

 my $tempFileName = "${outputFilename}.tmp";

 my $output;
 open($output, '>', $tempFileName) or die "Unable to open output file: $!";

 my $w = Mivvi::RdfXml::newXmlWriter(OUTPUT => $output, ENCODING => 'utf-8');

 if ($params{PREFIX_MAP}) {
  for my $ns (keys(%{$params{PREFIX_MAP}})) {
    $w->addPrefix($ns, $params{PREFIX_MAP}->{$ns});
  }
 }

 if ($params{FORCED_NS_DECLS}) {
  for my $ns (@{$params{FORCED_NS_DECLS}}) {
   $w->forceNSDecl($ns);
  }
 }

 $w->xmlDecl(undef, 'yes');

 if ($comment) {
  $w->comment($comment);
 }

 my $uri = $self->{URI};

 my $source = $self->_consumeUri('', $DC_SOURCE);

 Mivvi::RdfXml::startDoc($w, $uri, $self->_consumeLiteral($uri, $DC_TITLE), $source);

 Mivvi::RdfXml::startSeasons($w);

 foreach my $seasonCode (sort _seasonOrderCompare _unique(keys(%{$self->{SEASONS}}), keys(%{$self->{SEASON_URIS}}))) {
  my $s = $self->{SEASONS}->{$seasonCode};
  my @eps;
  foreach my $ep (sort {$a <=> $b} keys(%{$s})) {
   my $epUri = $s->{$ep};

   my @descriptions;
   my $d = $self->_consumeLiteral($epUri, $DC_DESCRIPTION);
   if ($d) {
    push @descriptions, $d;
   }

   # Core episode properties
   my $epData = {
    title => $self->_consumeLiteral($epUri, $DC_TITLE),
    date => $self->_consumeLiteral($epUri, $DC_DATE),
    href => $epUri,
    epNum => $self->_consumeLiteral($epUri, $MVI_EPISODENUMBER),
    sepNum => $ep,
    prodCode => $self->_consumeLiteral($epUri, $MVI_PRODUCTIONCODE),
    altTitles => \@descriptions
   };

   # Include any extra literals
   my @extra;

   foreach (keys(%{$self->{PROPS_LIT}->{$epUri}})) {
    push @extra, [Mivvi::RdfXml::splitNsUri($_)], $self->_consumeLiteral($epUri, $_);
   }

   if (@extra) {
    $epData->{extra} = \@extra;
   }

   push @eps, $epData;
  }

  my $seasonUri = $self->{SEASON_URIS}->{$seasonCode};
  my $seasonTitle;

  if ($seasonUri) {
   $seasonTitle = $self->_consumeLiteral($seasonUri, $DC_TITLE);

   if ($seasonUri =~ /^$BLANK_PREFIX/) {
    $seasonUri = undef;
   }
  }
  Mivvi::RdfXml::writeSeason($w, $seasonCode, $seasonTitle, $seasonUri, @eps);
 }

 Mivvi::RdfXml::endSeries($w);

 if ($source) {
  my $sourceTitle = $self->_consumeLiteral($source, $DC_TITLE);

  if ($sourceTitle) {
   $w->emptyTag([$RDF, 'Description'], [$RDF, 'about'] => $source,
                [$DC, 'title'] => $sourceTitle);
  }
 }

 # All other properties
 my $subj;

 for my $subj (_uniqueSorted(keys(%{$self->{PROPS_LIT}}), keys(%{$self->{PROPS_URI}}))) {
  # Are there any properties left?
  if (keys(%{$self->{PROPS_LIT}->{$subj}}) + keys(%{$self->{PROPS_URI}->{$subj}}) == 0) {
   next;
  }

  # Write all the properties
  # TODO Should sort them, for deterministic output
  $w->startTag([$RDF, 'Description'], [$RDF, 'about'] => $subj);
  my ($k, $v);
  while (($k, $v) = each(%{$self->{PROPS_LIT}->{$subj}})) {
   $w->dataElement([Mivvi::RdfXml::splitNsUri($k)], $v);
  }
  while (($k, $v) = each(%{$self->{PROPS_URI}->{$subj}})) {
   $w->emptyTag([Mivvi::RdfXml::splitNsUri($k)], [$RDF, 'resource'] => $v);
  }

  $w->endTag([$RDF, 'Description']);
 }

 Mivvi::RdfXml::endDoc($w);
 $w->end();

 close($output) or die "Unable to close output: $!";

 rename($tempFileName, $outputFilename) or die "Unable to rename output into place : $!";
}

1;
