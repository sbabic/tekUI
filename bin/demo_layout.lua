#!/usr/bin/env lua

local ui = require "tek.ui"
local Group = ui.Group
local Text = ui.Text

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Button class:
-------------------------------------------------------------------------------

local Button = Text:newClass { _NAME = "_button" }

function Button.init(self)
	self.Mode = self.Mode or "button"
	self.Class = self.Mode or "button"
	return Text.init(self)
end

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
	Notifications =
	{
		["Status"] =
		{
			["show"] =
			{
				{ ui.NOTIFY_ID, "layout-window-button", "setValue", "Selected", true }
			},
			["hide"] =
			{
				{ ui.NOTIFY_ID, "layout-window-button", "setValue", "Selected", false }
			}
		}
	},
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
			SameSize = true,
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
			GridWidth = 3,
			SameWidth = true,
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
