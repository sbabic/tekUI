
--
--	tek.ui.class.boing
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--

local ui = require "tek.ui"
local Frame = ui.Frame

local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin

module("tek.ui.class.boing", tek.ui.class.frame)
_VERSION = "Boing 1.4"

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Boing = _M

function Boing.init(self)
	self = self or { }
	self.Boing = { 0x8000, 0x8000 }
	self.Boing[3] = 0x334
	self.Boing[4] = 0x472
	self.Running = self.Running or false
	return Frame.init(self)
end

function Boing:show(display, drawable)
	if Frame.show(self, display, drawable) then
		self.Window:addInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
		return true
	end
end

function Boing:hide()
	self.Window:remInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
	Frame.hide(self)
end

function Boing:draw()
	local d = self.Drawable
	local r = self.Rect
	local w = r[3] - r[1] + 1
	local h = r[4] - r[2] + 1
	local x0, y0, x1, y1
	local w2 = w - w / 20
	local h2 = h - h / 20
	x0 = (self.Boing[1] * w2) / 0x10000 + self.Rect[1]
	y0 = (self.Boing[2] * h2) / 0x10000 + self.Rect[2]
	d:fillRect(r[1], r[2], r[3], r[4], d.Pens[ui.PEN_LIGHT])
	d:fillRect(x0, y0, x0 + w/20 - 1, y0 + h/20 - 1,
		d.Pens[ui.PEN_DARK])
end

function Boing:updateInterval(msg)
	if self.Running then
		local b = self.Boing
		b[1] = b[1] + b[3]
		b[2] = b[2] + b[4]
		if b[1] <= 0 or b[1] >= 0x10000 then
			b[3] = -b[3]
			b[1] = b[1] + b[3]
		end
		if b[2] <= 0 or b[2] >= 0x10000 then
			b[4] = -b[4]
			b[2] = b[2] + b[4]
		end
		self.Redraw = true
	end
	return msg
end
