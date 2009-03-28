#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	Theme = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "Tutorial 2",
			Children =
			{
				ui.Button:new
				{
					Text = "Hello world",
					onPress = function(self, pressed)
						if pressed == false then
							print "Hello world"
						end
						ui.Button.onPress(self, pressed)
					end
				}
			}
		}
	}
}:run()
