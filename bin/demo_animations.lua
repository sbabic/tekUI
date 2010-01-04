#!/usr/bin/env lua

local ui = require "tek.ui"
local Group = ui.Group
local Slider = ui.Slider
local Text = ui.Text
local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Helper class:
-------------------------------------------------------------------------------

local Coefficient = Group:newClass { _NAME = "_coefficient-group" }

function Coefficient.new(class, self)
	local group = self -- for building a closure with the group
	self.Children =
	{
		Text:new { Class = "caption", Text = self.Key1, MaxWidth = 0 },
		Slider:new
		{
			Min = 0,
			Max = 31,
			Value = self.Value1,
			Step = 3,
			Integer = true,
			onSetValue = function(self, val)
				Slider.onSetValue(self, val)
				local p = self.Application:getById("the-plasma")
				p:setValue(group.Key1, self.Value)
			end,
		},
		Text:new { Class = "caption", Text = self.Key2, MaxWidth = 0 },
		Slider:new
		{
			Min = -16,
			Max = 15,
			Value = self.Value2,
			Step = 3,
			Integer = true,
			onSetValue = function(self, val)
				Slider.onSetValue(self, val)
				local p = self.Application:getById("the-plasma")
				p:setValue(group.Key2, self.Value)
			end,
		},
	}
	return Group.new(class, self)
end

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local slider1 = ui.Slider:new
{
	Min = 1,
	Max = 19,
	Value = 8,
	Range = 20,
	Step = 1
}
slider1:addNotify("Value", ui.NOTIFY_ALWAYS, 
	{ ui.NOTIFY_ID, "the-tunnel", "setSpeed", ui.NOTIFY_VALUE })

local slider2 = ui.Slider:new
{
	Min = 0x10,
	Max = 0x1ff,
	Value = 0x50,
	Range = 0x200,
	Step = 20
}
slider2:addNotify("Value", ui.NOTIFY_ALWAYS, 
	{ ui.NOTIFY_ID, "the-tunnel", "setViewZ", ui.NOTIFY_VALUE })

local slider3 = ui.Slider:new 
{
	Min = 1,
	Max = 19,
	Value = 6,
	Range = 20,
	Step = 1
}
slider3:addNotify("Value", ui.NOTIFY_ALWAYS, 
	{ ui.NOTIFY_ID, "the-tunnel", "setNumSeg", ui.NOTIFY_VALUE })

local startbutton = ui.Button:new { Text = L.ANIMATIONS_START }
startbutton:addNotify("Pressed", false,
	{ ui.NOTIFY_ID, "the-boing", "setValue", "Running", true })

local stopbutton = ui.Button:new { Text = L.ANIMATIONS_STOP }
stopbutton:addNotify("Pressed", false,
	{ ui.NOTIFY_ID, "the-boing", "setValue", "Running", false })

local window = ui.Window:new
{
	Orientation = "vertical",
	Width = 400,
	MinWidth = 0,
	MaxWidth = "none", 
	MaxHeight = "none",
	Id = "anims-window",
	Title = L.ANIMATIONS_TITLE,
	Status = "hide",
	HideOnEscape = true,
	Children =
	{
		ui.PageGroup:new
		{
			PageCaptions = { "_Tunnel", "_Boing", "_Plasma" },
			Children =
			{
				Group:new
				{
					Children =
					{
						Group:new
						{
							Orientation = "vertical",
							Children =
							{
								ui.Tunnel:new
								{
									Id = "the-tunnel",
								},
								Group:new
								{
									Legend = L.ANIMATIONS_PARAMETERS,
									Columns = 2,
									Children =
									{
										Text:new
										{
											Text = L.ANIMATIONS_SPEED,
											Class = "caption",
											Width = "fill"
										},
										slider1,
										Text:new
										{
											Text = L.ANIMATIONS_FOCUS,
											Class = "caption",
											Width = "fill"
										},
										slider2,
										Text:new
										{
											Text = L.ANIMATIONS_SEGMENTS,
											Class = "caption",
											Width = "fill"
										},
										slider3,
									}
								}
							}
						}
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Children =
					{
						Group:new
						{
							Children =
							{
								Slider:new
								{
									Id = "boing-slider",
									Orientation = "vertical",
									Min = 0,
									Max = 0x10000,
									Range = 0x14000,
									Style = "border-width: 0; background-color: dark; margin: 0";
								},
								ui.Boing:new
								{
									Id = "the-boing",
									Style = "border-width: 0; margin: 0",
									onSetYPos = function(self, ypos)
										local s = self.Application:getById("boing-slider")
										s:setValue("Value", ypos)
										local s = self.Application:getById("boing-slider2")
										s:setValue("Value", ypos)
									end,
								},
								Slider:new
								{
									Id = "boing-slider2",
									Orientation = "vertical",
									Min = 0,
									Max = 0x10000,
									Range = 0x14000,
									Style = "border-width: 0; background-color: dark; margin: 0";
								}
							}
						},
						Group:new
						{
							Children =
							{
								startbutton,
								stopbutton,
							}
						}
					}
				},
				Group:new
				{
					Orientation = "vertical",
					Children =
					{
						ui.Plasma:new { Id = "the-plasma" },
						Group:new
						{
							Width = "fill",
							Orientation = "vertical",
							Legend = L.COEFFICIENTS,
							Children =
							{
								Coefficient:new { Key1 = "DeltaX1", Value1 = 12, Key2 = "SpeedX1", Value2 = 7 },
								Coefficient:new { Key1 = "DeltaX2", Value1 = 13, Key2 = "SpeedX2", Value2 = -2 },
								Coefficient:new { Key1 = "DeltaY1", Value1 = 8, Key2 = "SpeedY1", Value2 = 9 },
								Coefficient:new { Key1 = "DeltaY2", Value1 = 11, Key2 = "SpeedY2", Value2 = -4 },
								Coefficient:new { Key1 = "DeltaY3", Value1 = 18, Key2 = "SpeedY3", Value2 = 5 },
							}
						}
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
		Name = L.ANIMATIONS_BUTTON,
		Description = L.ANIMATIONS_DESCRIPTION
	}
end
