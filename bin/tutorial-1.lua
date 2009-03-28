#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	Theme = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "Tutorial 1",
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
