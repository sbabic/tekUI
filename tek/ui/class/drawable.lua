-------------------------------------------------------------------------------
--
--	tek.ui.class.drawable
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		Drawable
--
--	OVERVIEW::
--		This class implements a graphical context which can be painted on.
--
--	IMPLEMENTS::
--		- Drawable:copyArea() - Copies an area
--		- Drawable:drawLine() - Draws a line
--		- Drawable:drawPlot() - Draws a point
--		- Drawable:drawRect() - Draws an unfilled rectangle
--		- Drawable:drawText() - Renders text
--		- Drawable:fillRect() - Draws a filled rectangle
--		- Drawable:getMsg() - Gets the next pending input message
--		- Drawable:getShift() - Gets the current coordinate displacement
--		- Drawable:getTextSize() - Determines the width and height of text
--		- Drawable:popClipRect() - Pops the topmost cliprect from the drawable
--		- Drawable:pushClipRect() - Pushes a new cliprect on the drawable
--		- Drawable:setFont() - Sets a font
--		- Drawable:setShift() - Adds a coordinate displacement
--
--	OVERRIDES::
--		- Object.init()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local Object = require "tek.class.object"
local Region = require "tek.lib.region"

local assert = assert
local insert = table.insert
local intersect = Region.intersect
local remove = table.remove
local setmetatable = setmetatable
local unpack = unpack
local HUGE = ui.HUGE

module("tek.ui.class.drawable", tek.class.object)
_VERSION = "Drawable 17.0"

DEBUG_DELAY = 3

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Drawable = _M

function Drawable.init(self)
	assert(self.Display)
	self.Interval = false
	self.Visual = false
	self.Pens = false
	self.Left = false
	self.Top = false
	self.Width = false
	self.Height = false
	self.ShiftX = 0
	self.ShiftY = 0
	self.ClipStack = { }
	self.ClipRect = { }
	self.RectPool = { }
	self.DebugPen1 = false
	self.DebugPen2 = false
	return Object.init(self)
end

-------------------------------------------------------------------------------
--	open:
-------------------------------------------------------------------------------

function Drawable:open(userdata, title, w, h, minw, minh, maxw, maxh, x, y,
	center, fulls)
	assert(not w or w > 0)
	assert(not h or h > 0)
	assert(not minw or minw >= 0)
	assert(not minh or minh >= 0)
	assert(not maxw or maxw > 0)
	assert(not maxh or maxh > 0)
	if not self.Visual then
		self.Visual = self.Display:openVisual
		{
			UserData = userdata,
			Title = title,
			Width = w,
			Height = h,
			Left = x,
			Top = y,
			MinWidth = minw,
			MinHeight = minh,
			MaxWidth = maxw,
			MaxHeight = maxh,
			Borderless = (x or y) and true,
			Center = center,
			FullScreen = fulls,
			EventMask = self.Interval and ui.MSG_ALL or
				ui.MSG_ALL - ui.MSG_INTERVAL,
			BlankCursor = ui.NoCursor,
		}
		self.DebugPen1 = self.Visual:allocpen(128, 255, 0)
		self.DebugPen2 = self.Visual:allocpen(0, 0, 0)
		
		self.Pens = { }
		
		-- Attach metatable for late pen allocation:
		setmetatable(self.Pens, {
			__index = function(tab, key)
				if key:sub(1, 1) == "#" then
					-- we assume a string representing a color number:
					local pen = self.Visual:allocpen(
						self.Display:colorToRGB(key, "#f0f"))
					tab[key] = pen
					return pen
				end
				local pm
				if key:match("^url%b()") then
					local fname = key:match("^url%(([^()]+)%)")
					if fname then
						pm = self.Display.getPixmap(fname)
					end
				end
				pm = pm or tab[ui.PEN_BACKGROUND]
				tab[key] = pm
				return pm
			end
		})
		
		-- Allocate standard pens:
		for i = 1, ui.PEN_NUMBER do
			local name, r, g, b = self.Display:getPaletteEntry(i)
			local key = ("#%02x%02x%02x"):format(r, g, b)
			local pen = self.Pens[key]
			self.Pens[key] = pen
			self.Pens[name] = pen
			self.Pens[i] = pen
		end
		
		return true
	end
