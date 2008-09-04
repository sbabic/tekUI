#!/usr/bin/env lua

local ui = require "tek.ui"

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

local window = ui.Window:new
{
	Orientation = "vertical",
	Style = "width: 400; height: 400",
	Id = "anims-window",
	Title = L.ANIMATIONS_TITLE,
	Status = "hide",
	Notifications =
	{
		["Status"] =
		{
			["show"] =
			{
				{ ui.NOTIFY_ID, "anims-window-button", "setValue", "Selected", true }
			},
			["hide"] =
			{
				{ ui.NOTIFY_ID, "anims-window-button", "setValue", "Selected", false }
			},
		},
	},
	Children =
	{
		ui.PageGroup:new
		{
			PageCaptions = { "_Tunnel", "_Boing", "_Plasma" },
			Children =
			{
				ui.Group:new
				{
					Orientation = "vertical",
					Children =
					{
						ui.Tunnel:new
						{
							Id = "the-tunnel",
							Style = "horizontal-align: center",
						},
						ui.Group:new
						{
							Style = "width: fill; height: auto;",
							Legend = L.ANIMATIONS_PARAMETERS,
							GridWidth = 2,
							Children =
							{
								ui.text:new
								{
									Text = L.ANIMATIONS_SPEED,
									Class = "caption",
									Style = "width: fill",
								},
								ui.Slider:new
								{
									Style = "width: free",
									Min = 1,
									Max = 19,
									Value = 13,
									Range = 20,
									Step = 1,
									Notifications = {
										["Value"] = {
											[ui.NOTIFY_CHANGE] = {
												{ ui.NOTIFY_ID, "the-tunnel", "setSpeed", ui.NOTIFY_VALUE },
											},
										}
									},
								},
								ui.text:new
								{
									Text = L.ANIMATIONS_FOCUS,
									Class = "caption",
									Style = "width: fill",
								},
								ui.Slider:new
								{
									Style = "width: free",
									Min = 0x10,
									Max = 0x1ff,
									Value = 0x50,
									Range = 0x200,
									Step = 20,
									Notifications = {
										["Value"] = {
											[ui.NOTIFY_CHANGE] = {
												{ ui.NOTIFY_ID, "the-tunnel", "setViewZ", ui.NOTIFY_VALUE },
											},
										}
									},
								},
								ui.text:new
								{
									Text = L.ANIMATIONS_SEGMENTS,
									Class = "caption",
									Style = "width: fill",
								},
								ui.Slider:new {
									Style = "width: free",
									Min = 1,
									Max = 19,
									Value = 6,
									Range = 20,
									Step = 1,
									Notifications = {
										["Value"] = {
											[ui.NOTIFY_CHANGE] = {
												{ ui.NOTIFY_ID, "the-tunnel", "setNumSeg", ui.NOTIFY_VALUE },
											},
										}
									},
								},
							},
						},
					}
				},
				ui.Group:new
				{
					Orientation = "vertical",
					Children =
					{
						ui.Boing:new { Id = "the-boing" },
						ui.Group:new
						{
							Style = "height: auto",
							Children =
							{
								ui.text:new
								{
									Mode = "button",
									Class = "button",
									Text = L.ANIMATIONS_START,
									Notifications =
									{
										["Pressed"] =
										{
											[false] =
											{
												{
													ui.NOTIFY_ID, "the-boing", "setValue", "Running", true
												}
											}
										}
									}
								},
								ui.text:new
								{
									Mode = "button",
									Class = "button",
									Text = L.ANIMATIONS_STOP,
									Notifications =
									{
										["Pressed"] =
										{
											[false] =
											{
												{
													ui.NOTIFY_ID, "the-boing", "setValue", "Running", false
												}
											}
										}
									}
								},
							},
						},
					}
				},
				ui.Plasma:new { },
			},
		}
	}
}

if ui.ProgName == "anims.lua" then
	local app = ui.Application:new()
	ui.Application.connect(window)
	app:addMember(window)
	window:setValue("Status", "show")
	app:run()
else
	return
	{
		Window = window,
		Name = "Animations",
		Description = L.ANIMATIONS_DESCRIPTION
	}
end
