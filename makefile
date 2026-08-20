include config.mk

OBJS = pack.o sha256.o
OUT  = pack

.PHONY: clean install uninstall

all: $(OUT)

clean:
	rm -f $(OUT) $(OBJS) config.h

install: all
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f $(OUT) $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	cp -f $(OUT).1 $(DESTDIR)$(MANPREFIX)/man1

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(OUT)
	rm -f $(DESTDIR)$(MANPREFIX)/man1/$(OUT).1

$(OUT): $(OBJS)
	$(CC) -o $@ $^ $(LIBS) $(LDFLAGS)

config.h: config.def.h
	cp $^ $@

$(OBJS): config.h
	$(CC) $(CFLAGS) -c -o $@ $(@:.o=.c)
