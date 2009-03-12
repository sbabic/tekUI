
BASEDIR ?= ../..
include $(BASEDIR)/config

EXTRADEFS += $(LUA_DEFS) -DDISPLAY_DRIVER=\"$(DISPLAY_DRIVER)\"

###############################################################################

DISPLAYS = display/x11$(DLLEXT)
# DISPLAYS = display/windows$(DLLEXT)
# DISPLAYS = display/directfb$(DLLEXT)

###############################################################################

MODS = region$(DLLEXT) exec$(DLLEXT) visual$(DLLEXT)

EXECLIBS = $(LIBDIR)/libhal.a $(LIBDIR)/libexec.a $(LIBDIR)/libtekc.a $(LIBDIR)/libtekdebug.a
VISUALLIBS = $(LIBDIR)/libvisual.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a
DISPLAYX11LIBS = $(LIBDIR)/libdisplay_x11.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a
DISPLAYDFBLIBS = $(LIBDIR)/libdisplay_directfb.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a
DISPLAYWINLIBS = $(LIBDIR)/libdisplay_win.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a

region$(DLLEXT): $(OBJDIR)/region.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/region.lo $(PLATFORM_LIBS) $(LUA_DLLS)

exec$(DLLEXT): $(OBJDIR)/exec_lua.lo $(EXECLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/exec_lua.lo -L$(LIBDIR) -lhal -lexec -ltekc -ltekdebug $(PLATFORM_LIBS) $(LUA_DLLS)

visual$(DLLEXT): $(OBJDIR)/visual_lua.lo $(OBJDIR)/visual_api.lo $(VISUALLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/visual_lua.lo $(OBJDIR)/visual_api.lo -L$(LIBDIR) -lvisual -ltek -ltekdebug $(LUA_DLLS)

display/x11$(DLLEXT): $(OBJDIR)/x11_lua.lo $(DISPLAYX11LIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/x11_lua.lo -L$(LIBDIR) -ldisplay_x11 -ltek -ltekdebug $(X11_LIBS)

display/directfb$(DLLEXT): $(OBJDIR)/directfb_lua.lo $(DISPLAYDFBLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/directfb_lua.lo -L$(LIBDIR) -ldisplay_directfb -ltek -ltekdebug $(DFB_LIBS)

display/windows$(DLLEXT): $(OBJDIR)/windows_lua.lo $(DISPLAYWINLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/windows_lua.lo -L$(LIBDIR) -ldisplay_win -ltek -ltekdebug $(WIN_LIBS) $(LUA_DLLS)

$(OBJDIR)/region.lo: region.c
	$(CC) $(LIBCFLAGS) -o $@ -c region.c

$(OBJDIR)/exec_lua.lo: exec_lua.c
	$(CC) $(LIBCFLAGS) -o $@ -c exec_lua.c

$(OBJDIR)/visual_lua.lo: visual_lua.c visual_lua.h
	$(CC) $(LIBCFLAGS) -o $@ -c visual_lua.c
$(OBJDIR)/visual_api.lo: visual_api.c visual_lua.h
	$(CC) $(LIBCFLAGS) -o $@ -c visual_api.c

$(OBJDIR)/x11_lua.lo: display/x11_lua.c
	$(CC) $(LIBCFLAGS) -o $@ -c display/x11_lua.c

$(OBJDIR)/directfb_lua.lo: display/directfb_lua.c
	$(CC) $(LIBCFLAGS) -o $@ -c display/directfb_lua.c

$(OBJDIR)/windows_lua.lo: display/windows_lua.c
	$(CC) $(LIBCFLAGS) -o $@ -c display/windows_lua.c

###############################################################################

modules: $(OBJDIR) $(MODS) $(DISPLAYS)

install:
	$(INSTALL) -d $(LUA_LIB)/tek/lib/display
	$(INSTALL) -s $(MODS) $(LUA_LIB)/tek/lib
	$(INSTALL) -s $(DISPLAYS) $(LUA_LIB)/tek/lib/display
	$(INSTALL) -d $(LUA_SHARE)/tek/lib
	$(INSTALL) debug.lua $(LUA_SHARE)/tek/lib

clean: FORCE
	-$(RM) $(MODS) $(DISPLAYS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
