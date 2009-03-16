#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	ThemeName = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "tutorial-2",
			Children =
			{
				ui.Text:new
				{
					Text = "Hello world",
					Mode = "button",
					Class = "button",

					onPress = function(self, pressed)
						if pressed == false then
							print "Hello world"
						end
						ui.Text.onPress(self, pressed)
					end
				}
			}
		}
	}

}:run()
