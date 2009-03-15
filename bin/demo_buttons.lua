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
	Id = "buttons-window",
	Style = "Width: auto; Height: auto",
	Title = L.BUTTONS_TITLE,
	Orientation = "vertical",
	Status = "hide",
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
	Children =
	{
		Group:new
		{
			SameSize = true,
			Children =
			{
				Group:new
				{
					Orientation = "vertical",
					Legend = L.BUTTONS_CAPTION_STYLE,
					Style = "height: fill",
					Children =
					{
						Text:new { Class = "caption", Text = "Small",
							Style = "font: ui-small" },
						Text:new { Class = "caption", Text = "Main",
							Style = "font: ui-main" },
						Text:new { Class = "caption", Text = "Large",
							Style = "font: ui-large" },
						Text:new { Class = "caption", Text = "Huge",
							Style = "font: ui-huge" },
						Text:new { Class = "caption", Text = "Fixed",
							Style = "font: ui-fixed" },
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Legend = L.BUTTONS_NORMAL_STYLE,
					Style = "height: fill",
					Children =
					{
						Text:new { Text = "Small",
							Style = "font: ui-small" },
						Text:new { Text = "Main",
							Style = "font: ui-main" },
						Text:new { Text = "Large",
							Style = "font: ui-large" },
						Text:new { Text = "Huge",
							Style = "font: ui-huge" },
						Text:new { Text = "Fixed",
							Style = "font: ui-fixed" },
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Legend = L.BUTTONS_BUTTON,
					Style = "height: fill",
					Children =
					{
						Text:new { Mode = "button", Class = "button", Text = "Small",
							Style = "font: ui-small" },
						Text:new { Mode = "button", Class = "button", Text = "Main",
							Style = "font: ui-main" },
						Text:new { Mode = "button", Class = "button", Text = "Large",
							Style = "font: ui-large" },
						Text:new { Mode = "button", Class = "button", Text = "Huge",
							Style = "font: ui-huge" },
						Text:new { Mode = "button", Class = "button", Text = "Fixed",
							Style = "font: ui-fixed" },
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Legend = L.BUTTONS_COLORS,
					Style = "height: fill",
					Children =
					{
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_BUTTON,
							Style = "background-color: dark; color: shine" },
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_BUTTON,
							Style = "background-color: shadow; color: shine" },
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_BUTTON,
							Style = "background-color: half-shadow; color: shine" },
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_BUTTON,
							Style = "background-color: background; color: detail" },
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_BUTTON,
							Style = "background-color: half-shine; color: dark" },
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_BUTTON,
							Style = "background-color: shine; color: dark" },
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Legend = L.BUTTONS_TEXT_ALIGNMENTS,
					Style = "height: fill",
					SameHeight = true,
					Children =
					{
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_TOP_LEFT,
							Style = "text-align: left; vertical-align: top; height: free" },
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_CENTER,
							Style = "text-align: center; vertical-align: center; height: free" },
						Text:new { Mode = "button", Class = "button", Text = L.BUTTONS_RIGHT_BOTTOM,
							Style = "text-align: right; vertical-align: bottom; height: free" },
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
		Name = L.BUTTONS_TITLE,
		Description = L.BUTTONS_DESCRIPTION,
	}
end
