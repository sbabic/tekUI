
BASEDIR ?= ../..
include $(BASEDIR)/config

EXTRADEFS += $(LUA_DEFS) $(TEKUI_DEFS) -DDISPLAY_DRIVER=\"$(DISPLAY_DRIVER)\"

###############################################################################

DISPLAYS = display/x11$(DLLEXT) display/rawfb$(DLLEXT)
# DISPLAYS = display/windows$(DLLEXT)
# DISPLAYS = display/directfb$(DLLEXT)
# DISPLAYS = display/rawfb$(DLLEXT)

###############################################################################

MODS = region$(DLLEXT) exec$(DLLEXT) visual$(DLLEXT) string$(DLLEXT) support$(DLLEXT)

EXECLIBS = $(LIBDIR)/libhal.a $(LIBDIR)/libexec.a $(LIBDIR)/libtekc.a $(LIBDIR)/libtekdebug.a
VISUALLIBS = $(LIBDIR)/libvisual.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a
DISPLAYX11LIBS = $(LIBDIR)/libdisplay_x11.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a
DISPLAYDFBLIBS = $(LIBDIR)/libdisplay_directfb.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a
DISPLAYWINLIBS = $(LIBDIR)/libdisplay_win.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a
DISPLAYRAWFBLIBS = $(LIBDIR)/libdisplay_rawfb.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a

region$(DLLEXT): $(OBJDIR)/region.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/region.lo $(PLATFORM_LIBS) $(LUA_LIBS)

string$(DLLEXT): $(OBJDIR)/string.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/string.lo $(PLATFORM_LIBS) $(LUA_LIBS) -ltek

support$(DLLEXT): $(OBJDIR)/support.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/support.lo $(LUA_LIBS)

exec$(DLLEXT): $(OBJDIR)/exec_lua.lo $(EXECLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/exec_lua.lo -L$(LIBDIR) -lhal -lexec -ltekc -ltekdebug $(PLATFORM_LIBS) $(LUA_LIBS)

visual$(DLLEXT): $(OBJDIR)/visual_lua.lo $(OBJDIR)/visual_api.lo $(OBJDIR)/visual_io.lo $(VISUALLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/visual_lua.lo $(OBJDIR)/visual_api.lo $(OBJDIR)/visual_io.lo -L$(LIBDIR) -lvisual -ltek -ltekdebug $(LUA_LIBS) $(VISUAL_LIBS)

display/x11$(DLLEXT): $(OBJDIR)/x11_lua.lo $(DISPLAYX11LIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/x11_lua.lo -L$(LIBDIR) -ldisplay_x11 -ltek -ltekdebug $(X11_LIBS) $(LUA_LIBS)

display/directfb$(DLLEXT): $(OBJDIR)/directfb_lua.lo $(DISPLAYDFBLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/directfb_lua.lo -L$(LIBDIR) -ldisplay_directfb -ltek -ltekdebug $(DFB_LIBS) $(LUA_LIBS)

display/windows$(DLLEXT): $(OBJDIR)/windows_lua.lo $(DISPLAYWINLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/windows_lua.lo -L$(LIBDIR) -ldisplay_win -ltek -ltekdebug $(WIN_LIBS) $(LUA_LIBS)

display/nanox$(DLLEXT): $(OBJDIR)/nanox_lua.lo $(DISPLAYNANOXLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/nanox_lua.lo -L$(LIBDIR) -ldisplay_nanox -ltek -ltekdebug $(NANOX_LIBS) $(LUA_LIBS)

display/rawfb$(DLLEXT): $(OBJDIR)/rawfb_lua.lo $(DISPLAYRAWFBLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/rawfb_lua.lo -L$(LIBDIR) -ldisplay_rawfb -ltek -ltekdebug $(RAWFB_LIBS) $(LUA_LIBS)

$(OBJDIR)/region.lo: region.c
	$(CC) $(LIBCFLAGS) -o $@ -c region.c

$(OBJDIR)/string.lo: string.c
	$(CC) $(LIBCFLAGS) -o $@ -c string.c

$(OBJDIR)/support.lo: support.c
	$(CC) $(LIBCFLAGS) -o $@ -c support.c

$(OBJDIR)/exec_lua.lo: exec_lua.c
	$(CC) $(LIBCFLAGS) -o $@ -c exec_lua.c

$(OBJDIR)/visual_lua.lo: visual_lua.c visual_lua.h
	$(CC) $(LIBCFLAGS) -o $@ -c visual_lua.c
$(OBJDIR)/visual_api.lo: visual_api.c visual_lua.h
	$(CC) $(LIBCFLAGS) -o $@ -c visual_api.c
$(OBJDIR)/visual_io.lo: visual_io.c visual_lua.h
	$(CC) $(LIBCFLAGS) -o $@ -c visual_io.c

$(OBJDIR)/x11_lua.lo: display/x11_lua.c
	$(CC) $(LIBCFLAGS) -o $@ -c display/x11_lua.c

$(OBJDIR)/directfb_lua.lo: display/directfb_lua.c
	$(CC) $(LIBCFLAGS) -o $@ -c display/directfb_lua.c

$(OBJDIR)/windows_lua.lo: display/windows_lua.c
	$(CC) $(LIBCFLAGS) -o $@ -c display/windows_lua.c

$(OBJDIR)/rawfb_lua.lo: display/rawfb_lua.c
	$(CC) $(LIBCFLAGS) $(RAWFB_DEFS) -o $@ -c display/rawfb_lua.c

###############################################################################

modules: $(OBJDIR) $(MODS) $(DISPLAYS)

install:
	$(INSTALL_D) $(LUA_LIB)/tek/lib/display
	$(INSTALL_S) $(MODS) $(LUA_LIB)/tek/lib
	$(INSTALL_S) $(DISPLAYS) $(LUA_LIB)/tek/lib/display
	$(INSTALL_D) $(LUA_SHARE)/tek/lib
	$(INSTALL_F) debug.lua args.lua $(LUA_SHARE)/tek/lib

clean: FORCE
	-$(RM) $(MODS) $(DISPLAYS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