end

function Drawable:close()
	if self.Visual then
		self:getAttrs()
		self.Visual:close()
		self.Visual = false
		self.Pens = false
		return true
	end
end

-------------------------------------------------------------------------------
--	fillRect(x0, y0, x1, y1, pen): Draws a filled rectangle.
-------------------------------------------------------------------------------

function Drawable:fillRect_normal(...)
	self.Visual:frect(...)
end

-------------------------------------------------------------------------------
--	drawRect(x0, y0, x1, y1, pen): Draws an unfilled rectangle.
-------------------------------------------------------------------------------

function Drawable:drawRect_normal(...)
	self.Visual:rect(...)
end

-------------------------------------------------------------------------------
--	drawText(x0, y0, text, fgpen[, bgpen]): Renders text
--	with the specified foreground pen. If the optional background pen is
--	specified, the background under the text is filled in this color.
-------------------------------------------------------------------------------

function Drawable:drawText(...)
	self.Visual:text(...)
end

function Drawable:drawImage(...)
	self.Visual:drawimage(...)
end

function Drawable:drawRGB(...)
	self.Visual:drawrgb(...)
end

function Drawable:drawPixmap(...)
	self.Visual:drawpixmap(...)
end

-------------------------------------------------------------------------------
--	drawLine(x0, y0, x1, y1, pen): Draws a line using the specified
--	pen.
-------------------------------------------------------------------------------

function Drawable:drawLine_normal(...)
	self.Visual:line(...)
end

-------------------------------------------------------------------------------
--	drawPlot(x0, y0, pen): Draws a point.
-------------------------------------------------------------------------------

function Drawable:drawPlot_normal(...)
	self.Visual:plot(...)
end

-------------------------------------------------------------------------------
--	setFont(font): Sets the specified font.
-------------------------------------------------------------------------------

function Drawable:setFont(...)
	self.Visual:setfont(...)
end

-------------------------------------------------------------------------------
--	width, height = getTextSize(text): Determines the width and height
--	of a text using the font which is currently set on the Drawable.
-------------------------------------------------------------------------------

function Drawable:getTextSize(...)
	return self.Visual:textsize(...)
end

-------------------------------------------------------------------------------
--	msg = getMsg([msg]): Gets the next pending message from the
--	Drawable. Optionally, the fields of the new message are inserted into
--	the specified table.
-------------------------------------------------------------------------------

function Drawable:getMsg(msg)
	return self.Visual:getmsg(msg)
end

function Drawable:setAttrs(...)
	self.Visual:setattrs(...)
end

function Drawable:getAttrs()
	self.Width, self.Height, self.Left, self.Top =
		self.Visual:getattrs()
	return self.Width, self.Height, self.Left, self.Top
end

-------------------------------------------------------------------------------
--	pushClipRect(x0, y0, x1, y1): Pushes a new cliprect on the top
--	of the drawable's stack of cliprects.
-------------------------------------------------------------------------------

