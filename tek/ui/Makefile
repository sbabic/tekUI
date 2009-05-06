
BASEDIR ?= ../..
include $(BASEDIR)/config

EXTRADEFS += $(LUA_DEFS)

CLASSES = \
	class/application.lua \
	class/area.lua \
	class/border.lua \
	class/button.lua \
	class/canvas.lua \
	class/checkmark.lua \
	class/dirlist.lua \
	class/display.lua \
	class/drawable.lua \
	class/drawhook.lua \
	class/element.lua \
	class/family.lua \
	class/floattext.lua \
	class/frame.lua \
	class/gadget.lua \
	class/gauge.lua \
	class/group.lua \
	class/handle.lua \
	class/image.lua \
	class/imagegadget.lua \
	class/listgadget.lua \
	class/listview.lua \
	class/menuitem.lua \
	class/numeric.lua \
	class/pagegroup.lua \
	class/popitem.lua \
	class/poplist.lua \
	class/popupwindow.lua \
	class/radiobutton.lua \
	class/scrollbar.lua \
	class/scrollgroup.lua \
	class/slider.lua \
	class/spacer.lua \
	class/text.lua \
	class/textinput.lua \
	class/theme.lua \
	class/window.lua
BORDERS = border/default.lua
HOOKS = hook/ripple.lua
IMAGES = \
	image/arrowdown.lua \
	image/arrowleft.lua \
	image/arrowright.lua \
	image/arrowup.lua \
	image/check.lua \
	image/file.lua \
	image/radio.lua
STYLES = \
	style/internal.css \
	style/monochrome.css \
	style/tutorial.css \
	style/industrial.css \
	style/desktop.css
FONTS = \
	font/Vera.ttf \
	font/VeraMono.ttf
CURSORS = cursor/cursor-green.png
CATALOGS1 = \
	locale/schulze-mueller.de/tekui-demo/en \
	locale/schulze-mueller.de/tekui-demo/de
CATALOGS2 = \
	locale/schulze-mueller.de/dirlist-class/en \
	locale/schulze-mueller.de/dirlist-class/de

###############################################################################

MODS = layout/default$(DLLEXT)

layout/default$(DLLEXT): $(OBJDIR)/default.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/default.lo $(LUA_DLLS)

$(OBJDIR)/default.lo: layout/default.c
	$(CC) $(LIBCFLAGS) -o $@ -c layout/default.c

###############################################################################

modules: $(OBJDIR) $(MODS)

install:
	$(INSTALL) -d $(LUA_LIB)/tek/ui/layout
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/layout
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/border
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/hook
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/image
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/class
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/font
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/cursor
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/style
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/locale/schulze-mueller.de/tekui-demo
	$(INSTALL) -d $(LUA_SHARE)/tek/ui/locale/schulze-mueller.de/dirlist-class
	$(INSTALL) -s layout/default$(DLLEXT) $(LUA_LIB)/tek/ui/layout
	$(INSTALL) $(CLASSES) $(LUA_SHARE)/tek/ui/class
	$(INSTALL) $(BORDERS) $(LUA_SHARE)/tek/ui/border
	$(INSTALL) $(HOOKS) $(LUA_SHARE)/tek/ui/hook
	$(INSTALL) $(IMAGES) $(LUA_SHARE)/tek/ui/image
	$(INSTALL) $(FONTS) $(LUA_SHARE)/tek/ui/font
	$(INSTALL) $(CURSORS) $(LUA_SHARE)/tek/ui/cursor
	$(INSTALL) $(STYLES) $(LUA_SHARE)/tek/ui/style
	$(INSTALL) $(CATALOGS1) $(LUA_SHARE)/tek/ui/locale/schulze-mueller.de/tekui-demo
	$(INSTALL) $(CATALOGS2) $(LUA_SHARE)/tek/ui/locale/schulze-mueller.de/dirlist-class

clean: FORCE
	-$(RM) $(MODS) $(LIBS)
	-$(RMDIR) $(OBJDIR)
