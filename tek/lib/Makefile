
BASEDIR ?= ../..
include $(BASEDIR)/config

EXTRADEFS += $(LUA_DEFS) $(TEKUI_DEFS) -DDISPLAY_DRIVER=\"$(DISPLAY_DRIVER)\"

###############################################################################

# primary display driver:
DISPLAYS = display/$(DISPLAY_DRIVER)$(DLLEXT)

# comment in additional (sub-) display driver(s) here:
# DISPLAYS += display/x11$(DLLEXT)
# DISPLAYS += display/directfb$(DLLEXT)

###############################################################################

MODS = region$(DLLEXT) exec$(DLLEXT) visual$(DLLEXT) string$(DLLEXT) support$(DLLEXT)

EXECLIBS = $(LIBDIR)/libhal.a $(LIBDIR)/libexec.a $(LIBDIR)/libtekc.a $(LIBDIR)/libtekdebug.a
VISUALLIBS = $(LIBDIR)/libvisual.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a
DISPLAYX11LIBS = $(LIBDIR)/libdisplay_x11.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a $(LIBDIR)/libutf8.a $(LIBDIR)/libpixconv.a
DISPLAYDFBLIBS = $(LIBDIR)/libdisplay_directfb.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a $(LIBDIR)/libutf8.a
DISPLAYWINLIBS = $(LIBDIR)/libdisplay_win.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a $(LIBDIR)/libutf8.a
DISPLAYRAWFBLIBS = $(LIBDIR)/libdisplay_rawfb.a $(LIBDIR)/libtek.a $(LIBDIR)/libtekdebug.a $(LIBDIR)/libregion.a $(LIBDIR)/libutf8.a $(LIBDIR)/libpixconv.a

region$(DLLEXT): $(OBJDIR)/region.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/region.lo $(PLATFORM_LIBS) $(LUA_LIBS) -lregion -ltekdebug

string$(DLLEXT): $(OBJDIR)/string.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/string.lo $(PLATFORM_LIBS) $(LUA_LIBS) -ltek -ltekdebug -lutf8

support$(DLLEXT): $(OBJDIR)/support.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/support.lo $(LUA_LIBS)

exec$(DLLEXT): $(OBJDIR)/exec_lua.lo $(EXECLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/exec_lua.lo -L$(LIBDIR) -lhal -lexec -ltekc -ltekdebug $(PLATFORM_LIBS) $(LUA_LIBS)

visual$(DLLEXT): $(OBJDIR)/visual_lua.lo $(OBJDIR)/visual_api.lo $(OBJDIR)/visual_io.lo $(VISUALLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/visual_lua.lo $(OBJDIR)/visual_api.lo $(OBJDIR)/visual_io.lo -L$(LIBDIR) -lvisual -lcachemanager -limgload -lpixconv -ltek -ltekdebug $(LUA_LIBS) $(TEKUI_LIBS)

display/x11$(DLLEXT): $(OBJDIR)/x11_lua.lo $(DISPLAYX11LIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/x11_lua.lo -L$(LIBDIR) -ldisplay_x11 $(X11_LIBS) -lutf8 -lpixconv -limgcache -ltek -ltekdebug $(LUA_LIBS)

display/directfb$(DLLEXT): $(OBJDIR)/directfb_lua.lo $(DISPLAYDFBLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/directfb_lua.lo -L$(LIBDIR) -ldisplay_directfb $(DIRECTFB_LIBS) -lutf8 -ltek -ltekdebug $(LUA_LIBS)

display/windows$(DLLEXT): $(OBJDIR)/windows_lua.lo $(DISPLAYWINLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/windows_lua.lo -L$(LIBDIR) -ldisplay_win $(WIN_LIBS) -lutf8 -ltek -ltekdebug $(LUA_LIBS)

display/rawfb$(DLLEXT): $(OBJDIR)/rawfb_lua.lo $(DISPLAYRAWFBLIBS)
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/rawfb_lua.lo -L$(LIBDIR) -ldisplay_rawfb -limgload $(RAWFB_LIBS) -lutf8 -lregion -limgcache -lpixconv -ltek -ltekdebug $(LUA_LIBS)

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
#
#	libluatekui.so and tekui runner

LUADISTDIR = $(BASEDIR)/../lua-5.1.5

LUA_TEKUI_DLL = $(BASEDIR)/libluatekui$(DLLEXT)
LUA_TEKUI_EXE_DLL = $(BASEDIR)/tekui_dll
LUA_TEKUI_EXE_STANDALONE = $(BASEDIR)/tekui

LUA_TEKUI_DEFS = $(LIBCFLAGS) -I $(LUADISTDIR)/src -I../../src/hal -DLUA_TEKUI_INCLUDE_CLASS_LIBRARY
LUA_TEKUI_LIBS = -L$(LIBDIR) $(TEKUI_LIBS)
LUA_TEKUI_DEFS += -I../../display_x11 $(X11_DEFS)
LUA_TEKUI_LIBS += $(X11_LIBS)
LUA_TEKUI_DEFS += -I../../display_rawfb $(RAWFB_DEFS)
LUA_TEKUI_LIBS += $(RAWFB_LIBS) 

$(LUA_TEKUI_DLL): $(OBJDIR)/linit_tekui.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/linit_tekui.lo $(LUA_DLLS)

$(OBJDIR)/linit_tekui.lo: linit_tekui.c
	$(CC) $(BINCFLAGS) -DLUA_USE_LINUX $(LUA_TEKUI_DEFS) -o $@ -c linit_tekui.c

$(OBJDIR)/luatekui.lo: $(LUADISTDIR)/src/lua.c
	$(CC) $(BINCFLAGS) -DLUA_USE_LINUX -c -o $@ $(LUADISTDIR)/src/lua.c

$(LUA_TEKUI_EXE_DLL): $(LUA_TEKUI_DLL) $(OBJDIR)/luatekui.lo
	$(CC) $(BINCFLAGS) -o $@ $(OBJDIR)/luatekui.lo -L$(BASEDIR) -lluatekui $(LUA_TEKUI_LIBS) -lreadline -lm -ldl -pthread
	
$(LUA_TEKUI_EXE_STANDALONE): $(OBJDIR)/linit_tekui.lo $(OBJDIR)/luatekui.lo $(LUADISTDIR)/src/lua.c
	$(CC) $(BINCFLAGS) -o $@ $(OBJDIR)/luatekui.lo $(OBJDIR)/linit_tekui.lo -L$(BASEDIR) $(LUA_TEKUI_LIBS) -Wl,-E -lreadline -lm -ldl -pthread
	
###############################################################################

dll: $(OBJDIR) $(LUA_TEKUI_DLL)

tools: dll $(OBJDIR) $(LUA_TEKUI_EXE_STANDALONE) $(LUA_TEKUI_EXE_DLL)

modules: $(OBJDIR) $(MODS) $(DISPLAYS)

install:
	$(INSTALL_D) $(LUA_LIB)/tek/lib/display
	$(INSTALL_S) $(MODS) $(LUA_LIB)/tek/lib
	$(INSTALL_S) $(DISPLAYS) $(LUA_LIB)/tek/lib/display
	$(INSTALL_D) $(LUA_SHARE)/tek/lib
	$(INSTALL_F) debug.lua args.lua $(LUA_SHARE)/tek/lib

clean: FORCE
	-$(RM) $(MODS) $(DISPLAYS) $(LIBS) $(LUA_TEKUI_DLL) $(LUA_TEKUI_EXE_DLL) $(LUA_TEKUI_EXE_STANDALONE)
	-$(RMDIR) $(OBJDIR)
