
BASEDIR ?= ../..
include $(BASEDIR)/config

###############################################################################

LIBS = $(LIBDIR)/libexec.a
# MODS = $(MODDIR)/exec.so
# TOOLS = $(BINDIR)/scanmodules $(BINDIR)/interval

$(OBJDIR)/exec_mod.lo: \
	exec_all.c exec_mod.h $(INCDIR)/tek/mod/exec.h
	$(CC) $(LIBCFLAGS) -o $@ -c exec_all.c

$(LIBDIR)/libexec.a: \
	$(OBJDIR)/exec_mod.lo
	$(AR) $@ $?

$(MODDIR)/exec.so: $(OBJDIR)/exec_mod.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/exec_mod.lo -L$(LIBDIR) -ltekc -ltekdebug $(PLATFORM_LIBS)

$(BINDIR)/scanmodules: tests/scanmodules.c
	$(CC) $(BINCFLAGS) $(BINLFLAGS) -o $@ $? -L$(LIBDIR) -ltekcmain -ltekdebug -ldl $(PLATFORM_LIBS)
$(BINDIR)/interval: tests/interval.c
	$(CC) $(BINCFLAGS) $(BINLFLAGS) -o $@ $? -L$(LIBDIR) -ltekcmain -ltekdebug -ldl $(PLATFORM_LIBS)

###############################################################################

libs: $(LIBDIR) $(OBJDIR) $(LIBS)

modules: $(OBJDIR) $(MODDIR) $(MODS)

tools: $(BINDIR) $(TOOLS)

clean: FORCE
	-$(RM) $(MODS) $(TOOLS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
