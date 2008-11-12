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
_VERSION = "RadioButton 2.1"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local coords =
{
	0, 0,
	-2317048, -2317048,
	-3165146, -848099,
	-3165146, 848098,
	-2317048, 2317047,
	-848099, 3165145,
	848098, 3165145,
	2317047, 2317047,
	3165145, 848098,
	3165145, -848099,
	2317047, -2317048,
	848098, -3165146,
	-848099, -3165146,
	-1714616, -1714616,
	-2342208, -627593,
	-2342208, 627592,
	-1714616, 1714615,
	-627593, 2342207,
	627592, 2342207,
	1714615, 1714615,
	2342207, 627592,
	2342207, -627593,
	1714615, -1714616,
	627592, -2342208,
	-627593, -2342208,
	-1558211, -506294,
	-1558211, 506293,
	-963028, 1325493,
	-1, 1638400,
	963027, 1325493,
	1558210, 506293,
	1558210, -506294,
	963027, -1325494,
	0, -1638400,
	-963028, -1325494,
}

-- local function calccircle(n, r, t, a)
-- 	local nt = #t
-- 	a = a or 0
-- 	for i = 0, n - 1 do
-- 		local x = floor(-cos(a) * r)
-- 		local y = floor(sin(a) * r)
-- 		db.warn("%s, %s,", x, y)
-- 		t[1 + nt + i * 2] = x
-- 		t[2 + nt + i * 2] = y
--
-- 		a = a + 2 * pi / n
-- 	end
-- end
-- calccircle(12, 50*0x10000, coords, -45*pi/180)
-- calccircle(12, 37*0x10000, coords, -45*pi/180)
-- calccircle(10, 25*0x10000, coords, -18*pi/180)

local points11 = { 2,14,3,15,4,16,5,17,6,18,7,19,8,20,9,21 }
local points12 = { 9,21,10,22,11,23,12,24,13,25,2,14 }
local points2 = { 1,26,27,28,29,30,31,32,33,34,35,26 }

local RadioImage1 = VectorImage:new
{
	ImageData =
	{
		Coords = coords,
		Primitives =
		{
			{ 0x1000, 16, Points = points11, Pen = ui.PEN_BORDERSHADOW },
			{ 0x1000, 12, Points = points12, Pen = ui.PEN_BORDERSHINE },
		},
		MinMax = { -60*0x10000, 60*0x10000, 60*0x10000, -60*0x10000 },
	}
}

local RadioImage2 = VectorImage:new
{
	ImageData =
	{
		Coords = coords,
		Primitives = {
			{ 0x1000, 16, Points = points11, Pen = ui.PEN_BORDERSHADOW },
			{ 0x1000, 12, Points = points12, Pen = ui.PEN_BORDERSHINE },
			{ 0x2000, 12, Points = points2, Pen = ui.PEN_DETAIL },
		},
		MinMax = { -60*0x10000, 60*0x10000, 60*0x10000, -60*0x10000 },
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
