#!/usr/bin/env lua

local ui = require "tek.ui"

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

local window = ui.Window:new
{
	Orientation = "vertical",
	Id = "notifications-window",
	Title = L.NOTIFICATIONS_TITLE,
	Status = "hide",
	Notifications =
	{
		["Status"] =
		{
			["show"] =
			{
				{ ui.NOTIFY_ID, "notifications-window-button", "setValue", "Selected", true }
			},
			["hide"] =
			{
				{ ui.NOTIFY_ID, "notifications-window-button", "setValue", "Selected", false }
			},
		},
	},
	Children =
	{
		ui.Group:new
		{
			Style = "width: free; height: free",
			Legend = L.NOTIFICATIONS_CONNECTIONS,
			Children =
			{
				ui.Slider:new
				{
					Id = "slider-1",
					Orientation = "vertical",
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
				ui.Slider:new
				{
					Id = "slider-2",
					Orientation = "vertical",
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
				ui.Group:new
				{
					Orientation = "vertical",
					Style = "height: auto; vertical-grid-align: center",
					Children =
					{
						ui.Slider:new
						{
							Id = "slider-7",
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
						ui.Group:new
						{
							Style = "Width: free",
							Children =
							{
								ui.Gauge:new
								{
									Id = "slider-3",
									Style = "Width: free",
								},
								ui.Gauge:new
								{
									Id = "slider-4",
									Style = "width: free",
								},
							},
						},
					},
				},
				ui.Slider:new
				{
					Id = "slider-5",
					Orientation = "vertical",
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
				ui.Slider:new
				{
					Id = "slider-6",
					Orientation = "vertical",
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
				},
			},
		},
	},
}

if ui.ProgName == "notifications.lua" then
	local app = ui.Application:new()
	ui.Application.connect(window)
	app:addMember(window)
	window:setValue("Status", "show")
	app:run()
else
	return
	{
		Window = window,
		Name = "Notifications",
		Description = L.NOTIFICATIONS_DESCRIPTION,
	}
end
