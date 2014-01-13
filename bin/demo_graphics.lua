#!/usr/bin/env lua

local ui = require "tek.ui"

local Widget = ui.Widget
local Group = ui.Group
local CheckMark = ui.CheckMark
local RadioButton = ui.RadioButton

local floor = math.floor
local Region = require "tek.lib.region"

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

local RadioImage1 = ui.getStockImage("radiobutton")
local RadioImage2 = ui.getStockImage("radiobutton", 2)
local BitMapImage1 = ui.loadImage(ui.ProgDir .. "/graphics/world.ppm")
local BitMapImage2 = ui.loadImage(ui.ProgDir .. "/graphics/locale.ppm")
local FileImage = ui.getStockImage("file")

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = ui.Window:new
{
	Status = "hide",
	Id = "graphics-window",
	Title = L.GRAPHICS_TITLE,
	Width = "fill",
	Height = "fill",
	HideOnEscape = true,
	SameSize = "width",
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
				CheckMark:new { Text = "24", Style = "font: ui-huge:24", 
					Selected = true },
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
				RadioButton:new { Text = "24", Style = "font: ui-huge:24",
					Selected = true },
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
				ui.ImageWidget:new
				{
					Mode = "button",
					Class = "button",
					Image = BitMapImage2
				},
				ui.ImageWidget:new
				{
					Style = "background-color: #fff",
					Image = BitMapImage1
				}
			}
		},
		Group:new
		{
			Orientation = "vertical",
			Legend = L.GRAPHICS_BACKGROUND,
			Style = "height: fill",
			Children =
			{
				ui.Group:new
				{
					Style = [[
						height: fill; 
						background-color: url(bin/graphics/world.ppm);
					]],
					Children =
					{
						ui.ImageWidget:new 
						{
							Height = "fill",
							Mode = "button",
							Style = [[
								background-color: transparent; 
								margin: 10;
								padding: 4;
								border-width: 10;
								border-focus-width: 6;
							]],
							Image = FileImage
						},
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
		Name = L.GRAPHICS_TITLE,
		Description = L.GRAPHICS_DESCRIPTION,
	}
end
