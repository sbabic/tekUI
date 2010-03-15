#!/usr/bin/env lua

ui = require "tek.ui"

ui.Application:new
{
	AuthorStyleSheets = "tutorial",
	Children =
	{
		ui.Window:new
		{
			Title = "Tutorial 6",
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

					onSetValue = function(self)
						ui.Slider.onSetValue(self)
						local output = self:getById("output")
						output:setValue("Text", ("%.2f"):format(self.Value))
					end,

					show = function(self)
						ui.Slider.show(self)
						self:setValue("Value", self.Value, true)
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
