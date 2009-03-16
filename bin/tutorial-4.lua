#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	ThemeName = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "tutorial-4",
			Children =
			{
				ui.Text:new
				{
					Text = "Hello",
					Mode = "button",
					Class = "button",
					Width = "auto",

					onPress = function(self, pressed)
						local button = self.Application:getElementById("output")
						if pressed == true then
							button:setValue("Text", "world")
						else
							button:setValue("Text", "")
						end
						ui.Text.onPress(self, pressed)
					end

				},
				ui.Text:new
				{
					Legend = "Output",
					Id = "output",
					Height = "free",
					FontSpec = ":100",
				}
			}
		}
	}

}:run()
