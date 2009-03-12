#!/usr/bin/env lua

local ui = require "tek.ui"
local List = require "tek.class.list"
local Group = ui.Group
local MenuItem = ui.MenuItem
local PopItem = ui.PopItem
local Spacer = ui.Spacer
local Window = ui.Window

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = Window:new
{
	Orientation = "vertical",
	Id = "popups-window",
	Title = L.POPUPS_TITLE,
	Status = "hide",
	Notifications =
	{
		["Status"] =
		{
			["show"] =
			{
				{ ui.NOTIFY_ID, "popups-window-button", "setValue", "Selected", true }
			},
			["hide"] =
			{
				{ ui.NOTIFY_ID, "popups-window-button", "setValue", "Selected", false }
			}
		}
	},
	Children =
	{
		Orientation = "vertical",
		Group:new
		{
			Class = "menubar",
			Children =
			{
				MenuItem:new
				{
					Text = "_File",
					Children =
					{
						MenuItem:new { Text = "New" },
						Spacer:new { },
						MenuItem:new { Text = "Open..." },
						MenuItem:new { Text = "Open Recent" },
						MenuItem:new { Text = "Open With",
							Children =
							{
								MenuItem:new { Text = "Lua" },
								MenuItem:new { Text = "Kate" },
								MenuItem:new { Text = "UltraEdit" },
								MenuItem:new { Text = "Other..." },
							}
						},
						MenuItem:new
						{
							Text = "Nesting",
							Children =
							{
								MenuItem:new
								{
									Text = "Any",
									Children =
									{
										MenuItem:new
										{
											Text = "Recursion",
											Children =
											{
												MenuItem:new
												{
													Text = "Depth" ,
													Children =
													{
														MenuItem:new
														{
															Text = "Will" ,
															Children =
															{
																MenuItem:new
																{
																	Text = "Do."
																}
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
						Spacer:new { },
						MenuItem:new { Text = "Save..." },
						MenuItem:new { Text = "Save as" },
						Spacer:new { },
						MenuItem:new { Text = "_Reload" },
						MenuItem:new { Text = "Print" },
						Spacer:new { },
						MenuItem:new { Text = "Close" },
						MenuItem:new { Text = "Close all", Shortcut = "Shift+Ctrl+Q" },
						Spacer:new { },
						MenuItem:new
						{
							Text = "_Quit",
							Shortcut = "Ctrl+Q",
						}
					}
				},
				MenuItem:new
				{
					Text = "Edit",
					Children =
					{
						MenuItem:new { Text = "Undo" },
						MenuItem:new { Text = "Redo", Disabled = true },
						Spacer:new { },
						MenuItem:new { Text = "Cut" },
						MenuItem:new { Text = "Copy" },
						MenuItem:new { Text = "Paste" },
						Spacer:new { },
						MenuItem:new { Text = "Select all" },
						MenuItem:new { Text = "Deselect", Disabled = true },
						Spacer:new { },
						ui.CheckMark:new { Text = "Checkmark" }, -- TODO
					}
				}
			}
		},
		Group:new
		{
			Children =
			{
				Group:new
				{
					Orientation = "vertical",
					Width = "free",
					Height = "free",
					Children =
					{
						Group:new
						{
							Width = "free",
							Height = "auto",
							Children =
							{
								PopItem:new
								{
									Text = "Normal Popups",
									Width = "auto",
									-- these children are not connected initially:
									Children =
									{
										PopItem:new
										{
											Text = "Button Style",
											Children =
											{
												PopItem:new
												{
													Text = "English",
													Children =
													{
														PopItem:new { Text = "One" },
														PopItem:new { Text = "Two" },
														PopItem:new { Text = "Three" },
														PopItem:new { Text = "Four" },
													}
												},
												PopItem:new
												{
													Text = "Español",
													Children =
													{
														PopItem:new { Text = "Uno" },
														PopItem:new { Text = "Dos" },
														PopItem:new { Text = "Tres" },
														PopItem:new { Text = "Cuatro" },
													}
												}
											}
										},
										MenuItem:new
										{
											Text = "Menu Style",
											Children =
											{
												MenuItem:new
												{
													Text = "Français",
													Children =
													{
														MenuItem:new { Text = "Un" },
														MenuItem:new { Text = "Deux" },
														MenuItem:new { Text = "Trois" },
														MenuItem:new { Text = "Quatre" },
													}
												},
												MenuItem:new
												{
													Text = "Deutsch",
													Children =
													{
														MenuItem:new { Text = "Eins" },
														MenuItem:new { Text = "Zwei" },
														MenuItem:new { Text = "Drei" },
														MenuItem:new { Text = "Vier" },
													}
												},
												MenuItem:new
												{
													Text = "Binary",
													Children =
													{
														MenuItem:new { Text = "001" },
														MenuItem:new { Text = "010" },
														MenuItem:new { Text = "011" },
														MenuItem:new { Text = "100" },
													}
												}
											}
										}
									}
								},
								PopItem:new
								{
									Text = "Special Popups",
									Width = "auto",
									Children =
									{
										ui.Tunnel:new
										{
											Width = "fill",
										}
									}
								},
								ui.PopList:new
								{
									Id = "euro-combo",
									Text = "Combo Box",
									KeepMinWidth = true,
									Width = "fill",
									ListObject = List:new
									{
										Items =
										{
											{ { "Combo Box" } },
											{ { "Uno - Un - Uno" } },
											{ { "Dos - Deux - Due" } },
											{ { "Tres - Trois - Tre" } },
											{ { "Cuatro - Quatre - Quattro" } },
											{ { "Cinco - Cinq - Cinque" } },
											{ { "Seis - Six - Sei" } },
											{ { "Siete - Sept - Sette" } },
											{ { "Ocho - Huit - Otto" } },
											{ { "Nueve - Neuf - Nove" } },
										}
									},
									onSelect = function(self, val)
										ui.PopList.onSelect(self, val)
										local item = self.ListObject:getItem(self.SelectedEntry)
										if item then
											self.Application:getElementById("japan-combo"):setValue("SelectedEntry", self.SelectedEntry)
											self.Application:getElementById("popup-show"):setValue("Text", item[1][1])
										end
									end,
								},
								ui.PopList:new
								{
									Id = "japan-combo",
									Text = "日本語",
									-- Class = "japanese",
									Style = "font:kochi mincho",
									KeepMinWidth = true,
									Width = "fill",
									Height = "fill",
									MinWidth = 80,
									ListObject = List:new
									{
										Items =
										{
											{ { "日本語" } },
											{ { "一" } },
											{ { "二" } },
											{ { "三" } },
											{ { "四" } },
											{ { "五" } },
											{ { "六" } },
											{ { "七" } },
											{ { "八" } },
											{ { "九" } },
										}
									}
								}
							}
						},
						ui.ScrollGroup:new
						{
							VSliderMode = "on",
							HSliderMode = "on",
							Child = ui.Canvas:new
							{
								CanvasHeight = 400,
								AutoWidth = true,
								Child = ui.Group:new
								{
									Orientation = "vertical",
									Children =
									{
										ui.Text:new
										{
											Height = "free",
											Width = "free",
											Text = "",
											Style = "font: :48",
											Id = "popup-show",
										},
										ui.Group:new
										{
											Children =
											{
												ui.PopList:new
												{
													SelectedEntry = 1,
													ListObject = List:new
													{
														Items =
														{
															{ { "a Popup in" } },
															{ { "a shifted" } },
															{ { "Scrollgroup" } },
														}
													}
												}
											}
										}
									}
								}
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
		Name = L.POPUPS_TITLE,
		Description = L.POPUPS_DESCRIPTION
	}
end
