include config.mk

PROGRAM=pack

.PHONY: all clean install uninstall

all: $(PROGRAM).1 $(PROGRAM).5

clean:
	rm -f $(PROGRAM).1 $(PROGRAM).5

install: all
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f $(PROGRAM).sh $(DESTDIR)$(PREFIX)/bin/$(PROGRAM)
	chmod 755 $(DESTDIR)$(PREFIX)/bin/$(PROGRAM)
	mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	cp -f $(PROGRAM).1 $(DESTDIR)$(MANPREFIX)/man1
	chmod 644 $(DESTDIR)$(MANPREFIX)/man1/$(PROGRAM).1
	mkdir -p $(DESTDIR)$(MANPREFIX)/man5
	cp -f $(PROGRAM).5 $(DESTDIR)$(MANPREFIX)/man5
	chmod 644 $(DESTDIR)$(MANPREFIX)/man5/$(PROGRAM).5

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(PROGRAM)
	rm -f $(DESTDIR)$(MANPREFIX)/man1/$(PROGRAM).1
	rm -f $(DESTDIR)$(MANPREFIX)/man5/$(PROGRAM).5

$(PROGRAM).1:
	$(SCDOC) < $(PROGRAM).1.scd > $@

$(PROGRAM).5:
	$(SCDOC) < $(PROGRAM).5.scd > $@
