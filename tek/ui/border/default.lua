
local ui = require "tek.ui"
local Border = require "tek.ui.class.border"
local Region = require "tek.lib.region"
local assert = assert
local floor = math.floor
local max = math.max
local min = math.min
local unpack = unpack

module("tek.ui.border.default", tek.ui.class.border)
_VERSION = "DefaultBorder 1.6"

local PEN_SHINE = ui.PEN_BORDERSHINE
local PEN_SHADOW = ui.PEN_BORDERSHADOW
local PEN_RIM = ui.PEN_BORDERRIM
local PEN_FOCUS = ui.PEN_BORDERFOCUS
local PEN_BORDERLEGEND = ui.PEN_BORDERLEGEND

local DefaultBorder = _M

function DefaultBorder.init(self)
	self.Params = { }
	self.Border = self.Border or false
	self.BorderStyle = false
	self.BorderStyleActive = false
	self.Legend = self.Legend or false
	self.LegendFontName = false
	self.LegendFont = false
	self.LegendWidth = false
	self.LegendHeight = false
	return Border.init(self)
end

function DefaultBorder:getProperties(props, pclass)
	local e = self.Parent
	local p = self.Params
	self.BorderStyle = self.BorderStyle or
		e:getProperty(props, pclass, "border-style")
	self.LegendFontName = e:getProperty(props, pclass, "border-legend-font")
	p[1] = p[1] or e:getProperty(props, pclass, "border-left-color")
	p[2] = p[2] or e:getProperty(props, pclass, "border-top-color")
	p[3] = p[3] or e:getProperty(props, pclass, "border-right-color")
	p[4] = p[4] or e:getProperty(props, pclass, "border-bottom-color")
	self.BorderStyleActive = self.BorderStyleActive or
		e:getProperty(props, pclass or "active", "border-style")
	p[5] = p[5] or
		e:getProperty(props, pclass or "active", "border-left-color")
	p[6] = p[6] or
		e:getProperty(props, pclass or "active", "border-top-color")
	p[7] = p[7] or
		e:getProperty(props, pclass or "active", "border-right-color")
	p[8] = p[8] or
		e:getProperty(props, pclass or "active", "border-bottom-color")
	p[9] = p[9] or e:getProperty(props, pclass, "border-rim-color")
	p[10] = p[10] or e:getProperty(props, pclass, "border-focus-color")
	p[11] = p[11] or e:getProperty(props, pclass, "border-rim-width")
	p[12] = p[12] or e:getProperty(props, pclass, "border-focus-width")
	p[13] = p[13] or e:getProperty(props, pclass, "border-legend-color")
	return Border.getProperties(self, p, pclass)
end

function DefaultBorder:show(display, drawable)

	local e = self.Parent
	local p = self.Params

	-- consolidation of properties:

	local p1, p2, p3, p4

	local bs = self.BorderStyle
	if bs == "outset" or bs == "groove" then
		p1, p3 = PEN_SHINE, PEN_SHADOW
		p2, p4 = p1, p3
	elseif bs == "inset" or bs == "ridge" then
		p1, p3 = PEN_SHADOW, PEN_SHINE
		p2, p4 = p1, p3
	else -- solid / default
		p1 = PEN_SHADOW
		p2, p3, p4 = p1, p1, p1
	end

	p[1] = p[1] or p1
	p[2] = p[2] or p2
	p[3] = p[3] or p3
	p[4] = p[4] or p4

	bs = self.BorderStyleActive
	if bs == "outset" or bs == "groove" then
		p1, p3 = PEN_SHINE, PEN_SHADOW
		p2, p4 = p1, p3
	elseif bs == "inset" or bs == "ridge" then
		p1, p3 = PEN_SHADOW, PEN_SHINE
		p2, p4 = p1, p3
	else -- solid / default
		p1 = PEN_SHADOW
		p2, p3, p4 = p1, p1, p1
	end
	p[5] = p[5] or p1
	p[6] = p[6] or p2
	p[7] = p[7] or p3
	p[8] = p[8] or p4

	p[9] = p[9] or PEN_RIM
	p[10] = p[10] or PEN_FOCUS
	p[11] = p[11] or 0
	p[12] = p[12] or 0
	p[13] = p[13] or PEN_BORDERLEGEND

	-- p[14]...p[17]: temp rect
	-- p[18]...p[21]: temp border

	if self.Legend then
		self.LegendFont = display:openFont(self.LegendFontName)
		self.LegendWidth, self.LegendHeight =
			ui.Display:getTextSize(self.LegendFont, self.Legend)
	end

	Border.show(self, display, drawable)
