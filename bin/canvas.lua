#!/usr/bin/env lua

local ui = require "tek.ui"

local Frame1 = ui.Text:new
{
	Text = "Element 1\nFixed Size",
	Class = "button",
	Style = [[
		font: ui-huge;
		background-color: #cc0000;
		color: #fff;
		width: 350;
		height: 350;
		margin: 10;
	 ]]
}

local Frame2 = ui.Text:new
{
	Text = "Element 2\nFlexible Height",
	Class = "button",
	Style = [[
		font: ui-huge;
		background-color: #00aa00;
		color: #fff;
		width: 350;
		max-height: none;
		margin: 10;
	]]
}

local Frame3 = ui.Text:new
{
	Text = "Element 3\nFlexible Width",
	Class = "button",
	Style = [[
		font: ui-huge;
		background-color: #0000aa;
		color: #fff;
		max-width: none;
		height: 350;
		margin: 10;
	]]
}

local app = ui.Application:new
{
	Children =
	{
		ui.Window:new
		{
			Title = "Canvas and Scrollgroup",
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
							Text = "Element 1",
							onPress = function(self, pressed)
								if pressed == false then
									self:getById("the-canvas"):setValue("Child", Frame1)
								end
							end
						},
						ui.Button:new
						{
							Text = "Element 2",
							onPress = function(self, pressed)
								if pressed == false then
									self:getById("the-canvas"):setValue("Child", Frame2)
								end
							end
						},
						ui.Button:new
						{
							Text = "Element 3",
							onPress = function(self, pressed)
								if pressed == false then
									self:getById("the-canvas"):setValue("Child", Frame3)
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
-- 						Style = "background-image: url(bin/graphics/locale.ppm)",
						Style = "background-color: #678",
						UseChildBG = false,
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
