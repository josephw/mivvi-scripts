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

package ScrapingUtil;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(trim month2Num withFragment);

my %m2n;
my @mn = ('jan', 'feb', 'mar', 'apr', 'may', 'jun',
          'jul', 'aug', 'sep', 'oct', 'nov', 'dec');
@m2n{@mn} = 1 .. @mn;

# Month number
sub month2Num($)
{
       my $m = shift;

       $m = lc(substr($m, 0, 3));

       my $n = $m2n{$m} or die "No month number for $m";

       return $n;
}

# Normalise whitespace, and remove all leading and trailing blanks
sub trim($)
{
  $_ = pop;

  s/^\s+//;
  s/\s+$//;
  s/\s+/ /g;

  return $_;
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


# Parse out 'a.k.a.'s and alternate titles for episodes
sub parseAkas($)
{
	my $tvtTitle = shift;
	my @alts;

	if (my ($t, $aka) = $tvtTitle =~ /^(.*?)\s*[\(\[](?:a\.k\.a\.?,?|aka,?\s)\s*(.+)[\)\]]$/i)
	{
		while (my ($a, $b) = $aka =~ /^(.*?),\s+(?:a\.k\.a\.|aka\s)\s*(.*)$/i) {
			push @alts, $a;
			$aka = $b;
		}
		push @alts, $aka;
		$tvtTitle = $t;
	}

	return ($tvtTitle, @alts);
}

use XML::LibXML;

#  Load HTML as an XML::LibXML document
sub loadAsXml($)
{
	my $dataFile = shift;

	open(INPUT, '-|', "../tidy.sh <${dataFile} || true") or die "Unable to open input: $!";

	my $p = new XML::LibXML();

	my $d = $p->parse_fh(\*INPUT) or die "Unable to parse: $!";
#	my $d = $p->parse_html_file($dataFile, {recover => 1});

	if (!$d) {
		die "Unable to parse $dataFile: $!";
	}

#	$d->documentElement()->setAttributeNS('http://www.w3.org/1999/xhtml', 'x:class', 'dummy');

	return $d;
}

sub newXPathContext()
{
 my $xpc = XML::LibXML::XPathContext->new();
 $xpc->registerNs('x', 'http://www.w3.org/1999/xhtml');
 return $xpc;
}

1;
