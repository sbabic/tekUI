-------------------------------------------------------------------------------
--
--	tek.ui.class.gauge
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		[[#tek.ui.class.frame : Frame]] /
--		[[#tek.ui.class.gadget : Gadget]] /
--		[[#tek.ui.class.numeric : Numeric]] /
--		Gauge ${subclasses(Gauge)}
--
--		This class implements a gauge for the visualization of
--		numerical values.
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Element:cleanup()
--		- Area:draw()
--		- Area:hide()
--		- Object.init()
--		- Area:layout()
--		- Numeric:onSetValue()
--		- Area:setState()
--		- Element:setup()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Numeric = ui.require("numeric", 1)
local Region = ui.loadLibrary("region", 9)

local floor = math.floor
local max = math.max
local min = math.min
local reuseRegion = ui.reuseRegion
local unpack = unpack

module("tek.ui.class.gauge", tek.ui.class.numeric)
_VERSION = "Gauge 12.0"

-------------------------------------------------------------------------------
-- Gauge:
-------------------------------------------------------------------------------

local Gauge = _M

function Gauge.init(self)
	self.BGRegion = false
	self.Child = self.Child or ui.Frame:new { Class = "gauge-fill" }
	self.Mode = "inert"
	self.Orientation = self.Orientation or "horizontal"
	return Numeric.init(self)
end

-------------------------------------------------------------------------------
--	connect: overrides
-------------------------------------------------------------------------------

function Gauge:connect(parent)
	-- our parent is also our knob's parent
	-- (suggesting it that it rests in a Group):
	self.Child:connect(parent)
	return Numeric.connect(self, parent)
end

-------------------------------------------------------------------------------
--	decodeProperties: overrides
-------------------------------------------------------------------------------

function Gauge:decodeProperties(p)
	Numeric.decodeProperties(self, p)
	self.Child:decodeProperties(p)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Gauge:setup(app, window)
	Numeric.setup(self, app, window)
	
	if self.Orientation == "horizontal" then
		self.MaxWidth = ui.HUGE
		self.MaxHeight = 0
		self.Width = false
	else
		self.MaxWidth = 0
		self.MaxHeight = ui.HUGE
		self.Height = false
	end
	
	self.Child:setup(app, window)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Gauge:cleanup()
	self.Child:cleanup()
	Numeric.cleanup(self)
	self.BGRegion = false
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Gauge:show(drawable)
	Numeric.show(self, drawable)
	self.Child:show(drawable)
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Gauge:hide()
	self.Child:hide()
	Numeric.hide(self)
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function Gauge:askMinMax(m1, m2, m3, m4)
	local w, h = self.Child:askMinMax(0, 0, 0, 0)
	return Numeric.askMinMax(self, m1 + w, m2 + h, m3 + w, m4 + h)
end

-------------------------------------------------------------------------------
--	getKnobRect:
-------------------------------------------------------------------------------

function Gauge:getKnobRect()
	local r1, r2, r3, r4 = self:getRect()
	if r1 then
		local p1, p2, p3, p4 = self:getPadding()
		local m = self.Child.Margin
		local km = self.Child.MinMax
		local x0 = r1 + p1 + m[1]
		local y0 = r2 + p2 + m[2]
		local x1 = r3 - p3 - m[3]
		local y1 = r4 - p4 - m[4]
		local r = self.Max - self.Min
		if self.Orientation == "horizontal" then
			local w = x1 - x0 - km[1] + 1
			x1 = min(x1, x0 + floor((self.Value - self.Min) * w / r) + km[1])
		else
			local h = y1 - y0 - km[2] + 1
			y0 = max(y0, 
				y1 - floor((self.Value - self.Min) * h / r) - km[2])
		end
		return x0 - m[1], y0 - m[2], x1 + m[3], y1 + m[4]
	end
end

-------------------------------------------------------------------------------
--	updateBGRegion:
-------------------------------------------------------------------------------

function Gauge:updateBGRegion()
	local r = self.Rect
	local bg = reuseRegion(self.BGRegion, r[1], r[2], r[3], r[4])
	self.BGRegion = bg
	local c = self.Child
	r = c.Rect
	local c1, c2, c3, c4 = c:getBorder()
	bg:subRect(r[1] - c1, r[2] - c2, r[3] + c3, r[4] + c4)
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function Gauge:layout(r1, r2, r3, r4, markdamage)
	local res = Numeric.layout(self, r1, r2, r3, r4, markdamage)
	local x0, y0, x1, y1 = self:getKnobRect()
	local res2 = self.Child:layout(x0, y0, x1, y1, markdamage)
	if res or res2 then
		self:updateBGRegion()
		return true
	end
end

-------------------------------------------------------------------------------
--	damage: overrides
-------------------------------------------------------------------------------

function Gauge:damage(r1, r2, r3, r4)
	Numeric.damage(self, r1, r2, r3, r4)
	self.Child:damage(r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	erase: overrides
-------------------------------------------------------------------------------

function Gauge:erase()
	local bg = self.BGRegion
	if bg then
		local d = self.Drawable
		local bgpen, tx, ty = self:getBG()
		bg:forEach(d.fillRect, d, d.Pens[bgpen], tx, ty)
	end
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function Gauge:draw()
	local res = Numeric.draw(self)
	self.Child:draw()
	return res
end

-------------------------------------------------------------------------------
--	onSetValue: overrides
-------------------------------------------------------------------------------

function Gauge:onSetValue(v)
	Numeric.onSetValue(self, v)
	local x0, y0, x1, y1 = self:getKnobRect()
	if x0 then
		if self.Window:relayout(self.Child, x0, y0, x1, y1) then
			self:updateBGRegion()
			self.Flags:set(ui.FL_REDRAW)
		end
	end
end
