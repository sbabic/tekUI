#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	AuthorStyleSheets = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "Tutorial 5",
			Orientation = "vertical",
			Children =
			{
				ui.Text:new
				{
					Legend = "Output",
					Id = "output",
					Height = "free",
					Style = "font: :100",
				},

				ui.Slider:new
				{
					Min = 0,
					Max = 100,
					Value = 50,
					onSetValue = function(self, value)
						ui.Slider.onSetValue(self, value)
						print("Value:", self.Value)
					end,
				},

				ui.Group:new
				{
					Children =
					{
						ui.Text:new
						{
							Text = "0",
							Style = "text-align: left",
							Class = "caption",
						},
						ui.Text:new
						{
							Text = "100",
							Style = "text-align: right",
							Class = "caption",
						},
					}
				}

			}
		}
	}

}:run()
