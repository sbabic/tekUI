
local db = require "tek.lib.debug"
local getenv = os.getenv
local insert = table.insert
local ipairs = ipairs
local min = math.min
local open = io.open
local tonumber = tonumber

module "tek.ui.style.desktop"
_VERSION = "Desktop Style 1.0"
local DesktopStyle = _M

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

function DesktopStyle.importConfiguration(s)
	if 3 / 2 == 1 then
		db.error("Need floating point support for GTK+ settings import")
		return false
	end
	local p = getenv("GTK2_RC_FILES")
	if p then
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
								d["rgb-menu"] = c
								d["rgb-background"] = fmtrgb(r, g, b, 0.91)
								d["rgb-group"] = fmtrgb(r, g, b, 0.985)
								d["rgb-shadow"] = fmtrgb(r, g, b, 0.45)
								d["rgb-border-shine"] = fmtrgb(r, g, b, 1.25)
								d["rgb-border-shadow"] = fmtrgb(r, g, b, 0.65)
								d["rgb-half-shine"] = fmtrgb(r, g, b, 1.25)
								d["rgb-half-shadow"] = fmtrgb(r, g, b, 0.65)
								d["rgb-outline"] = c
							elseif color == "bg[INSENSITIVE]" then
								d["rgb-disabled"] = c
							elseif color == "bg[ACTIVE]" then
								d["rgb-active"] = c
							elseif color == "bg[PRELIGHT]" then
								d["rgb-hover"] = fmtrgb(r, g, b, 1.03)
								d["rgb-focus"] = c
							elseif color == "bg[SELECTED]" then
								d["rgb-fill"] = c
								d["rgb-border-focus"] = c
								d["rgb-cursor"] = c

							elseif color == "fg[NORMAL]" then
								d["rgb-detail"] = c
								d["rgb-menu-detail"] = c
								d["rgb-border-legend"] = c
							elseif color == "fg[INSENSITIVE]" then
								d["rgb-disabled-detail"] = c
								d["rgb-disabled-detail-shine"] =
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
								d["rgb-list-alt"] = fmtrgb(r, g, b, 0.92)
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
					setclass(s, ".page-button", "background-color:active", 
						"group")
					setclass(s, "tek.ui.class.display", "rgb-border-rim",
						"#000")
					setclass(s, ".page-button", "background-color:hover",
						"hover")
					setclass(s, ".page-button", "background-color:focus",
						"hover")
					return true
				end
			end
		end
	end
	return false
end
