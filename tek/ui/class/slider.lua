-------------------------------------------------------------------------------
--
--	tek.ui.class.slider
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
--		Slider
--
--	OVERVIEW::
--		This class implements a slider for adjusting a numerical value.
--
--	ATTRIBUTES::
--		- {{AutoFocus [IG]}} (boolean)
--			If '''true''' and the slider is receiving the focus, it reacts
--			on keyboard shortcuts instantly; otherwise, it must be selected
--			first (and deselected afterwards). Default: '''false'''
--		- {{Child [IG]}} ([[#tek.ui.class.gadget : Gadget]])
--			A Gadget object for being used as the slider's knob. By default,
--			a knob gadget of the style class {{"knob"}} is created internally.
--		- {{Integer [IG]}} (boolean)
--			If '''true''', integer steps are enforced. By default, the
--			slider knob moves continuously.
--		- {{Kind [IG]}} (string)
--			Kind of the slider:
--				- {{"scrollbar"}} - for scrollbars. Sets the additional
--				style class {{"knob-scrollbar"}}.
--				- {{"number"}} - for adjusting numbers. Sets the additional
--				style class {{"knob-number"}}.
--			Default: '''false''', the kind is unspecified.
--		- {{Orientation [IG]}} (string)
--			Orientation of the slider, which can be {{"horizontal"}} or
--			{{"vertical"}}. Default: {{"horizontal"}}
--		- {{Range [ISG]}} (number)
--			The size of the slider, i.e. the range that it represents.
--			Setting this value invokes the Slider:onSetRange() method.
--
--	IMPLEMENTS::
--		- Slider:onSetRange() - Handler for the {{Range}} attribute
--
--	OVERRIDES:
--		- Element:cleanup()
--		- Area:draw()
--		- Area:hide()
--		- Object.init()
--		- Area:layout()
--		- Area:passMsg()
--		- Gadget:onFocus()
--		- Gadget:onHold()
--		- Area:refresh()
--		- Area:relayout()
--		- Area:setState()
--		- Element:setup()
--		- Area:show()
--		- Numeric:onSetMax()
--		- Numeric:onSetValue()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Gadget = ui.Gadget
local Region = require "tek.lib.region"
local Numeric = ui.Numeric
local floor = math.floor
local max = math.max
local min = math.min
local freeRegion = ui.freeRegion
local reuseRegion = ui.reuseRegion

module("tek.ui.class.slider", tek.ui.class.numeric)
_VERSION = "Slider 14.0"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_RANGE = { ui.NOTIFY_SELF, "onSetRange", ui.NOTIFY_VALUE }
local NOTIFY_HOLD = { ui.NOTIFY_SELF, "onHold", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
-- Class implementation:
-------------------------------------------------------------------------------

local Slider = _M

function Slider.init(self)
	if self.AutoPosition == nil then
		self.AutoPosition = false
	end
	if self.AutoFocus == nil then
		self.AutoFocus = false
	end
	self.BGRegion = false
	self.Integer = self.Integer or false
	self.Kind = self.Kind or false
	self.Orientation = self.Orientation or "horizontal"
	self.Range = self.Range or false
	self.Captured = false
	self.Child = self.Child or Gadget:new {
		Class = "knob knob-" .. (self.Kind or "normal")
	}
	self.ClickDirection = false
	self.HoldXY = { }
	self.Mode = "button"
	self.Move0 = false
	self.Pos0 = 0
	self = Numeric.init(self)
	self.Range = max(self.Max, self.Range or self.Max)
	return self
end

-------------------------------------------------------------------------------
--	connect: overrides
-------------------------------------------------------------------------------

function Slider:connect(parent)
	-- our parent is also our knob's parent:
	self.Child:connect(parent)
	return Numeric.connect(self, parent)
end

-------------------------------------------------------------------------------
--	decodeProperties: overrides
-------------------------------------------------------------------------------

function Slider:decodeProperties(p)
	Numeric.decodeProperties(self, p)
	self.Child:decodeProperties(p)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Slider:setup(app, window)
	Numeric.setup(self, app, window)
	self:addNotify("Range", ui.NOTIFY_ALWAYS, NOTIFY_RANGE, 1)
	self:addNotify("Hold", ui.NOTIFY_ALWAYS, NOTIFY_HOLD)
	self.Child:setup(app, window)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Slider:cleanup()
	self.Child:cleanup()
	self:remNotify("Hold", ui.NOTIFY_ALWAYS, NOTIFY_HOLD)
	self:remNotify("Range", ui.NOTIFY_ALWAYS, NOTIFY_RANGE)
	Numeric.cleanup(self)
	self.BGRegion = freeRegion(self.BGRegion)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Slider:show(drawable)
	Numeric.show(self, drawable)
	self.Child:show(drawable)
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Slider:hide()
	self:setCapture(false)
	self.Child:hide()
	Numeric.hide(self)
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function Slider:askMinMax(m1, m2, m3, m4)
	local w, h = self.Child:askMinMax(0, 0, 0, 0)
	if self.Orientation == "horizontal" then
		w = w + w
	else
		h = h + h
	end
	return Numeric.askMinMax(self, m1 + w, m2 + h, m3 + w, m4 + h)
end

-------------------------------------------------------------------------------
--	getKnobRect: internal
-------------------------------------------------------------------------------

function Slider:getKnobRect()
	local r1, r2, r3, r4 = self:getRect()
	if r1 then
		local p = self.Padding
		local m = self.Child.MarginAndBorder
		local km = self.Child.MinMax
		local x0 = r1 + p[1] + m[1]
		local y0 = r2 + p[2] + m[2]
		local x1 = r3 - p[3] - m[3]
		local y1 = r4 - p[4] - m[4]
		local r = self.Range - self.Min
		local v = self.Value
		v = self.Integer and floor(v) or v
		if r > 0 then
			if self.Orientation == "horizontal" then
				local w = x1 - x0 - km[1] + 1
				x0 = max(x0, x0 + floor((v - self.Min) * w / r))
				x1 = min(x1, x0 + floor((self.Range - self.Max) * w / r) +
					km[1] - 1)
			else
				local h = y1 - y0 - km[2] + 1
				y0 = max(y0, y0 + floor((v - self.Min) * h / r))
				y1 = min(y1, y0 + floor((self.Range - self.Max) * h / r) +
					km[2] - 1)
			end
		end
		return x0 - m[1], y0 - m[2], x1 + m[3], y1 + m[4]
	end
end

-------------------------------------------------------------------------------
--	updateBGRegion:
-------------------------------------------------------------------------------

function Slider:updateBGRegion()
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

function Slider:layout(r1, r2, r3, r4, markdamage)
	if Numeric.layout(self, r1, r2, r3, r4, markdamage) then
		local x0, y0, x1, y1 = self:getKnobRect()
		self.Child:layout(x0, y0, x1, y1, markdamage)
		self:updateBGRegion()
		return true
	end
end

-------------------------------------------------------------------------------
--	relayout: overrides
-------------------------------------------------------------------------------

function Slider:relayout(e, r1, r2, r3, r4)
	local res, changed = Numeric.relayout(self, e, r1, r2, r3, r4)
	if res then
		return res, changed
	end
	return self.Child:relayout(e, r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	refresh: overrides
-------------------------------------------------------------------------------

function Slider:refresh()
	Numeric.refresh(self)
	self.Child:refresh()
end

-------------------------------------------------------------------------------
--	damage: overrides
-------------------------------------------------------------------------------

function Slider:damage(r1, r2, r3, r4)
	Numeric.damage(self, r1, r2, r3, r4)
	self.Child:damage(r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function Slider:draw()
	local d = self.Drawable
	local bgpen, tx, ty = self:getBG()
	self.BGRegion:forEach(d.fillRect, d, d.Pens[bgpen], tx, ty)
end

-------------------------------------------------------------------------------
--	clickContainer:
-------------------------------------------------------------------------------

function Slider:clickContainer(xy)
	if not self.ClickDirection then
		local b1, b2, b3, b4 = self.Child:getBorder()
		if self.Orientation == "horizontal" then
			if xy[1] < self.Child.Rect[1] - b1 then
				self.ClickDirection = -1
			elseif xy[1] > self.Child.Rect[3] + b3 then
				self.ClickDirection = 1
			end
		else
			if xy[2] < self.Child.Rect[2] - b2 then
				self.ClickDirection = -1
			elseif xy[2] > self.Child.Rect[4] + b4 then
				self.ClickDirection = 1
			end
		end
	end
	if self.ClickDirection then
		self:increase(self.ClickDirection * self.Step)
	end
end

-------------------------------------------------------------------------------
--	onHold:
-------------------------------------------------------------------------------

function Slider:onHold(hold)
	if hold then
		if not self.Move0 then
			if self.HoldXY[1] then
				self:clickContainer(self.HoldXY)
			end
		end
	else
		self.ClickDirection = false
	end
end

-------------------------------------------------------------------------------
--	startMove:
-------------------------------------------------------------------------------

function Slider:startMove(x, y)
	local b1, b2, b3, b4 = self.Child:getBorder()
	if x >= self.Child.Rect[1] - b1 and x <= self.Child.Rect[3] + b3 and
		y >= self.Child.Rect[2] - b2 and y <= self.Child.Rect[4] + b4 then
	 	self.Move0 = { x, y }
	 	self.Pos0 = self.Value
		return self
	end
	return false
end

-------------------------------------------------------------------------------
--	doMove:
-------------------------------------------------------------------------------

function Slider:doMove(x, y)
	local r = self.Rect
	local m = self.Child.MarginAndBorder
	local newv
	local km = self.Child.MinMax
	if self.Orientation == "horizontal" then
		local w = r[3] - r[1] - m[3] - m[1] - km[1] + 1
		newv = self.Pos0 +
			(x - self.Move0[1]) * (self.Range - self.Min) / max(w, 1)
	else
		local h = r[4] - r[2] - m[4] - m[2] - km[2] + 1
		newv = self.Pos0 +
			(y - self.Move0[2]) * (self.Range - self.Min) / max(h, 1)
	end
	if self.Integer then
		newv = floor(newv)
	end
	self:setValue("Value", newv)
end

-------------------------------------------------------------------------------
--	updateslider: internal
-------------------------------------------------------------------------------

local function updateslider(self)
	local win = self.Window
	if win then
		local x0, y0, x1, y1 = self:getKnobRect()
		if x0 then
			local _, changed = win:relayout(self.Child, x0, y0, x1, y1)
			if changed then
				self:updateBGRegion()
				if self.Redraw then
					-- also redraw child if we're slated for redraw already:
					self.Child.Redraw = true
				end
				self.Redraw = true
			end
		end
	end
end

-------------------------------------------------------------------------------
--	onSetValue: overrides
-------------------------------------------------------------------------------

function Slider:onSetValue(v)
	Numeric.onSetValue(self, v)
	updateslider(self)
end

-------------------------------------------------------------------------------
--	onSetMax: overrides
-------------------------------------------------------------------------------

function Slider:onSetMax(m)
	Numeric.onSetMax(self, m)
	updateslider(self)
end

-------------------------------------------------------------------------------
--	onSetRange(range): This handler is invoked when the Slider's
--	{{Range}} attribute has changed.
-------------------------------------------------------------------------------

function Slider:onSetRange(r)
	updateslider(self)
end

-------------------------------------------------------------------------------
--	passMsg: overrides
-------------------------------------------------------------------------------

function Slider:passMsg(msg)
	if self:getElementByXY(msg[4], msg[5]) then
		if msg[2] == ui.MSG_MOUSEBUTTON then
			if msg[3] == 64 then -- wheelup
				self:decrease()
				return false -- absorb
			elseif msg[3] == 128 then -- wheeldown
				self:increase()
				return false -- absorb
			end
		elseif msg[2] == ui.MSG_KEYDOWN then
			if msg[3] == 0xf023 then -- PgUp
				self:decrease(self.Range - (self.Max - self.Min + 1))
			elseif msg[3] == 0xf024 then -- PgDown
				self:increase(self.Range - (self.Max - self.Min + 1))
			end
		end
	end
	local win = self.Window
	if win then
		if msg[2] == ui.MSG_MOUSEBUTTON then
			if msg[3] == 1 then -- leftdown:
				if win.HoverElement == self and not self.Disabled then
					if self:startMove(msg[4], msg[5]) then
						win:setMovingElement(self)
					else
						-- otherwise the container was clicked:
						self.HoldXY[1] = msg[4]
						self.HoldXY[2] = msg[5]
						self:clickContainer(self.HoldXY)
					end
				end
			elseif msg[3] == 2 then -- leftup:
				if win.MovingElement == self then
					win:setMovingElement()
				end
				self.Move0 = false
				self.ClickDirection = false
			end
		elseif msg[2] == ui.MSG_MOUSEMOVE then
			if win.MovingElement == self then
				self:doMove(msg[4], msg[5])
				-- do not pass message to other elements while dragging:
				return false
			end
		end
	end
	return Numeric.passMsg(self, msg)
end

-------------------------------------------------------------------------------
--	handleInput:
-------------------------------------------------------------------------------

function Slider:handleInput(msg)
	if msg[2] == ui.MSG_KEYDOWN then
		if msg[3] == 13 and self.Captured and not self.AutoFocus then
			self:setCapture(false)
			return false
		end
		local na = not self.AutoFocus
		local h = self.Orientation == "horizontal"
		if msg[3] == 0xf010 and (na or h) or 
			msg[3] == 0xf012 and (na or not h) then
			self:decrease()
			return false
		elseif msg[3] == 0xf011 and (na or h) or
			msg[3] == 0xf013 and (na or not h) then
			self:increase()
			return false
		end
	end
	return msg
end

-------------------------------------------------------------------------------
--	onFocus: overrides
-------------------------------------------------------------------------------

function Slider:onFocus(focused)
	if self.AutoFocus then
		self:setCapture(focused)
	elseif not focused then
		self:setCapture(false)
	end
	Numeric.onFocus(self, focused)
end

-------------------------------------------------------------------------------
--	onSelect: overrides
-------------------------------------------------------------------------------

function Slider:onSelect(selected)
	if selected and not self.AutoFocus then
		-- enter captured mode:
		self:setCapture(true)
	end
	Numeric.onSelect(self, selected)
end

-------------------------------------------------------------------------------
--	setCapture: [internal] Sets the element's capture mode. If captured,
--	keyboard shortcuts can be used to adjust the slider's knob.
-------------------------------------------------------------------------------

function Slider:setCapture(onoff)
	if onoff and not self.Captured then
		self.Window:addInputHandler(ui.MSG_KEYDOWN, self, self.handleInput)
	elseif not onoff and self.Captured then
		self.Window:remInputHandler(ui.MSG_KEYDOWN, self, self.handleInput)
	end
	self.Captured = onoff
	self:setState()
end

-------------------------------------------------------------------------------
--	setState: overrides
-------------------------------------------------------------------------------

function Slider:setState(bg, fg)
	if not bg and self.Captured then
		bg = self.BGSelected
	end
	Gadget.setState(self, bg)
end

