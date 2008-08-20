#!/usr/bin/env lua

local ui = require "tek.ui"

ui.Application:new
{
	Children =
	{
		ui.Window:new
		{
			Orientation = "vertical",
			Title = "Alignment Demo",
			Children =
			{
				ui.Group:new
				{
					Orientation = "vertical",
					Width = "free",
					Legend = "Align Horizontal",
					Children =
					{
						ui.Text:new { Class = "button", Mode = "button", Text = "Begin", Width = "auto", Height = "free", HAlign = "left" },
						ui.Text:new { Class = "button", Mode = "button", Text = "Center", Width = "auto", Height = "free", HAlign = "center" },
						ui.Group:new { Legend = "Group", Width = "auto", Height = "free", HAlign = "right",
							Children =
							{
								ui.Text:new { Class = "button", Mode = "button", Text = "End", Width = "auto", Height = "free" }
							}
						},
					},
				},
				ui.Group:new
				{
					Height = "free",
					Legend = "Align Vertical",
					Children =
					{
						ui.Text:new { Class = "button", Mode = "button", Text = "Begin", Width = "free", VAlign = "top", Legend = "Border Legend" },
						ui.Text:new { Class = "button", Mode = "button", Text = "Center", Width = "free", VAlign = "center" },
						ui.Group:new
						{
							Legend = "Group", Width = "free", VAlign = "bottom",
							Children =
							{
								ui.Text:new { Class = "button", Mode = "button", Text = "End", Width = "free" }
							}
						}
					},
				},
			},
		},
	},
}:run()
