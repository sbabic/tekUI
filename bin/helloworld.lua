#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	Children =
	{
		ui.Window:new
		{
			Title = "Hello",
			Children =
			{
				ui.Text:new
				{
					Text = "_Hello, World!",
					Class = "button",
					Mode = "button",

					onPress = function(self, pressed)
						if pressed == false then
							print "Hello, World!"
						end
						ui.Text.onPress(self, pressed)
					end,

					-- alternative implementation using Notification:

					-- Notifications =
					-- {
					-- 	["Pressed"] =
					-- 	{
					-- 		[false] =
					-- 		{
					-- 			{ ui.NOTIFY_SELF, ui.NOTIFY_FUNCTION,
					-- 				function(self)
					-- 					print "Hello, World!"
					-- 				end
					-- 			},
					-- 		},
					-- 	},
					-- },

				},
			},
		},
	},
}:run()
