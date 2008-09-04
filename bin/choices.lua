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
			Width = "auto",
			Height = "auto",
			Title = L.CHOICES,
			Legend = L.CHOICES,
			SameSize = true,
			Children =
			{
				ui.Group:new
				{
					Orientation = "vertical",
					Legend = L.ORDER_BEVERAGES,
					Children =
					{
						ui.CheckMark:new { Text = L.CHOICE_WATER },
						ui.CheckMark:new { Text = L.CHOICE_JUICE, Disabled = true },
						ui.CheckMark:new { Text = L.CHOICE_MILK },
						ui.Spacer:new { },
						ui.CheckMark:new { Text = L.CHOICE_TEA },
						ui.CheckMark:new { Text = L.CHOICE_COFFEE },
						ui.Spacer:new { },
						ui.CheckMark:new { Text = L.CHOICE_BEER },
						ui.CheckMark:new { Text = L.CHOICE_WINE },
					},
				},
				ui.Group:new
				{
					Orientation = "vertical",
					Legend = L.ARE_YOU_IMPRESSED,
					Children =
					{
						ui.RadioButton:new { Text = L.CHOICE_YES },
						ui.RadioButton:new { Text = L.CHOICE_NO },
						ui.Spacer:new { },
						ui.RadioButton:new { Text = L.CHOICE_POSSIBLY },
						ui.RadioButton:new { Text = L.CHOICE_MAYBE },
						ui.RadioButton:new { Text = L.CHOICE_PERHAPS, Disabled = true },
						ui.Spacer:new { },
						ui.RadioButton:new { Text = L.CHOICE_WHAT_ME },
						ui.RadioButton:new { Text = L.CHOICE_ASK_AGAIN_LATER },
					},
				},
			},
		},
	},
}:run()
