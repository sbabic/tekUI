-------------------------------------------------------------------------------
--
--	tek.ui.class.theme
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		Theme
--
--	IMPLEMENTS::
--		- Theme.getStyleSheet() - get a stylesheet for a named theme
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local Class = require "tek.class"
local getenv = os.getenv
local insert = table.insert
local ipairs = ipairs
local min = math.min
local open = io.open
local tonumber = tonumber

module("tek.ui.class.theme", tek.class)
_VERSION = "Theme 6.0"
local Theme = _M

local DEF_STYLESHEET =
{ 
	-- element classes:

	["tek.ui.class.area"] = {
		["margin"] = 1,
	},

	["tek.ui.class.checkmark"] = {
		["padding"] = 0,
		["margin"] = 0,
		["border-width"] = 1,
		["border-focus-width"] = 1,
		["text-align"] = "left",
		["vertical-align"] = "center",
		["background-color"] = "parent-group",
	},
	
	["tek.ui.class.floattext"] = {
		["background-color"] = "list",
	},
	
	["tek.ui.class.frame"] = {
		["border-width"] = 2,
		["border-style"] = "inset",
	},
	
	["tek.ui.class.gadget"] = {
		["border-width"] = 3,
		["border-style"] = "outset",
		["border-focus-width"] = 1,
	},
	
	["tek.ui.class.gadget:active"] = {
		["border-style"] = "inset",
		["background-color"] = "active",
		["color"] = "active-detail",
	},
	
	["tek.ui.class.gadget:disabled"] = {
		["background-color"] = "disabled",
		["color"] = "disabled-detail",
	},
	
	["tek.ui.class.gadget:focus"] = {
		["background-color"] = "focus",
		["color"] = "focus-detail",
	},
	
	["tek.ui.class.gadget:hover"] = {
		["background-color"] = "hover",
		["color"] = "hover-detail",
	},
	
	["tek.ui.class.gadget.knob-scrollbar"] = {
		["effect"] = "ripple",
		["effect-orientation"] = "inline",
		["effect-kind"] = "dot",
	},
	
	["tek.ui.class.gauge"] = {
		["padding"] = 0,
		["border-style"] = "inset",
		["height"] = "auto",
	},
	
	["tek.ui.class.group"] = {
		["margin"] = 0,
		["background-color"] = "group",
		["border-width"] = 0,
		["border-focus-width"] = 0,
	},
	
	["tek.ui.class.handle"] = {
		["effect"] = "ripple",
		["effect-orientation"] = "across",
		["effect-kind"] = "slant",
		["border-width"] = 0,
		["background-color"] = "parent-group",
		["padding"] = 5,
	},
	
	["tek.ui.class.handle:active"] = {
		["border-style"] = "outset",
		["background-color"] = "hover",
	},
	
	["tek.ui.class.handle:hover"] = {
		["background-color"] = "hover",
	},
	
	["tek.ui.class.listgadget"] = {
		["background-color"] = "list",
		["background-color2"] = "list2",
		["color"] = "list-detail",
	},
	["tek.ui.class.listgadget:active"] = {
		["background-color"] = "list-active",
		["color"] = "list-active-detail",
	},
	
	["tek.ui.class.menuitem"] = {
		["font"] = "default-menu-font",
		["border-width"] = 0,
		["margin"] = 0,
		["width"] = "fill",
	},
	
	["tek.ui.class.menuitem:active"] = {
		["background-color"] = "menu-active",
		["color"] = "menu-active-detail",
	},
	
	["tek.ui.class.menuitem:hover"] = {
		["background-color"] = "menu-active",
		["color"] = "menu-active-detail",
	},
	
	["tek.ui.class.menuitem:focus"] = {
		["background-color"] = "menu-active",
		["color"] = "menu-active-detail",
	},
	
	["tek.ui.class.menuitem:popup-root"] = {
		["margin"] = 2,
		["width"] = "auto",
	},
	
	["tek.ui.class.popitem"] = {
		["border-width"] = 4,
		["border-style"] = "outset",
		["border-focus-width"] = 1,
		["border-rim-width"] = 1,
		["width"] = "fill",
	},
	
	["tek.ui.class.popitem:active"] = {
		["background-color"] = "hover",
	},
	
	["tek.ui.class.popupwindow"] = {
		["background-color"] = "background",
		["border-width"] = 1,
		["border-style"] = "solid",
		["border-color"] = "dark",
		["padding"] = 0,
	},
	
	["tek.ui.class.slider"] = {
		["padding"] = 0,
		["border-style"] = "inset",
		["width"] = "fill",
		["height"] = "fill",
	},
	
	["tek.ui.class.slider:active"] = {
		["border-style"] = "inset",
	},
	
	["tek.ui.class.spacer"] = {
		["border-style"] = "inset",
		["border-width"] = 1,
	},
	
	["tek.ui.class.text"] = {
		["border-style"] = "inset",
		["padding"] = "2 5 2 5",
		["height"] = "auto",
	},
	
	["tek.ui.class.textinput"] = {
		["font"] = "default-fixed-font",
		["border-style"] = "inset",
	},
	
	["tek.ui.class.window"] = {
		["padding"] = 0,
		["margin"] = 0,
	},
	
	-- pre-defined classes:
	
	[".button"] = {
		["border-style"] = "outset",
		["border-width"] = 4,
		["border-rim-width"] = 1,
	},
	
	[".button:active"] = {
		["border-style"] = "inset",
	},
	
	[".caption"] = {
		["border-width"] = 0,
		["background-color"] = "parent-group",
		["horizontal-align"] = "center",
		["vertical-align"] = "center",
	},
	
	[".gauge-fill"] = {
		["border-style"] = "solid",
		["border-color"] = "dark",
		["border-width"] = 1,
		["background-color"] = "fill",
		["padding"] = 4,
	},
	
	[".knob"] = {
		["border-width"] = 3,
		["border-focus-width"] = 0,
		["border-rim-width"] = 1,
		["margin"] = 0,
		["padding"] = 4,
	},
	
	[".legend"] = {
		["border-legend-font"] = "default-small-font",
		["border-style"] = "groove",
		["border-width"] = 2,
		["margin"] = 2,
		["padding"] = 1,
	},
	
	[".menubar"] = {
		["margin"] = 0,
		["border-style"] = "solid",
		["border-width"] = "0 0 1 0",
		["padding"] = 0,
		["background-color"] = "background",
		["width"] = "fill",
		["height"] = "auto",
	},
	
	[".page-button"] = {
		["border-style"] = "inset",
		["border-width"] = 2,
		["border-focus-width"] = 0,
		["margin"] = 0,
	},
	
	[".page-button:active"] = {
		["border-style"] = "outset",
		["border-bottom-color"] = "group",
	},
	
	[".page-button:focus"] = {
		["background-color"] = "hover",
	},
	
	-- internal classes:
	
	["_listviewheaditem"] = {
		["background-color"] = "active",
		["padding"] = 0,
	},
	
	["_pagebuttongroup"] = {
		["margin"] = "4 2 0 2",
		["padding-left"] = 2,
	},
	
	["_pagecontainer"] = {
		["border-width"] = "0 2 2 2",
		["margin"] = "0 2 2 2",
		["padding"] = 2,
	},
	
	["_scrollbar-arrow"] = {
		["margin"] = 0,
		["border-width"] = 4,
		["border-rim-width"] = 1,
		["min-width"] = 12,
		["min-height"] = 12,
	},

	["_scrollbar-slider"] = {
		["margin"] = 0,
	},
}

