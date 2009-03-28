#!/usr/bin/env lua

local ui = require "tek.ui"
local Group = ui.Group
local Text = ui.Text
local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = ui.Window:new
{
	Orientation = "vertical",
	Id = "borders-window",
	Title = L.BORDERS_TITLE,
	Status = "hide",
	Height = "auto",
	Children =
	{
		Group:new
		{
			Width = "free",
			Height = "auto",
			Children =
			{
				SameSize = true,
				Columns = 4,
				Group:new
				{
					Legend = L.BORDER_INSET,
					Orientation = "vertical",
					Children =
					{
						Text:new
						{
							Style = "border-style:inset; border-width: 2;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:inset; border-width: 4;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:inset; border-width: 6;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:inset; border-width: 8;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:inset; border-width: 12;",
							Mode = "button",
						},
					}
				},
				Group:new
				{
					Legend = L.BORDER_OUTSET,
					Orientation = "vertical",
					Children =
					{
						Text:new
						{
							Style = "border-style:outset; border-width: 2;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:outset; border-width: 4;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:outset; border-width: 6;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:outset; border-width: 8;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:outset; border-width: 12;",
							Mode = "button",
						},
					}
				},
				Group:new
				{
					Legend = L.BORDER_GROOVE,
					Orientation = "vertical",
					Children =
					{
						Text:new
						{
							Style = "border-style:groove; border-width: 2;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:groove; border-width: 4;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:groove; border-width: 6;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:groove; border-width: 8;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:groove; border-width: 12;",
							Mode = "button",
						},
					}
				},
				Group:new
				{
					Legend = L.BORDER_RIDGE,
					Orientation = "vertical",
					Children =
					{
						Text:new
						{
							Style = "border-style:ridge; border-width: 2;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:ridge; border-width: 4;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:ridge; border-width: 6;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:ridge; border-width: 8;",
							Mode = "button",
						},
						Text:new
						{
							Style = "border-style:ridge; border-width: 12;",
							Mode = "button",
						},
					}
				},
			}
		},
		Group:new
		{
			Legend = L.BORDER_INDIVIDUAL_STYLES,
			Children =
			{
				ui.Button:new
				{
					Legend = L.BORDER_CAPTION,
					Text = L.BORDER_CAPTION,
				},
				ui.Button:new
				{
					Style = "border-color: border-focus; border-rim-width: 1; border-rim-color:shine; border-focus-color: dark; border-width: 6 12 6 12;",
					Text = L.BORDER_INDIVIDUAL_STYLE,
					Height = "fill",
				},
			}
		},
		Group:new
		{
			Legend = L.BORDER_DYNAMIC_THICKNESS,
			Children =
			{
				ui.Button:new
				{
					Border = { 2, 2, 2, 2 },
					Width = "auto",
					Id = "dyn-border-button",
					Text = L.BORDER_WATCH,
				},
				ui.Slider:new
				{
					Border = { 2, 2, 2, 2 },
					Style = "border-rim-width: 1; border-focus-width: 1;",
					Width = "free",
					Value = 2,
					Min = 0,
					Max = 20,
					Integer = true,
					Notifications =
					{
						["Value"] =
						{
							[ui.NOTIFY_CHANGE] =
							{
								{
									ui.NOTIFY_SELF, ui.NOTIFY_FUNCTION, function(self, val)
										local e = self.Application:getElementById("dyn-border-button")
										local b = e.Border
										b[1], b[2], b[3], b[4] = val, val, val, val
										e:rethinkLayout(1)
										local b = self.Border
										b[1], b[2], b[3], b[4] = val, val, val, val
										self:rethinkLayout(1)
									end, ui.NOTIFY_VALUE
								}
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
		Name = L.BORDERS_BUTTON,
		Description = L.BORDERS_DESCRIPTION
	}
end
