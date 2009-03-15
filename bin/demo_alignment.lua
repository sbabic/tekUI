#!/usr/bin/env lua

local ui = require "tek.ui"
local Group = ui.Group
local List = require "tek.class.list"
local Window = ui.Window
local Text = ui.Text

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = Window:new
{
	Orientation = "vertical",
	Id = "alignment-window",
	Title = L.ALIGNMENT_TITLE,
	Status = "hide",
	Notifications =
	{
		["Status"] =
		{
			["show"] =
			{
				{ ui.NOTIFY_ID, "alignment-window-button", "setValue", "Selected", true }
			},
			["hide"] =
			{
				{ ui.NOTIFY_ID, "alignment-window-button", "setValue", "Selected", false }
			}
		}
	},
	Orientation = "vertical",
	Children =
	{
		Group:new
		{
			Orientation = "vertical",
			Width = "free",
			Legend = L.ALIGN_HORIZONTAL,
			Children =
			{
				Text:new
				{
					Class = "button",
					Mode = "button",
					Text = L.BEGIN,
					Width = "auto",
					Height = "free",
					HAlign = "left", -- Style = "horizontal-grid-align: left",
				},
				Text:new
				{
					Class = "button",
					Mode = "button",
					Text = L.CENTER,
					Width = "auto",
					Height = "free",
					HAlign = "center", -- Style = "horizontal-grid-align: center",
				},
				Group:new
				{
					Legend = L.GROUP,
					Width = "auto",
					Height = "free",
					HAlign = "right", -- Style = "horizontal-grid-align: right",
					Children =
					{
						Text:new
						{
							Class = "button",
							Mode = "button",
							Text = L.END,
							Width = "auto",
							Height = "free"
						}
					}
				}
			}
		},
		Group:new
		{
			Height = "free",
			Legend = L.ALIGN_VERTICAL,
			Children =
			{
				Text:new
				{
					Class = "button",
					Mode = "button",
					Text = L.BEGIN,
					Width = "free",
					VAlign = "top", -- Style = "vertical-grid-align: top",
					Legend = L.BORDER_CAPTION,
				},
				Text:new
				{
					Class = "button",
					Mode = "button",
					Text = L.CENTER,
					Width = "free",
					VAlign = "center", -- Style = "vertical-grid-align: center",
				},
				Group:new
				{
					Legend = L.GROUP,
					Width = "free",
					VAlign = "bottom", -- Style = "vertical-grid-align: bottom",
					Children =
					{
						Text:new
						{
							Class = "button",
							Mode = "button",
							Text = L.END,
							Width = "free"
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
		Name = L.ALIGNMENT_BUTTON,
		Description = L.ALIGNMENT_DESCRIPTION
	}
end
