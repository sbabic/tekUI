
local ui = require "tek.ui"
local DrawHook = ui.DrawHook
local Region = require "tek.lib.region"
local unpack = unpack

module("tek.ui.class.border", tek.ui.class.drawhook)
_VERSION = "Border 6.0"
local Border = _M

function Border.init(self)
	self.Border = self.Border or false
	self.Rect = { }
	return DrawHook.init(self)
end

function Border:getBorder()
	return unpack(self.Border)
end

function Border:layout(x0, y0, x1, y1)
	local r = self.Rect
	if not x0 then
		x0, y0, x1, y1 = unpack(self.Parent.Rect)
	end
	r[1], r[2], r[3], r[4] = x0, y0, x1, y1
	return x0, y0, x1, y1
end

function Border:getBorderRegion()
	local b1, b2, b3, b4 = self:getBorder()
	local x0, y0, x1, y1 = self:layout()
	local b = Region.new(x0 - b1, y0 - b2, x1 + b3, y1 + b4)
	b:subRect(x0, y0, x1, y1)
	return b, x0, y0, x1, y1
end
