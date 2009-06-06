
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
_VERSION = "ImageGadget 5.0"

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
	self.EraseBG = false -- We paint the background ourselves
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
	self.Redraw = true
	self.Image = img
	if img then
		local iw, ih = img:askWidthHeight(false, false)
		if iw ~= self.ImageWidth or ih ~= self.ImageHeight then
			self.ImageWidth = iw
			self.ImageHeight = ih
			self:rethinkLayout()
		end
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
		local rw = r[3] - x + 1
		local rh = r[4] - y + 1
		local w = rw - p[1] - p[3]
		local h = rh - p[2] - p[4]
		local id = self.ImageData
		local iw, ih
		
		if self.ImageWidth then
			-- given size:
			iw, ih = self.ImageWidth, self.ImageHeight
		else
			-- can stretch:
			iw, ih = self.Application.Display:fitMinAspect(w, h,
				self.ImageAspectX, self.ImageAspectY, 0)
		end
		
		if iw ~= rw or ih ~= rh then
			self.Region = Region.new(x, y, r[3], r[4])
		elseif self.Image[4] then -- transparent?
			self.Region = Region.new(x, y, r[3], r[4])
		else
			self.Region = false
		end
		x = x + p[1]
		y = y + p[2]
		if iw ~= rw or ih ~= rh then
			if self.HAlign == "center" then
				x = x + floor((w - iw) / 2)
				y = y + floor((h - ih) / 2)
			end
			if self.Image and not self.Image[4] then -- transparent?
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
	local img = self.Image
	if R then
		local bgpen, tx, ty = self:getBG()
		R:forEach(d.fillRect, d, d.Pens[bgpen], tx, ty)
	end
	if img then
		local x, y, iw, ih = unpack(self.ImageData)
		img:draw(d, x, y, x + iw - 1, y + ih - 1, 
			self.Disabled and d.Pens[self.FGPen])
	end
end
