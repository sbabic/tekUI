-------------------------------------------------------------------------------
--
--	tek.ui.class.display
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		Display
--
--	OVERVIEW::
--		This class manages a display.
--
--	IMPLEMENTS::
--		- Display:closeFont() - Close font
--		- Display:getFontAttrs() - Get font attributes
--		- Display:getTime() - Get system time
--		- Display:openFont() - Open a named font
--		- Display:openVisual() - Open a visual
--		- Display:sleep() - Sleep for a period of time
--		- Display:getTextSize() - Get size of text rendered with a given font
--		- Display:wait() - Wait for a list of visuals
--
--	STYLE PROPERTIES::
--		- {{rgb-dark}}
--		- {{rgb-shadow}}
--		- {{rgb-half-shadow}}
--		- {{rgb-half-shine}}
--		- {{rgb-shine}}
--		- {{rgb-light}}
--		- {{rgb-background}}
--		- {{rgb-fill}}
--		- {{rgb-active}}
--		- {{rgb-focus}}
--		- {{rgb-hover}}
--		- {{rgb-disabled}}
--		- {{rgb-detail}}
--		- {{rgb-active-detail}}
--		- {{rgb-focus-detail}}
--		- {{rgb-hover-detail}}
--		- {{rgb-disabled-detail}}
--		- {{rgb-disabled-detail2}}
--		- {{rgb-border-shine}}
--		- {{rgb-border-shadow}}
--		- {{rgb-border-rim}}
--		- {{rgb-border-focus}}
--		- {{rgb-border-legend}}
--		- {{rgb-menu}}
--		- {{rgb-menu-detail}}
--		- {{rgb-menu-active}}
--		- {{rgb-menu-active-detail}}
--		- {{rgb-list}}
--		- {{rgb-list2}}
--		- {{rgb-list-detail}}
--		- {{rgb-list-active}}
--		- {{rgb-list-active-detail}}
--		- {{rgb-group}}
--		- {{rgb-cursor}}
--		- {{rgb-cursor-detail}}
--
--	OVERRIDES::
--		- Class.new()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local assert = assert
local ipairs = ipairs
local pairs = pairs
local type = type
local tonumber = tonumber
local Element = require "tek.ui.class.element"
local Visual = require "tek.lib.visual"

module("tek.ui.class.display", tek.ui.class.element)
_VERSION = "Display 7.0"

-------------------------------------------------------------------------------
--	Class data and constants:
-------------------------------------------------------------------------------

local DEF_RGB_BACK       = "#d2d2d2"
local DEF_RGB_DETAIL     = "#000"
local DEF_RGB_SHINE      = "#fff"
local DEF_RGB_FILL       = "#6e82a0"
local DEF_RGB_SHADOW     = "#777"
local DEF_RGB_HALFSHADOW = "#bebebe"
local DEF_RGB_HALFSHINE  = "#e1e1e1"
local DEF_RGB_CURSOR     = "#c85014"

-- local DEF_RGB_BLACK      = "#000"
-- local DEF_RGB_RED        = "#f00"
-- local DEF_RGB_LIME       = "#0f0"
-- local DEF_RGB_YELLOW     = "#ff0"
-- local DEF_RGB_BLUE       = "#00f"
-- local DEF_RGB_FUCHSIA    = "#f0f"
-- local DEF_RGB_AQUA       = "#0ff"
-- local DEF_RGB_WHITE      = "#fff"
-- local DEF_RGB_GRAY       = "#808080"
-- local DEF_RGB_MAROON     = "#800000"
-- local DEF_RGB_GREEN      = "#008000"
-- local DEF_RGB_OLIVE      = "#808000"
-- local DEF_RGB_NAVY       = "#000080"
-- local DEF_RGB_PURPLE     = "#800080"
-- local DEF_RGB_TEAL       = "#008080"
-- local DEF_RGB_SILVER     = "#c0c0c0"
-- local DEF_RGB_ORANGE     = "#ffa500"

local DEF_MAINFONT  = "sans-serif,helvetica,Vera:12"
local DEF_SMALLFONT = "sans-serif,helvetica,Vera:10"
local DEF_MENUFONT  = "sans-serif,helvetica,Vera:14"
local DEF_FIXEDFONT = "monospace,fixed,VeraMono:14"
local DEF_LARGEFONT = "sans-serif,helvetica,Vera:20"
local DEF_HUGEFONT  = "sans-serif,helvetica,Vera:28"

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Display = _M

