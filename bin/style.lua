#!/usr/bin/env lua 

local db = require "tek.lib.debug"
local ui = require "tek.ui"

ui.Application:new
{
	Children =
	{
		ui.Window:new
		{
			Title = "Style Test",
			HideOnEscape = true,
			Orientation = "vertical",
			Children =
			{
				ui.Text:new 
				{
					Id = "the-area",
					Text = "Une question\nde style",
					Width = "free",
					Height = "free",
				},
				ui.ScrollGroup:new
				{
					VSliderMode = "auto",
					HSliderMode = "off",
					Child = ui.Canvas:new
					{
						AutoPosition = true,
						UseChildBG = true,
						Child = ui.Input:new
						{
							Id = "the-editor",
							InitialFocus = true,
							Font = "ui-fixed",
							FixedFont = true,
							LineSpacing = 2,
							SmoothScroll = 2,
							Data = 
							{ 
								"background-color: #800;",
								"color: white;",
								"font: ui-huge:48;",
								"border-style: inset;",
								"border-width: 10;",
								"margin: 10;",
								"padding: 10;",
								"text-align: right;",
								"vertical-align: bottom;",
							}
						}
					}
				},
				ui.Button:new
				{
					Text = "_Apply",
					onClick = function(self)
						local style = table.concat(self:getById("the-editor"):getText(), "\n")
						self:getById("the-area"):setValue("Style", style)
					end
				}
			}
		}
	}
}:run()
