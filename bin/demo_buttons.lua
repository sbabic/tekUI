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
	Id = "buttons-window",
	Title = L.BUTTONS_TITLE,
	Orientation = "vertical",
	Status = "hide",
	HideOnEscape = true,
	Width = "auto",
	Height = "auto",
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
						Button:new { Text = "Small", Style = "font: ui-small" },
						Button:new { Text = "Main", Style = "font: ui-main" },
						Button:new { Text = "Large", Style = "font: ui-large" },
						Button:new { Text = "Huge", Style = "font: ui-huge" },
						Button:new { Text = "Fixed", Style = "font: ui-fixed" },
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Legend = L.BUTTONS_COLORS,
					Style = "height: fill",
					Children =
					{
						Button:new { Text = L.BUTTONS_BUTTON, Style = "background-color: dark; color: shine" },
						Button:new { Text = L.BUTTONS_BUTTON, Style = "background-color: shadow; color: shine" },
						Button:new { Text = L.BUTTONS_BUTTON, Style = "background-color: half-shadow; color: shine" },
						Button:new { Text = L.BUTTONS_BUTTON, Style = "background-color: half-shine; color: dark" },
						Button:new { Text = L.BUTTONS_BUTTON, Style = "background-color: shine; color: dark" },
						Button:new { Text = L.BUTTONS_BUTTON, Style = "background-color: #aa0000; color: #ffff00" },
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Legend = L.BUTTONS_TEXT_ALIGNMENTS,
					Style = "height: fill",
					SameSize = "height",
					Children =
					{
						Button:new { Text = L.BUTTONS_TOP_LEFT, Style = "text-align: left; vertical-align: top; height: free" },
						Button:new { Text = L.BUTTONS_CENTER, Style = "text-align: center; vertical-align: center; height: free" },
						Button:new { Text = L.BUTTONS_RIGHT_BOTTOM, Style = "text-align: right; vertical-align: bottom; height: free" },
					}
				}
			}
		},
		Group:new
		{
			Legend = L.GADGET_MODES,
			Children = 
			{
				Button:new
				{
					Text = "inert", Mode = "inert",
				},
				Button:new
				{
					Text = "toggle", Mode = "toggle",
				},
				Button:new
				{
					Text = "button", Mode = "button",
				},
				Button:new
				{
					Id = "buttons-touch",
					Font = "ui-fixed", Text = "touch", Mode = "touch",
					onSelect = function(self, selected)
						Button.onSelect(self, selected)
						self:getById("buttons-unselect"):
							setValue("Disabled", not selected)
					end
				},
				Button:new
				{
					Id = "buttons-unselect",
					Width = "auto",
					Disabled = true,
					Text = "« " .. L.GADGET_UNSELECT,
					onPress = function(self, pressed)
						if pressed == false then
							self:getById("buttons-touch"):
								setValue("Selected", false)
						end
					end
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
