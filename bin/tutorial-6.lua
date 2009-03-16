#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	ThemeName = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "tutorial-6",
			Orientation = "vertical",
			Children =
			{
				ui.Text:new
				{
					Legend = "Output",
					Id = "output",
					Height = "free",
					FontSpec = ":100",
				},

				ui.Slider:new
				{
					Min = 0,
					Max = 100,
					Value = 50,

					onSetValue = function(self, value)
						ui.Slider.onSetValue(self, value)
						local output = self.Application:getElementById("output")
						output:setValue("Text", ("%.2f"):format(self.Value))
					end,

					show = function(self, display, drawable)
						self:setValue("Value", self.Value, true)
						return ui.Slider.show(self, display, drawable)
					end,
				},

				ui.Group:new
				{
					Children =
					{
						ui.Text:new
						{
							Text = "0",
							Width = "auto",
							Class = "caption",
						},
						ui.Area:new
						{
							Width = "free",
							Height = "auto"
						},
						ui.Text:new
						{
							Text = "100",
							Width = "auto",
							Class = "caption",
						},
					}
				}
			}
		}
	}

}:run()
