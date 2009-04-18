-------------------------------------------------------------------------------
--
--	tek.ui.class.checkmark
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
--		[[#tek.ui.class.text : Text]] /
--		CheckMark
--
--	OVERVIEW::
--		Specialization of a [[#tek.ui.class.text : Text]] for placing
--		checkmarks.
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Area:draw()
--		- Area:hide()
--		- Object.init()
--		- Area:layout()
--		- Class.new()
--		- Area:setState()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Text = ui.Text
local VectorImage = ui.VectorImage

local floor = math.floor
local ipairs = ipairs
local max = math.max
local unpack = unpack

module("tek.ui.class.checkmark", tek.ui.class.text)
_VERSION = "CheckMark 3.9"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local coords =
{
	0x8000, 0x8000,
	0x5555, 0xaaaa,
	0x4000, 0x9555,
	0x8000, 0x5555,
	0xeaaa, 0xc000,
	0xd555, 0xd555,
	0x1555, 0xeaaa,
	0x2aaa, 0xd555,
	0xeaaa, 0xeaaa,
	0xd555, 0xd555,
	0xeaaa, 0x1555,
	0xd555, 0x2aaa,
	0x1555, 0x1555,
	0x2aaa, 0x2aaa,
}

local points1 = { 1,2,3,4,5,6 }
local points21 = { 13,14,7,8,9,10 }
local points22 = { 9,10,11,12,13,14 }
local points3 = { 8,10,14,12 }

local CheckImage1 = VectorImage:new
{
	Coords = coords,
	Primitives =
	{
		{ 0x1000, 6, Points = points21, Pen = ui.PEN_BORDERSHADOW },
		{ 0x1000, 6, Points = points22, Pen = ui.PEN_BORDERSHINE },
		{ 0x1000, 4, Points = points3, Pen = ui.PEN_BACKGROUND },
	}
}

local CheckImage2 = VectorImage:new
{
	Coords = coords,
	Primitives =
	{
		{ 0x1000, 6, Points = points21, Pen = ui.PEN_BORDERSHADOW },
		{ 0x1000, 6, Points = points22, Pen = ui.PEN_BORDERSHINE },
		{ 0x1000, 4, Points = points3, Pen = ui.PEN_BACKGROUND },
		{ 0x2000, 6, Points = points1, Pen = ui.PEN_DETAIL },
	}
}

local DEF_IMAGEMINHEIGHT = 18

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local CheckMark = _M

function CheckMark.new(class, self)
	self = self or { }
	self.ImageRect = { 0, 0, 0, 0 }
	return Text.new(class, self)
end

function CheckMark.init(self)
	self.AltImage = self.AltImage or CheckImage2
	self.Image = self.Image or CheckImage1
	self.ImageHeight = false
	self.ImageMinHeight = self.ImageMinHeight or DEF_IMAGEMINHEIGHT
	self.ImageWidth = false
	self.KeyCode = self.KeyCode == nil and true or self.KeyCode
	self.Mode = self.Mode or "toggle"
	self.OldSelected = false
	return Text.init(self)
end

-------------------------------------------------------------------------------
--	hide:
-------------------------------------------------------------------------------

function CheckMark:hide()
	if self.TextRecords then
		self.TextRecords[1] = false
	end
	Text.hide(self)
end

-------------------------------------------------------------------------------
--	askMinMax:
-------------------------------------------------------------------------------

function CheckMark:askMinMax(m1, m2, m3, m4)
	local tr = self.TextRecords and self.TextRecords[1]
	if tr then
		local w, h = tr[9], tr[10]
		self.ImageHeight = max(h, self.ImageMinHeight or h)
		self.ImageWidth = self.ImageHeight * self.Drawable.AspectX /
			self.Drawable.AspectY
		h = max(0, self.ImageHeight - h)
		local h2 = floor(h / 2)
		tr[5] = self.ImageWidth
		tr[6] = h2
		tr[7] = 0
		tr[8] = h - h2
	end
	return Text.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	layout:
-------------------------------------------------------------------------------

function CheckMark:layout(x0, y0, x1, y1, markdamage)
	if Text.layout(self, x0, y0, x1, y1, markdamage) then
		local i = self.ImageRect
		local r = self.Rect
		local p = self.Padding
		local eh = r[4] - r[2] - p[4] - p[2] + 1
		local iw = self.ImageWidth
		local ih = self.ImageHeight
		i[1] = r[1] + p[1]
		i[2] = r[2] + p[2] + floor((eh - ih) / 2)
		i[3] = i[1] + iw - 1
		i[4] = i[2] + ih - 1
		return true
	end
end

-------------------------------------------------------------------------------
--	draw:
-------------------------------------------------------------------------------

function CheckMark:draw()
	Text.draw(self)
	local img = self.Selected and self.AltImage or self.Image
	if img then
		img:draw(self.Drawable, unpack(self.ImageRect))
	end
end

-------------------------------------------------------------------------------
--	setState:
-------------------------------------------------------------------------------

function CheckMark:setState(bg, fg)
	if self.Selected ~= self.OldSelected then
		self.OldSelected = self.Selected
		self.Redraw = true
	end
	Text.setState(self, bg, fg)
end
