
--
--	tek.ui.class.bitmapimage
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--	Implements bitmap rendering
--

local tonumber = tonumber
local Class = require "tek.class"
module("tek.ui.class.bitmapimage", tek.class)
_VERSION = "BitmapImage 1.0"
local BitmapImage = _M

function BitmapImage.new(class, self)
	self.Transparent = self.Transparent or false
	return Class.new(class, self)
end

function BitmapImage:draw(d, r1, r2, r3, r4)
	d:drawPPM(self.Image, r1, r2, r3, r4)
end

function BitmapImage:askWidthHeight(w, h)
	local iw, ih = self.Image:match("^P6\n(%d+) (%d+)\n")
	if not iw then
		iw, ih = img:match("^P6\n#[^\n]*\n(%d+) (%d+)\n")
	end
	if iw and ih then
		iw = tonumber(iw)
		ih = tonumber(ih)
		if iw > 0 and ih > 0 then
			return iw, ih
		end
	end
end
