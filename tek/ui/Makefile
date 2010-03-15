
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
	class/drawhook.lua \
	class/element.lua \
	class/family.lua \
	class/floattext.lua \
	class/frame.lua \
	class/widget.lua \
	class/gauge.lua \
	class/group.lua \
	class/handle.lua \
	class/image.lua \
	class/imagewidget.lua \
	class/layout.lua \
	class/lister.lua \
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
	class/window.lua
BORDERS = border/default.lua
HOOKS = hook/ripple.lua
IMAGES = \
	image/arrowdown.lua \
	image/arrowleft.lua \
	image/arrowright.lua \
	image/arrowup.lua \
	image/checkmark.lua \
	image/file.lua \
	image/radiobutton.lua
STYLES = \
	style/dark.css \
	style/desktop.css \
	style/industrial.css \
	style/default.css \
	style/monochrome.css \
	style/tutorial.css \
	style/desktop.lua
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

MODS = layout/default$(DLLEXT) support$(DLLEXT)

layout/default$(DLLEXT): $(OBJDIR)/default.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/default.lo $(LUA_DLLS)

support$(DLLEXT): $(OBJDIR)/support.lo
	$(CC) $(MODCFLAGS) -o $@ $(OBJDIR)/support.lo $(LUA_DLLS)

$(OBJDIR)/default.lo: layout/default.c
	$(CC) $(LIBCFLAGS) -o $@ -c layout/default.c

$(OBJDIR)/support.lo: support.c
	$(CC) $(LIBCFLAGS) -o $@ -c support.c

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
	$(INSTALL) -s support$(DLLEXT) $(LUA_LIB)/tek/ui
	$(INSTALL) layout/fixed.lua $(LUA_SHARE)/tek/ui/layout
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