function Drawable:pushClipRect(x0, y0, x1, y1)
	local v = self.Visual
	if v then
		local cr = self.ClipRect
		local sx = self.ShiftX
		local sy = self.ShiftY
		x0 = x0 + sx
		y0 = y0 + sy
		x1 = x1 + sx
		y1 = y1 + sy
		local r = remove(self.RectPool) or { }
		r[1], r[2], r[3], r[4] = x0, y0, x1, y1
		insert(self.ClipStack, r)
		if cr[1] then
			x0, y0, x1, y1 = intersect(x0, y0, x1, y1, 
				cr[1], cr[2], cr[3], cr[4])
			if not x0 then
				x0, y0, x1, y1 = -1, -1, -1, -1
			end
		end
		cr[1], cr[2], cr[3], cr[4] = x0, y0, x1, y1
		v:setcliprect(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	end
end

-------------------------------------------------------------------------------
--	popClipRect(): Pop the topmost cliprect from the Drawable.
-------------------------------------------------------------------------------

function Drawable:popClipRect()
	local v = self.Visual
	if v then
		local cs = self.ClipStack
		local cr = self.ClipRect
		insert(self.RectPool, remove(cs))
		local x0, y0, x1, y1
		if #cs > 0 then
			x0, y0, x1, y1 = 0, 0, HUGE, HUGE
			for i = 1, #cs do
				x0, y0, x1, y1 = intersect(x0, y0, x1, y1, unpack(cs[i]))
				if not x0 then
					x0, y0, x1, y1 = -1, -1, -1, -1
					break
				end
			end
		end
		cr[1], cr[2], cr[3], cr[4] = x0, y0, x1, y1
		if x0 then
			v:setcliprect(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
		else
			v:unsetcliprect()
		end
	end
end

-------------------------------------------------------------------------------
--	setShift(deltax, deltay): Add a delta to the Drawable's
--	coordinate displacement.
-------------------------------------------------------------------------------

function Drawable:setShift(dx, dy)
	local v = self.Visual
	if v then
		self.ShiftX = self.ShiftX + dx
		self.ShiftY = self.ShiftY + dy
		v:setshift(dx, dy)
	end
end

-------------------------------------------------------------------------------
--	shiftx, shifty = getShift(): Get the Drawable's current
--	coordinate displacement.
-------------------------------------------------------------------------------

function Drawable:getShift()
	return self.ShiftX, self.ShiftY
end

-------------------------------------------------------------------------------
--	copyArea(x0, y0, x1, y1, deltax, deltay, exposures): Copy the
--	specified rectangle to the position determined by the relative
--	coordinates {{deltax}} and {{deltay}}. The {{exposures}} argument is a
--	table used for collecting the raw coordinates of rectangles getting
--	exposed as a result of the copy operation.
-------------------------------------------------------------------------------

function Drawable:copyArea(x0, y0, x1, y1, dx, dy, t)
	self.Visual:copyarea(x0, y0, x1 - x0 + 1, y1 - y0 + 1, dx, dy, t)
end

-------------------------------------------------------------------------------
--	setInterval(onoff) - Enables or disables interval messages.
-------------------------------------------------------------------------------

function Drawable:setInterval(onoff)
	self.Interval = onoff
	if self.Visual then
		if onoff then
			db.info("enable interval")
			self.Visual:setinput(ui.MSG_INTERVAL)
		else
			db.info("clear interval")
			self.Visual:clearinput(ui.MSG_INTERVAL)
		end
	end
end

-------------------------------------------------------------------------------
--	debug versions:
-------------------------------------------------------------------------------

function Drawable:fillRect_debug(...)
	local x0, y0, x1, y1 = ...
	self.Visual:frect(x0, y0, x1, y1, self.DebugPen1)
	self.Display.sleep(DEBUG_DELAY)
	self.Visual:frect(x0, y0, x1, y1, self.DebugPen2)
	self.Display.sleep(DEBUG_DELAY)
	self.Visual:frect(...)
end

function Drawable:drawRect_debug(...)
	local x0, y0, x1, y1 = ...
	self.Visual:rect(x0, y0, x1, y1, self.DebugPen1)
	self.Display.sleep(DEBUG_DELAY)
	self.Visual:rect(x0, y0, x1, y1, self.DebugPen2)
	self.Display.sleep(DEBUG_DELAY)
	self.Visual:rect(...)
end

function Drawable:drawLine_debug(...)
	local x0, y0, x1, y1 = ...
	self.Visual:line(x0, y0, x1, y1, self.DebugPen1)
	self.Display.sleep(DEBUG_DELAY)
	self.Visual:line(x0, y0, x1, y1, self.DebugPen2)
	self.Display.sleep(DEBUG_DELAY)
	self.Visual:line(...)
end

function Drawable:drawPlot_debug(...)
	local x0, y0 = ...
	self.Visual:plot(x0, y0, self.DebugPen1)
	self.Display.sleep(DEBUG_DELAY)
	self.Visual:plot(x0, y0, self.DebugPen2)
	self.Display.sleep(DEBUG_DELAY)
	self.Visual:plot(...)
end

function Drawable.enableDebug(enabled)
	if enabled then
		fillRect = fillRect_debug
		drawRect = drawRect_debug
		drawLine = drawLine_debug
		drawPlot = drawPlot_debug
	else
		fillRect = fillRect_normal
		drawRect = drawRect_normal
		drawLine = drawLine_normal
		drawPlot = drawPlot_normal
	end
end

enableDebug(ui.DEBUG)
