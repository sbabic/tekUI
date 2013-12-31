-------------------------------------------------------------------------------
--
--	tek.ui.class.sizeable
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
--		[[#tek.ui.class.widget : Widget]] /
--		Sizeable ${subclasses(Sizeable)}
--
--		This class implements the ability to resize an element without the
--		need to repaint it completely. Its parent must be a Canvas element.
--
--	IMPLEMENTS::
--		- Sizeable:resize() - Resize the element
--
--	OVERRIDES::
--		- Element:connect()
--		- Area:draw()
--		- Object.init()
--		- Area:layout()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"

local Canvas = ui.require("canvas", 30)
local Widget = ui.require("widget", 25)
local Region = ui.loadLibrary("region", 10)

module("tek.ui.class.sizeable", tek.ui.class.widget)
_VERSION = "Sizeable 9.1"
local Sizeable = _M
Widget:newClass(Sizeable)

-------------------------------------------------------------------------------
--	init: overrides
-------------------------------------------------------------------------------

function Sizeable.init(self)
	self.InsertX = false	-- internal
	self.InsertY = false	-- internal
	self.EraseBG = false
	self.TrackDamage = true
	return Widget.init(self)
end

-------------------------------------------------------------------------------
--	connect: overrides
-------------------------------------------------------------------------------

function Sizeable:connect(parent)
	return parent:instanceOf(Canvas) and Widget.connect(self, parent)
end

-------------------------------------------------------------------------------
--	blitAxis: grows or shrinks element efficiently, using blit operations and
--	partial damages
-------------------------------------------------------------------------------

function Sizeable:blitAxis(r1, r2, r3, r4, dw, dh, insx, insy)
	local c1, c2, c3, c4 = self.Parent:getRect()
	local sx, sy = self.Window.Drawable:setShift()
	
	local s1 = r1 + sx + insx
	local s2 = r2 + sy + insy
	local s3 = r3 + sx
	local s4 = r4 + sy
	
	if dw > 0 then
		s3 = s3 + dw
	elseif dw < 0 then
		s1 = s1 - dw
	end
	
	if dh > 0 then
		s4 = s4 + dh
	elseif dh < 0 then
		s2 = s2 - dh
	end
	
	self.Window:addBlit(s1, s2, s3, s4, dw, dh, c1, c2, c3, c4)
	
	-- damage(incoming) = (source - clip)* /\ clip
	local d = Region.new(s1, s2, s3, s4)
	d:subRect(c1, c2, c3, c4)
	d:shift(dw, dh)
	
	-- damage(outgoing) = (source - dest) /\ clip
	local r = Region.new(s1, s2, s3, s4)
	r:subRect(s1 + dw, s2 + dh, s3 + dw, s4 + dh)
	
	-- d(incoming) \/ d(outgoing)
	r:forEach(d.orRect, d)
	
	-- /\ clip:
	d:andRect(c1, c2, c3, c4)
	
	-- shift back:
	d:shift(-sx, -sy)
	
	local dr = self.DamageRegion
	if dr then
		d:forEach(dr.orRect, dr)
	else
		self.DamageRegion = d
	end
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function Sizeable:layout(x0, y0, x1, y1, markdamage)

	markdamage = markdamage ~= false
	
	local m1, m2, m3, m4 = self:getMargin()

	local n1 = x0 + m1
	local n2 = y0 + m2
	local n3 = x1 - m3
	local n4 = y1 - m4

	local r1, r2, r3, r4 = self:getRect()
	
	if n1 == r1 and n2 == r2 and markdamage and self.TrackDamage then
		local dw = n3 - r3
		local dh = n4 - r4
		local insx = self.InsertX
		local insy = self.InsertY
		self.InsertX = false
		self.InsertY = false
		local redraw
	
		if dw ~= 0 and insx then
			self:blitAxis(r1, r2, r3, r4, dw, 0, insx, 0)
			redraw = true
		end
		if dh ~= 0 and insy then
			self:blitAxis(r1, r2, r3, r4, 0, dh, 0, insy)
			redraw = true
		end
		if redraw then
			self.Rect:setRect(n1, n2, n3, n4)
			self:setFlags(ui.FL_REDRAW)
			return true
		end
	end
	
	return Widget.layout(self, x0, y0, x1, y1, markdamage)
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function Sizeable:draw()
	local dr = self.DamageRegion
	if Widget.draw(self) then
		local d = self.Window.Drawable
		d:setBGPen(self:getBG())
		dr:forEach(d.fillRect, d)
	end
end

-------------------------------------------------------------------------------
--	Sizeable:resize(dx, dy, insx, insy): Resize the element by {{dx}} on the
--	x axis and {{dy}} on the y axis, inserting or removing space at {{insx}}
--	on the x axis and {{insy}} on the y axis.
-------------------------------------------------------------------------------

function Sizeable:resize(dx, dy, insx, insy)
	local resize
	local c = self.Parent
	if dx ~= 0 then
		self.InsertX = insx
		c:setValue("CanvasWidth", c.CanvasWidth + dx)
		resize = true
	end
	if dy ~= 0 then
		self.InsertY = insy
		c:setValue("CanvasHeight", c.CanvasHeight + dy)
		resize = true
	end
	if resize then
		c:rethinkLayout()
	end
end