function Display.new(class, self)
	self = self or { }
	self.RGBTab = { }
	self.PenTab = { }
	self.ColorNames = { }
	self.DefFonts = self.DefFonts or { }
	self.DefFonts["default-font"] =
		self.DefFonts["default-font"] or DEF_MAINFONT
	self.DefFonts["default-small-font"] = 
		self.DefFonts["default-small-font"] or DEF_SMALLFONT
	self.DefFonts["default-menu-font"] = 
		self.DefFonts["default-menu-font"] or DEF_MENUFONT
	self.DefFonts["default-fixed-font"] = 
		self.DefFonts["default-fixed-font"] or DEF_FIXEDFONT
	self.DefFonts["default-large-font"] = 
		self.DefFonts["default-large-font"] or DEF_LARGEFONT
	self.DefFonts["default-huge-font"] = 
		self.DefFonts["default-huge-font"] or DEF_HUGEFONT
	self.DefFonts[""] = self.DefFonts[""] or self.DefFonts["default-font"]
	self.FontCache = { }
	return Element.new(class, self)
end

local function matchrgb(col, def)
	for i = 1, 2 do
		local r, g, b = col:match("%#(%x%x)(%x%x)(%x%x)")
		if r then
			r, g, b = tonumber("0x" .. r), tonumber("0x" .. g), 
				tonumber("0x" .. b)
			return r, g, b
		end
		r, g, b = col:match("%#(%x)(%x)(%x)")
		if r then
			r, g, b = tonumber("0x" .. r), tonumber("0x" .. g), 
				tonumber("0x" .. b)
			r = r * 16 + r
			g = g * 16 + g
			b = b * 16 + b
			return r, g, b
		end
		db.warn("'%s' : invalid RGB specification", col)
		col = def
	end
end

function Display:allocRGB(data, num, key, def)
	local col = self:getProperty(data[1], data[2], "rgb-" .. key) or def
	local r, g, b = matchrgb(col, def)
	if r then
		local rgbtab, pentab = data[3], data[4]
		local idx = rgbtab[col]
		if not idx then
			data[5] = data[5] + 1
			idx = data[5]
			rgbtab[col] = idx
			rgbtab[idx] = { r, g, b }
		end
		pentab[num] = idx
		data[6][key] = num
		return r, g, b
	end
end

