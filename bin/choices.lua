#!/usr/bin/env lua

local ui = require "tek.ui"

local APP_ID = "tekui-demo"
local VENDOR = "schulze-mueller.de"

local L = ui.getLocale(APP_ID, VENDOR)

-------------------------------------------------------------------------------

local VerboseCheckMark = ui.CheckMark:newClass { _NAME = "_vbcheckmark" }

function VerboseCheckMark:onSelect(selected)
	local tw = self.Application:getElementById("text-window")
	local text = selected and L.ORDER or L.REVOKE
	text = text .. ": " .. self.Text:gsub("_", "")
	tw:appendLine(text, true)
	ui.CheckMark.onSelect(self, selected)
end

-------------------------------------------------------------------------------

local VerboseRadioButton = ui.RadioButton:newClass { _NAME = "_vbradiobutton" }

function VerboseRadioButton:onSelect(selected)
	if selected == true then
		local tw = self.Application:getElementById("text-window")
		local text = L.IMPRESSED .. ": " .. self.Text:gsub("_", "")
		tw:appendLine(text, true)
	end
	ui.RadioButton.onSelect(self, selected)
end

-------------------------------------------------------------------------------

ui.Application:new
{
	ApplicationId = APP_ID,
	VendorDomain = VENDOR,
	Children =
	{
		ui.Window:new
		{
			Title = L.CHOICES,
			Height = "auto",
			Children =
			{
				ui.Group:new
				{
					Width = "auto",
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
								VerboseCheckMark:new
								{
									Text = L.CHOICE_WATER
								},
								VerboseCheckMark:new
								{
									Text = L.CHOICE_JUICE,
									Disabled = true
								},
								VerboseCheckMark:new
								{
									Text = L.CHOICE_MILK
								},
								ui.Spacer:new { },
								VerboseCheckMark:new
								{
									Text = L.CHOICE_TEA
								},
								VerboseCheckMark:new
								{
									Text = L.CHOICE_COFFEE
								},
								ui.Spacer:new { },
								VerboseCheckMark:new
								{
									Text = L.CHOICE_BEER
								},
								VerboseCheckMark:new
								{
									Text = L.CHOICE_WINE
								},
							}
						},
						ui.Group:new
						{
							Orientation = "vertical",
							Legend = L.ARE_YOU_IMPRESSED,
							Children =
							{
								VerboseRadioButton:new
								{
									Text = L.CHOICE_YES
								},
								VerboseRadioButton:new
								{
									Text = L.CHOICE_NO
								},
								ui.Spacer:new { },
								VerboseRadioButton:new
								{
									Text = L.CHOICE_POSSIBLY
								},
								VerboseRadioButton:new
								{
									Text = L.CHOICE_MAYBE
								},
								VerboseRadioButton:new
								{
									Text = L.CHOICE_PERHAPS,
									Disabled = true
								},
								ui.Spacer:new { },
								VerboseRadioButton:new
								{
									Text = L.CHOICE_WHAT_ME
								},
								VerboseRadioButton:new
								{
									Text = L.CHOICE_ASK_AGAIN_LATER
								},
							}
						}
					}
				},
				ui.ScrollGroup:new
				{
					Legend = L.OUTPUT,
					VSliderMode = "auto",
					Child = ui.Canvas:new
					{
						AutoWidth = true,
						Child = ui.FloatText:new
						{
							LatchOn = "bottom",
							Id = "text-window",
						}
					}
				}
			}
		}
	}
}:run()
