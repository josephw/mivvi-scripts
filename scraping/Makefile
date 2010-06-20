MIVVI_DATA_DIR=../../data
export MIVVI_DATA_DIR

PERL5LIB=../perl
export PERL5LIB

all: Makefile.scraping extras
	make -f $<

extras: $(MIVVI_DATA_DIR)/extras/the-larry-sanders-show_guests.rdf

Makefile.scraping: resources make-makefile.pl Scraping.pm tvcom-seasons Makefile
	./make-makefile.pl >Makefile.scraping.tmp && mv Makefile.scraping.tmp $@

tvcom-seasons:
	touch $@

fetched/imdb-guests-larry-sanders.html:
	mkdir -p fetched
	wget -O $@ 'http://www.imdb.com/title/tt0103466/epcast'

$(MIVVI_DATA_DIR)/epguides/the-larry-sanders-show.rdf:
	make -f Makefile.scraping $@

transient/the-larry-sanders-show_local-identifiers.rdf: $(MIVVI_DATA_DIR)/epguides/the-larry-sanders-show.rdf
	../python/show-local-identifiers.py $< >$@

$(MIVVI_DATA_DIR)/extras/the-larry-sanders-show_guests.rdf: fetched/imdb-guests-larry-sanders.html scrape-imdb-guests-larry-sanders.pl transient/the-larry-sanders-show_local-identifiers.rdf
	mkdir -p $(MIVVI_DATA_DIR)/extras
	./scrape-imdb-guests-larry-sanders.pl >$@.tmp transient/the-larry-sanders-show_local-identifiers.rdf
	mv -v $@.tmp $@

urimaint:
	for f in $(MIVVI_DATA_DIR)/*/*.rdf; do rapper $$f; done | ../perl/maintain-published-uris.pl $(MIVVI_DATA_DIR)/published-uris
