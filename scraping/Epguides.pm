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

package Epguides;

use ScrapingUtil qw(trim month2Num);

# dd mmm yy
sub epguidesToIsoDate($)
{
  $_ = $_[0];

  if (/^\s*$/) {
    return '';
  } else {
    # Check for named month and slash-separated
    if (my ($d, $m, $y) = /(\d\d)\/([A-Z][a-z][a-z])\/(\d\d)/) {
      my $yy;
      if ($y <70) {
        $yy = 2000 + $y;
      } else {
        $yy = 1900 + $y;
      }
      return sprintf('%04d-%02d-%02d', $yy, month2Num($m), $d);
    }

    my ($d, $m, $y) = /\s*(\d+) ([A-Z][a-z]{2}) (\d+)\s*$/ or die "Unable to parse: $_";

       if ($y < 100) {
         if ($y < 20) {
        $y = 2000 + $y;
         } else {
           $y = 1900 + $y;
         }
       }
       return sprintf('%04d-%02d-%02d', $y, month2Num($m), $d);
  }
}

sub epNum($)
{
    my ($n) = @_;

    if (my ($rn) = $n =~ /^\s*(\d+)\./) {
        return $rn;
    } else {
        return '';
    }
}

sub splitCode($)
{
    my ($c) = @_;

    if ($c =~ /^\s*$/) {
        die "Bad season/episode code: $c";
    } else {
        if (my ($ssn, $ep) = $c =~ /^\s*([0-9A-Z]+)-\s*(\d+)$/) {
            return ($ssn, $ep);
        } else {
            die "Bad season/number code: $c";
		}
	}
}

sub scrapeline($)
{
	$_ = shift;

	# Check for TVRage format
	if (/tvrage\.com/) {
		if (my ($epNum, $season, $sepNum, $prodcode, $date, $url, $title) = /^(\d+)\s+(\d+)-(\d+)\s+(\S*)\s+(\d{2}\/[A-Z][a-z][a-z]\/\d\d)\s+.*<a href='(\S+)'>([^<]*)<\/a>$/)
		{
			my $isoDate = epguidesToIsoDate($date);
			$title =~ s/&amp;/&/g;
			if ($title =~ /&\w;/) {
				die "Unexpected HTML escape";
			}
			return [$epNum, $season, $sepNum, $prodcode, $isoDate, $url, $title];
		}
		else
		{
			return undef;
		}
	}	

	# Traditional format
	if (my ($epNum, $seasonAndEpisode, $prodcode, $date, $url, $title) = /^(?:<li>)?(.{4})(.{3}\S-.\d)(.{11,})(.{14})\s+<a.*href="(.*)">(.+)<\/a>\s*$/)
	{
		$epNum = epNum($epNum);
		my ($season, $sepNum) = splitCode($seasonAndEpisode);
		$prodcode = trim($prodcode);

		if ($season eq 'P') {
			$season = '0';
		}

		$title =~ s/&amp;/&/g;
		$title =~ s/&(#039|lsquo|rsquo);/'/g;

		if ($title =~ /&\w;/) {
			die "Unexpected HTML escape";
		}

		my $isoDate;

		if ($date && $date !~ /\s*UNAIRED\s*/ && $date !~ /^\s*\?/ && $date !~ /DVD only/) {
			$isoDate = epguidesToIsoDate($date);
		} else {
			$date = undef;
		}

		if ($prodcode =~ /^n\/a$/i) {
			$prodcode = undef;
		}

		if ($prodcode eq $epNum) {
			$prodcode = undef;
		}
		
		return [$epNum, $season, $sepNum, $prodcode, $isoDate, $url, $title];
	} else {
		return undef;
	}
}

sub reduce($)
{
	my $url = shift;

	if (my ($s, $e) = $url =~ /^http:\/\/www\.tvrage\.com\/([^\/]+|shows\/id-\d+)\/episodes\/(\d+)\/.*$/) {
		$url = "http://www.tvrage.com/$s/episodes/$e/#";
	} else {
		die "Unexpected TvRage URI: $url";
	}

	return $url;
}

1;
