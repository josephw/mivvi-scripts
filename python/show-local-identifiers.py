#!/usr/bin/python

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

import RDF

import urlparse
import urllib

from sys import argv, stderr, exit
from os import getcwd, stat

import Mivvi
from datetime import date,timedelta
from re import compile

if len(argv) < 2:
  print >>stderr,"Usage: show-local-identifiers.py file.rdf ..."
  exit(5)

parser = RDF.Parser()

predType = RDF.NS('http://www.w3.org/1999/02/22-rdf-syntax-ns#')['type']
typeSeries = RDF.Node(Mivvi.MVI('Series'))
typeEpisode = RDF.Node(Mivvi.MVI('Episode'))

def mtmp(series,part=''):
  return RDF.Node(uri_string = 'tag:kafsemo.org,2005:mtmp/' + series + '/' + part)

idxPrefix = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#_'

def produceSeasonStatements(model, name, season, target):
  snum = model.get_target(season, RDF.Node(Mivvi.MVI('seasonNumber')))
  if snum == None:
    return
  snum = str(snum.literal_value['string'])
  target.append(RDF.Statement(mtmp(name, snum), Mivvi.OWL('sameAs'), season))

  eps = model.get_target(season, Mivvi.MVI('episodes'))
  for s in model.find_statements(RDF.Statement(eps, None, None)):
    ps = str(s.predicate.uri)
    if ps.startswith(idxPrefix):
      pnum = int(ps[len(idxPrefix):])
      if model.contains_statement(RDF.Statement(s.object, predType, typeEpisode)):
        target.append(RDF.Statement(mtmp(name, snum + 'x' + str(pnum)), Mivvi.OWL('sameAs'), s.object))

def produceStatements(model, name, series, target):
  target.append(RDF.Statement(mtmp(name), Mivvi.OWL('sameAs'), series))

  ssns = model.get_target(series, Mivvi.MVI('seasons'))
  for s in model.find_statements(RDF.Statement(ssns, None, None)):
    if model.contains_statement(RDF.Statement(s.object, predType, RDF.Node(Mivvi.MVI('Season')))):
      produceSeasonStatements(model, name, s.object, target)

targetModel = RDF.Model(RDF.HashStorage('memory', options="hash-type='memory'"))

for f in argv[1:]:
  model = RDF.Model(RDF.HashStorage('memory', options="hash-type='memory'"))
  url = urlparse.urljoin('file:' + urllib.pathname2url(getcwd()) + '/', f)

  i = url.rindex('/')
  if i >= 0:
    name = url[i+1:]
  else:
    name = url

  i = name.index('.')
  if i >= 0:
    name = name[:i]

  i = name.find('_')
  if i >= 0:
    name = name[:i]


  parser.parse_into_model(model, url)

  for s in model.find_statements(RDF.Statement(None, predType, typeSeries)):
    series = s.subject
    if series.is_resource():
      produceStatements(model, name, series, targetModel)

ser = RDF.RDFXMLSerializer()
ser.set_namespace('owl', Mivvi.OWL(''))

s = ser.serialize_model_to_string(targetModel)

print s
