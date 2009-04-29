#!/usr/bin/env lua

local ui = require "tek.ui"

local RadioImage1 = ui.createImage("radio")
local RadioImage2 = ui.createImage("radio", 2)

local BitMapImage1 = ui.BitmapImage:new
{
	io.open(ui.ProgDir .. "/graphics/world.ppm", "rb"):read("*a"),
}

local BitMapImage2 = ui.BitmapImage:new
{
	io.open(ui.ProgDir .. "/graphics/locale.ppm", "rb"):read("*a"),
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
					MinWidth = 20,
					MinHeight = 20,
					Mode = "button",
					Style = "padding: 10",
					ImageAspectX = 2,
					ImageAspectY = 3,
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
