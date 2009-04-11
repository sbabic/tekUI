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
--		- {{font}}
--		- {{font-fixed}}
--		- {{font-huge}}
--		- {{font-large}}
--		- {{font-menu}}
--		- {{font-small}}
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
_VERSION = "Display 9.0"

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

local DEF_MAINFONT  = "sans-serif,helvetica,arial,Vera:14"
local DEF_SMALLFONT = "sans-serif,helvetica,arial,Vera:12"
local DEF_MENUFONT  = "sans-serif,helvetica,arial,Vera:14"
local DEF_FIXEDFONT = "monospace,fixed,courier new,VeraMono:14"
local DEF_LARGEFONT = "sans-serif,helvetica,arial,Vera:18"
local DEF_HUGEFONT  = "sans-serif,helvetica,arial,Vera:24"

local ColorDefaults =
{
	{ "background", DEF_RGB_BACK },
	{ "dark", DEF_RGB_DETAIL },
	{ "light", DEF_RGB_SHINE },
	{ "fill", DEF_RGB_FILL },
	{ "active", DEF_RGB_HALFSHADOW },
	{ "focus", DEF_RGB_BACK },
	{ "hover", DEF_RGB_HALFSHINE },
	{ "disabled", DEF_RGB_BACK },
	{ "detail", DEF_RGB_DETAIL },
	{ "active-detail", DEF_RGB_DETAIL },
	{ "focus-detail", DEF_RGB_DETAIL },
	{ "hover-detail", DEF_RGB_DETAIL },
	{ "disabled-detail", DEF_RGB_SHADOW },
	{ "disabled-detail2", DEF_RGB_HALFSHINE },
	{ "border-shine", DEF_RGB_HALFSHINE },
	{ "border-shadow", DEF_RGB_SHADOW },
	{ "border-rim", DEF_RGB_DETAIL },
	{ "border-focus", DEF_RGB_CURSOR },
	{ "border-legend", DEF_RGB_DETAIL },
	{ "menu", DEF_RGB_BACK },
	{ "menu-detail", DEF_RGB_DETAIL },
	{ "menu-active", DEF_RGB_FILL },
	{ "menu-active-detail", DEF_RGB_SHINE },
	{ "list", DEF_RGB_BACK },
	{ "list2", DEF_RGB_HALFSHINE },
	{ "list-detail", DEF_RGB_DETAIL },
	{ "list-active", DEF_RGB_FILL },
	{ "list-active-detail", DEF_RGB_SHINE },
	{ "cursor", DEF_RGB_CURSOR },
	{ "cursor-detail", DEF_RGB_SHINE },
	{ "group", DEF_RGB_HALFSHADOW },
	{ "shadow", DEF_RGB_SHADOW },
	{ "shine", DEF_RGB_SHINE },
	{ "half-shadow", DEF_RGB_HALFSHADOW },
	{ "half-shine", DEF_RGB_HALFSHINE },
}

local FontDefaults =
{
	-- cache name : propname : default
	["ui-main"] = { "font", DEF_MAINFONT },
	["ui-small"] = { "font-small", DEF_SMALLFONT },
	["ui-menu"] = { "font-menu", DEF_MENUFONT },
	["ui-fixed"] = { "font-fixed", DEF_FIXEDFONT },
	["ui-large"] = { "font-large", DEF_LARGEFONT },
	["ui-huge"] = { "font-huge", DEF_HUGEFONT },
}
FontDefaults[""] = FontDefaults["ui-main"]


-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Display = _M

function Display.new(class, self)
	self = self or { }
	self.RGBTab = { }
	self.PenTab = { }
	self.ColorNames = { }
	self.FontTab = self.FontTab or { }
	self.FontCache = { }
	return Element.new(class, self)
end

-------------------------------------------------------------------------------
--	allocPens(visual, pentable): Allocates the colors managed by the
--	Display from the specified {{visual}}, and places the resulting
--	pens in {{pentable}}.
-------------------------------------------------------------------------------

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

function Display:allocPens(visual, pentable)
	for i, color in ipairs(ColorDefaults) do
		local name, defrgb = color[1], color[2]
		local rgb = self.RGBTab[i] or defrgb
		pentable[i] = visual:allocpen(matchrgb(rgb, defrgb))
		pentable[name] = pentable[i]
	end
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function Display:getProperties(p, pclass)
	for i, color in ipairs(ColorDefaults) do
		self.RGBTab[i] = self.RGBTab[i] or
			self:getProperty(p, pclass, "rgb-" .. color[1])
	end
	local ft = self.FontTab
	for cfname, font in pairs(FontDefaults) do
		ft[cfname] = ft[cfname] or self:getProperty(p, pclass, font[1])
	end
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
	local fname = fname or ""
	if not self.FontCache[fname] then
		local name, size = fname:match("^([^:]*):?(%d*)$")
		local deff = self.FontTab[name] or
			FontDefaults[name] and FontDefaults[name][2]
		if deff then
			local nname, nsize = deff:match("^([^:]*):?(%d*)$")
			if size == "" then
				size = nsize
			end
			name = nname
		end
		size = size ~= "" and tonumber(size) or nil
		for name in name:gmatch("%s*([^,]*)%s*,?") do
			if name == "" then
				name = FontDefaults[""][2]:match("^([^:,]*),?[^:]*:?(%d*)$")
			end
			db.info("Open font: '%s' -> '%s:%d'", fname, name, size or -1)
			local font = Visual.openfont(name, size)
			if font then
				local r = { font, font:getattrs { }, fname, name }
				self.FontCache[fname] = r
				self.FontCache[font] = r
				return font
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
--	getmsg:
-------------------------------------------------------------------------------

function Display:getmsg(...)
	return Visual.getmsg(...)
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
