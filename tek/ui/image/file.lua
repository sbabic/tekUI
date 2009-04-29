-------------------------------------------------------------------------------
--
--	tek.ui.image.file
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	Version 1.1
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local VectorImage = ui.VectorImage
module("tek.ui.image.file", tek.ui.class.vectorimage)

local coords =
{
	0x9999, 0xffff,
	0x7777, 0xeeee,
	0x1111, 0xffff,
	0x3333, 0xeeee,
	0x1111, 0x0000,
	0x3333, 0x2222,
	0xffff, 0x0000,
	0xdddd, 0x2222,
	0xffff, 0xaaaa,
	0xdddd, 0x8888,
	0x7777, 0x8888,
	0x9999, 0xdddd,
	0xcccc, 0xaaaa,
	0x9999, 0xaaaa
}

local primitives =
{
	{ 0x2000, 6, { 11,2,4,6,8,10 }, ui.PEN_OUTLINE },
	{ 0x1000, 10, { 1,2,3,4,5,6,7,8,9,10 }, ui.PEN_DETAIL },
	{ 0x1000, 10, { 1,2,12,11,14,10,13,9,12,1 }, ui.PEN_DETAIL },
	{ 0x2000, 3, { 12,13,14 }, ui.PEN_OUTLINE },
}

function new(class, num)
	return VectorImage.new(class, { coords, primitives, true })
end
