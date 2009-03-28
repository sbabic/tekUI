#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	Theme = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "Tutorial 4",
			Children =
			{
				ui.Button:new
				{
					Text = "Hello",
					Width = "auto",

					onPress = function(self, pressed)
						local button = self.Application:getElementById("output")
						if pressed == true then
							button:setValue("Text", "world")
						else
							button:setValue("Text", "")
						end
						ui.Button.onPress(self, pressed)
					end

				},
				ui.Text:new
				{
					Legend = "Output",
					Id = "output",
					Height = "free",
					Font = ":100",
				}
			}
		}
	}
}:run()
