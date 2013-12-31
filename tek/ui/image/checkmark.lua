-------------------------------------------------------------------------------
--
--	tek.ui.image.checkmark
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	Version 1.3
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Image = ui.Image
module("tek.ui.image.checkmark", tek.ui.class.image)
Image:newClass(_M)

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
	{ 0x1000, 6, points21, "border-shadow" },
	{ 0x1000, 6, points22, "border-shine" },
	{ 0x1000, 4, points3, "background" },
}

local primitives2 =
{
	{ 0x1000, 6, points21, "border-shadow" },
	{ 0x1000, 6, points22, "border-shine" },
	{ 0x1000, 4, points3, "background" },
	{ 0x2000, 6, points1, "detail" },
}

function new(class, num)
	return Image.new(class, { coords, false, false, true,
		num == 2 and primitives2 or primitives1 })
end
