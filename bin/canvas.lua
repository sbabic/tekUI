#!/usr/bin/env lua

local ui = require "tek.ui"

local Frame1 = ui.Text:new
{
	Text = "1",
	Class = "caption",
	Style = [[
		background-color: #ff0000;
		min-width: 350;
		max-width: 350;
		min-height: 350;
		max-height: 350;
		margin: 10;
	 ]]
}

local Frame2 = ui.Text:new
{
	Text = "2",
	Class = "button",
	Mode = "button",
	Style = [[
		width: 500;
		height: 500;
		min-width:500;
		max-width:500;
		margin: 10;
	]]
}

local app = ui.Application:new
{
	Children =
	{
		ui.Window:new
		{
			HideOnEscape = true,
			Orientation = "vertical",
			Children =
			{
				ui.Group:new
				{
					Children =
					{
						ui.Button:new
						{
							Text = "Canvas 1",
							onPress = function(self, pressed)
								if pressed == false then
									self:getById("the-canvas"):setValue("Child", Frame1)
								end
							end
						},
						ui.Button:new
						{
							Text = "Canvas 2",
							onPress = function(self, pressed)
								if pressed == false then
									self:getById("the-canvas"):setValue("Child", Frame2)
								end
							end
						},
						ui.Button:new
						{
							Text = "Clear",
							onPress = function(self, pressed)
								if pressed == false then
									self:getById("the-canvas"):setValue("Child", false)
								end
							end
						}
					}
				},
				ui.ScrollGroup:new
				{
					HSliderMode = "on",
					VSliderMode = "on",
					Child = ui.Canvas:new
					{
						Style = "background-color: url(bin/graphics/locale.ppm)",
						UseChildBG = false,
						Margin = { 10,10,10,10 },
						AutoWidth = true,
						AutoHeight = true,
						Id = "the-canvas",
					}
				}
			}
		}
	}

}

app:run()
app:hide()
app:cleanup()
