#!/usr/bin/env lua

local ui = require "tek.ui"
local Group = ui.Group
local Text = ui.Text

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Helper classes:
-------------------------------------------------------------------------------

local VerboseCheckMark = ui.CheckMark:newClass { _NAME = "_vbcheckmark" }

function VerboseCheckMark:onSelect(selected)
	local tw = self.Application:getElementById("text-window")
	local text = selected and L.SELECTED or L.REVOKED
	text = text .. ": " .. self.Text:gsub("_", "")
	tw:appendLine(text, true)
	ui.CheckMark.onSelect(self, selected)
end

local VerboseRadioButton = ui.RadioButton:newClass { _NAME = "_vbradiobutton" }

function VerboseRadioButton:onSelect(selected)
	if selected == true then
		local tw = self.Application:getElementById("text-window")
		local text = L.SELECTED .. ": " .. self.Text:gsub("_", "")
		tw:appendLine(text, true)
	end
	ui.RadioButton.onSelect(self, selected)
end

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = ui.Window:new
{
	Id = "choices-window",
	Style = "Width: auto; Height: auto",
	Title = L.CHOICES_TITLE,
	Status = "hide",
	Height = "free",
	Width = "free",
	Children =
	{
		Group:new
		{
			Width = "fill",
			Rows = 5,
			SameSize = "width",
			Orientation = "vertical",
			Legend = L.CHOICES_ORDER_BEVERAGES,
			Children =
			{
				VerboseRadioButton:new
				{
					Text = L.CHOICES_COFFEE,
					Id = "drink-coffee",
					Selected = true,
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-hot"):setValue("Selected", true)
							self.Application:getElementById("drink-hot"):setValue("Disabled", false)
							self.Application:getElementById("drink-ice"):setValue("Disabled", false)
							self.Application:getElementById("drink-straw"):setValue("Disabled", false)
							self.Application:getElementById("drink-shaken"):setValue("Disabled", false)
							self.Application:getElementById("drink-stirred"):setValue("Selected", false)
							self.Application:getElementById("drink-stirred"):setValue("Disabled", false)
						end
						VerboseRadioButton.onSelect(self, active)
					end,
				},
				VerboseRadioButton:new
				{
					Text = L.CHOICES_JUICE,
					Id = "drink-juice",
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-hot"):setValue("Selected", false)
							self.Application:getElementById("drink-hot"):setValue("Disabled", true)
							self.Application:getElementById("drink-ice"):setValue("Disabled", false)
							self.Application:getElementById("drink-straw"):setValue("Disabled", false)
							self.Application:getElementById("drink-shaken"):setValue("Disabled", false)
							self.Application:getElementById("drink-stirred"):setValue("Disabled", false)
						end
						VerboseRadioButton.onSelect(self, active)
					end,
				},
				VerboseRadioButton:new
				{
					Text = L.CHOICES_MANGO_LASSI,
					Id = "drink-lassi",
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-hot"):setValue("Selected", false)
							self.Application:getElementById("drink-hot"):setValue("Disabled", true)
							self.Application:getElementById("drink-ice"):setValue("Disabled", false)
							self.Application:getElementById("drink-straw"):setValue("Disabled", false)
							self.Application:getElementById("drink-straw"):setValue("Selected", true)
							self.Application:getElementById("drink-shaken"):setValue("Selected", false)
							self.Application:getElementById("drink-shaken"):setValue("Disabled", true)
							self.Application:getElementById("drink-stirred"):setValue("Disabled", true)
							self.Application:getElementById("drink-stirred"):setValue("Selected", true)
						end
						VerboseRadioButton.onSelect(self, active)
					end,
				},
				VerboseRadioButton:new
				{
					Text = L.CHOICES_BEER,
					Id = "drink-beer",
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-hot"):setValue("Selected", false)
							self.Application:getElementById("drink-hot"):setValue("Disabled", true)
							self.Application:getElementById("drink-ice"):setValue("Selected", false)
							self.Application:getElementById("drink-ice"):setValue("Disabled", true)
							self.Application:getElementById("drink-straw"):setValue("Selected", false)
							self.Application:getElementById("drink-straw"):setValue("Disabled", true)
							self.Application:getElementById("drink-shaken"):setValue("Selected", false)
							self.Application:getElementById("drink-shaken"):setValue("Disabled", true)
							self.Application:getElementById("drink-stirred"):setValue("Selected", false)
							self.Application:getElementById("drink-stirred"):setValue("Disabled", true)
						end
						VerboseRadioButton.onSelect(self, active)
					end,
				},
				VerboseRadioButton:new
				{
					Text = L.CHOICES_WHISKY,
					Id = "drink-whisky",
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-hot"):setValue("Selected", false)
							self.Application:getElementById("drink-hot"):setValue("Disabled", true)
							self.Application:getElementById("drink-ice"):setValue("Disabled", false)
							self.Application:getElementById("drink-straw"):setValue("Disabled", false)
							self.Application:getElementById("drink-shaken"):setValue("Disabled", false)
							self.Application:getElementById("drink-stirred"):setValue("Disabled", false)
						end
						VerboseRadioButton.onSelect(self, active)
					end,
				},
				VerboseCheckMark:new
				{
					Text = L.CHOICES_HOT,
					Id = "drink-hot",
					Selected = true,
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-ice"):setValue("Selected", false)
							self.Application:getElementById("drink-straw"):setValue("Selected", false)
							self.Application:getElementById("drink-shaken"):setValue("Selected", false)
						end
						VerboseCheckMark.onSelect(self, active)
					end,
				},
				VerboseCheckMark:new
				{
					Text = L.CHOICES_WITH_ICE,
					Id = "drink-ice",
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-hot"):setValue("Selected", false)
							self.Application:getElementById("drink-straw"):setValue("Selected", true)
						end
						VerboseCheckMark.onSelect(self, active)
					end,
				},
				VerboseCheckMark:new
				{
					Text = L.CHOICES_STIRRED,
					Id = "drink-stirred",
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-shaken"):setValue("Selected", false)
						end
						VerboseCheckMark.onSelect(self, active)
					end,
				},
				VerboseCheckMark:new
				{
					Text = L.CHOICES_SHAKEN,
					Id = "drink-shaken",
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-stirred"):setValue("Selected", false)
							self.Application:getElementById("drink-hot"):setValue("Selected", false)
							self.Application:getElementById("drink-ice"):setValue("Selected", true)
						end
						VerboseCheckMark.onSelect(self, active)
					end,
				},
				VerboseCheckMark:new
				{
					Text = L.CHOICES_DRINKING_STRAW,
					Id = "drink-straw",
					onSelect = function(self, active)
						if active then
							self.Application:getElementById("drink-hot"):setValue("Selected", false)
							self.Application:getElementById("drink-ice"):setValue("Selected", true)
						end
						VerboseCheckMark.onSelect(self, active)
					end,
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
					Id = "text-window",
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
		Name = L.CHOICES_TITLE,
		Description = L.CHOICES_DESCRIPTION,
	}
end
