-------------------------------------------------------------------------------
--
--	tek.ui.class.display
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		Display ${subclasses(Display)}
--
--		This class manages a display.
--
--	ATTRIBUTES::
--		- {{AspectX [IG]}} (number)
--			- X component of the display's aspect ratio
--		- {{AspectY [IG]}} (number)
--			- Y component of the display's aspect ratio
--
--	IMPLEMENTS::
--		- Display:closeFont() - Closes font
--		- Display.createPixMap() - Creates a pixmap from picture file data
--		- Display:getFontAttrs() - Gets font attributes
--		- Display.getPixmap() - Gets a a pixmap from the cache
--		- Display:colorToRGB() - Converts a color specification to RGB
--		- Display:getTime() - Gets system time
--		- Display.loadPixmap() - Loads a pixmap from the file system
--		- Display:openFont() - Opens a named font
--		- Display:openVisual() - Opens a visual
--		- Display:sleep() - Sleeps for a period of time
--
--	STYLE PROPERTIES::
--		- {{font}}
--		- {{font-fixed}}
--		- {{font-huge}}
--		- {{font-large}}
--		- {{font-menu}}
--		- {{font-small}}
--		- {{rgb-active}}
--		- {{rgb-active-detail}}
--		- {{rgb-background}}
--		- {{rgb-border-focus}}
--		- {{rgb-border-legend}}
--		- {{rgb-border-rim}}
--		- {{rgb-border-shadow}}
--		- {{rgb-border-shine}}
--		- {{rgb-cursor}}
--		- {{rgb-cursor-detail}}
--		- {{rgb-dark}}
--		- {{rgb-detail}}
--		- {{rgb-disabled}}
--		- {{rgb-disabled-detail}}
--		- {{rgb-disabled-detail-shine}}
--		- {{rgb-fill}}
--		- {{rgb-focus}}
--		- {{rgb-focus-detail}}
--		- {{rgb-group}}
--		- {{rgb-half-shadow}}
--		- {{rgb-half-shine}}
--		- {{rgb-hover}}
--		- {{rgb-hover-detail}}
--		- {{rgb-list}}
--		- {{rgb-list-active}}
--		- {{rgb-list-active-detail}}
--		- {{rgb-list-detail}}
--		- {{rgb-list-alt}}
--		- {{rgb-menu}}
--		- {{rgb-menu-active}}
--		- {{rgb-menu-active-detail}}
--		- {{rgb-menu-detail}}
--		- {{rgb-outline}}
--		- {{rgb-shadow}}
--		- {{rgb-shine}}
--		- {{rgb-user1}}
--		- {{rgb-user2}}
--		- {{rgb-user3}}
--		- {{rgb-user4}}
--
--	OVERRIDES::
--		- Class.new()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"

local Element = ui.require("element", 17)
local Visual = ui.loadLibrary("visual", 4)

local floor = math.floor
local open = io.open
local pairs = pairs
local tonumber = tonumber
local unpack = unpack

module("tek.ui.class.display", tek.ui.class.element)
_VERSION = "Display 25.1"

local Display = _M

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
local DEF_RGB_FOCUS      = "#e05014"

local DEF_MAINFONT  = "sans-serif,helvetica,arial,Vera:14"
local DEF_SMALLFONT = "sans-serif,helvetica,arial,Vera:12"
local DEF_MENUFONT  = "sans-serif,helvetica,arial,Vera:14"
local DEF_FIXEDFONT = "monospace,fixed,courier new,VeraMono:14"
local DEF_LARGEFONT = "sans-serif,helvetica,arial,Vera:18"
local DEF_HUGEFONT  = "sans-serif,utopia,arial,Vera:24"

