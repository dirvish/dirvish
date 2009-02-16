#
# Dirvish Makefile
# $Rev: 657 $
# $Date: 2009-02-08 00:40:34 +0100 (So, 08 Feb 2009) $
# $Author: tex $
# $HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/Makefile $
#

INSTALL=/usr/bin/install
BINDIR=$(DESTDIR)/usr/bin
SBINDIR=$(DESTDIR)/usr/sbin
LIBDIR=$(DESTDIR)/usr/lib/perl5
CFGDIR ?= $(DESTDIR)/etc/dirvish

MAN1FILES=doc/dirvish-locate.1
MAN5FILES=doc/dirvish.conf.5
MAN8FILES=doc/dirvish.8 doc/dirvish-expire.8 doc/dirvish-runall.8
DOCFILES=doc/RELEASE.txt doc/INSTALL.txt doc/FAQ.txt doc/TODO.txt doc/debian.howto.txt
BINFILES=dirvish.pl Dirvish.pm dirvish-expire.pl dirvish-locate.pl dirvish-restore.pl dirvish-runall.pl

.PHONY: all install clean check

all: $(BINFILES) $(MAN1FILES) $(MAN5FILES) $(MAN8FILES) $(DOCFILES) 

$(BINFILES): FORCE
	perl -c $@
FORCE:

svn: clean
	svn commit
	svn update
	
%.1: %.pod 
	pod2man $< > $@

%.5: %.pod
	pod2man $< > $@

%.8: %.pod
	pod2man $< > $@
	
%.txt: %.pod
	pod2text $< > $@

clean:
	rm -f $(patsubst %.pod,%.1,$(MAN1FILES))
	rm -f $(patsubst %.pod,%.5,$(MAN5FILES)) 
	rm -f $(patsubst %.pod,%.8,$(MAN8FILES))
	rm -f $(patsubst %.pod,%.txt,$(DOCFILES))

install: $(BINFILES)
	$(INSTALL) -d $(BINDIR) $(SBINDIR) $(CFGDIR) $(LIBDIR)
	$(INSTALL) -c -m 600 init/dirvish-cronjob $(CFGDIR)
	$(INSTALL) -c -m 755 dirvish.pl $(SBINDIR)/dirvish
	$(INSTALL) -c -m 755 dirvish-expire.pl $(SBINDIR)/dirvish-expire
	$(INSTALL) -c -m 755 dirvish-locate.pl $(BINDIR)/dirvish-locate
	$(INSTALL) -c -m 755 dirvish-restore.pl $(BINDIR)/dirvish-restore
	$(INSTALL) -c -m 755 dirvish-runall.pl $(SBINDIR)/dirvish-runall
	$(INSTALL) -c -m 600 Dirvish.pm $(LIBDIR)/Dirvish.pm
