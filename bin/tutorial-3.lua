#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	ThemeName = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "tutorial-3",
			Children =
			{
				ui.Text:new
				{
					Text = "Hello",
					Mode = "button",
					Class = "button",
					Width = "auto",
				},
				ui.Text:new
				{
					Text = "world",
					Mode = "button",
					Class = "button",
					Height = "free",
				},
			}
		}
	}

}:run()
