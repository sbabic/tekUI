#!/usr/bin/env lua

local ui = require "tek.ui"

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

local window = ui.Window:new
{
	Id = "slider-window",
	Title = L.SLIDER_TITLE,
	Status = "hide",
	Orientation = "vertical",
	Notifications =
	{
		["Status"] =
		{
			["show"] =
			{
				{ ui.NOTIFY_ID, "slider-window-button", "setValue", "Selected", true }
			},
			["hide"] =
			{
				{ ui.NOTIFY_ID, "slider-window-button", "setValue", "Selected", false }
			},
		},
	},
	Children =
	{
		ui.Group:new
		{
			Legend = L.SLIDER_SLIDERS,
			GridWidth = 3,
			Children =
			{
				ui.Text:new
				{
					Text = L.SLIDER_CONTINUOUS,
					Style = "width: fill",
				},
				ui.ScrollBar:new
				{
					Id = "slider-slider-1",
					Style = "width: free",
					Min = 0,
					Max = 10,
					Kind = "number",
					Notifications =
					{
						["Value"] =
						{
							[ui.NOTIFY_CHANGE] =
							{
								{ ui.NOTIFY_ID, "slider-text-1", "setValue", "Text", ui.NOTIFY_FORMAT, "%2.2f" },
								{ ui.NOTIFY_ID, "slider-slider-2", "setValue", "Value", ui.NOTIFY_VALUE },
								{ ui.NOTIFY_ID, "slider-gauge-1", "setValue", "Value", ui.NOTIFY_VALUE  }
							}
						}
					}
				},
				ui.Text:new
				{
					Id = "slider-text-1",
					Style = "width: fill",
					Text = "  0.00  ",
					KeepMinWidth = true,
				},

				ui.Text:new
				{
					Text = L.SLIDER_INTEGER_STEP,
					Style = "width: fill",
				},
				ui.ScrollBar:new
				{
					Id = "slider-slider-2",
					Style = "width: free",
					Min = 0,
					Max = 10,
					ForceInteger = true,
					Kind = "number",
					Notifications =
					{
						["Value"] =
						{
							[ui.NOTIFY_CHANGE] =
							{
								{ ui.NOTIFY_ID, "slider-text-2", "setValue", "Text", ui.NOTIFY_FORMAT, "%d" },
								{ ui.NOTIFY_ID, "slider-slider-1", "setValue", "Value", ui.NOTIFY_VALUE },
								{ ui.NOTIFY_ID, "slider-gauge-1", "setValue", "Value", ui.NOTIFY_VALUE  }
							}
						}
					}
				},
				ui.Text:new
				{
					Id = "slider-text-2",
					Style = "width: fill",
					Text = "  0  ",
					KeepMinWidth = true,
				},

				ui.Text:new
				{
					Text = L.SLIDER_RANGE,
					Style = "width: fill",
				},
				ui.ScrollBar:new
				{
					Id = "slider-slider-3",
					Style = "width: free",
					Min = 10,
					Max = 20,
					ForceInteger = true,
					Kind = "number",
					Notifications =
					{
						["Value"] =
						{
							[ui.NOTIFY_CHANGE] =
							{
								{ ui.NOTIFY_ID, "slider-text-3", "setValue", "Text", ui.NOTIFY_FORMAT, "%d" },
								{ ui.NOTIFY_ID, "slider-slider-1", "setValue", "Range", ui.NOTIFY_VALUE },
								{ ui.NOTIFY_ID, "slider-slider-2", "setValue", "Range", ui.NOTIFY_VALUE },
							}
						}
					}
				},
				ui.Text:new
				{
					Id = "slider-text-3",
					Style = "width: fill",
					Text = "  0  ",
					KeepMinWidth = true,
				},

			}
		},
		ui.Group:new
		{
			Legend = L.SLIDER_GAUGES,
			Children =
			{
				ui.Gauge:new
				{
					Min = 0,
					Max = 10,
					Id = "slider-gauge-1",
				},
			}
		},
	}
}

if ui.ProgName == "slider.lua" then
	local app = ui.Application:new()
	ui.Application.connect(window)
	app:addMember(window)
	window:setValue("Status", "show")
	app:run()
else
	return
	{
		Window = window,
		Name = "Slider",
		Description = L.SLIDER_DESCRIPTION,
	}
end
