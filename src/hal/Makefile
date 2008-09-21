
BASEDIR ?= ../..
include $(BASEDIR)/config

###############################################################################

LIBS = $(LIBDIR)/libhal.a
# MODS = $(MODDIR)/hal.so

$(OBJDIR)/hal_mod.lo: hal_mod.c hal_mod.h $(INCDIR)/tek/mod/hal.h
	$(CC) $(LIBCFLAGS) -o $@ -c hal_mod.c
$(OBJDIR)/hal.lo: $(PLATFORM)/hal.c hal_mod.h $(INCDIR)/tek/mod/hal.h
	$(CC) $(LIBCFLAGS) -o $@ -c $(PLATFORM)/hal.c

$(LIBDIR)/libhal.a: \
		$(OBJDIR)/hal_mod.lo $(OBJDIR)/hal.lo
	$(AR) $@ $?

$(MODDIR)/hal.so: $(OBJDIR)/hal_mod.lo $(OBJDIR)/hal.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/hal_mod.lo $(OBJDIR)/hal.lo -L$(LIBDIR) -ltekc -ltekdebug $(PLATFORM_LIBS)

###############################################################################

libs: $(LIBDIR) $(OBJDIR) $(LIBS)

modules: $(OBJDIR) $(MODDIR) $(MODS)

tools:

clean: FORCE
	-$(RM) $(MODS) $(TOOLS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
