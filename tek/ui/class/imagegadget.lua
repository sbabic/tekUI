
--
--	tek.ui.class.imagegadget
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--

local ui = require "tek.ui"
local Gadget = ui.Gadget
local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type
local unpack = unpack
local Region = require "tek.lib.region"

module("tek.ui.class.imagegadget", tek.ui.class.gadget)
_VERSION = "ImageGadget 4.0"

-------------------------------------------------------------------------------
-- Class implementation:
-------------------------------------------------------------------------------

local ImageGadget = _M

function ImageGadget.new(class, self)
	self.HAlign = self.HAlign or "center"
	self.Image = self.Image or false
	self.ImageAspectX = self.ImageAspectX or 1
	self.ImageAspectY = self.ImageAspectY or 1
	self.ImageData = { } -- layouted x, y, width, height
	self.ImageWidth = self.ImageWidth or false
	self.ImageHeight = self.ImageHeight or false
	self.EraseBG = true -- We paint the background ourselves
	self.Region = false
	self = Gadget.new(class, self)
	self:setImage(self.Image)
	return self
end

-------------------------------------------------------------------------------
--	askMinMax:
-------------------------------------------------------------------------------

function ImageGadget:askMinMax(m1, m2, m3, m4)
	local d = self.ImageData
	
	local mw = self.MinWidth
	local mh = self.MinHeight
	local iw = self.ImageWidth
	local ih = self.ImageHeight
	local ax = self.ImageAspectX
	local ay = self.ImageAspectY
	
	if iw then
		iw = max(iw, mw)
	else
		iw = floor((ih or mh) * ax / ay)
	end
	
	if ih then
		ih = max(ih, mh)
	else
		ih = floor((iw or mw) * ay / ax)
	end
	
	return Gadget.askMinMax(self, m1 + iw, m2 + ih, m3 + iw, m4 + ih)
end

-------------------------------------------------------------------------------
--	setImage:
-------------------------------------------------------------------------------

function ImageGadget:setImage(img)
	self.Image = img
	self.Redraw = true
	local iw, ih = img:askWidthHeight(false, false)
	if iw ~= self.ImageWidth or ih ~= self.ImageHeight then
		self.ImageWidth = iw
		self.ImageHeight = ih
		self:rethinkLayout()
	end
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function ImageGadget:layout(r1, r2, r3, r4, markdamage)
	if Gadget.layout(self, r1, r2, r3, r4, markdamage) then
		local r = self.Rect
		local p = self.Padding
		local x, y = r[1], r[2]
		local w = r[3] - x - p[1] - p[3] + 1
		local h = r[4] - y - p[2] - p[4] + 1
		local id = self.ImageData
		local iw, ih
		
		if self.ImageWidth then
			-- given size:
			iw, ih = self.ImageWidth, self.ImageHeight
		else
			-- can stretch:
			iw, ih = self.Display:fitMinAspect(w, h, self.ImageAspectX,
				self.ImageAspectY)
		end
		
		if iw ~= w or ih ~= h then
			self.Region = Region.new(x, y, r[3], r[4])
		elseif self.Image[3] then -- transparent?
			self.Region = Region.new(x, y, r[3], r[4])
		else
			self.Region = false
		end
		x = x + p[1]
		y = y + p[2]
		if iw ~= w or ih ~= h then
			if self.HAlign == "center" then
				x = x + floor((w - iw) / 2)
				y = y + floor((h - ih) / 2)
			end
			if not self.Image[3] then -- transparent?
				self.Region:subRect(x, y, x + iw - 1, y + ih - 1)
			end
		end
		id[1], id[2], id[3], id[4] = x, y, iw, ih
		return true
	end
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function ImageGadget:draw()
	Gadget.draw(self)
	local d = self.Drawable
	local R = self.Region
	if R then
		local bgpen = d.Pens[self.Background]
		for _, r1, r2, r3, r4 in R:getRects() do
			d:fillRect(r1, r2, r3, r4, bgpen)
		end
	end
	local x, y, iw, ih = unpack(self.ImageData)
	self.Image:draw(d, x, y, x + iw - 1, y + ih - 1, 
		self.Disabled and d.Pens[self.Foreground])
end
