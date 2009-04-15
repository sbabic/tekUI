-------------------------------------------------------------------------------
--
--	tek.ui.class.radiobutton
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
--		[[#tek.ui.class.checkmark : CheckMark]] /
--		RadioButton
--
--	OVERVIEW::
--		Specialization of a [[#tek.ui.class.checkmark : CheckMark]] to
--		implement mutually exclusive 'radio buttons'; they really make
--		sense only if more than one of their kind are grouped together.
--
--	OVERRIDES::
--		- Object.init()
--		- Gadget:onSelect()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local CheckMark = ui.CheckMark
local VectorImage = ui.VectorImage
local ipairs = ipairs

-- local floor = math.floor
-- local sin = math.sin
-- local cos = math.cos
-- local insert = table.insert
-- local pi = math.pi

module("tek.ui.class.radiobutton", tek.ui.class.checkmark)
_VERSION = "RadioButton 2.6"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local coords =
{
	0x8000, 0x8000,

	0x318e, 0x318e,
	0x14d8, 0x6349,
	0x14d8, 0x9cb6,
	0x318e, 0xce71,
	0x6349, 0xeb27,
	0x9cb6, 0xeb27,
	0xce71, 0xce71,
	0xeb27, 0x9cb6,
	0xeb27, 0x6349,
	0xce71, 0x318e,
	0x9cb6, 0x14d8,
	0x6349, 0x14d8,
	0x4b33, 0x4b33,
	0x37e0, 0x6cac,
	0x37e0, 0x9353,
	0x4b33, 0xb4cc,
	0x6cac, 0xc81f,
	0x9353, 0xc81f,
	0xb4cc, 0xb4cc,
	0xc81f, 0x9353,
	0xc81f, 0x6cac,
	0xb4cc, 0x4b33,
	0x9353, 0x37e0,
	0x6cac, 0x37e0,
	0x4d46, 0x6f84,
	0x4d46, 0x907b,
	0x60a6, 0xab25,
	0x7fff, 0xb555,
	0x9f59, 0xab25,
	0xb2b9, 0x907b,
	0xb2b9, 0x6f84,
	0x9f59, 0x54da,
	0x8000, 0x4aaa,
	0x60a6, 0x54da,
}

-- local function calccircle(n, r, t, a)
-- 	local nt = #t
-- 	a = a or 0
-- 	for i = 0, n - 1 do
-- 		local x = floor(-cos(a) * r * 0.5) + 0x8000
-- 		local y = floor(sin(a) * r * 0.5) + 0x8000
-- 		db.warn("0x%04x, 0x%04x,", x, y)
-- 		t[1 + nt + i * 2] = x
-- 		t[2 + nt + i * 2] = y
--
-- 		a = a + 2 * pi / n
-- 	end
-- end
--
-- calccircle(12, 0.52/0.6*0x10000, coords, -45*pi/180)
-- calccircle(12, 0.35/0.6*0x10000, coords, -45*pi/180)
-- calccircle(10, 0.25/0.6*0x10000, coords, -18*pi/180)

local points11 = { 2,14,3,15,4,16,5,17,6,18,7,19,8,20,9,21 }
local points12 = { 9,21,10,22,11,23,12,24,13,25,2,14 }
local points2 = { 1,26,27,28,29,30,31,32,33,34,35,26 }
local points3 = { 1,14,15,16,17,18,19,20,21,22,23,24,25,14 }

local RadioImage1 = VectorImage:new
{
	Coords = coords,
	Primitives =
	{
		{ 0x1000, 16, Points = points11, Pen = ui.PEN_BORDERSHADOW },
		{ 0x2000, 14, Points = points3, Pen = ui.PEN_BACKGROUND },
		{ 0x1000, 12, Points = points12, Pen = ui.PEN_BORDERSHINE },
	}
}

local RadioImage2 = VectorImage:new
{
	Coords = coords,
	Primitives = {
		{ 0x1000, 16, Points = points11, Pen = ui.PEN_BORDERSHADOW },
		{ 0x1000, 12, Points = points12, Pen = ui.PEN_BORDERSHINE },
		{ 0x2000, 14, Points = points3, Pen = ui.PEN_BACKGROUND },
		{ 0x2000, 12, Points = points2, Pen = ui.PEN_DETAIL },
	}
}

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local RadioButton = _M

function RadioButton.init(self)
	self.Image = self.Image or RadioImage1
	self.AltImage = self.AltImage or RadioImage2
	self.Mode = self.Mode or "touch"
	return CheckMark.init(self)
end

-------------------------------------------------------------------------------
--	onSelect:
-------------------------------------------------------------------------------

function RadioButton:onSelect(selected)
	if selected then
		-- unselect siblings in group:
		local myclass = self:getClass()
		for _, e in ipairs(self:getElement("siblings")) do
			if e ~= self and e:getClass() == myclass and e.Selected then
				e:setValue("Selected", false) -- no notify
			end
		end
	end
	CheckMark.onSelect(self, selected)
end
