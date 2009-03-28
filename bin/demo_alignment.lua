#!/usr/bin/env lua

local ui = require "tek.ui"
local List = require "tek.class.list"
local Button = ui.Button
local Group = ui.Group
local Text = ui.Text
local Window = ui.Window

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
				Button:new
				{
					Text = L.BEGIN,
					Width = "auto",
					Height = "free",
					HAlign = "left", -- Style = "horizontal-grid-align: left",
				},
				Button:new
				{
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
						Button:new
						{
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
				Button:new
				{
					Text = L.BEGIN,
					Width = "free",
					VAlign = "top", -- Style = "vertical-grid-align: top",
					Legend = L.BORDER_CAPTION,
				},
				Button:new
				{
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
						Button:new
						{
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
