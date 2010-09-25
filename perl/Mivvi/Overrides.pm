use strict;
 
package Mivvi::Overrides;
 
use RDF::Redland;

my $predOwlSameAs = new RDF::Redland::Node(new RDF::Redland::URI('http://www.w3.org/2002/07/owl#sameAs'));
my $predDcTitle = new RDF::Redland::Node(new RDF::Redland::URI('http://purl.org/dc/elements/1.1/title'));
my $predDcDescription = new RDF::Redland::Node(new RDF::Redland::URI('http://purl.org/dc/elements/1.1/description'));
my $predDcDate = new RDF::Redland::Node(new RDF::Redland::URI('http://purl.org/dc/elements/1.1/date'));

sub new($)
{
 my ($class) = @_;

 my $storage = RDF::Redland::Storage->new("hashes", "test", "new='yes',hash-type='memory'");
 my $model = RDF::Redland::Model->new($storage, "");

 my $self = {
  MODEL => $model
 };

 return bless($self, $class);
}

sub getSourcesSameAs($$)
{
 my ($self, $uri) = @_;

 my @sameAs;

 my $model = $self->{MODEL};
 foreach ($model->sources($predOwlSameAs, RDF::Redland::Node->new(RDF::Redland::URI->new($uri)))) {
  push @sameAs, $_->uri->as_string;
 }

 return @sameAs;
}

sub getDescriptions($$)
{
 my ($self, $uri) = @_;

 my @descriptions;

 my $model = $self->{MODEL};
 foreach ($model->targets(RDF::Redland::Node->new(RDF::Redland::URI->new($uri)), $predDcDescription)) {
  push @descriptions, $_->literal_value;
 }

 return @descriptions;
}

sub _getLiteral($$$)
{
 my ($self, $uri, $pred) = @_;

 my $model = $self->{MODEL};
 my $t = $model->target(RDF::Redland::Node->new(RDF::Redland::URI->new($uri)), $pred);
 if ($t) {
  return $t->literal_value;
 } else {
  return undef;
 }
}

sub getTitle($$)
{
 my ($self, $uri) = @_;

 return $self->_getLiteral($uri, $predDcTitle);
}

sub getDate($$)
{
 my ($self, $uri) = @_;

 return $self->_getLiteral($uri, $predDcDate);
}

sub load($$)
{
 my $self = shift;

 my ($filename) = @_;

 my $model = $self->{MODEL};

 my $f;
 open($f, '<:utf8', $filename) or die "Unable to open overrides file $filename: $!";

 while (<$f>) {
  next if /^\s*$/ || /^\s*\#/;

  my ($uri, $pred, $val) = /^<(\S+)>\t((?:dc|owl):\w+)\t(.*)$/ or die "Bad override line: $_";

  my ($s, $p, $o);

  $s = new RDF::Redland::URI($uri);

  if ($pred eq 'dc:title') {
   $p = $predDcTitle;
   $o = RDF::Redland::Node->new_literal($val);
  } elsif ($pred eq 'dc:description') {
   $p = $predDcDescription;
   $o = RDF::Redland::Node->new_literal($val);
  } elsif ($pred eq 'dc:date') {
   $p = $predDcDate;
   $o = RDF::Redland::Node->new_literal($val);
  } elsif ($pred eq 'owl:sameAs') {
   my ($objUri) = $val =~ /^<(.*)>$/ or die "Bad object URI: $val";
   $p = $predOwlSameAs;
   $o = RDF::Redland::Node->new(RDF::Redland::URI->new($objUri));
  } else {
   die "Bad override predicate: $pred";
  }

  $model->add($s, $p, $o);
 }
}

sub isPublished($$)
{
 my ($self,$uri) = @_;

 return $self->{PUBLISHED}->{$uri};
}

sub loadPublishedUris($$)
{
 my ($self, $publishedUrisFilename) = @_;

 my $f;

 open($f, '<', $publishedUrisFilename) or die "Unable to open published URI list $publishedUrisFilename: $!";
 while (<$f>) {
  chomp;
  $self->{PUBLISHED}->{$_} = 1;
 }
 close($f) or die "Unable to close published URI list: $!";
}

sub loadRdfXml($@)
{
 my ($self, @fn) = @_;

 my $model = $self->{MODEL};

 my $parser = new RDF::Redland::Parser(undef, 'application/rdf+xml');

 foreach (@fn) {
   my $uri = new RDF::Redland::URI('file:' . $_);
   $parser->parse_into_model($uri, $uri, $model);
 }
}

my $TEMP_URI_BASE = 'tag:kafsemo.org,2005:mtmp/';

sub tempUriFor($$$;$)
{
 my ($self, $series, $season, $episode) = @_;

 if ($season =~ /^\d+$/) {
  $season = int($season);
 }

 if ($episode) {
  return $TEMP_URI_BASE.sprintf('%s/%sx%d', $series, $season, $episode);
 } else {
  return $TEMP_URI_BASE.sprintf('%s/%s', $series, $season, $episode);
 }
}	

sub bestUriFor($$$$;$)
{
 my ($self, $origUri, $series, $season, $episode) = @_;

 my $model = $self->{MODEL};

 my $sa;

 # Is there an explicit override?
 $sa = $model->target(RDF::Redland::Node->new(RDF::Redland::URI->new($origUri)), $predOwlSameAs);
 if($sa) {
  my $u = $sa->uri->as_string;
  if ($self->{PUBLISHED}->{$origUri}) {
   $self->{PUBLISHED_OVERRIDES}->{$origUri} = $u;
  }
  return $u;
 }

 # Is there a temporary URI for this episode that specifies a better alternative?
 my $tempUri = $self->tempUriFor($series, $season, $episode);
 $sa = $model->target(RDF::Redland::Node->new(RDF::Redland::URI->new($tempUri)), $predOwlSameAs);
 if($sa && $sa->uri) {
  my $u = $sa->uri->as_string;
  if ($origUri && $self->{PUBLISHED}->{$origUri}) {
   $self->{PUBLISHED_OVERRIDES}->{$origUri} = $u;
  }
  return $u;
 }

 return undef;
}

sub getOverriddenPublishedUris($)
{
 my $self = shift;

 return $self->{PUBLISHED_OVERRIDES} || {};
}

1;
