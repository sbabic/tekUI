#!/usr/bin/env lua

local lfs = require "lfs"
local List = require "tek.class.list"
local ui = require "tek.ui"
local db = require "tek.lib.debug"

local APP_ID = "tekui-demo"
local VENDOR = "schulze-mueller.de"
local L = ui.getLocale(APP_ID, VENDOR)

function lfs.readdir(path)
	local dir = lfs.dir(path)
	return function()
		local e
		repeat
			e = dir()
		until e ~= "." and e ~= ".."
		return e
	end
end

-- -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--	Load demos and insert them to the application:
-- -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function loaddemos(app)

	local demogroup = app:getElementById("demo-group")

	local demos = { }

	for fname in lfs.readdir(ui.ProgDir) do
		if fname:match("^demo_.*") then
			fname = ui.ProgDir .. "/" .. fname
			db.info("Loading demo '%s' ...", fname)
			local success, res = pcall(dofile, fname)
			if success then
				table.insert(demos, res)
			else
				db.error("*** Error loading demo '%s'", fname)
				db.error(res)
			end
		end
	end

	table.sort(demos, function(a, b) return a.Name < b.Name end)

	for _, demo in ipairs(demos) do
		ui.Application.connect(demo.Window)
		app:addMember(demo.Window)
		local button = ui.Text:new
		{
			Id = demo.Window.Id .. "-button",
			Text = demo.Name,
			Mode = "toggle",
			Width = "free",
			Class = "button",
			UserData = demo.Window
		}
		button:addNotify("Selected", true, { ui.NOTIFY_ID, "info-text", "setValue", "Text", demo.Description })
		button:addNotify("Selected", true, { ui.NOTIFY_ID, demo.Window.Id, "setValue", "Status", "show" })
		button:addNotify("Selected", false, { ui.NOTIFY_ID, demo.Window.Id, "setValue", "Status", "hide" })
		ui.Application.connect(button)
		demogroup:addMember(button)
	end

end

-------------------------------------------------------------------------------
--	Application:
-------------------------------------------------------------------------------

local QuitNotification =
{
	ui.NOTIFY_APPLICATION, ui.NOTIFY_COROUTINE, function(self)
		if self:easyRequest(false, L.CONFIRM_QUIT_APPLICATION,
			L.QUIT, L.CANCEL) == 1 then
			self:setValue("Status", "quit")
		end
	end
}

