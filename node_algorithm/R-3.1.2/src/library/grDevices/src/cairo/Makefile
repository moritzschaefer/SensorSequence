#
# ${R_HOME}/src/library/grDevices/src/cairo/Makefile


srcdir = .
top_srcdir = ../../../../..

top_builddir = ../../../../..
subdir = src/library/grDevices/src/cairo
R_HOME = $(top_builddir)

pkg = grDevices

include $(top_builddir)/Makeconf

## need to find bitmap.h
ALL_CPPFLAGS = $(R_XTRA_CPPFLAGS) -pthread -I/usr/include/pango-1.0 -I/usr/include/cairo -I/usr/include/glib-2.0 -I/usr/lib/x86_64-linux-gnu/glib-2.0/include -I/usr/include/pixman-1 -I/usr/include/freetype2 -I/usr/include/libpng12   \
  -I$(top_srcdir)/src/modules/X11 $(CPPFLAGS) $(DEFS)
ALL_CFLAGS = $(ALL_CFLAGS_LO)

## the X11 module is not made at all if BUILD_X11 is false.
SOURCES = cairoBM.c
DEPENDS = $(SOURCES:.c=.d)
OBJECTS = $(SOURCES:.c=.o) $(top_builddir)/src/modules/X11/rbitmap.o

cairo_la = cairo$(SHLIB_EXT)
## AIX needs LIBM
cairo_la_LIBADD = -lpangocairo-1.0 -lpango-1.0 -lgobject-2.0 -lglib-2.0 -lpng12 -lz -lcairo   -ljpeg -lpng -lz $(LIBR) $(LIBM) # $(LIBINTL)

all: Makedeps
	@$(MAKE) R

Makefile: $(srcdir)/Makefile.in  $(top_builddir)/config.status
	@cd $(top_builddir) && $(SHELL) ./config.status $(subdir)/$@

Makedeps: Makefile $(DEPENDS)
	@cat $(DEPENDS) >> Makefile
	@touch $@

R: Makefile
	@$(MAKE) $(cairo_la)
	@$(MKINSTALLDIRS) $(top_builddir)/library/$(pkg)/libs
	@cp $(cairo_la) $(top_builddir)/library/$(pkg)/libs

$(top_builddir)/src/modules/X11/rbitmap.o:
	(cd $(top_builddir)/src/modules/X11; $(MAKE) rbitmap.o)

$(cairo_la): $(OBJECTS)
	$(SHLIB_LINK) -o $@ $(OBJECTS) $(cairo_la_LIBADD)

mostlyclean: clean
clean:
	@-rm -rf .libs _libs Makedeps *.d *.o $(cairo_la)
distclean: clean
	@-rm -f Makefile
maintainer-clean: distclean

## Automagically generated dependencies:
