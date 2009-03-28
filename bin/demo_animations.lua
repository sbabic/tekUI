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
	self.Width = "fill"
	self.Children =
	{
		Text:new { Class = "caption", Text = self.Key1, Width = "auto" },
		Slider:new
		{
			Width = "free",
			Min = 0,
			Max = 31,
			Value = self.Value1,
			Step = 3,
			Integer = true,
			onSetValue = function(self, val)
				Slider.onSetValue(self, val)
				local p = self.Application:getElementById("the-plasma")
				p:setValue(group.Key1, self.Value)
			end,
		},
		Text:new { Class = "caption", Text = self.Key2, Width = "auto" },
		Slider:new
		{
			Width = "free",
			Min = -16,
			Max = 15,
			Value = self.Value2,
			Step = 3,
			Integer = true,
			onSetValue = function(self, val)
				Slider.onSetValue(self, val)
				local p = self.Application:getElementById("the-plasma")
				p:setValue(group.Key2, self.Value)
			end,
		},
	}
	return Group.new(class, self)
end

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = ui.Window:new
{
	Orientation = "vertical",
	Style = "width: 400; height: 400",
	Id = "anims-window",
	Title = L.ANIMATIONS_TITLE,
	Status = "hide",
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
									Style = "horizontal-align: center",
								},
								Group:new
								{
									Style = "width: fill; height: auto;",
									Legend = L.ANIMATIONS_PARAMETERS,
									Columns = 2,
									Children =
									{
										Text:new
										{
											Text = L.ANIMATIONS_SPEED,
											Class = "caption",
											Style = "width: fill",
										},
										Slider:new
										{
											Style = "width: free",
											Min = 1,
											Max = 19,
											Value = 8,
											Range = 20,
											Step = 1,
											Notifications =
											{
												["Value"] =
												{
													[ui.NOTIFY_CHANGE] =
													{
														{ ui.NOTIFY_ID, "the-tunnel", "setSpeed", ui.NOTIFY_VALUE },
													}
												}
											}
										},
										Text:new
										{
											Text = L.ANIMATIONS_FOCUS,
											Class = "caption",
											Style = "width: fill",
										},
										Slider:new
										{
											Style = "width: free",
											Min = 0x10,
											Max = 0x1ff,
											Value = 0x50,
											Range = 0x200,
											Step = 20,
											Notifications =
											{
												["Value"] =
												{
													[ui.NOTIFY_CHANGE] =
													{
														{ ui.NOTIFY_ID, "the-tunnel", "setViewZ", ui.NOTIFY_VALUE },
													}
												}
											}
										},
										Text:new
										{
											Text = L.ANIMATIONS_SEGMENTS,
											Class = "caption",
											Style = "width: fill",
										},
										Slider:new {
											Style = "width: free",
											Min = 1,
											Max = 19,
											Value = 6,
											Range = 20,
											Step = 1,
											Notifications =
											{
												["Value"] =
												{
													[ui.NOTIFY_CHANGE] =
													{
														{ ui.NOTIFY_ID, "the-tunnel", "setNumSeg", ui.NOTIFY_VALUE },
													}
												}
											}
										}
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
								},
								ui.Boing:new
								{
									Id = "the-boing",
									onSetYPos = function(self, ypos)
										local s = self.Application:getElementById("boing-slider")
										s:setValue("Value", ypos)
										local s = self.Application:getElementById("boing-slider2")
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
								}
							}
						},
						Group:new
						{
							Style = "height: auto",
							Children =
							{
								ui.Button:new
								{
									Text = L.ANIMATIONS_START,
									Notifications =
									{
										["Pressed"] =
										{
											[false] =
											{
												{ ui.NOTIFY_ID, "the-boing", "setValue", "Running", true }
											}
										}
									}
								},
								ui.Button:new
								{
									Text = L.ANIMATIONS_STOP,
									Notifications =
									{
										["Pressed"] =
										{
											[false] =
											{
												{ ui.NOTIFY_ID, "the-boing", "setValue", "Running", false }
											}
										}
									}
								}
							}
						}
					}
				},
				Group:new
				{
					Height = "fill",
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
