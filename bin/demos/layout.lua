#!/usr/bin/env lua

local ui = require "tek.ui"
local db = require "tek.lib.debug"

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

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
			},
		},
	},
	Children =
	{
		ui.Group:new
		{
			Legend = L.LAYOUT_RELATIVE_SIZES,
			Children =
			{
				ui.Text:new { Text = "1", Style = "max-width: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "12", Style = "max-width: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "123", Style = "max-width: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "1234", Style = "max-width: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "12345", Style = "max-width: free" },
			},
		},
		ui.Group:new
		{
			SameSize = true,
			Legend = L.LAYOUT_SAME_SIZES,
			Children =
			{
				ui.Text:new { Text = "1", Style = "max-width: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "12", Style = "max-width: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "123", Style = "max-width: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "1234", Style = "max-width: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "12345", Style = "max-width: free" },
			},
		},
		ui.Group:new
		{
			Legend = L.LAYOUT_BALANCING_GROUP,
			Children =
			{
				ui.Text:new { Text = "free", Style = "height: fill" },
				ui.Handle:new { },
				ui.Text:new { Text = "free", Style = "height: fill" },
				ui.Handle:new { },
				ui.Text:new { Text = "free", Style = "height: fill" },
			},
		},
		ui.Handle:new { },
		ui.Group:new
		{
			Style = "height: free",
			Legend = L.LAYOUT_GRID,
			GridWidth = 3,
			SameSize = true,
			Children =
			{
				ui.Text:new { Text = "1", Style = "height: free" },
				ui.Text:new { Text = "12", Style = "height: free" },
				ui.Text:new { Text = "123", Style = "height: free" },
				ui.Text:new { Text = "1234", Style = "height: free" },
				ui.Text:new { Text = "12345", Style = "height: free" },
				ui.Text:new { Text = "123456", Style = "height: free" },
			},
		},
		ui.Group:new
		{
			Legend = L.LAYOUT_FIXED_VS_FREE,
			Children =
			{
				ui.Text:new { Text = L.LAYOUT_FIX },
				ui.Text:new { Text = "25%", Style = "max-width: free", Weight = 0x4000 },
				ui.Text:new { Text = L.LAYOUT_FIX },
				ui.Text:new { Text = "75%", Style = "max-width: free", Weight = 0xc000 },
				ui.Text:new { Text = L.LAYOUT_FIX },
			},
		},
		ui.Group:new
		{
			Style = "max-height: free",
			Legend = L.LAYOUT_DIFFERENT_WEIGHTS,
			Children =
			{
				ui.Text:new { Text = "25%", Weight = 0x4000,
					Style = "max-width: free; max-height: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "25%", Weight = 0x4000,
					Style = "max-width: free; max-height: free" },
				ui.Spacer:new { },
				ui.Text:new { Text = "50%", Weight = 0x8000,
					Style = "max-width: free; max-height: free" },
			},
		},
	},
}

if ui.ProgName == "layout.lua" then
	local app = ui.Application:new()
	ui.Application.connect(window)
	app:addMember(window)
	window:setValue("Status", "show")
	app:run()
else
	return
	{
		Window = window,
		Name = "Layout",
		Description = L.LAYOUT_DESCRIPTION,
	}
end
