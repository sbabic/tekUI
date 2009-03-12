
BASEDIR ?= ../..
include $(BASEDIR)/config

EXTRADEFS += $(X11_DEFS)

###############################################################################

LIBS = \
	$(LIBDIR)/libdisplay_x11.a

$(OBJDIR)/display_x11_all.lo: \
	display_x11_all.c display_x11_mod.h display_x11_mod.c display_x11_api.c \
		display_x11_inst.c display_x11_font.c display_x11_utf8.c
	$(CC) $(LIBCFLAGS) -o $@ -c display_x11_all.c

$(LIBDIR)/libdisplay_x11.a: \
	$(OBJDIR)/display_x11_all.lo
	$(AR) $@ $?

###############################################################################

libs: $(LIBDIR) $(OBJDIR) $(LIBS)

tools:

modules:

clean: FORCE
	-$(RM) $(MODS) $(TOOLS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
