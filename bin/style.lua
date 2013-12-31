#!/usr/bin/env lua 

local db = require "tek.lib.debug"
local ui = require "tek.ui"

ui.Application:new
{
	Children =
	{
		ui.Window:new
		{
			Title = "Realtime style",
			HideOnEscape = true,
			Orientation = "vertical",
			Children =
			{
				ui.Text:new 
				{
					Id = "the-area",
					Text = "Edit and apply\nstyle settings",
					Width = "free",
					Height = "free",
				},
				ui.Input:new
				{
					Id = "the-editor",
					InitialFocus = true,
					Font = "ui-fixed",
-- 					Style = "margin: 10",
					MultiLine = true,
					Text = [[
background-color: #800;
color: white;
font: ui-huge:48;
border-style: inset;
border-width: 10;
margin: 10;
padding: 10;
text-align: right;
vertical-align: bottom;
]]
				},
				ui.Button:new					
				{
					Text = "_Apply",
					onClick = function(self)
						local style = self:getById("the-editor"):getText()
						self:getById("the-area"):setValue("Style", style)
					end
				}
			}
		}
	}
}:run()
