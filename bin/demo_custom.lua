#!/usr/bin/env lua

local ui = require "tek.ui"
local UTF8String = require "tek.class.utf8string"
local Group = ui.Group
local Text = ui.Text
local TextInput = ui.TextInput
local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Keybutton class:
-------------------------------------------------------------------------------

local KeyButton = ui.Text:newClass { _NAME = "_keybutton" }

function KeyButton.init(self)
	self.KeyString = self.KeyString or self.Text
	self.KeyCode = self.KeyCode or self.KeyString:byte()
	assert(self.KeyCode)
	assert(self.Group)
	self.Width = self.Width or "fill"
	self.Mode = self.Mode or "button"
	self.Class = self.Class or "button"
	return ui.Text.init(self)
end

function KeyButton:onPress(pressed)
	if pressed == true then
		local pe = self.Group.Element
		if pe then
			local w = self.Window
			w:setActiveElement(pe)
			w:postMsg {
				0, -- timestamp?
				ui.MSG_KEYDOWN, -- type
				self.KeyCode, -- code
				0, -- mousex
				0, -- mousey
				0, -- ?
				self.KeyString,
			}
		end
	end
end

-------------------------------------------------------------------------------
--	NumberInput class:
-------------------------------------------------------------------------------

local NumberInput = Group:newClass { _NAME = "_numberinput" }

function NumberInput.new(class, self)
	self.Disabled = true
	self.Element = self.Element or false
	self.Buttons1 = {
		KeyButton:new { Text = "7", Group = self, Disabled = true },
		KeyButton:new { Text = "8", Group = self, Disabled = true },
		KeyButton:new { Text = "9", Group = self, Disabled = true },
		KeyButton:new { Text = "4", Group = self, Disabled = true },
		KeyButton:new { Text = "5", Group = self, Disabled = true },
		KeyButton:new { Text = "6", Group = self, Disabled = true },
		KeyButton:new { Text = "1", Group = self, Disabled = true },
		KeyButton:new { Text = "2", Group = self, Disabled = true },
		KeyButton:new { Text = "3", Group = self, Disabled = true },
		KeyButton:new { Text = "0", Group = self, Disabled = true },
		KeyButton:new { Text = ",", Group = self, Disabled = true },
		KeyButton:new { Text = "«", Group = self, Disabled = true, KeyCode = 0xf010, Height = "auto" },
	}
	self.Buttons2 = {
		KeyButton:new { Text = "Ret", Group = self, Disabled = true, KeyCode = 13, Height = "fill" },
		KeyButton:new { Text = "Del", Group = self, Disabled = true, KeyCode = 127 },
	}
	self.Children =
	{
		Group:new
		{
		 	Columns = 3,
			SameSize = "width",
			Children = self.Buttons1
		},
		Group:new
		{
			Height = "fill",
			Width = "auto",
			Orientation = "vertical",
			Children = self.Buttons2
		}
	}
	return Group.new(class, self)
end

function NumberInput:onDisable(disable)
	for k, e in ipairs(self.Buttons1) do
		e:setValue("Disabled", disable)
	end
	for k, e in ipairs(self.Buttons2) do
		e:setValue("Disabled", disable)
	end
	if disable then
		self.Buttons2[1]:setValue("Selected", false)
	end
	return Group.onDisable(self, disable)
end

-------------------------------------------------------------------------------
--	NetworkInput class:
-------------------------------------------------------------------------------

local NetworkInput = TextInput:newClass { _NAME = "_networkinput" }

function NetworkInput.init(self)
	self.Text = self.Text or "0.0.0.0"
	self.TextCursor = 0
	self.ActivateId = self.ActivateId or false
	return TextInput.init(self)
end

function NetworkInput:onSelect(selected)
	local e = self:getById(self.ActivateId)
	if e then
		if selected then
			e:setValue("Element", self)
			e:setValue("Disabled", false)
		else
			e:setValue("Disabled", true)
		end
	end
	TextInput.onSelect(self, selected)
end

function NetworkInput:onDisable(disabled)
	if disabled then
		local e = self:getById(self.ActivateId)
		if e then
			e:setValue("Disabled", true)
		end
	end
	TextInput.onDisable(self, disabled)
end

function NetworkInput:moveCursorRight()
	local res = TextInput.moveCursorRight(self)
	if self:getChar() == "." then
		res = TextInput.moveCursorRight(self)
	end
	return res
end

function NetworkInput:moveCursorLeft()
	local res = TextInput.moveCursorLeft(self)
	if self:getChar() == "." then
		res = TextInput.moveCursorLeft(self)
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
--	Create demo window:
-------------------------------------------------------------------------------

local window = ui.Window:new
{
	Orientation = "vertical",
	Id = "custom-window",
	Title = L.CUSTOMCLASS_TITLE,
	Status = "hide",
	Orientation = "vertical",
	HideOnEscape = true,
	Children =
	{
		Group:new
		{
			Legend = L.CUSTOMCLASS_NETWORK_CONFIGURATION,

			Children =
			{
				Group:new
				{
					Style = "border-style: inset; border-width: 2;",
					Orientation = "vertical",
					Children =
					{
						ui.CheckMark:new { Text = L.CUSTOMCLASS_DHCP, Selected = true,
							onSelect = function(self, selected)
								ui.CheckMark.onSelect(self, selected)
								self:getById("input-address"):setValue("Disabled", selected)
								self:getById("input-netmask"):setValue("Disabled", selected)
								self:getById("input-gateway"):setValue("Disabled", selected)
								self:getById("input-dns"):setValue("Disabled", selected)
								if not selected then
									self:getById("input-address"):setValue("Focus", true)
								end
							end,
						},
						Group:new
						{
							Columns = 2,
							Children =
							{
								Text:new { Text = L.CUSTOMCLASS_ADDRESS, Class = "caption", Width = "auto", HAlign = "right" },
								NetworkInput:new { Id = "input-address", EnterNext = true, Disabled = true,
									ActivateId = "number-input",
									onEnter = function(self, text)
										local a, b, c = text:match("^(%d+)%.(%d+)%.(%d+)%.%d+$")
										local mask = c and tonumber(c) ~= 0 and "255.255.0.0" or "255.255.255.0"
										self:getById("input-netmask"):setValue("Text", mask)
										self:getById("input-gateway"):setValue("Text", ("%d.%d.0.0"):format(a, b))
										self:getById("input-dns"):setValue("Text", ("%d.%d.0.0"):format(a, b))
										NetworkInput.onEnter(self, text)
									end,
								},
								Text:new { Text = L.CUSTOMCLASS_NETMASK, Class = "caption", Width = "auto", HAlign = "right" },
								NetworkInput:new { Id = "input-netmask", EnterNext = true, Disabled = true,
									ActivateId = "number-input",
								},
								Text:new { Text = L.CUSTOMCLASS_GATEWAY, Class = "caption", Width = "auto", HAlign = "right" },
								NetworkInput:new { Id = "input-gateway", EnterNext = true, Disabled = true,
									ActivateId = "number-input",
								},
								Text:new { Text = L.CUSTOMCLASS_DNS, Class = "caption", Width = "auto", HAlign = "right" },
								NetworkInput:new { Id = "input-dns", Disabled = true,
									ActivateId = "number-input",
								}
							}
						}
					}
				},
				NumberInput:new
				{
					Legend = L.CUSTOMCLASS_KEYPAD,
					Id = "number-input",
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
		Name = L.CUSTOMCLASS_TITLE,
		Description = L.CUSTOMCLASS_DESCRIPTION
	}
end
