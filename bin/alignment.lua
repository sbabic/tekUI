#!/usr/bin/env lua

local ui = require "tek.ui"

local APP_ID = "tekui-demo"
local VENDOR = "schulze-mueller.de"

local L = ui.getLocale(APP_ID, VENDOR)

ui.Application:new
{
	ApplicationId = APP_ID,
	VendorDomain = VENDOR,
	Children =
	{
		ui.Window:new
		{
			Orientation = "vertical",
			Title = L.ALIGNMENT_DEMO,
			Children =
			{
				ui.Group:new
				{
					Orientation = "vertical",
					Width = "free",
					Legend = L.ALIGN_HORIZONTAL,
					Children =
					{
						ui.Text:new
						{
							Class = "button",
							Mode = "button",
							Text = L.BEGIN,
							Width = "auto",
							Height = "free",
							HAlign = "left"
						},
						ui.Text:new
						{
							Class = "button",
							Mode = "button",
							Text = L.CENTER,
							Width = "auto",
							Height = "free",
							HAlign = "center"
						},
						ui.Group:new
						{
							Legend = L.GROUP,
							Width = "auto",
							Height = "free",
							HAlign = "right",
							Children =
							{
								ui.Text:new
								{
									Class = "button",
									Mode = "button",
									Text = L.END,
									Width = "auto",
									Height = "free"
								},
							},
						},
					},
				},
				ui.Group:new
				{
					Height = "free",
					Legend = L.ALIGN_VERTICAL,
					Children =
					{
						ui.Text:new
						{
							Class = "button",
							Mode = "button",
							Text = L.BEGIN,
							Width = "free",
							VAlign = "top",
							Legend = L.BORDER_LEGEND,
						},
						ui.Text:new
						{
							Class = "button",
							Mode = "button",
							Text = L.CENTER,
							Width = "free",
							VAlign = "center"
						},
						ui.Group:new
						{
							Legend = L.GROUP,
							Width = "free",
							VAlign = "bottom",
							Children =
							{
								ui.Text:new
								{
									Class = "button",
									Mode = "button",
									Text = L.END,
									Width = "free"
								},
							},
						},
					},
				},
			},
		},
	},
}:run()
