#!/usr/bin/env lua

local ui = require "tek.ui"

local Gadget = ui.Gadget
local Group = ui.Group
local CheckMark = ui.CheckMark
local RadioButton = ui.RadioButton

local floor = math.floor
local Region = require "tek.lib.region"

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = ui.Window:new
{
	Status = "hide",
	Id = "graphics-window",
	Style = "Width: auto; Height: auto",
	Title = L.GRAPHICS_TITLE,
	Width = "fill",
	Height = "fill",
	HideOnEscape = true,
	Children =
	{
		Group:new
		{
			Orientation = "vertical",
			Legend = L.GRAPHICS_CHECKMARKS,
			Style = "height: fill",
			Children =
			{
				CheckMark:new { Text = "10", Style = "font: ui-huge:10" },
				CheckMark:new { Text = "14", Style = "font: ui-huge:14" },
				CheckMark:new { Text = "18", Style = "font: ui-huge:18" },
				CheckMark:new { Text = "24", Style = "font: ui-huge:24", Selected = true },
				CheckMark:new { Text = "32", Style = "font: ui-huge:32" },
				CheckMark:new { Text = "40", Style = "font: ui-huge:40" },
				CheckMark:new { Text = "48", Style = "font: ui-huge:48" },
			}
		},
		Group:new
		{
			Orientation = "vertical",
			Legend = L.GRAPHICS_RADIOBUTTONS,
			Style = "height: fill",
			Children =
			{
				RadioButton:new { Text = "10", Style = "font: ui-huge:10" },
				RadioButton:new { Text = "14", Style = "font: ui-huge:14" },
				RadioButton:new { Text = "18", Style = "font: ui-huge:18" },
				RadioButton:new { Text = "24", Style = "font: ui-huge:24", Selected = true },
				RadioButton:new { Text = "32", Style = "font: ui-huge:32" },
				RadioButton:new { Text = "40", Style = "font: ui-huge:40" },
				RadioButton:new { Text = "48", Style = "font: ui-huge:48" },
			}
		},
		Group:new
		{
			Orientation = "vertical",
			Legend = L.GRAPHICS_BITMAPS,
			Style = "height: fill",
			Children =
			{
				ui.ImageGadget:new
				{
					Mode = "button",
					Class = "button",
					Width = "free",
					Height = "free",
					Image = ui.loadImage(ui.ProgDir .. "/graphics/locale.ppm")
				},
				ui.ImageGadget:new
				{
					Width = "free",
					Height = "free",
					Style = "background-color: shine;",
					Image = ui.loadImage(ui.ProgDir .. "/graphics/world.ppm")
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
		Name = L.GRAPHICS_TITLE,
		Description = L.GRAPHICS_DESCRIPTION,
	}
end
