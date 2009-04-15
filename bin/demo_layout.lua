#!/usr/bin/env lua

local ui = require "tek.ui"
local Button = ui.Button
local Group = ui.Group
local Text = ui.Text

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = ui.Window:new
{
	Orientation = "vertical",
	Id = "layout-window",
	Title = L.LAYOUT_TITLE,
	Status = "hide",
	MaxWidth = ui.HUGE,
	MaxHeight = ui.HUGE,
	HideOnEscape = true,
	Children =
	{
		Group:new
		{
			Legend = L.LAYOUT_RELATIVE_SIZES,
			Children =
			{
				Button:new { Text = "1", Style = "max-width: free" },
				ui.Spacer:new { },
				Button:new { Text = "12", Style = "max-width: free" },
				ui.Spacer:new { },
				Button:new { Text = "123", Style = "max-width: free" },
				ui.Spacer:new { },
				Button:new { Text = "1234", Style = "max-width: free" },
			},
		},
		Group:new
		{
			SameSize = "width",
			Legend = L.LAYOUT_SAME_SIZES,
			Children =
			{
				Button:new { Text = "1", Style = "max-width: free" },
				ui.Spacer:new { },
				Button:new { Text = "12", Style = "max-width: free" },
				ui.Spacer:new { },
				Button:new { Text = "123", Style = "max-width: free" },
				ui.Spacer:new { },
				Button:new { Text = "1234", Style = "max-width: free" },
			}
		},
		Group:new
		{
			Legend = L.LAYOUT_BALANCING_GROUP,
			Children =
			{
				Text:new { Text = "free", Style = "height: fill" },
				ui.Handle:new { },
				Text:new { Text = "free", Style = "height: fill" },
				ui.Handle:new { },
				Text:new { Text = "free", Style = "height: fill" },
			}
		},
		Group:new
		{
			Style = "height: free",
			Legend = L.LAYOUT_GRID,
			Columns = 3,
			SameSize = "width",
			Height = "auto",
			Children =
			{
				Button:new { Text = "1", Style = "height: free" },
				Button:new { Text = "12", Style = "height: free" },
				Button:new { Text = "123", Style = "height: free" },
				Button:new { Text = "1234", Style = "height: free" },
				Button:new { Text = "12345", Style = "height: free" },
				Button:new { Text = "123456", Style = "height: free" },
			}
		},
		Group:new
		{
			Legend = L.LAYOUT_FIXED_VS_FREE,
			Children =
			{
				Text:new { Text = L.LAYOUT_FIX, Height = "fill" },
				Button:new { Text = "25%", Style = "max-width: free", Weight = 0x4000 },
				Text:new { Text = L.LAYOUT_FIX, Height = "fill" },
				Button:new { Text = "75%", Style = "max-width: free", Weight = 0xc000 },
				Text:new { Text = L.LAYOUT_FIX, Height = "fill" },
			}
		},
		Group:new
		{
			Style = "max-height: free",
			Legend = L.LAYOUT_DIFFERENT_WEIGHTS,
			Children =
			{
				Button:new { Text = "25%", Weight = 0x4000,
					Style = "max-width: free; max-height: free" },
				ui.Spacer:new { },
				Button:new { Text = "25%", Weight = 0x4000,
					Style = "max-width: free; max-height: free" },
				ui.Spacer:new { },
				Button:new { Text = "50%", Weight = 0x8000,
					Style = "max-width: free; max-height: free" },
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
		Name = L.LAYOUT_TITLE,
		Description = L.LAYOUT_DESCRIPTION,
	}
end
