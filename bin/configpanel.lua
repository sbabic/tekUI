#!/usr/bin/env lua

local ui = require "tek.ui"
local UTF8String = require "tek.class.utf8string"

-------------------------------------------------------------------------------
--	NetworkInput class
-------------------------------------------------------------------------------

local NetworkInput = ui.TextInput:newClass { _NAME = "_networkinput" }

function NetworkInput.init(self)
	self.Text = self.Text or "0.0.0.0"
	self.TextCursor = 0
	return ui.TextInput.init(self)
end

function NetworkInput:moveCursorRight()
	local res = self:getSuper().moveCursorRight(self)
	if self:getChar() == "." then
		res = self:getSuper().moveCursorRight(self)
	end
	return res
end

function NetworkInput:moveCursorLeft()
	local res = self:getSuper().moveCursorLeft(self)
	if self:getChar() == "." then
		res = self:getSuper().moveCursorLeft(self)
	end
	return res
end

function NetworkInput:checkValid(s)
	local a, b, c, d = s:get():match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	a, b, c, d = tonumber(a) or -1, tonumber(b) or -1, tonumber(c) or -1,
		tonumber(d) or -1
	local valid = a >= 0 and a < 256 and b >= 0 and b < 256 and
		c >= 0 and c < 256 and d >= 0 and d < 256
	if valid then
		s:set(("%d.%d.%d.%d"):format(a, b, c, d))
	end
	return valid
end

function NetworkInput:addChar(utf8c)
	if utf8c:match("^[0-9]$") then
		local t = self.TextBuffer
		local s = UTF8String:new(t:get())
		local pos = self:getCursor() + 1
		s:insert(utf8c, pos)
		if self:checkValid(s) then
			self.TextBuffer = s
			self:moveCursorRight()
			return
		end
		s = UTF8String:new(t:get())
		s:overwrite(utf8c, pos)
		if self:checkValid(s) then
			self.TextBuffer = s
			self:moveCursorRight()
			return
		end
	end
end

function NetworkInput:backSpace()
	if self:moveCursorLeft() then
		local pos = self:getCursor() + 1
		local t = self.TextBuffer
		local s = UTF8String:new(t:get())
		s:erase(pos, pos)
		if self:checkValid(s) then
			self.TextBuffer = s
			return
		end
		self.TextBuffer:overwrite("0", pos)
	end
end

function NetworkInput:delChar()
	local t = self.TextBuffer
	if t:len() > 0 then
		local pos = self:getCursor() + 1
		local s = UTF8String:new(t:get())
		s:erase(pos, pos)
		if self:checkValid(s) then
			self.TextBuffer = s
			return
		end
		local s = UTF8String:new(t:get())
		s:overwrite("0", pos)
		if self:checkValid(s) then
			self.TextBuffer = s
			return
		end
	end
end

-------------------------------------------------------------------------------

local APP_ID = "demo-configpanel"
local VENDOR = "schulze-mueller.de"

app = ui.Application:new
{
	ApplicationId = APP_ID,
	VendorDomain = VENDOR,
	ProgramName = "Demo Config Panel",
	Author = "Timm S. Müller",
	CopyRight = "Copyright © 2008, Schulze-Müller GbR",
	ThemeName = "demo",
	Children =
	{
		ui.Window:new
		{
			Orientation = "vertical",
			Children =
			{
				ui.Group:new
				{
					Children =
					{
						ui.PageGroup:new
						{
							PageCaptions = { "_Configuration" },
							Orientation = "vertical",
							Children =
							{
								ui.Group:new
								{
									Orientation = "vertical",
									Children =
									{
										ui.Group:new
										{
											Legend = "Network",

											Children =
											{
												ui.Group:new
												{
													Style = "border-style: inset; border-width: 2;",
													Orientation = "vertical",
													Children =
													{
														ui.CheckMark:new { Text = "Receive automatically (DHCP)", Selected = false,
															onSelect = function(self, selected)
																self.Application:getElementById("input-address"):setValue("Disabled", selected)
																self.Application:getElementById("input-netmask"):setValue("Disabled", selected)
																self.Application:getElementById("input-gateway"):setValue("Disabled", selected)
																self.Application:getElementById("input-dns"):setValue("Disabled", selected)
																self:getSuper().onSelect(self, selected)
															end,
														},
														ui.Group:new
														{
															GridWidth = 2,
															Children =
															{
																ui.Text:new { Text = "Address", Class = "caption", Width = "auto", HAlign = "right" },
																NetworkInput:new { Id = "input-address", EnterNext = true },
																ui.Text:new { Text = "Netmask", Class = "caption", Width = "auto", HAlign = "right" },
																NetworkInput:new { Id = "input-netmask", EnterNext = true },
																ui.Text:new { Text = "Gateway", Class = "caption", Width = "auto", HAlign = "right" },
																NetworkInput:new { Id = "input-gateway", EnterNext = true },
																ui.Text:new { Text = "DNS", Class = "caption", Width = "auto", HAlign = "right" },
																NetworkInput:new { Id = "input-dns" },
															}
														}
													}
												}
											}
										},
										ui.Group:new
										{
											Legend = "User Interface",
											Children =
											{
												ui.Group:new
												{
													Style = "border-style: inset; border-width: 2;",
													Orientation = "vertical",
													GridHeight = 3,
													Children =
													{
														ui.RadioButton:new { Text = "English", Selected = true },
														ui.RadioButton:new { Text = "日本語", Class = "japanese" },
														ui.RadioButton:new { Text = "Français" },
														ui.RadioButton:new { Text = "Español" },
														ui.RadioButton:new { Text = "Deutsch" },
														ui.RadioButton:new { Text = "Italiano" },
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
}:run()

