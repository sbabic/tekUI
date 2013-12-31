
BASEDIR ?= ../..
include $(BASEDIR)/config

EXTRADEFS += $(RAWFB_DEFS)

###############################################################################

LIBS = \
	$(LIBDIR)/libdisplay_rawfb.a

$(OBJDIR)/display_rfb_all.lo: \
	display_rfb_all.c display_rfb_mod.h display_rfb_mod.c display_rfb_api.c \
		display_rfb_region.c display_rfb_font.c display_rfb_draw.c \
		vnc/display_rfb_vnc.c
	$(CC) $(LIBCFLAGS) -o $@ -c display_rfb_all.c

$(LIBDIR)/libdisplay_rawfb.a: \
	$(OBJDIR)/display_rfb_all.lo
	$(AR) $@ $?

###############################################################################

libs: $(LIBDIR) $(OBJDIR) $(LIBS)

tools:

modules:

clean: FORCE
	-$(RM) $(MODS) $(TOOLS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
