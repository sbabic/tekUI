-------------------------------------------------------------------------------
--
--	tek.ui.image.check
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	Version 1.0
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local VectorImage = ui.VectorImage
module("tek.ui.image.check", tek.ui.class.vectorimage)

local coords =
{
	0x8000, 0x8000,
	0x5555, 0xaaaa,
	0x4000, 0x9555,
	0x8000, 0x5555,
	0xeaaa, 0xc000,
	0xd555, 0xd555,
	0x0000, 0xffff,
	0x2aaa, 0xd555,
	0xffff, 0xffff,
	0xd555, 0xd555,
	0xffff, 0x0000,
	0xd555, 0x2aaa,
	0x0000, 0x0000,
	0x2aaa, 0x2aaa,
	
}

local points1 = { 1,2,3,4,5,6 }
local points21 = { 13,14,7,8,9,10 }
local points22 = { 9,10,11,12,13,14 }
local points3 = { 8,10,14,12 }

local primitives1 =
{
	{ 0x1000, 6, points21, ui.PEN_BORDERSHADOW },
	{ 0x1000, 6, points22, ui.PEN_BORDERSHINE },
	{ 0x1000, 4, points3, ui.PEN_BACKGROUND },
}

local primitives2 =
{
	{ 0x1000, 6, points21, ui.PEN_BORDERSHADOW },
	{ 0x1000, 6, points22, ui.PEN_BORDERSHINE },
	{ 0x1000, 4, points3, ui.PEN_BACKGROUND },
	{ 0x2000, 6, points1, ui.PEN_DETAIL },
}

function new(class, num)
	return VectorImage.new(class, {
		coords,
		num == 2 and primitives2 or primitives1,
		true
	})
end