app = ui.Application:new
{
	ProgramName = "tekUI Demo",
	Author = "Timm S. Müller",
	Copyright = "Copyright © 2008, 2009, Schulze-Müller GbR",
	ApplicationId = APP_ID,
	VendorDomain = VENDOR,
	-- ThemeName = "internal",
	Children =
	{
		ui.Window:new
		{
			Style = "width: 400; height: 500",

			UserData =
			{
				MemRefreshTickCount = 0,
				MemRefreshTickInit = 25,
				MinMem = false,
				MaxMem = false,
			},

			updateInterval = function(self, msg)
				local data = self.UserData
				data.MemRefreshTickCount = data.MemRefreshTickCount - 1
				if data.MemRefreshTickCount <= 0 then
					data.MemRefreshTickCount = data.MemRefreshTickInit
					local m = collectgarbage("count")
					data.MinMem = math.min(data.MinMem or m, m)
					data.MaxMem = math.max(data.MaxMem or m, m)
					local mem = self.Application:getElementById("about-mem-used")
					if mem then
						mem:setValue("Text", ("%dk - min: %dk - max: %dk"):format(m,
							data.MinMem, data.MaxMem))
					end
					local gauge = self.Application:getElementById("about-mem-gauge")
					if gauge then
						gauge:setValue("Min", data.MinMem)
						gauge:setValue("Max", data.MaxMem)
						gauge:setValue("Value", m)
					end
				end
				return msg
			end,

			show = function(self, display, drawable)
				if ui.Window.show(self, display, drawable) then
					self:addInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
					return true
				end
			end,

			hide = function(self)
				self:remInputHandler(ui.MSG_INTERVAL, self, self.handlerInterval)
				ui.Window.hide(self)
			end,

			Center = true,
			Orientation = "vertical",
			Id = "about-window",
			Status = "hide",
			Title = L.ABOUT_TEKUI,
			Notifications =
			{
				["Status"] =
				{
					["opening"] =
					{
						{ ui.NOTIFY_ID, "about-mem-refresh", "setValue", "Pressed", false },
					},
					["show"] =
					{
						{ ui.NOTIFY_ID, "about-button", "setValue", "Selected", true },
					},
					["hide"] =
					{
						{ ui.NOTIFY_ID, "about-button", "setValue", "Selected", false }
					}
				}
			},
			Children =
			{
				ui.Text:new { Text = L.ABOUT_TEKUI, Style = "font: ui-large" },
				ui.PageGroup:new
				{
					PageCaptions = { L.ABOUT_APPLICATION, L.ABOUT_LICENSE, L.ABOUT_SYSTEM },
					PageNumber = 3,
					Children =
					{
						ui.Group:new
						{
							Orientation = "vertical",
							Children =
							{
								ui.Group:new
								{
									Legend = L.ABOUT_APPLICATION_INFORMATION,
									Children =
									{
										ui.ListView:new
										{
											HSliderMode = "auto",
											VSliderMode = "auto",
											Headers = { L.PROPERTY, L.VALUE },
											Child = ui.ListGadget:new
											{
												SelectMode = "none",
												ListObject = List:new
												{
													Items =
													{
														{ { "ProgramName", "tekUI Demo" } },
														{ { "Version", "1.0" } },
														{ { "Author", "Timm S. Müller" } },
														{ { "Copyright", "© 2008, 2009, Schulze-Müller GbR" } },
													}
												}
											}
										}
									}
								}
							}
						},
						ui.Group:new
						{
							Orientation = "vertical",
							Children =
							{
								ui.PageGroup:new
								{
									PageCaptions = { "tekUI", "Lua", L.DISCLAIMER },
									Children =
									{
										ui.ScrollGroup:new
										{
											Legend = L.TEKUI_LICENSE,
											VSliderMode = "auto",
											Child = ui.Canvas:new
											{
												KeepMinHeight = true,
												AutoWidth = true,
												Child = ui.FloatText:new
												{
													Text = L.TEKUI_COPYRIGHT_TEXT
												}
											}
										},
										ui.ScrollGroup:new
										{
											Legend = L.LUA_LICENSE,
											VSliderMode = "auto",
											Child = ui.Canvas:new
											{
												KeepMinHeight = true,
												AutoWidth = true,
												Child = ui.FloatText:new
												{
													Text = L.LUA_COPYRIGHT_TEXT
												}
											}
										},
										ui.ScrollGroup:new
										{
											Legend = L.DISCLAIMER,
											VSliderMode = "auto",
											Child = ui.Canvas:new
											{
												KeepMinHeight = true,
												AutoWidth = true,
												Child = ui.FloatText:new
												{
													Text = L.DISCLAIMER_TEXT
												}
											}
										}
									}
								}
							}
						},
						ui.Group:new
						{
							Orientation = "vertical",
							Children =
							{
								ui.Group:new
								{
									Legend = L.SYSTEM_INFORMATION,
									Orientation = "vertical",
									Children =
									{
										ui.ScrollGroup:new
										{
											VSliderMode = "auto",
											Child = ui.Canvas:new
											{
												AutoWidth = true,
												Child = ui.FloatText:new
												{
													Text = L.INTERPRETER_VERSION:format(_VERSION)
												}
											}
										},
										ui.Group:new
										{
											Legend = L.LUA_VIRTUAL_MACHINE,
											GridWidth = 2,
											Children =
											{
												ui.Text:new
												{
													Text = L.MEMORY_USAGE,
													Class = "caption",
													Style = "text-align: right; width: fill"
												},
												ui.Group:new
												{
													Orientation = "vertical",
													Children =
													{
														ui.Text:new { Id = "about-mem-used" },
														ui.Gauge:new { Id = "about-mem-gauge" },
													}
												}
											}
										},
										ui.Group:new
										{
											Legend = L.DEBUGGING,
											GridWidth = 2,
											Children =
											{
												ui.Text:new
												{
													Text = L.DEBUG_LEVEL,
													Class = "caption",
													Style = "width: fill; text-align: right",
												},
												ui.ScrollBar:new
												{
													ArrowOrientation = "vertical",
													Width = "free",
													Min = 1,
													Max = 20,
													Value = db.level,
													Child = ui.Text:new
													{
														Id = "about-system-debuglevel",
														Class = "knob button",
														Text = tostring(db.level),
														Style = "font: ui-small;",
													},
													Notifications =
													{
														["Value"] =
														{
															[ui.NOTIFY_CHANGE] =
															{
																{ ui.NOTIFY_ID, "about-system-debuglevel", "setValue", "Text", ui.NOTIFY_FORMAT, "%d" },
																{ ui.NOTIFY_SELF, ui.NOTIFY_FUNCTION, function(self, value)
																	db.level = math.floor(value)
																end, ui.NOTIFY_VALUE }
															}
														}
													}
												},
												ui.Text:new
												{
													Text = L.DEBUG_OPTIONS,
													Class = "caption",
													Style = "width: fill; text-align: right",
												},
												ui.Group:new
												{
													Children =
													{
														ui.CheckMark:new
														{
															Selected = ui.DEBUG,
															Text = L.SLOW_RENDERING,
															Notifications =
															{
																["Selected"] =
																{
																	[ui.NOTIFY_CHANGE] =
																	{
																		{ ui.NOTIFY_SELF, ui.NOTIFY_FUNCTION, function(self, value)
																			ui.DEBUG = value
																			ui.Drawable.enableDebug(value)
																		end, ui.NOTIFY_VALUE }
																	}
																}
															}
														},
														ui.Text:new
														{
															Mode = "button",
															Class = "button",
															Text = L.DEBUG_CONSOLE,
															Notifications =
															{
																["Pressed"] =
																{
																	[false] =
																	{
																		{ ui.NOTIFY_SELF, ui.NOTIFY_FUNCTION, function(self)
																			db.console()
																		end }
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
				},
				ui.Text:new
				{
					Focus = true,
					Mode = "button",
					Class = "button",
					Text = L.OKAY,
					Style = "width: fill",
					Notifications =
					{
						["Pressed"] =
						{
							[false] =
							{
								{ ui.NOTIFY_WINDOW, "setValue", "Status", "hide" }
							}
						}
					}
				}
			}
		},
		ui.Window:new
		{
			Orientation = "vertical",
			Notifications =
			{
				["Status"] =
				{
					["hide"] =
					{
						{ ui.NOTIFY_APPLICATION, "setValue", "Status", "quit" }
					}
				}
			},
			Children =
			{
				ui.Group:new
				{
					Class = "menubar",
					Children =
					{
						ui.MenuItem:new
						{
							Text = L.MENU_FILE,
							Children =
							{
								ui.MenuItem:new
								{
									Text = L.MENU_ABOUT,
									Shortcut = "Ctrl+?",
									Notifications =
									{
										["Pressed"] =
										{
											[false] =
											{
												{ ui.NOTIFY_ID, "about-window", "setValue", "Status", "show" }
											}
										}
									}
								},
								ui.Spacer:new { },
								ui.MenuItem:new
								{
									Text = L.MENU_QUIT,
									Shortcut = "Ctrl+Q",
									Notifications =
									{
										["Pressed"] =
										{
											[false] =
											{
												QuitNotification
											}
										}
									}
								}
							}
						}
					}
				},
				ui.Text:new
				{
					Text = L.TEKUI_DEMO,
					Style = "font: ui-large"
				},
				ui.Group:new
				{
					Children =
					{
						ui.Group:new
						{
							Weight = 0,
							Orientation = "vertical",
							Children =
							{
								ui.ScrollGroup:new
								{
									Legend = L.AVAILABLE_DEMOS,
									Style = "max-width: free",
									VSliderMode = "auto",
									Child = ui.Canvas:new
									{
										KeepMinWidth = true,
										AutoWidth = true,
										AutoHeight = true,
										Child = ui.Group:new
										{
											Id = "demo-group",
											Style = "max-width: free",
											Orientation = "vertical",
										}
									}
								},
-- 								ui.Group:new
-- 								{
-- 									Children =
-- 									{
-- 										ui.Text:new
-- 										{
-- 											Text = L.OPEN_ALL,
-- 											Mode = "button",
-- 											Class = "button",
-- 											Notifications =
-- 											{
-- 												["Pressed"] =
-- 												{
-- 													[false] =
-- 													{
-- 														{ ui.NOTIFY_ID, "demo-group", ui.NOTIFY_FUNCTION, function(self)
-- 															for _, c in ipairs(self.Children) do
-- 																c:setValue("Selected", true)
-- 															end
-- 														end }
-- 													}
-- 												}
-- 											}
-- 										},
-- 										ui.Text:new
-- 										{
-- 											Text = L.CLOSE_ALL,
-- 											Mode = "button",
-- 											Class = "button",
-- 											Notifications =
-- 											{
-- 												["Pressed"] =
-- 												{
-- 													[false] =
-- 													{
-- 														{ ui.NOTIFY_ID, "demo-group", ui.NOTIFY_FUNCTION, function(self)
-- 															for _, c in ipairs(self.Children) do
-- 																c:setValue("Selected", false)
-- 															end
-- 														end }
-- 													}
-- 												}
-- 											}
-- 										}
-- 									}
-- 								}
							}
						},
						ui.Handle:new { },
						ui.ScrollGroup:new
						{
							Weight = 0x10000,
							Legend = L.COMMENT,
							VSliderMode = "auto",
							Child = ui.Canvas:new
							{
								AutoWidth = true,
								Child = ui.FloatText:new
								{
									Id = "info-text",
									Text = L.DEMO_TEXT,
								}
							}
						}
					}
				}
			}
		}
	}
}

loaddemos(app)

-- -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--	run application:
-- -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

app:run()
