#!/usr/bin/env lua

local ui = require "tek.ui"

-------------------------------------------------------------------------------
--	coordinates are 16 bit integers, encoding a fraction in the range from
--	0 to 1.
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

-------------------------------------------------------------------------------
--	point tables encode indices in the coordinate table:
-------------------------------------------------------------------------------

local points11 = { 2,14,3,15,4,16,5,17,6,18,7,19,8,20,9,21 }
local points12 = { 9,21,10,22,11,23,12,24,13,25,2,14 }
local points2 = { 1,26,27,28,29,30,31,32,33,34,35,26 }

-------------------------------------------------------------------------------
--	Primitive types:
--	- 0x1000 specifies a triangle strip,
--	- 0x2000 specifies a triangle fan.
-------------------------------------------------------------------------------

local RadioImage1 = ui.VectorImage:new
{
	Coords = coords,
	Primitives =
	{
		{ 0x1000, 16, Points = points11, Pen = ui.PEN_BORDERSHADOW },
		{ 0x1000, 12, Points = points12, Pen = ui.PEN_BORDERSHINE },
	},
	Transparent = true,
}

local RadioImage2 = ui.VectorImage:new 
{
	Coords = coords,
	Primitives = {
		{ 0x1000, 16, Points = points11, Pen = ui.PEN_BORDERSHADOW },
		{ 0x1000, 12, Points = points12, Pen = ui.PEN_BORDERSHINE },
		{ 0x2000, 12, Points = points2, Pen = ui.PEN_DETAIL },
	},
	Transparent = true,
}

local BitMapImage1 = ui.BitmapImage:new
{
	Image = io.open(ui.ProgDir .. "/graphics/world.ppm"):read("*a"),
}

local BitMapImage2 = ui.BitmapImage:new
{
	Image = io.open(ui.ProgDir .. "/graphics/locale.ppm"):read("*a"),
}

-------------------------------------------------------------------------------
--	Main:
-------------------------------------------------------------------------------

ui.Application:new 
{
	Children = 
	{
		ui.Window:new 
		{
			HideOnEscape = true,
			Children = 
			{
				ui.ImageGadget:new 
				{ 
					Image = RadioImage1, 
					MinWidth = 100,
					MinHeight = 100,
					Mode = "button",
					Style = "padding: 10",
					onPress = function(self, press)
						self:setImage(press and RadioImage2 or RadioImage1)
						ui.ImageGadget.onPress(self, press)
					end
				},
				ui.ImageGadget:new 
				{ 
					Mode = "button",
					Image = BitMapImage1,
					Style = "padding: 10",
					onPress = function(self, press)
						self:setImage(press and BitMapImage2 or BitMapImage1)
						ui.ImageGadget.onPress(self, press)
					end
				}
			}
		}
	}
}:run()