end

function DefaultBorder:hide()
	if self.Parent.Display then
		self.Parent.Display:closeFont(self.LegendFont)
	end
	self.LegendFont = false
	Border.hide(self)
end

function DefaultBorder:getBorder()
	local b = self.Border
	return b[1], b[2] + (self.LegendHeight or 0), b[3], b[4]
end

local function drawBorderRect(d, p, b1, b2, b3, b4, p1, p2, p3, p4)
	if b1 > 0 then
		d:fillRect(p[14] - b1, p[15], p[14] - 1, p[17], p1)
	end
	if b2 > 0 then
		d:fillRect(p[14] - b1, p[15] - b2, p[16] + b3, p[15] - 1, p2)
	end
	if b3 > 0 then
		d:fillRect(p[16] + 1, p[15], p[16] + b3, p[17], p3)
	end
	if b4 > 0 then
		d:fillRect(p[14] - b1, p[17] + 1, p[16] + b3, p[17] + b4, p4)
		p[17] = p[17] + b4
		p[21] = p[21] - b4
	end
	p[14] = p[14] - b1
	p[18] = p[18] - b1
	p[15] = p[15] - b2
	p[19] = p[19] - b2
	p[16] = p[16] + b3
	p[20] = p[20] - b3
-- 	p[17] = p[17] + b4
-- 	p[21] = p[21] - b4
end

function DefaultBorder:draw()
	local p = self.Params
	local e = self.Parent
	local d = e.Drawable
	local pens = d.Pens
	local rw = p[11]

	p[14], p[15], p[16], p[17] = unpack(self.Rect)
	p[18], p[19], p[20], p[21] = unpack(self.Border)

	local x = e:getElement("group").Background
	local gb = pens[x] or x

	local tw = self.LegendWidth
	if tw then
		local th = self.LegendHeight
		local w = p[16] - p[14] + 1
		local tx = p[14] + max(floor((w - tw) / 2), 0)
		local y0 = p[15] - th - p[19]
		d:setFont(self.LegendFont)
		d:pushClipRect(p[14] - p[18], y0, p[16] + p[20], p[15] - p[19] - 1)
		d:drawText(tx, y0, self.Legend, pens[p[13]], gb)
		d:popClipRect()
	end

	local i = e.Selected and 5 or 1

	-- thickness of outer borders:
	local t = rw + p[12]

	local bs = e.Selected and self.BorderStyleActive or self.BorderStyle

	local p1, p2, p3, p4 = pens[p[i]], pens[p[i + 1]], pens[p[i + 2]],
		pens[p[i + 3]]

	local d1 = max(p[18] - t, 0)
	local d2 = max(p[19] - t, 0)
	local d3 = max(p[20] - t, 0)
	local d4 = max(p[21] - t, 0)

	if bs == "ridge" or bs == "groove" then
		local e1, e2, e3, e4 =
			floor(d1 / 2), floor(d2 / 2), floor(d3 / 2), floor(d4 / 2)
		drawBorderRect(d, p, e1, e2, e3, e4, p1, p2, p3, p4)
		drawBorderRect(d, p, d1 - e1, d2 - e2, d3 - e3, d4 - e4,
			p3, p4, p1, p2)
	else
		drawBorderRect(d, p, d1, d2, d3, d4, p1, p2, p3, p4)
	end

	local pen = pens[p[9]]
	drawBorderRect(d, p,
		min(p[18], rw), min(p[19], rw), min(p[20], rw), min(p[21], rw),
		pen, pen, pen, pen)

	pen = e.Focus and pens[p[10]] or gb
	drawBorderRect(d, p, p[18], p[19], p[20], p[21], pen, pen, pen, pen)
end

function DefaultBorder:getBorderRegion()
	local b1, b2, b3, b4 = unpack(self.Border)
	local x0, y0, x1, y1 = self:layout()
	local b = Region.new(x0 - b1, y0 - b2, x1 + b3, y1 + b4)
	b:subRect(x0, y0, x1, y1)
	local tw = self.LegendWidth
	if tw then
		local w = x1 - x0 + 1
		tw = min(tw, w)
		local tx = x0 + floor((w - tw) / 2)
		b:orRect(tx, y0 - self.LegendHeight - b2, tx + tw - 1, y0 - 1)
	end
	return b
end
