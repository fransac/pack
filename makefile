include config.mk

PROGRAM=pack

.PHONY: install uninstall

install: all
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f $(PROGRAM).sh $(DESTDIR)$(PREFIX)/bin/$(PROGRAM)
	mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	cp -f $(PROGRAM).1 $(DESTDIR)$(MANPREFIX)/man1

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(PROGRAM)
	rm -f $(DESTDIR)$(MANPREFIX)/man1/$(PROGRAM).1
