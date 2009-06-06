-------------------------------------------------------------------------------
--
--	tek.ui.class.canvas
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		[[#tek.ui.class.area : Frame]] /
--		Canvas
--
--	OVERVIEW::
--		This class implements a scrollable area acting as a managing container
--		for a child element. Currently, this class is used exclusively for
--		child objects of the [[#tek.ui.class.scrollgroup : ScrollGroup]] class.
--
--	ATTRIBUTES::
--		- {{AutoPosition [IG]}} (boolean)
--			See [[#tek.ui.class.area : Area]]
--		- {{AutoHeight [IG]}} (boolean)
--			The height of the canvas is automatically adapted to the height
--			of the region it is layouted into. Default: '''false'''
--		- {{AutoWidth [IG]}} (boolean)
--			The width of the canvas is automatically adapted to the width
--			of the canvas it is layouted into. Default: '''false'''
--		- {{CanvasHeight [ISG]}} (number)
--			The height of the canvas in pixels
--		- {{CanvasLeft [ISG]}} (number)
--			Left visible offset of the canvas in pixels
--		- {{CanvasTop [ISG]}} (number)
--			Top visible offset of the canvas in pixels
--		- {{CanvasWidth [ISG]}} (number)
--			The width of the canvas in pixels
--		- {{Child [ISG]}} (object)
--			The child element being managed by the Canvas
--		- {{KeepMinHeight [IG]}} (boolean)
--			Report the minimum height of the Canvas's child object as the
--			Canvas' minimum display height
--		- {{KeepMinWidth [IG]}} (boolean)
--			Report the minimum width of the Canvas's child object as the
--			Canvas' minimum display width
--		- {{UnusedRegion [G]}} ([[#tek.lib.region : Region]])
--			Region of the Canvas which is not covered by its {{Child}}
--		- {{UseChildBG [IG]}} (boolean)
--			If '''true''', the Canvas borrows its background properties from
--			its child for rendering its {{UnusedRegion}}. If '''false''',
--			the Canvas' own background properties are used. Default: '''true'''
--		- {{VScrollStep [IG]}} (number)
--			Vertical scroll step, used e.g. for mouse wheels
--
--	IMPLEMENTS::
--		- Canvas:checkArea() - Gets the canvas shift [internal]
--		- Canvas:damageChild() - Damage a child object where it is visible
--		- Canvas:onSetChild() - Handler called when {{Child}} is set
--		- Canvas:updateUnusedRegion() - Update region not covered by Child
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Element:cleanup()
--		- Element:connect()
--		- Area:damage()
--		- Element:decodeProperties()
--		- Element:disconnect()
--		- Area:draw()
--		- Area:focusRect()
--		- Area:getBG()
--		- Area:getBGElement()
--		- Area:getChildren()
--		- Area:getElementByXY()
--		- Area:hide()
--		- Object.init()
--		- Area:layout()
--		- Area:passMsg()
--		- Area:refresh()
--		- Area:relayout()
--		- Element:setup()
--		- Area:show()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local Application = ui.Application
local Area = ui.Area
local Element = ui.Element
local Frame = ui.Frame
local Region = require "tek.lib.region"
local assert = assert
local max = math.max
local min = math.min
local intersect = Region.intersect
local reuseRegion = ui.reuseRegion
local unpack = unpack

module("tek.ui.class.canvas", tek.ui.class.frame)
_VERSION = "Canvas 17.0"
local Canvas = _M

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_CHILD = { ui.NOTIFY_SELF, "onSetChild", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	init: overrides
-------------------------------------------------------------------------------

function Canvas.init(self)
	if self.AutoPosition == nil then
		self.AutoPosition = false
	end
	self.AutoHeight = self.AutoHeight or false
	self.AutoWidth = self.AutoWidth or false
	self.CanvasHeight = self.CanvasHeight or 0
	self.CanvasLeft = self.CanvasLeft or 0
	self.CanvasTop = self.CanvasTop or 0
	self.CanvasWidth = self.CanvasWidth or 0
	self.NullArea = Area:new { Margin = ui.NULLOFFS, 
		MaxWidth = 0, MinWidth = 0 }
	self.Child = self.Child or self.NullArea
	self.KeepMinHeight = self.KeepMinHeight or false
	self.KeepMinWidth = self.KeepMinWidth or false
	self.OldCanvasLeft = self.CanvasLeft
	self.OldCanvasTop = self.CanvasTop
	self.OldChild = self.Child
	self.TempMsg = { }
	-- track intra-area damages, so that they can be applied to child object:
	self.TrackDamage = true
	self.UnusedRegion = false
	if self.UseChildBG == nil then
		self.UseChildBG = true
	end
	self.VScrollStep = self.VScrollStep or 10
	return Frame.init(self)
end

-------------------------------------------------------------------------------
--	connect: overrides
-------------------------------------------------------------------------------

function Canvas:connect(parent)
	-- this connects recursively:
	Application.connect(self.Child, self)
	self.Child:connect(self)
	return Frame.connect(self, parent)
end

-------------------------------------------------------------------------------
--	disconnect: overrides
-------------------------------------------------------------------------------

function Canvas:disconnect(parent)
	Frame.disconnect(self, parent)
	return Element.disconnect(self.Child, parent)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Canvas:setup(app, window)
	Frame.setup(self, app, window)
	self.Child:setup(app, window)
	self:addNotify("Child", ui.NOTIFY_ALWAYS, NOTIFY_CHILD)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Canvas:cleanup()
	self:remNotify("Child", ui.NOTIFY_ALWAYS, NOTIFY_CHILD)
	self.Child:cleanup()
	Frame.cleanup(self)
end

-------------------------------------------------------------------------------
--	decodeProperties: overrides
-------------------------------------------------------------------------------

function Canvas:decodeProperties(p)
	self.Child:decodeProperties(p)
	Frame.decodeProperties(self, p)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Canvas:show(drawable)
	self.Child:show(drawable)
	Frame.show(self, drawable)
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Canvas:hide()
	self.Child:hide()
	Frame.hide(self)
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function Canvas:askMinMax(m1, m2, m3, m4)
	local c1, c2, c3, c4 = self.Child:askMinMax(0, 0, 
		self.MaxWidth, self.MaxHeight)
	m1 = m1 + c1
	m2 = m2 + c2
	m3 = m3 + c3
	m4 = m4 + c4
	m1 = self.KeepMinWidth and m1 or 0
	m2 = self.KeepMinHeight and m2 or 0
	m3 = self.MaxWidth and max(self.MaxWidth, m1) or self.CanvasWidth
	m4 = self.MaxHeight and max(self.MaxHeight, m2) or self.CanvasHeight
	return Frame.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

local function markchilddamage(child, r1, r2, r3, r4, sx, sy)
	child:damage(r1 + sx, r2 + sy, r3 + sx, r4 + sy)
end

function Canvas:layout(r1, r2, r3, r4, markdamage)

	local sizechanged = false
	local m = self.MarginAndBorder
	local r = self.Rect
	local c = self.Child
	local mm = c.MinMax
	local res = Frame.layout(self, r1, r2, r3, r4, markdamage)

	if self.AutoWidth then
		local w = r3 - r1 + 1 - m[1] - m[3]
		w = max(w, mm[1])
		w = mm[3] and min(w, mm[3]) or w
		if w ~= self.CanvasWidth then
			self:setValue("CanvasWidth", w)
			sizechanged = true
		end
	end

	if self.AutoHeight then
		local h = r4 - r2 + 1 - m[2] - m[4]
		h = max(h, mm[2])
		h = mm[4] and min(h, mm[4]) or h
		if h ~= self.CanvasHeight then
			self:setValue("CanvasHeight", h)
			sizechanged = true
		end
	end

	-- set shift (information needed in subsequent relayouts):
	local d = self.Drawable
	local sx = r[1] - self.CanvasLeft
	local sy = r[2] - self.CanvasTop

	d:setShift(sx, sy)
	
	-- layout child until width and height settle in:
	-- TODO: break out if they don't settle in?
	local iw, ih
	repeat
		iw, ih = self.CanvasWidth, self.CanvasHeight
		if c:layout(0, 0, iw - 1, ih - 1, sizechanged) then
			sizechanged = true
		end
	until self.CanvasWidth == iw and self.CanvasHeight == ih

	-- unset shift:
	d:setShift(-sx, -sy)

	-- propagate intra-area damages calculated in Frame.layout to child object:
	local dr = self.DamageRegion
	if dr and markdamage ~= false then
		local sx = self.CanvasLeft - r[1]
		local sy = self.CanvasTop - r[2]
		-- mark as damage shifted into canvas space:
		dr:forEach(markchilddamage, c, sx, sy)		
	end

	if res or sizechanged or not self.UnusedRegion then
		self:updateUnusedRegion()
	end

	if res or sizechanged then
		self.Redraw = true
		return true
	end

end

-------------------------------------------------------------------------------
--	updateUnusedRegion(): Updates the {{UnusedRegion}} attribute, which
--	contains the Canvas' area which isn't covered by its {{Child}}.
-------------------------------------------------------------------------------

function Canvas:updateUnusedRegion()
	-- determine unused region:
	local r1, r2, r3, r4 = self:getRect()
	if r1 then
		local ur = reuseRegion(self.UnusedRegion, 0, 0, 
			max(r3 - r1, self.CanvasWidth - 1),
			max(r4 - r2, self.CanvasHeight - 1))
		self.UnusedRegion = ur
		local c = self.Child
		local r = c.Rect
		local m = c.MarginAndBorder
		local b = c.Margin
		ur:subRect(r[1] - m[1] + b[1], r[2] - m[2] + b[2], 
			r[3] + m[3] - b[3], r[4] + m[4] - b[4])
		self.Redraw = true
	end
end

-------------------------------------------------------------------------------
--	relayout: overrides
-------------------------------------------------------------------------------

function Canvas:relayout(e, r1, r2, r3, r4)
	local res, changed = Frame.relayout(self, e, r1, r2, r3, r4)
	if res then
		return res, changed
	end
	local d = self.Drawable
	local r = self.Rect
	local sx = r[1] - self.CanvasLeft
	local sy = r[2] - self.CanvasTop
	d:pushClipRect(r[1], r[2], r[3], r[4])
	d:setShift(sx, sy)
	res, changed = self.Child:relayout(e, r1, r2, r3, r4)
	d:setShift(-sx, -sy)
	d:popClipRect()
	return res, changed
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function Canvas:draw()
	local d = self.Drawable
	local f = self.UnusedRegion
	local r = self.Rect
	local sx = r[1] - self.CanvasLeft
	local sy = r[2] - self.CanvasTop
	local bgpen, tx, ty = self:getBG()
	d:pushClipRect(r[1], r[2], r[3], r[4])
	d:setShift(sx, sy)
	f:forEach(d.fillRect, d, d.Pens[bgpen], tx, ty)
	d:setShift(-sx, -sy)
	d:popClipRect()
end

-------------------------------------------------------------------------------
--	getBG: overrides
-------------------------------------------------------------------------------

function Canvas:getBG()
	if self.UseChildBG then
		local c = self.Child
		local r = c.Rect
		return c.BGPen, r[1], r[2]
	end
	return Frame.getBG(self)
end

-------------------------------------------------------------------------------
--	refresh: overrides
-------------------------------------------------------------------------------

function Canvas:refresh()
	Frame.refresh(self)
	local d = self.Drawable
	local r = self.Rect
	local sx = r[1] - self.CanvasLeft
	local sy = r[2] - self.CanvasTop
	d:pushClipRect(r[1], r[2], r[3], r[4])
	d:setShift(sx, sy)
	self.Child:refresh()
	d:setShift(-sx, -sy)
	d:popClipRect()
end

-------------------------------------------------------------------------------
--	damage: overrides
-------------------------------------------------------------------------------

function Canvas:damage(r1, r2, r3, r4)
	Frame.damage(self, r1, r2, r3, r4)
	-- clip absolute:
	local r = self.Rect
	r1, r2, r3, r4 = intersect(r1, r2, r3, r4, r[1], r[2], r[3], r[4])
	if r1 then
		-- shift into canvas space:
		local sx = self.CanvasLeft - r[1]
		local sy = self.CanvasTop - r[2]
		self.Child:damage(r1 + sx, r2 + sy, r3 + sx, r4 + sy)
	end
end

-------------------------------------------------------------------------------
--	damageChild(r1, r2, r3, r4): Damages the specified region in the
--	child area where it overlaps with the visible part of the canvas.
-------------------------------------------------------------------------------

function Canvas:damageChild(r1, r2, r3, r4)
	local r = self.Rect
	local x = self.CanvasLeft
	local y = self.CanvasTop
	local w = min(self.CanvasWidth, r[3] - r[1] + 1)
	local h = min(self.CanvasHeight, r[4] - r[2] + 1)
	r1, r2, r3, r4 = intersect(r1, r2, r3, r4, x, y, x + w - 1, y + h - 1)
	if r1 then
		self.Child:damage(r1, r2, r3, r4)
	end
end

-------------------------------------------------------------------------------
--	sx, sy = checkArea(x, y): Checks if {{x, y}} are inside the element's
--	rectangle, and if so, returns the canvas shift by x and y [internal]
-------------------------------------------------------------------------------

function Canvas:checkArea(x, y)
	local r1, r2, r3, r4 = self:getRect()
	if r1 and x >= r1 and x <= r3 and y >= r2 and y <= r4 then
		return r1 - self.CanvasLeft, r2 - self.CanvasTop
	end
end

-------------------------------------------------------------------------------
--	getElementByXY: overrides
-------------------------------------------------------------------------------

function Canvas:getElementByXY(x, y)
	local sx, sy = self:checkArea(x, y)
	return sx and self.Child:getElementByXY(x - sx, y - sy)
end

-------------------------------------------------------------------------------
--	passMsg: overrides
-------------------------------------------------------------------------------

function Canvas:passMsg(msg)
	local isover = self:checkArea(msg[4], msg[5])
	if isover then
		if msg[2] == ui.MSG_MOUSEBUTTON then
			local r = self.Rect
			local h = self.CanvasHeight - (r[4] - r[2] + 1)
			if msg[3] == 64 then -- wheelup
				self:setValue("CanvasTop",
					max(0, min(h, self.CanvasTop - self.VScrollStep)))
				return false -- absorb
			elseif msg[3] == 128 then -- wheeldown
				self:setValue("CanvasTop",
					max(0, min(h, self.CanvasTop + self.VScrollStep)))
				return false -- absorb
			end
		elseif msg[2] == ui.MSG_KEYDOWN then
			if msg[3] == 0xf023 then -- PgUp
				local h = self.Rect[4] - self.Rect[2] + 1
				self:setValue("CanvasTop", self.CanvasTop - h)
			elseif msg[3] == 0xf024 then -- PgDown
				local h = self.Rect[4] - self.Rect[2] + 1
				self:setValue("CanvasTop", self.CanvasTop + h)
			end
		end
	end
	if isover or
		msg[2] == ui.MSG_MOUSEMOVE and self.Window.MovingElement then
		-- operate on copy of the input message:
		local r = self.Rect
		local m = self.TempMsg
		m[1], m[2], m[3], m[4], m[5], m[6] = unpack(msg)
		-- shift mouse position into canvas area:
		m[4] = m[4] - r[1] + self.CanvasLeft
		m[5] = m[5] - r[2] + self.CanvasTop
		self.Child:passMsg(m)
	end
	return msg
end

-------------------------------------------------------------------------------
--	getChildren: overrides
-------------------------------------------------------------------------------

function Canvas:getChildren()
	return { self.Child }
end

-------------------------------------------------------------------------------
--	Canvas:onSetChild(child): This handler is invoked when the canvas'
--	child element has changed.
-------------------------------------------------------------------------------

function Canvas:onSetChild(child)
	local oldchild = self.OldChild
	if oldchild then
		if oldchild == self.Window.FocusElement then
			self.Window:setFocusElement()
		end
		oldchild:hide()
		oldchild:cleanup()
	end
	child = child or self.NullArea
	self.Child = child
	self.OldChild = child
	self.Application:decodeProperties(child)
	child:setup(self.Application, self.Window)
	child:show(self.Drawable)
	child:connect(self)
	child:connect(self)
	self:rethinkLayout(2)
end

-------------------------------------------------------------------------------
--	focusRect - overrides
-------------------------------------------------------------------------------

function Canvas:focusRect(x0, y0, x1, y1)
	local r1, r2, r3, r4 = self:getRect()
	local vw = r3 - r1
	local vh = r4 - r2
	local vx0 = self.CanvasLeft
	local vy0 = self.CanvasTop
	local vx1 = vx0 + vw
	local vy1 = vy0 + vh
	if x0 and self.AutoPosition then
		local n1, n2, n3, n4 = intersect(x0, y0, x1, y1, vx0, vy0, vx1, vy1)
		if n1 == x0 and n2 == y0 and n3 == x1 and n4 == y1 then
			return
		end
		
		if y1 > vy1 then
			vy1 = y1
			vy0 = vy1 - vh
		end	
		if y0 < vy0 then
			vy0 = y0
			vy1 = vy0 + vh
		end
		if x1 > vx1 then
			vx1 = x1
			vx0 = vx1 - vw
		end	
		if x0 < vx0 then
			vx0 = x0
			vx1 = vx0 + vw
		end
		
		self:setValue("CanvasLeft", vx0)
		self:setValue("CanvasTop", vy0)
		
		vx0 = x0
		vy0 = y0
		vx1 = x1
		vy1 = y1
	end
	local parent = self:getParent()
	if parent then
		parent:focusRect(r1 + vx0, r2 + vy0, r3 + vx1,
			r4 + vy1)
	end
end

-------------------------------------------------------------------------------
--	getBGElement: overrides
-------------------------------------------------------------------------------

function Canvas:getBGElement()
	return self
end
