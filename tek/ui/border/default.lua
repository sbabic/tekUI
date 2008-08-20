
local ui = require "tek.ui"
local Border = require "tek.ui.class.border"
local Region = require "tek.lib.region"
local assert = assert
local floor = math.floor
local max = math.max
local min = math.min
local unpack = unpack

module("tek.ui.border.default", tek.ui.class.border)
_VERSION = "DefaultBorder 1.1"

local PEN_SHINE = ui.PEN_BORDERSHINE
local PEN_SHADOW = ui.PEN_BORDERSHADOW
local PEN_RIM = ui.PEN_BORDERRIM
local PEN_FOCUS = ui.PEN_BORDERFOCUS

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
	return Border.getProperties(self, p, class)
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

	if self.Legend then
		self.LegendFont = display:openFont(self.LegendFontName)
		self.LegendWidth, self.LegendHeight =
			ui.Display:getTextSize(self.LegendFont, self.Legend)
	end
	
	Border.show(self, display, drawable)
end

function DefaultBorder:hide()
	self.Parent.Display:closeFont(self.LegendFont)
	self.LegendFont = false
	Border.hide(self)
end

function DefaultBorder:getBorder()
	local b = self.Border
	return b[1], b[2] + (self.LegendHeight or 0), b[3], b[4]
end

function DefaultBorder.drawBorderRect(d, r1, r2, r3, r4, a1, a2, a3, a4,
	b1, b2, b3, b4, p1, p2, p3, p4)
	local s1, s2, s3, s4 = r1, r2, r3, r4
	if b1 > 0 then
		d:fillRect(r1 - b1, r2, r1 - 1, r4, p1)
		s1 = s1 - b1
		a1 = a1 - b1
	end
	if b2 > 0 then
		d:fillRect(r1 - b1, r2 - b2, r3 + b3, r2 - 1, p2)
		s2 = s2 - b2
		a2 = a2 - b2
	end
	if b3 > 0 then
		d:fillRect(r3 + 1, r2, r3 + b3, r4, p3)
		s3 = s3 + b3
		a3 = a3 - b3
	end
	if b4 > 0 then
		d:fillRect(r1 - b1, r4 + 1, r3 + b3, r4 + b4, p4)
		s4 = s4 + b4
		a4 = a4 - b4
	end
	return s1, s2, s3, s4, a1, a2, a3, a4
end

function DefaultBorder:draw()

	local p = self.Params
	local e = self.Parent
	local d = e.Drawable
	local pens = d.Pens
	local b1, b2, b3, b4 = unpack(self.Border)
	local r1, r2, r3, r4 = unpack(self.Rect)

	local gb = pens[e:getElement("group").Background]

	local tw = self.LegendWidth
	if tw then
		local th = self.LegendHeight
		local w = r3 - r1 + 1
		local tx = r1 + max(floor((w - tw) / 2), 0)
		local y0 = r2 - th - b2
		d:setFont(self.LegendFont)
		d:pushClipRect(r1 - b1, y0, r3 + b3, r2 - b2 - 1)
		d:drawText(tx, y0, self.Legend, pens[ui.PEN_BORDERLEGEND], gb)
		d:popClipRect()
	end
	
	local i = e.Selected and 5 or 1

	-- thickness of outer borders:
	local t = p[11] + p[12]

	local bs = e.Selected and self.BorderStyleActive or self.BorderStyle

	if bs == "ridge" or bs == "groove" then
		local d1 = b1 >= t and (b1 - t) or b1
		local d2 = b2 >= t and (b2 - t) or b2
		local d3 = b3 >= t and (b3 - t) or b3
		local d4 = b4 >= t and (b4 - t) or b4
		d1 = floor(d1 / 2)
		d2 = floor(d2 / 2)
		d3 = floor(d3 / 2)
		d4 = floor(d4 / 2)
		r1, r2, r3, r4, b1, b2, b3, b4 = drawBorderRect(d, r1, r2, r3, r4,
			b1, b2, b3, b4,
			d1, d2, d3, d4,
			pens[p[i]], pens[p[i+1]], pens[p[i+2]], pens[p[i+3]])
		r1, r2, r3, r4, b1, b2, b3, b4 = drawBorderRect(d, r1, r2, r3, r4,
			b1, b2, b3, b4,
			d1, d2, d3, d4,
			pens[p[i+2]], pens[p[i+3]], pens[p[i]], pens[p[i+1]])
	else
		r1, r2, r3, r4, b1, b2, b3, b4 = 
			drawBorderRect(d, r1, r2, r3, r4, b1, b2, b3, b4,
			b1 >= t and (b1 - t) or b1,
			b2 >= t and (b2 - t) or b2,
			b3 >= t and (b3 - t) or b3,
			b4 >= t and (b4 - t) or b4,
			pens[p[i]], pens[p[i+1]], pens[p[i+2]], pens[p[i+3]])
	end

	local pen = pens[p[9]]
	r1, r2, r3, r4, b1, b2, b3, b4 = drawBorderRect(d, 
		r1, r2, r3, r4, b1, b2, b3, b4,
		min(b1, p[11]),
		min(b2, p[11]),
		min(b3, p[11]),
		min(b4, p[11]),
		pen, pen, pen, pen)

	if e.Focus then
		pen = pens[p[10]]
	else
		pen = gb
	end

	drawBorderRect(d, r1, r2, r3, r4, b1, b2, b3, b4,
		b1, b2, b3, b4,
		pen, pen, pen, pen)

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
