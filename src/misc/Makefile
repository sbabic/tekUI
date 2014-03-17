
BASEDIR ?= ../..
include $(BASEDIR)/config

###############################################################################

LIBS = \
	$(LIBDIR)/libregion.a \
	$(LIBDIR)/libutf8.a \
	$(LIBDIR)/libpixconv.a \
	$(LIBDIR)/libimgcache.a \
	$(LIBDIR)/libcachemanager.a

$(OBJDIR)/libregion.lo: region.c
	$(CC) $(LIBCFLAGS) -o $@ -c region.c
$(OBJDIR)/libutf8.lo: utf8.c
	$(CC) $(LIBCFLAGS) -o $@ -c utf8.c
$(OBJDIR)/libpixconv.lo: pixconv.c
	$(CC) $(LIBCFLAGS) -o $@ -c pixconv.c
$(OBJDIR)/libimgcache.lo: imgcache.c
	$(CC) $(LIBCFLAGS) -o $@ -c imgcache.c
$(OBJDIR)/libcachemanager.lo: cachemanager.c
	$(CC) $(LIBCFLAGS) -o $@ -c cachemanager.c

$(LIBDIR)/libregion.a: \
	$(OBJDIR)/libregion.lo
	$(AR) $@ $?
$(LIBDIR)/libutf8.a: \
	$(OBJDIR)/libutf8.lo
	$(AR) $@ $?
$(LIBDIR)/libpixconv.a: \
	$(OBJDIR)/libpixconv.lo
	$(AR) $@ $?
$(LIBDIR)/libimgcache.a: \
	$(OBJDIR)/libimgcache.lo
	$(AR) $@ $?
$(LIBDIR)/libcachemanager.a: \
	$(OBJDIR)/libcachemanager.lo
	$(AR) $@ $?

###############################################################################

libs: $(LIBDIR) $(OBJDIR) $(LIBS)

tools:

modules:

clean: FORCE
	-$(RM) $(MODS) $(TOOLS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
