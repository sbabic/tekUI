#!/usr/bin/env lua

local ui = require "tek.ui"

local APP_ID = "tekui-demo"
local VENDOR = "schulze-mueller.de"

local L = ui.getLocale(APP_ID, VENDOR)

app = ui.Application:new
{
	ApplicationId = APP_ID,
	VendorDomain = VENDOR,
	Children =
	{
		ui.Window:new
		{
			Title = L.FILE_REQUEST,
			Orientation = "vertical",
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
							Width = "auto",
							Class = "caption",
							HAlign = "right",
							ShortcutMark = ui.ShortcutMark,
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
							Width = "auto",
							Class = "caption",
							HAlign = "right",
							ShortcutMark = ui.ShortcutMark,
						},
						ui.TextInput:new
						{
							Id = "filefield",
						},
						ui.Text:new
						{
							Text = L.STATUS,
							Width = "auto",
							Class = "caption",
							HAlign = "right",
							ShortcutMark = ui.ShortcutMark,
						},
						ui.Text:new
						{
							Id = "statusfield",
							TextHAlign = "left",
						},
						ui.Text:new
						{
							Text = L.MULTISELECT,
							Width = "auto",
							Class = "caption",
							HAlign = "right",
							ShortcutMark = ui.ShortcutMark,
						},
						ui.CheckMark:new
						{
							Id = "multiselect",
							KeyCode = ui.extractKeyCode(L.MULTISELECT),
							VAlign = "center",
						},
					}
				},
				ui.Button:new
				{
					Text = L.CHOOSE_FILE,
					Width = "auto",
					HAlign = "right",

					onPress = function(self, pressed)
						if pressed == false then
							local app = self.Application
							app:addCoroutine(function()
								local pathfield = app:getElementById("pathfield")
								local filefield = app:getElementById("filefield")
								local statusfield = app:getElementById("statusfield")
								local status, path, select = app:requestFile
								{
									Path = pathfield.Text,
									SelectMode = app:getElementById("multiselect").Selected and
										"multi" or "single"
								}
								statusfield:setValue("Text", status)
								if status == "selected" then
									pathfield:setValue("Text", path)
									app:getElementById("filefield"):setValue("Text",
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
