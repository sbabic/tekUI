
--
--	tek.ui.class.meter
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	This class paints sets of 256 16bit numbers coming in as MSG_USER,
--	for which it registers an input handler with the application.
--

local ui = require "tek.ui"
local Frame = ui.Frame

local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin
local tonumber = tonumber

module("tek.ui.class.meter", tek.ui.class.frame)
_VERSION = "Meter 1.1"

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Meter = _M

function Meter.init(self)
	self.Data = { }
	self.NumSamples = self.NumSamples or 256
	for cx = 0, self.NumSamples - 1 do
		self.Data[cx] = 0
	end
	return Frame.init(self)
end

function Meter:show(display, drawable)
	if Frame.show(self, display, drawable) then
		self.Application:addInputHandler(ui.MSG_USER, self, self.updateData)
		return true
	end
end

function Meter:hide()
	self.Application:remInputHandler(ui.MSG_USER, self, self.updateData)
	Frame.hide(self)
end

function Meter:draw()
	local d = self.Drawable
	local p0, p1 = d.Pens[ui.PEN_DARK], d.Pens[ui.PEN_SHINE]
	local r = self.Rect
	local width = r[3] - r[1] + 1
	local height = r[4] - r[2] + 1
	d:fillRect(r[1], r[2], r[3], r[4], p0)
	local y = r[2]
	local n = #self.Data
	local dx = width / (n - 1)
	local y = r[2] + height
	local data = self.Data
	local v0 = data[0] * height / 0x10000
	local x0 = r[1]
	for i = 1, min(n - 1, 255) do
		local v1 = data[i] * height / 0x10000
		d:drawLine(x0, y - v0, x0 + dx, y - v1, p1)
		x0 = x0 + dx
		v0 = v1
	end
end

function Meter:updateData(msg)
	local i = 0
	for val in msg[-1]:gmatch("(%d+)") do
		self.Data[i] = tonumber(val)
		i = i + 1
	end
	self.Redraw = true
	return msg
end
