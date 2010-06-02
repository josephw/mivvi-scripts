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

package Tvcom;

sub reduce($)
{
	my $uri = shift;

	if (my ($epid, $res, $frag) = $uri =~ /^http:\/\/(?:www\.)tv\.com\/.*\/episode\/(\d+)\/(.*?)(?:\?tag=.*?)?(#.*)?$/)
	{
		if ($frag) {
			return "http://www.tv.com/episode/${epid}/${res}${frag}";
		} else {
			return "http://www.tv.com/episode/${epid}/${res}";
		}
	} else {
		return $uri;
	}
}

sub seasonUriFor($$)
{
	my ($dataUrl, $seasonNumber) = @_;

	my $showid;

	if ($dataUrl =~ /^\d+$/) {
		$showid = $dataUrl;
	} else {
		($showid) = $dataUrl =~ /^http:\/\/(?:www\.)tv\.com\/.*\/show\/(\d+)\/episode\.html[\?]season=0$/ or die "Unable to decode $dataUrl";
	}

	if (!$seasonNumber || $seasonNumber !~ /^\d+$/) {
		return undef;
	}

	return "http://www.tv.com/show/${showid}/episode.html?season=${seasonNumber}#";
}

sub seasonTitle($)
{
	$_ = shift;

	if ($_ eq 'P' || $_ eq '0') {
		return 'Pilot';
	} elsif ($_ eq 'S') {
		return 'Specials';
	} elsif ($_ eq 'M') {
		return 'TV Movies';
	} elsif ($_ eq 'F') {
		return 'Films';
	} elsif ($_ eq 'V') {
		return 'Video';
	} elsif (/^\d+$/) {
		return "Season $_";
	} else {
		return undef;
	}
}

1;
