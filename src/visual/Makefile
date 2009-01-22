
BASEDIR ?= ../..
include $(BASEDIR)/config

###############################################################################

LIBS = \
	$(LIBDIR)/libvisual.a

$(OBJDIR)/visual_mod.lo: \
	visual_all.c $(INCDIR)/tek/mod/visual.h
	$(CC) $(LIBCFLAGS) -o $@ -c visual_all.c

$(LIBDIR)/libvisual.a: \
	$(OBJDIR)/visual_mod.lo
	$(AR) $@ $?

###############################################################################

libs: $(LIBDIR) $(OBJDIR) $(LIBS)

tools:

modules:

clean: FORCE
	-$(RM) $(MODS) $(TOOLS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
