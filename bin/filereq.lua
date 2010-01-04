#!/usr/bin/env lua

local ui = require "tek.ui"

local APP_ID = "tekui-demo"
local DOMAIN = "schulze-mueller.de"

local L = ui.getLocale(APP_ID, DOMAIN)

app = ui.Application:new
{
	ApplicationId = APP_ID,
	Domain = DOMAIN,
	Children =
	{
		ui.Window:new
		{
			Title = L.FILE_REQUEST,
			Orientation = "vertical",
			HideOnEscape = true,
			Children =
			{
				ui.Group:new
				{
					Columns = 2,
					SameSize = "height",
					Children =
					{
						ui.Text:new
						{
							Text = L.PATH,
							Class = "caption",
							Style = "text-align: right",
							Width = "fill",
							MaxWidth = 0,
							KeyCode = true,
						},
						ui.TextInput:new
						{
							Id = "pathfield",
							Text = "/home",
							KeyCode = ui.extractKeyCode(L.PATH),
						},
						ui.Text:new
						{
							Text = L.SELECTED,
							Class = "caption",
							Style = "text-align: right",
							Width = "fill",
							MaxWidth = 0,
							KeyCode = true,
						},
						ui.TextInput:new
						{
							Id = "filefield",
						},
						ui.Text:new
						{
							Text = L.STATUS,
							Class = "caption",
							Style = "text-align: right",
							Width = "fill",
							MaxWidth = 0,
							KeyCode = true,
						},
						ui.Text:new
						{
							Id = "statusfield",
							Style = "text-align: left",
						},
						ui.Text:new
						{
							Text = L.MULTISELECT,
							Class = "caption",
							Style = "text-align: right",
							Width = "fill",
							MaxWidth = 0,
							KeyCode = true,
						},
						ui.CheckMark:new
						{
							Id = "multiselect",
							KeyCode = ui.extractKeyCode(L.MULTISELECT),
						},
					}
				},
				ui.Button:new
				{
					Text = L.CHOOSE_FILE,
					MaxWidth = 0,
					HAlign = "right",

					onPress = function(self, pressed)
						if pressed == false then
							local app = self.Application
							app:addCoroutine(function()
								local pathfield = app:getById("pathfield")
								local filefield = app:getById("filefield")
								local statusfield = app:getById("statusfield")
								local status, path, select = app:requestFile
								{
									Path = pathfield.Text,
									SelectMode = app:getById("multiselect").Selected and
										"multi" or "single"
								}
								statusfield:setValue("Text", status)
								if status == "selected" then
									pathfield:setValue("Text", path)
									app:getById("filefield"):setValue("Text",
										table.concat(select, ", "))
								end
							end)
						end
						self:getClass().onPress(self, pressed)
					end,
				}
			}
		}
	}
}:run()
