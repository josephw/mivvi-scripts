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

# Mivvi utility methods

import RDF

SEQNUM_PREFIX = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#_'

def DC(x):
 return RDF.Uri(string='http://purl.org/dc/elements/1.1/' + x)

def MVI(x):
  return RDF.Uri(string='http://mivvi.net/rdf#' + x)

def OWL(x):
  return RDF.Uri(string='http://www.w3.org/2002/07/owl#' + x)

def getContainerAndIndex(model, uri):
  for s in model.find_statements(RDF.Statement(object = uri)):
    pu = str(s.predicate.uri)
    if pu.startswith(SEQNUM_PREFIX):
      return (s.subject, int(pu[len(SEQNUM_PREFIX):]))
  return None

def details(model, uri):
  episode = RDF.Uri(string = uri)

  x = model.get_target(episode, DC('title'))
  if not(x):
    return None
  title = str(x)

  ci = getContainerAndIndex(model, episode)
  if not(ci):
    return None

  (episodes, epnum) = ci

  season = model.get_source(MVI('episodes'), episodes)
  if not(season):
    return None

  x = model.get_target(season, MVI('seasonNumber'))
  snum = x and str(x)

  ci = getContainerAndIndex(model, season)
  if not(ci):
    return None

  seasons = ci[0]

  series = model.get_source(MVI('seasons'), seasons)
  if not(series):
    return None

  x = model.get_target(series, DC('title'))
  seriesName = x and str(x)

  return [seriesName, snum, epnum, title]