local ColorDefaults =
{
	["background"] = DEF_RGB_BACK,
	["dark"] = DEF_RGB_DETAIL,
	["outline"] = DEF_RGB_SHINE,
	["fill"] = DEF_RGB_FILL,
	["active"] = DEF_RGB_HALFSHADOW,
	["focus"] = DEF_RGB_BACK,
	["hover"] = DEF_RGB_HALFSHINE,
	["disabled"] = DEF_RGB_BACK,
	["detail"] = DEF_RGB_DETAIL,
	["active-detail"] = DEF_RGB_DETAIL,
	["focus-detail"] = DEF_RGB_DETAIL,
	["hover-detail"] = DEF_RGB_DETAIL,
	["disabled-detail"] = DEF_RGB_SHADOW,
	["disabled-detail-shine"] = DEF_RGB_HALFSHINE,
	["border-shine"] = DEF_RGB_HALFSHINE,
	["border-shadow"] = DEF_RGB_SHADOW,
	["border-rim"] = DEF_RGB_DETAIL,
	["border-focus"] = DEF_RGB_FOCUS,
	["border-legend"] = DEF_RGB_DETAIL,
	["menu"] = DEF_RGB_BACK,
	["menu-detail"] = DEF_RGB_DETAIL,
	["menu-active"] = DEF_RGB_FILL,
	["menu-active-detail"] = DEF_RGB_SHINE,
	["list"] = DEF_RGB_BACK,
	["list-alt"] = DEF_RGB_HALFSHINE,
	["list-detail"] = DEF_RGB_DETAIL,
	["list-active"] = DEF_RGB_FILL,
	["list-active-detail"] = DEF_RGB_SHINE,
	["cursor"] = DEF_RGB_FILL,
	["cursor-detail"] = DEF_RGB_SHINE,
	["group"] = DEF_RGB_HALFSHADOW,
	["shadow"] = DEF_RGB_SHADOW,
	["shine"] = DEF_RGB_SHINE,
	["half-shadow"] = DEF_RGB_HALFSHADOW,
	["half-shine"] = DEF_RGB_HALFSHINE,
	["paper"] = DEF_RGB_SHINE,
	["ink"] = DEF_RGB_DETAIL,
	["user1"] = DEF_RGB_DETAIL,
	["user2"] = DEF_RGB_DETAIL,
	["user3"] = DEF_RGB_DETAIL,
	["user4"] = DEF_RGB_DETAIL,
	["black"] =   "#000",
	["red"] =     "#f00",
	["lime"] =    "#0f0",
	["yellow"] =  "#ff0",
	["blue"] =    "#00f",
	["fuchsia"] = "#f0f",
	["aqua"] =    "#0ff",
	["white"] =   "#fff",
	["gray"] =    "#808080",
	["maroon"] =  "#800000",
	["green"] =   "#008000",
	["olive"] =   "#808000",
	["navy"] =    "#000080",
	["purple"] =  "#800080",
	["teal"] =    "#008080",
	["silver"] =  "#c0c0c0",
	["orange"] =  "#ffa500",
}

local FontDefaults =
{
	-- cache name : propname : default
	["ui-fixed"] = { "font-fixed", DEF_FIXEDFONT },
	["ui-huge"] = { "font-huge", DEF_HUGEFONT },
	["ui-large"] = { "font-large", DEF_LARGEFONT },
	["ui-main"] = { "font", DEF_MAINFONT },
	["ui-menu"] = { "font-menu", DEF_MENUFONT },
	["ui-small"] = { "font-small", DEF_SMALLFONT },
}
FontDefaults[""] = FontDefaults["ui-main"]

local PixmapCache = { }

-------------------------------------------------------------------------------
--	image, width, height, transparency = Display.createPixmap(picture):
--	Creates a pixmap object from data in a picture file format. Currently
--	only the PPM file format is recognized.
-------------------------------------------------------------------------------

Display.createPixmap = Visual.createPixmap

-------------------------------------------------------------------------------
--	image, width, height, transparency = Display.loadPixmap(filename): Creates
--	a pixmap object from an image file in the file system. Currently only the
--	PPM file format is recognized.
-------------------------------------------------------------------------------

function Display.loadPixmap(fname)
	local f = open(fname, "rb")
	if f then
		local img, w, h, trans = createPixmap(f:read("*a"))
		f:close()
		if img then
			return img, w, h, trans
		end
	end
	db.warn("loading '%s' failed", fname)
	return false
end

-------------------------------------------------------------------------------
--	image, width, height, transparency = Display.getPixmap(fname): Gets a
--	pixmap object, either by loading it from the filesystem or by retrieving
--	it from the cache.
-------------------------------------------------------------------------------

function Display.getPixmap(fname)
	if PixmapCache[fname] then
		db.info("got cache copy for '%s'", fname)
		return unpack(PixmapCache[fname])
	end
	local pm, w, h, trans = loadPixmap(fname)
	if pm then
		PixmapCache[fname] = { pm, w, h, trans }
	end
	return pm, w, h, trans
end

