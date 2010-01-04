
--
--	tek.ui.class.imagegadget
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--

local ui = require "tek.ui"

local Gadget = ui.require("gadget", 19)
local Region = ui.loadLibrary("region", 9)

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type
local unpack = unpack

module("tek.ui.class.imagegadget", tek.ui.class.gadget)
_VERSION = "ImageGadget 9.1"

-------------------------------------------------------------------------------
-- Class implementation:
-------------------------------------------------------------------------------

local ImageGadget = _M

function ImageGadget.new(class, self)
	self.EraseBG = false
	self.HAlign = self.HAlign or "center"
	self.VAlign = self.VAlign or "center"
	self.Image = self.Image or false
	self.ImageAspectX = self.ImageAspectX or 1
	self.ImageAspectY = self.ImageAspectY or 1
	self.ImageData = { } -- layouted x, y, width, height
	self.ImageWidth = self.ImageWidth or false
	self.ImageHeight = self.ImageHeight or false
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
	self.Flags:set(ui.FL_REDRAW + ui.FL_CHANGED)
	if img then
		local iw, ih = img:askWidthHeight(false, false)
		if iw ~= self.ImageWidth or ih ~= self.ImageHeight then
			self.ImageWidth = iw
			self.ImageHeight = ih
			self:rethinkLayout(1, true)
		end
	end
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function ImageGadget:layout(r1, r2, r3, r4, markdamage)
	local res = Gadget.layout(self, r1, r2, r3, r4, markdamage)
	if self.Flags:checkClear(ui.FL_CHANGED) or res then
		local r = self.Rect
		local p1, p2, p3, p4 = self:getPadding()

		local x, y = r[1], r[2]
		local rw = r[3] - x + 1
		local rh = r[4] - y + 1
		local w = rw - p1 - p3
		local h = rh - p2 - p4
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
		elseif self.Image and self.Image[4] then -- transparent?
			self.Region = Region.new(x, y, r[3], r[4])
		else
			self.Region = false
		end
		x = x + p1
		y = y + p2
		if iw ~= rw or ih ~= rh then
			
			local ha = self.HAlign
			if ha == "center" then
				x = x + floor((w - iw) / 2)
			elseif ha == "right" then
				x = x + w - iw
			end
			local va = self.VAlign
			if va == "center" then
				y = y + floor((h - ih) / 2)
			elseif va == "bottom" then
				y = y + h - ih			
			end
			if self.Image and not self.Image[4] then -- transparent?
				self.Region:subRect(x, y, x + iw - 1, y + ih - 1)
			end
		end
		id[1], id[2], id[3], id[4] = x, y, iw, ih
	end
	return res
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function ImageGadget:draw()
	if Gadget.draw(self) then
		local d = self.Drawable
		local R = self.Region
		local img = self.Image
		if R then
			local bgpen, tx, ty = self:getBG()
			R:forEach(d.fillRect, d, d.Pens[bgpen], tx, ty)
		end
		if img then
			local x, y, iw, ih = unpack(self.ImageData)
			local pen = self.FGPen
			img:draw(d, x, y, x + iw - 1, y + ih - 1, 
				pen ~= "transparent" and 
				d.Pens[pen])
		end
		return true
	end
end