-------------------------------------------------------------------------------
--	GTK+ settings import:
-------------------------------------------------------------------------------

local function fmtrgb(r, g, b, l)
	l = l or 1
	r = min(r * l * 255, 255)
	g = min(g * l * 255, 255)
	b = min(b * l * 255, 255)
	return ("#%02x%02x%02x"):format(r, g, b)
end
 
local function getclass(s, class)
	local c = s[class]
	if not c then
		c = { }
		s[class] = c
	end
	return c
end
 
local function setclass(s, class, key, val)
	local c = getclass(s, class)
	c[key] = val
end
 
local function importGTKConfig(def_s)
	if 3 / 2 == 1 then
		db.error("Need floating point support for GTK+ settings import")
		return def_s
	end
	local p = getenv("GTK2_RC_FILES")
	if p then
		local s = def_s
		local paths = { }
		p:gsub("([^:]+):?", function(p)
			insert(paths, p)
		end)
		for _, fname in ipairs(paths) do
			db.info("Trying config file %s", fname)
			local f = open(fname)
			if f then
				local d = getclass(s, "tek.ui.class.display")
				local style
				local found = false
				for line in f:lines() do
					line = line:match("^%s*(.*)%s*$")
					local newstyle = line:match("^style%s+\"(%w+)\"$")
					if newstyle then
						style = newstyle:lower()
					end
					local color, r, g, b =
						line:match("^(%w+%[%w+%])%s*=%s*{%s*([%d.]+)%s*,%s*([%d.]+)%s*,%s*([%d.]+)%s*}$")
					if color and r then
						local r, g, b = tonumber(r), tonumber(g), tonumber(b)
						local c = fmtrgb(r, g, b)
						if style == "default" then
							found = true
							if color == "bg[NORMAL]" then
								d["rgb-background"] = fmtrgb(r, g, b, 0.95)
								d["rgb-group"] = fmtrgb(r, g, b, 1.05)
								d["rgb-shadow"] = fmtrgb(r, g, b, 0.45)
								d["rgb-border-shine"] = fmtrgb(r, g, b, 1.3)
								d["rgb-border-shadow"] = fmtrgb(r, g, b, 0.65)
								d["rgb-half-shine"] = fmtrgb(r, g, b, 1.3)
								d["rgb-half-shadow"] = fmtrgb(r, g, b, 0.65)
							elseif color == "bg[INSENSITIVE]" then
								d["rgb-disabled"] = c
							elseif color == "bg[ACTIVE]" then
								d["rgb-active"] = c
							elseif color == "bg[PRELIGHT]" then
								d["rgb-hover"] = c
								d["rgb-focus"] = c
							elseif color == "bg[SELECTED]" then
								d["rgb-fill"] = c
								d["rgb-border-focus"] = c
								d["rgb-cursor"] = c
								
							elseif color == "fg[NORMAL]" then
								d["rgb-detail"] = c
								d["rgb-border-legend"] = c
							elseif color == "fg[INSENSITIVE]" then
								d["rgb-disabled-detail"] = c
								d["rgb-disabled-detail2"] = 
									fmtrgb(r, g, b, 2)
							elseif color == "fg[ACTIVE]" then
								d["rgb-active-detail"] = c
							elseif color == "fg[PRELIGHT]" then
								d["rgb-hover-detail"] = c
								d["rgb-focus-detail"] = c
							elseif color == "fg[SELECTED]" then
								d["rgb-cursor-detail"] = c
								
							elseif color == "base[NORMAL]" then
								d["rgb-list"] = fmtrgb(r, g, b, 1.05)
								d["rgb-list2"] = fmtrgb(r, g, b, 0.95)
							elseif color == "base[SELECTED]" then
								d["rgb-list-active"] = c
								
							elseif color == "text[NORMAL]" then
								d["rgb-list-detail"] = c
							elseif color == "text[ACTIVE]" then
								d["rgb-list-active-detail"] = c
							end
						elseif style == "menuitem" then
							if color == "bg[NORMAL]" then
								d["rgb-menu"] = c
							elseif color == "bg[PRELIGHT]" then
								d["rgb-menu-active"] = c
							elseif color == "fg[NORMAL]" then
								d["rgb-menu-detail"] = c
							elseif color == "fg[PRELIGHT]" then
								d["rgb-menu-active-detail"] = c
							end
						end
					end
				end
				f:close()
				if found then
					setclass(s, ".page-button", "background-color", "active")
					setclass(s, ".page-button:active", "background-color",
						"group")
					setclass(s, "tek.ui.class.display", "rgb-border-rim",
						"#000")
					setclass(s, "tek.ui.class.display", "rgb-border-light",
						"#fff")
					return s
				end
			end
		end
	end
	return def_s
end
 
-------------------------------------------------------------------------------
--	stylesheet = Theme.getStyleSheet([themename]): Get a stylesheet of a named
--	theme. Theme names currently defined are:
--		- "default" - the default external stylesheet (or hardcoded defaults),
--		including an imported color scheme (if available)
--		- "internal" - the hardcoded internal stylesheet
-------------------------------------------------------------------------------

function Theme.getStyleSheet(themename)
	themename = themename or "default"
	local s, msg
	if themename == "internal" then
		s = DEF_STYLESHEET
	else
		local fname = ("tek/ui/style/%s.css"):format(themename)
		s, msg = ui.loadStyleSheet(fname)
		if not s then
			db.error("failed to load style sheet '%s' : %s", fname, msg)
			s = DEF_STYLESHEET
		end
		s = importGTKConfig(s)
	end
	return s
end
