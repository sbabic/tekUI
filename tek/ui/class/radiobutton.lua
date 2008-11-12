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

module("tek.ui.class.radiobutton", tek.ui.class.checkmark)
_VERSION = "RadioButton 2.0"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local coords =
{
	40,30,
	30,40,
	10,50,
	-10,50,
	-30,40,
	-40,30,
	-50,10,
	-50,-10,
	-40,-30,
	-30,-40,
	-10,-50,
	10,-50,
	30,-40,
	40,-30,
	50,-10,
	50,10,

	26,23,
	10,30,
	-10,30,
	-23,23,
	-30,10,
	-30,-10,
	-23,-23,
	-10,-30,
	10,-30,
	23,-23,
	30,-10,
	30,10,

	0,0,
}

local points1 = { 1,17,2,18,3,19,4,20,5,20,6,21,7,22,8,23,9,23,10 }
local points2 = { 23,10,24,11,25,12,26,13,26,14,27,15,28,16,17,1 }
local points3 = { 29,17,18,19,20,21,22,23,24,25,26,27,28,17 }

local RadioImage1 = VectorImage:new
{
	ImageData =
	{
		Coords = coords,
		Primitives =
		{
			{ 0x1000, 19, Points = points1, Pen = ui.PEN_BORDERSHINE },
			{ 0x1000, 16, Points = points2, Pen = ui.PEN_BORDERSHADOW },
		},
		MinMax = { -60, -60, 60, 60 },
	}
}

local RadioImage2 = VectorImage:new
{
	ImageData =
	{
		Coords = coords,
		Primitives = {
			{ 0x1000, 19, Points = points1, Pen = ui.PEN_BORDERSHADOW },
			{ 0x1000, 16, Points = points2, Pen = ui.PEN_BORDERSHINE },
			{ 0x2000, 14, Points = points3, Pen = ui.PEN_DETAIL },
		},
		MinMax = { -60, -60, 60, 60 },
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
