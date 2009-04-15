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
				CheckMark:new { Text = "10", Style = "font: :10" },
				CheckMark:new { Text = "15", Style = "font: :15" },
				CheckMark:new { Text = "18", Style = "font: :18" },
				CheckMark:new { Text = "24", Style = "font: :24" },
				CheckMark:new { Text = "32", Style = "font: :32" },
				CheckMark:new { Text = "36", Style = "font: :36", Selected = true },
				CheckMark:new { Text = "44", Style = "font: :44" },
			}
		},
		Group:new
		{
			Orientation = "vertical",
			Legend = L.GRAPHICS_RADIOBUTTONS,
			Style = "height: fill",
			Children =
			{
				RadioButton:new { Text = "10", Style = "font: :10" },
				RadioButton:new { Text = "15", Style = "font: :15" },
				RadioButton:new { Text = "18", Style = "font: :18" },
				RadioButton:new { Text = "24", Style = "font: :24", Selected = true },
				RadioButton:new { Text = "32", Style = "font: :32" },
				RadioButton:new { Text = "36", Style = "font: :36" },
				RadioButton:new { Text = "44", Style = "font: :44" },
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
					Image = ui.BitmapImage:new { 
						Image = io.open(ui.ProgDir .. "/graphics/locale.ppm"):read("*a") 
					},
				},
				ui.ImageGadget:new
				{
					Width = "free",
					Height = "free",
					Style = "background-color: shine;",
					Image = ui.BitmapImage:new { 
						Image = io.open(ui.ProgDir .. "/graphics/world.ppm"):read("*a") 
					},
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
