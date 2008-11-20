#!/usr/bin/env lua

local ui = require "tek.ui"

local APP_ID = "tekui-demo"
local VENDOR = "schulze-mueller.de"

local L = ui.getLocale(APP_ID, VENDOR)

app = ui.Application:new
{
	ApplicationId = APP_ID,
	VendorDomain = VENDOR,
-- 	ThemeName = "internal",
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
					GridWidth = 2,
					SameHeight = true,
					Children =
					{
						ui.Text:new
						{
							Text = L.PATH,
							Width = "auto",
							Class = "caption",
							HAlign = "right",
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
						},
						ui.CheckMark:new
						{
							Id = "multiselect",
							KeyCode = ui.extractKeyCode(L.MULTISELECT),
							VAlign = "center",
						},
					}
				},
				ui.Text:new
				{
					Text = L.CHOOSE_FILE,
					Class = "button",
					Mode = "button",
					Width = "auto",
					HAlign = "right",
					Notifications =
					{
						["Pressed"] =
						{
							[false] =
							{
								{ ui.NOTIFY_APPLICATION, ui.NOTIFY_COROUTINE, function(self)
									local pathfield = self:getElementById("pathfield")
									local filefield = self:getElementById("filefield")
									local statusfield = self:getElementById("statusfield")
									local status, path, select = self:requestFile
									{
										Path = pathfield.Text,
										SelectMode = self:getElementById("multiselect").Selected and
											"multi" or "single"
									}
									statusfield:setValue("Text", status)
									if status == "selected" then
										pathfield:setValue("Text", path)
										self:getElementById("filefield"):setValue("Text",
											table.concat(select, ", "))
									end
								end }
							}
						}
					}
				}
			}
		}
	}
}:run()
