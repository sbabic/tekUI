#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	ThemeName = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "tutorial-1",
			Children =
			{
				ui.Text:new
				{
					Text = "Hello world",
				}
			}
		}
	}

}:run()
