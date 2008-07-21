#!/usr/bin/env lua

local ui = require "tek.ui"

local window = ui.Window:new
{
	Status = "hide",
	Id = "buttons-window",
	Notifications =
	{
		["Status"] =
		{
			["show"] =
			{
				{ ui.NOTIFY_ID, "buttons-window-button", "setValue", "Selected", true }
			},
			["hide"] =
			{
				{ ui.NOTIFY_ID, "buttons-window-button", "setValue", "Selected", false }
			},
		},
	},
	Width = "auto",
	Height = "auto",
	Title = "Buttons",
	SameSize = true,
	Children =
	{
		ui.Group:new
		{
			Orientation = "vertical",
			Legend = "Caption Style",
			Height = "fill",
			Children =
			{
				ui.Text:new { Style = "caption", Text = "Small", FontSpec = "__small" },
				ui.Text:new { Style = "caption", Text = "Main", FontSpec = "__main" },
				ui.Text:new { Style = "caption", Text = "Large", FontSpec = "__large" },
				ui.Text:new { Style = "caption", Text = "Huge", FontSpec = "__huge" },
				ui.Text:new { Style = "caption", Text = "Fixed", FontSpec = "__fixed" },
			},
		},
		ui.Group:new
		{
			Orientation = "vertical",
			Legend = "Normal Style",
			Height = "fill",
			Children =
			{
				ui.Text:new { Text = "Small", FontSpec = "__small" },
				ui.Text:new { Text = "Main", FontSpec = "__main" },
				ui.Text:new { Text = "Large", FontSpec = "__large" },
				ui.Text:new { Text = "Huge", FontSpec = "__huge" },
				ui.Text:new { Text = "Fixed", FontSpec = "__fixed" },
			},
		},
		ui.Group:new
		{
			Orientation = "vertical",
			Legend = "Button Style",
			Height = "fill",
			Children =
			{
				ui.Text:new { Mode = "button", Style = "button", Text = "Small", FontSpec = "__small" },
				ui.Text:new { Mode = "button", Style = "button", Text = "Main", FontSpec = "__main" },
				ui.Text:new { Mode = "button", Style = "button", Text = "Large", FontSpec = "__large" },
				ui.Text:new { Mode = "button", Style = "button", Text = "Huge", FontSpec = "__huge" },
				ui.Text:new { Mode = "button", Style = "button", Text = "Fixed", FontSpec = "__fixed" },
			},
		},
		ui.Group:new
		{
			Orientation = "vertical",
			Legend = "Colors",
			Height = "fill",
			Children =
			{
				ui.Text:new { Mode = "button", Style = "button", Text = "Button", BGPen = ui.PEN_SHADOW, FGPen = ui.PEN_SHINE },
				ui.Text:new { Mode = "button", Style = "button", Text = "Button", BGPen = ui.PEN_HALFSHADOW, FGPen = ui.PEN_SHINE },
				ui.Text:new { Mode = "button", Style = "button", Text = "Button", BGPen = ui.PEN_AREABACK, FGPen = ui.PEN_SHINE },
				ui.Text:new { Mode = "button", Style = "button", Text = "Button", BGPen = ui.PEN_HALFSHINE, FGPen = ui.PEN_SHADOW },
				ui.Text:new { Mode = "button", Style = "button", Text = "Button", BGPen = ui.PEN_SHINE, FGPen = ui.PEN_SHADOW },
			},
		},
		ui.Group:new
		{
			Orientation = "vertical",
			Legend = "Text Alignments",
			Height = "fill",
			SameHeight = true,
			Children =
			{
				ui.Text:new { Mode = "button", Style = "button", Text = "Top\nLeft", TextHAlign = "left", TextVAlign = "top", Height = "free" },
				ui.Text:new { Mode = "button", Style = "button", Text = "Center", TextHAlign = "center", Height = "free" },
				ui.Text:new { Mode = "button", Style = "button", Text = "Right\nBottom", TextHAlign = "right", TextVAlign = "bottom", Height = "free" },
			},
		},
	}
}

if ui.ProgName == "buttons.lua" then
	local app = ui.Application:new()
	ui.Application.connect(window)
	app:addMember(window)
	window:setValue("Status", "show")
	app:run()
else
	return
	{
		Window = window,
		Name = "Buttons",
		Description = [[
			Buttons
		]]
	}
end