function Display:getProperties(p, pclass)
	local pens = self.PenTab
	-- properties, pclass, rgbtab, pentab, numrgb, colornames:
	local alloc = { p, pclass, self.RGBTab, self.PenTab, 0, self.ColorNames }
	self:allocRGB(alloc, ui.PEN_DARK, "dark", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_SHADOW, "shadow", DEF_RGB_SHADOW)
	self:allocRGB(alloc, ui.PEN_HALFSHADOW, "half-shadow", DEF_RGB_HALFSHADOW)
	self:allocRGB(alloc, ui.PEN_HALFSHINE, "half-shine", DEF_RGB_HALFSHINE)
	self:allocRGB(alloc, ui.PEN_SHINE, "shine", DEF_RGB_SHINE)
	self:allocRGB(alloc, ui.PEN_LIGHT, "light", DEF_RGB_SHINE)
	self:allocRGB(alloc, ui.PEN_BACKGROUND, "background", DEF_RGB_BACK)
	self:allocRGB(alloc, ui.PEN_FILL, "fill", DEF_RGB_FILL)
	self:allocRGB(alloc, ui.PEN_ACTIVE, "active", DEF_RGB_HALFSHADOW)
	self:allocRGB(alloc, ui.PEN_FOCUS, "focus", DEF_RGB_BACK)
	self:allocRGB(alloc, ui.PEN_HOVER, "hover", DEF_RGB_HALFSHINE)
	self:allocRGB(alloc, ui.PEN_DISABLED, "disabled", DEF_RGB_BACK)
	self:allocRGB(alloc, ui.PEN_DETAIL, "detail", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_ACTIVEDETAIL, "active-detail", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_FOCUSDETAIL, "focus-detail", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_HOVERDETAIL, "hover-detail", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_DISABLEDDETAIL, "disabled-detail", 
		DEF_RGB_SHADOW)
	self:allocRGB(alloc, ui.PEN_DISABLEDDETAIL2, "disabled-detail2", 
		DEF_RGB_HALFSHINE)
	self:allocRGB(alloc, ui.PEN_BORDERSHINE, "border-shine", DEF_RGB_HALFSHINE)
	self:allocRGB(alloc, ui.PEN_BORDERSHADOW, "border-shadow", DEF_RGB_SHADOW)
	self:allocRGB(alloc, ui.PEN_BORDERRIM, "border-rim", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_BORDERFOCUS, "border-focus", DEF_RGB_CURSOR)
	self:allocRGB(alloc, ui.PEN_BORDERLEGEND, "border-legend", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_MENU, "menu", DEF_RGB_BACK)
	self:allocRGB(alloc, ui.PEN_MENUDETAIL, "menu-detail", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_MENUACTIVE, "menu-active", DEF_RGB_FILL)
	self:allocRGB(alloc, ui.PEN_MENUACTIVEDETAIL, "menu-active-detail",
		DEF_RGB_SHINE)
	self:allocRGB(alloc, ui.PEN_LIST, "list", DEF_RGB_BACK)
	self:allocRGB(alloc, ui.PEN_LIST2, "list2", DEF_RGB_HALFSHINE)
	self:allocRGB(alloc, ui.PEN_LISTDETAIL, "list-detail", DEF_RGB_DETAIL)
	self:allocRGB(alloc, ui.PEN_LISTACTIVE, "list-active", DEF_RGB_FILL)
	self:allocRGB(alloc, ui.PEN_LISTACTIVEDETAIL, "list-active-detail",
		DEF_RGB_SHINE)
	self:allocRGB(alloc, ui.PEN_GROUP, "group", DEF_RGB_HALFSHADOW)
	self:allocRGB(alloc, ui.PEN_CURSOR, "cursor", DEF_RGB_CURSOR)
	self:allocRGB(alloc, ui.PEN_CURSORDETAIL, "cursor-detail", DEF_RGB_SHINE)
	Element.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	width, height = Display:getTextSize(font, text): Returns the width and
--	height of the specified {{text}} when it is rendered with the given
--	{{font}}.
-------------------------------------------------------------------------------

function Display:getTextSize(...)
	return Visual.textsize(...)
end

-------------------------------------------------------------------------------
--	font = Display:openFont(fontname): Opens the named font. For a discussion
--	of the fontname format, see [[#tek.ui.class.text : Text]].
-------------------------------------------------------------------------------

function Display:openFont(fname)
	fname = fname or ""
	if not self.FontCache[fname] then
		local deff = self.DefFonts
		local name, size = fname:match("^([^:]*):?(%d*)$")
		if deff[name] then
			local nname, nsize = deff[name]:match("^([^:]*):?(%d*)$")
			if size == "" then
				size = nsize
			end
			name = nname
		end
		size = size ~= "" and tonumber(size) or nil
		for name in name:gmatch("%s*([^,]*)%s*,?") do
			if name ~= "" then
				db.info("Fontname: %s -> %s:%d", fname, name, size or -1)
				local font = Visual.openfont(name, size)
				if font then
					local r = { font, font:getattrs { }, fname, name }
					self.FontCache[fname] = r
					self.FontCache[font] = r
					return font
				end
			end
		end
		return
	end
	return self.FontCache[fname][1]
end

-------------------------------------------------------------------------------
--	Display:closeFont(font): Closes the specified font
-------------------------------------------------------------------------------

function Display:closeFont(display, font)
end

-------------------------------------------------------------------------------
--	Display:getFontAttrs(font): Returns the font attributes height,
--	underline position and underline thickness.
-------------------------------------------------------------------------------

function Display:getFontAttrs(font)
	local a = self.FontCache[font][2]
	return a.Height, a.UlPosition, a.UlThickness
end

-------------------------------------------------------------------------------
--	wait:
-------------------------------------------------------------------------------

function Display:wait(...)
	return Visual.wait(...)
end

-------------------------------------------------------------------------------
--	sleep:
-------------------------------------------------------------------------------

function Display:sleep(...)
	return Visual.sleep(...)
end

-------------------------------------------------------------------------------
--	getTime:
-------------------------------------------------------------------------------

function Display:getTime(...)
	return Visual.gettime(...)
end

-------------------------------------------------------------------------------
--	openVisual:
-------------------------------------------------------------------------------

function Display:openVisual(...)
	return Visual.open(...)
end
