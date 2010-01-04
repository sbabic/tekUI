
local ui = require "tek.ui"
local Border = require "tek.ui.class.border"
local assert = assert
local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local unpack = unpack

module("tek.ui.border.default", tek.ui.class.border)
_VERSION = "DefaultBorder 6.0"

local DefaultBorder = _M

function DefaultBorder.init(self)
	self.Border = self.Border or false
	self.Legend = self.Legend or false
	self.LegendFont = false
	self.LegendWidth = false
	self.LegendHeight = false
	return Border.init(self)
end

function DefaultBorder:setup(app, win)
	
	Border.setup(self, app, win)
	
	local e = self.Parent
	local b = self.Border
	
	-- consolidation of properties:
	local props = e.Properties
	local p1, p2, p3, p4

	local bs = props["border-style"]
	if bs == "outset" or bs == "groove" then
		p1, p3 = "border-shine", "border-shadow"
		p2, p4 = p1, p3
	elseif bs == "inset" or bs == "ridge" then
		p1, p3 = "border-shadow", "border-shine"
		p2, p4 = p1, p3
	else -- solid / default
		p1 = "border-shadow"
		p2, p3, p4 = p1, p1, p1
	end

	b[5] = props["border-left-color"] or p1
	b[6] = props["border-top-color"] or p2
	b[7] = props["border-right-color"] or p3
	b[8] = props["border-bottom-color"] or p4

	local bs = props["border-style:active"]
	if bs == "outset" or bs == "groove" then
		p1, p3 = "border-shine", "border-shadow"
		p2, p4 = p1, p3
	elseif bs == "inset" or bs == "ridge" then
		p1, p3 = "border-shadow", "border-shine"
		p2, p4 = p1, p3
	else -- solid / default
		p1 = "border-shadow"
		p2, p3, p4 = p1, p1, p1
	end
	b[9] = props["border-left-color:active"] or p1
	b[10] = props["border-top-color:active"] or p2
	b[11] = props["border-right-color:active"] or p3
	b[12] = props["border-bottom-color:active"] or p4

	b[13] = props["border-rim-color"] or "border-rim"
	b[14] = props["border-focus-color"] or "border-focus"
	b[15] = tonumber(props["border-rim-width"]) or 0
	b[16] = tonumber(props["border-focus-width"]) or 0
	b[17] = props["border-legend-color"] or "border-legend"

	-- p[14]...p[17]: temp rect
	-- p[18]...p[21]: temp border

	local l = self.Legend
	if l then
		local f = app.Display:openFont(props["border-legend-font"])
		self.LegendFont = f
		self.LegendWidth, self.LegendHeight = f:getTextSize(l)
	end

end

function DefaultBorder:cleanup()
	self.LegendFont = 
		self.Application.Display:closeFont(self.LegendFont)
	Border.cleanup(self)
end

function DefaultBorder:getBorder()
	local b = self.Border
	return b[1], b[2] + (self.LegendHeight or 0), b[3], b[4]
end

local function drawBorderRect(d, b, b1, b2, b3, b4, p1, p2, p3, p4, tx, ty)
	if b1 > 0 then
		d:fillRect(b[18] - b1, b[19], b[18] - 1, b[21], p1, tx, ty)
	end
	if b2 > 0 then
		d:fillRect(b[18] - b1, b[19] - b2, b[20] + b3, b[19] - 1, p2, tx, ty)
	end
	if b3 > 0 then
		d:fillRect(b[20] + 1, b[19], b[20] + b3, b[21], p3, tx, ty)
	end
	if b4 > 0 then
		d:fillRect(b[18] - b1, b[21] + 1, b[20] + b3, b[21] + b4, p4, tx, ty)
		b[21] = b[21] + b4
		b[25] = b[25] - b4
	end
	b[18] = b[18] - b1
	b[22] = b[22] - b1
	b[19] = b[19] - b2
	b[23] = b[23] - b2
	b[20] = b[20] + b3
	b[24] = b[24] - b3
-- 	b[21] = b[21] + b4
-- 	b[25] = b[25] - b4
end

function DefaultBorder:draw()
	local e = self.Parent
	local d = e.Drawable
	local pens = d.Pens
	local b = self.Border
	local rw = b[15]

	b[18], b[19], b[20], b[21] = unpack(self.Rect)
	if not b[18] then
		return
	end
	
	b[22], b[23], b[24], b[25] = unpack(self.Border, 1, 4)
	local _, ox, oy = e:getBG()
	local gb, gox, goy = e:getBGElement():getBG()
	
	gb = d.Pens[gb]

	local tw = self.LegendWidth
	if tw then
		local th = self.LegendHeight
		local w = b[20] - b[18] + 1
		local tx = b[18] + max(floor((w - tw) / 2), 0)
		local y0 = b[19] - th - b[23]
		d:setFont(self.LegendFont)
		d:pushClipRect(b[18] - b[22], y0, b[20] + b[24], b[19] - b[23] - 1)
		d:drawText(tx, y0, tx + tw - 1, y0 + th - 1, self.Legend,
			pens[b[17]], gb, gox, goy)
		d:popClipRect()
	end

	local i = e.Selected and 9 or 5

	-- thickness of outer borders:
	local t = rw + b[16]

	local bs = e.Selected and e.Properties["border-style:active"] or
		e.Properties["border-style"]
	local p1, p2, p3, p4 = pens[b[i]], pens[b[i + 1]], pens[b[i + 2]],
		pens[b[i + 3]]

	local d1 = max(b[22] - t, 0)
	local d2 = max(b[23] - t, 0)
	local d3 = max(b[24] - t, 0)
	local d4 = max(b[25] - t, 0)

	if bs == "ridge" or bs == "groove" then
		local e1, e2, e3, e4 =
			floor(d1 / 2), floor(d2 / 2), floor(d3 / 2), floor(d4 / 2)
		drawBorderRect(d, b, e1, e2, e3, e4, p1, p2, p3, p4, ox, oy)
		drawBorderRect(d, b, d1 - e1, d2 - e2, d3 - e3, d4 - e4,
			p3, p4, p1, p2, ox, oy)
	else
		drawBorderRect(d, b, d1, d2, d3, d4, p1, p2, p3, p4, ox, oy)
	end

	local pen = pens[b[13]]
	drawBorderRect(d, b,
		min(b[22], rw), min(b[23], rw), min(b[24], rw), min(b[25], rw),
		pen, pen, pen, pen, ox, oy)

	pen = e.Focus and pens[b[14]] or gb
	drawBorderRect(d, b, b[22], b[23], b[24], b[25], pen, pen, pen, pen, 
		gox, goy)
end

function DefaultBorder:getRegion(b)
	local b1, b2, b3, b4 = unpack(self.Border, 1, 4)
	local x0, y0, x1, y1 = self:layout()
	b:setRect(x0 - b1, y0 - b2, x1 + b3, y1 + b4)
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
