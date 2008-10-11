-------------------------------------------------------------------------------
--
--	tek.ui.class.gauge
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		[[#tek.ui.class.frame : Frame]] /
--		[[#tek.ui.class.gadget : Gadget]] /
--		[[#tek.ui.class.numeric : Numeric]] /
--		Gauge
--
--	OVERVIEW::
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
--		- Area:refresh()
--		- Area:relayout()
--		- Area:setState()
--		- Element:setup()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Region = require "tek.lib.region"
local Numeric = ui.Numeric

local floor = math.floor
local max = math.max
local min = math.min
local unpack = unpack

module("tek.ui.class.gauge", tek.ui.class.numeric)
_VERSION = "Gauge 4.4"

-------------------------------------------------------------------------------
-- Gauge:
-------------------------------------------------------------------------------

local Gauge = _M

function Gauge.init(self)
	self.Mode = "inert"
	self.Orientation = self.Orientation or "horizontal"
	self.Child = self.Child or ui.Frame:new { Class = "gauge-fill" }
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
	self.Child:setup(app, window)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Gauge:cleanup()
	self.Child:cleanup()
	Numeric.cleanup(self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Gauge:show(display, drawable)
	Numeric.show(self, display, drawable)
	self.Child:show(display, drawable)
	return true
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Gauge:hide()
	self.Child:hide()
	Numeric.hide(self)
	return true
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
	if self.Display then
		local r = self.Rect
		local p = self.Padding
		local m = self.Child.MarginAndBorder
		local km = self.Child.MinMax
		local x0 = r[1] + p[1] + m[1]
		local y0 = r[2] + p[2] + m[2]
		local x1 = r[3] - p[3] - m[3]
		local y1 = r[4] - p[4] - m[4]
		local r = self.Max - self.Min
		if self.Orientation == "horizontal" then
			local w = x1 - x0 - km[1] + 1
			x1 = min(x1, x0 + floor((self.Value - self.Min) * w / r) + km[1])
		else
			local h = y1 - y0 - km[2] + 1
			y1 = min(y1, y0 + floor((self.Value - self.Min) * h / r) + km[2])
		end
		return x0 - m[1], y0 - m[2], x1 + m[3], y1 + m[4]
	end
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function Gauge:layout(r1, r2, r3, r4, markdamage)
	if Numeric.layout(self, r1, r2, r3, r4, markdamage) then
		local x0, y0, x1, y1 = self:getKnobRect()
		self.Child:layout(x0, y0, x1, y1, markdamage)
		return true
	end
end

-------------------------------------------------------------------------------
--	relayout: overrides
-------------------------------------------------------------------------------

function Gauge:relayout(e, r1, r2, r3, r4)
	local res, changed = Numeric.relayout(self, e, r1, r2, r3, r4)
	if res then
		return res, changed
	end
	return self.Child:relayout(e, r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	refresh: overrides
-------------------------------------------------------------------------------

function Gauge:refresh()
	Numeric.refresh(self)
	self.Child:refresh()
end

-------------------------------------------------------------------------------
--	markDamage: overrides
-------------------------------------------------------------------------------

function Gauge:markDamage(r1, r2, r3, r4)
	Numeric.markDamage(self, r1, r2, r3, r4)
	self.Child:markDamage(r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function Gauge:draw()
	local d = self.Drawable
	local r = self.Rect
	local bg = Region.new(r[1], r[2], r[3], r[4])
	local c = self.Child
	local r = c.Rect
	local c1, c2, c3, c4 = c:getBorder()
	bg:subRect(r[1] - c1, r[2] - c2, r[3] + c3, r[4] + c4)
	local bgpen = d.Pens[self.Background]
	for _, r1, r2, r3, r4 in bg:getRects() do
		d:fillRect(r1, r2, r3, r4, bgpen)
	end
end

-------------------------------------------------------------------------------
--	onSetValue: overrides
-------------------------------------------------------------------------------

function Gauge:onSetValue(v)
	Numeric.onSetValue(self, v)
	local x0, y0, x1, y1 = self:getKnobRect()
	if x0 then
		self.Window:relayout(self.Child, x0, y0, x1, y1)
		self.Redraw = true
	end
end
