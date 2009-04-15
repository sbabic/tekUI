#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	Children =
	{
		ui.Window:new
		{
			Title = "Hello",
			HideOnEscape = true,
			Children =
			{
				ui.Button:new
				{
					Text = "_Hello, World!",
					onPress = function(self, pressed)
						if pressed == false then
							print "Hello, World!"
						end
						ui.Button.onPress(self, pressed)
					end,
				},
			},
		},
	},
}:run()