-------------------------------------------------------------------------------
--	a, r, g, b = hexToRGB(colspec) - Converts a hexadecimal string color
--	specification to RGB and an opacity in the range from 0 to 255.
--	Valid color specifications are {{#rrggbb}}, {{#aarrggbb}} (each component
--	is noted in 8 bit hexadecimal) and {{#rgb}} (each color component is noted
--	in 4 bit hexadecimal).
-------------------------------------------------------------------------------

function Display.hexToRGB(col)
	local r, g, b = col:match("^%s*%#(%x%x)(%x%x)(%x%x)%s*$")
	if r then
		return 255, tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
	end
	r, g, b = col:match("^%s*%#(%x)(%x)(%x)%s*$")
	if r then
		r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
		return 255, r * 16 + r, g * 16 + g, b * 16 + b
	end
	local a
	a, r, g, b = col:match("^%s*%#(%x%x)(%x%x)(%x%x)(%x%x)%s*$")
	if a then
		return tonumber(r, 16), tonumber(r, 16), tonumber(g, 16), 
			tonumber(b, 16)
	end
end

-------------------------------------------------------------------------------
--	wait:
-------------------------------------------------------------------------------

Display.wait = Visual.wait

-------------------------------------------------------------------------------
--	getMsg:
-------------------------------------------------------------------------------

Display.getMsg = Visual.getMsg

-------------------------------------------------------------------------------
--	sleep:
-------------------------------------------------------------------------------

Display.sleep = Visual.sleep

-------------------------------------------------------------------------------
--	Display:getTime(): Gets the system time.
-------------------------------------------------------------------------------

Display.getTime = Visual.getTime

-------------------------------------------------------------------------------
--	Display:openDrawable(): Open a drawable
-------------------------------------------------------------------------------

Display.openDrawable = Visual.open

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Display.new(class, self)
	self = self or { }
	self.AspectX = self.AspectX or 1
	self.AspectY = self.AspectY or 1
	self.FontCache = { }
	return Element.new(class, self)
end

-------------------------------------------------------------------------------
--	w, h = fitMinAspect(w, h, iw, ih[, evenodd]) - Fit to size, considering
--	the display's aspect ratio. If the optional {{evenodd}} is {{0}}, even
--	numbers are returned, if it is {{1}}, odd numbers are returned.
-------------------------------------------------------------------------------

function Display:fitMinAspect(w, h, iw, ih, round)
	local ax, ay = self.AspectX, self.AspectY
	if w * ih * ay / (ax * iw) > h then
		w = h * ax * iw / (ay * ih)
	else
		h = w * ih * ay / (ax * iw)
	end
	if round then
		return floor(w / 2) * 2 + round, floor(h / 2) * 2 + round
	end
	return floor(w), floor(h)
end

-------------------------------------------------------------------------------
--	a, r, g, b = colorToRGB(key): Gets the r, g, b values of a color. The color
--	can be a hexadecimal RGB specification or a symbolic name.
-------------------------------------------------------------------------------

function Display:colorToRGB(key)
	return self.hexToRGB(self.Properties["rgb-" .. key] or
		ColorDefaults[key] or key)
end

-------------------------------------------------------------------------------
--	font = openFont(fontname): Opens the named font. For a discussion
--	of the {{fontname}} format, see [[#tek.ui.class.text : Text]].
-------------------------------------------------------------------------------

function Display:openFont(fname)
	local fname = fname or ""
	if not self.FontCache[fname] then
		local name, size = fname:match("^([^:]*)%s*:?%s*(%d*)$")
		local defname = FontDefaults[name]
		local deff = defname and (self.Properties[defname[1]] or defname[2])
		if deff then
			local nname, nsize = deff:match("^([^:]*):?(%d*)$")
			if size == "" then
				size = nsize
			end
			name = nname
		end
		size = tonumber(size)
		for name in name:gmatch("%s*([^,]*)%s*,?") do
			if name == "" then
				name = FontDefaults[""][2]:match("^([^:,]*),?[^:]*:?(%d*)$")
			end
			db.info("Open font: '%s' -> '%s:%d'", fname, name, size or -1)
			local font = Visual.openFont(name, size)
			if font then
				local r = { font, font:getAttrs { }, fname, name }
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
--	closeFont(font): Closes the specified font. Always returns '''false'''.
-------------------------------------------------------------------------------

function Display:closeFont(display, font)
	return false
end

-------------------------------------------------------------------------------
--	h, up, ut = getFontAttrs(font): Returns the font attributes height,
--	underline position and underline thickness.
-------------------------------------------------------------------------------

function Display:getFontAttrs(font)
	local a = self.FontCache[font][2]
	return a.Height, a.UlPosition, a.UlThickness
end
