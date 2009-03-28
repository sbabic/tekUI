#!/usr/bin/env lua

local ui = require "tek.ui"
local Gauge = ui.Gauge
local Group = ui.Group
local ScrollBar = ui.ScrollBar
local Slider = ui.Slider
local Text = ui.Text
local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = ui.Window:new
{
	Id = "slider-window",
	Title = L.SLIDER_TITLE,
	Status = "hide",
	Orientation = "vertical",
	Children =
	{
		Group:new
		{
			Legend = L.SLIDER_SLIDERS,
			Columns = 3,
			Children =
			{
				Text:new
				{
					Text = L.SLIDER_CONTINUOUS,
					Style = "width: fill",
				},
				ScrollBar:new
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
				Text:new
				{
					Id = "slider-text-1",
					Style = "width: fill",
					Text = "  0.00  ",
					KeepMinWidth = true,
				},
				Text:new
				{
					Text = L.SLIDER_INTEGER_STEP,
					Style = "width: fill",
				},
				ScrollBar:new
				{
					Id = "slider-slider-2",
					Style = "width: free",
					Min = 0,
					Max = 10,
					Integer = true,
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
				Text:new
				{
					Id = "slider-text-2",
					Style = "width: fill",
					Text = "  0  ",
					KeepMinWidth = true,
				},
				Text:new
				{
					Text = L.SLIDER_RANGE,
					Style = "width: fill",
				},
				ScrollBar:new
				{
					Id = "slider-slider-3",
					Style = "width: free",
					Min = 10,
					Max = 20,
					Integer = true,
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
				Text:new
				{
					Id = "slider-text-3",
					Style = "width: fill",
					Text = "  0  ",
					KeepMinWidth = true,
				}
			}
		},
		Group:new
		{
			Legend = L.SLIDER_GAUGE,
			Children =
			{
				Gauge:new
				{
					Min = 0,
					Max = 10,
					Id = "slider-gauge-1",
				}
			}
		},

		Group:new
		{
			Style = "width: free; height: free",
			Legend = L.SLIDER_CONNECTIONS,
			Children =
			{
				Slider:new
				{
					Id = "slider-1",
					Orientation = "vertical",
					Step = 5,
					Notifications =
					{
						["Value"] =
						{
							[ui.NOTIFY_ALWAYS] =
							{
								{ ui.NOTIFY_ID, "slider-2", "setValue", "Value", ui.NOTIFY_VALUE },
							}
						}
					}
				},
				Slider:new
				{
					Id = "slider-2",
					Orientation = "vertical",
					Step = 5,
					Notifications =
					{
						["Value"] =
						{
							[ui.NOTIFY_ALWAYS] =
							{
								{ ui.NOTIFY_ID, "slider-3", "setValue", "Value", ui.NOTIFY_VALUE },
							}
						}
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Style = "height: auto; vertical-grid-align: center",
					Children =
					{
						Slider:new
						{
							Id = "slider-7",
							Step = 5,
							Notifications =
							{
								["Value"] =
								{
									[ui.NOTIFY_ALWAYS] =
									{
										{ ui.NOTIFY_ID, "slider-1", "setValue", "Value", ui.NOTIFY_VALUE },
										{ ui.NOTIFY_ID, "slider-6", "setValue", "Value", ui.NOTIFY_VALUE },
									}
								}
							}
						},
						Group:new
						{
							Style = "Width: free",
							Children =
							{
								Gauge:new
								{
									Id = "slider-3",
									Style = "Width: free",
								},
								Gauge:new
								{
									Id = "slider-4",
									Style = "width: free",
								}
							}
						}
					}
				},
				Slider:new
				{
					Id = "slider-5",
					Orientation = "vertical",
					Step = 5,
					Notifications =
					{
						["Value"] =
						{
							[ui.NOTIFY_ALWAYS] =
							{
								{ ui.NOTIFY_ID, "slider-4", "setValue", "Value", ui.NOTIFY_VALUE },
							}
						}
					}
				},
				Slider:new
				{
					Id = "slider-6",
					Orientation = "vertical",
					Step = 5,
					Notifications =
					{
						["Value"] =
						{
							[ui.NOTIFY_ALWAYS] =
							{
								{ ui.NOTIFY_ID, "slider-5", "setValue", "Value", ui.NOTIFY_VALUE },
							}
						}
					}
				}
			}
		}
	}
}

-------------------------------------------------------------------------------
--	Started stand-alone or as part of the demo?
-------------------------------------------------------------------------------

if ui.ProgName:match("^demo_") then
	local app = ui.Application:new()
	ui.Application.connect(window)
	app:addMember(window)
	window:setValue("Status", "show")
	app:run()
else
	return
	{
		Window = window,
		Name = L.SLIDER_TITLE,
		Description = L.SLIDER_DESCRIPTION,
	}
end
