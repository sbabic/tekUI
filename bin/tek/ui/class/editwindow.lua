
local lfs = require "lfs"
local db = require "tek.lib.debug"
local ui = require "tek.ui"

local CheckMark = ui.require("checkmark", 9)
local Group = ui.require("group", 31)
local Input = ui.require("input", 15)
local MenuItem = ui.require("menuitem", 10)
local Spacer = ui.require("spacer", 2)
local Text = ui.require("text", 28)
local Window = ui.require("window", 33)

module("tek.ui.class.editwindow", tek.ui.class.window)
_VERSION = "EditWindow 6.0"

local EditWindow = _M

local FileImage = ui.getStockImage("file")

-------------------------------------------------------------------------------
--	EditInput: handled load/save file dialogs, status bar, and focusing
-------------------------------------------------------------------------------

local EditInput = Input:newClass()

function EditInput:loadRequest()
	local app = self.Application
	app:addCoroutine(function()
		self:setEditing(false)
		local win = self.Window
		local status, path, entry = app:requestFile 
		{
			Path = win.OpenPathName,
			Location = win.OpenFileName,
			Title = win.Locale.OPEN_FILE
		}
		if status == "selected" then
			win.OpenPathName = path
			local file = entry[1]
			if file then
				win.OpenFileName = file
				local fullname = path .. "/" .. file
				self:loadText(fullname)
			end
		end
		self:setEditing(true)
	end)
end

function EditInput:saveRequest()
	self:setEditing(false)
	local win = self.Window
	local status, path, entry = self.Application:requestFile 
	{
		Path = win.OpenPathName,
		Location = win.OpenFileName,
		Title = win.Locale.SAVE_FILE_AS,
		SelectText = win.Locale.SAVE,
		FocusElement = "location",
	}
	if status == "selected" then
		win.OpenPathName = path
		local file = entry[1]
		if file then
			win.OpenFileName = file
			local fullname = path .. "/" .. file
			self:saveText(fullname)
		end
	end
	self:setEditing(true)
end

function EditInput:updateCursorStatus()
	self.Window.CursorField:setValue("Text", 
		self.Locale.LINE_COL:format(self.CursorY, self.VisualCursorX))
end

function EditInput:updateFileNameStatus()
	self.Window.FilenameField:setValue("Text", self.FileName)
end

function EditInput:updateChangedStatus()
	local img = self.Changed and FileImage or false
	self.Window.StatusField:setImage(img)
end

function EditInput:onSetCursorX(cx)
	Input.onSetCursorX(self, cx)
	self:updateCursorStatus()
end

function EditInput:onSetCursorY(cy)
	Input.onSetCursorY(self, cy)
	self:updateCursorStatus()
end

function EditInput:onSetFileName(fname)
	Input.onSetFileName(self, fname)
	self:updateFileNameStatus()
end
		
function EditInput:onSetChanged(changed)
	self:updateChangedStatus()
end

function EditInput:show()
	Input.show(self)
	self.Window:addInputHandler(ui.MSG_MOUSEBUTTON + ui.MSG_FOCUS, self, 
		self.handleInput)
	self:updateCursorStatus()
	self:updateFileNameStatus()
end

function EditInput:hide()
	self.Window:remInputHandler(ui.MSG_MOUSEBUTTON + ui.MSG_FOCUS, self, 
		self.handleInput)
	Input.hide(self)
end

function EditInput:handleInput(msg)
	
	local mw = self.Application:getModalWindow()
	if mw and mw ~= self.Window then
		-- do not intercept input messages if there is a modal window open
		return msg
	end
	
	if msg[2] == ui.MSG_FOCUS then
		self:setEditing(msg[3])
	
	elseif msg[2] == ui.MSG_MOUSEBUTTON then
	
		if msg[3] == 64 then -- wheelup
			self:setValue("Focus", true)
			self:cursorUp()
			return false
		elseif msg[3] == 128 then -- wheeldown
			self:setValue("Focus", true)
			self:cursorDown()
			return false
		end		
		
		if msg[3] == 1 then
		
			local c = self.Parent
			local r1, r2, r3, r4 = c:getRect()
			local vw = r3 - r1 + 1
			local vh = r4 - r2 + 1
			
			local m1, m2, m3, m4 = self:getMargin()
			local x = msg[4] - r1
			local y = msg[5] - r2
			
			if x >= 0 and x < vw and y >= 0 and y <= vh then
				x = x + c.CanvasLeft
				y = y + c.CanvasTop
				if x >= m1 and y >= m2 and x < c.CanvasWidth - m3 and
					y < c.CanvasHeight - m4 then
					-- db.warn("in text")
					self:setValue("Focus", true)
				else
					-- db.warn("in canvas")
					self:setEditing(true)
				end
				self:setCursorByXY(x, y)
			else
				if self.Window.EditScrollGroup:getByXY(msg[4], msg[5]) then
					-- db.warn("in group")
					self:setEditing(true)
				else
					-- db.warn("outside")
				end
			end
		end
		
	end
	return msg
end

function EditInput:checkChanges(finalizer)
	local app = self.Application
	if self.Changed then
		app:addCoroutine(function()
			local win = self.Window
			local L = win.Locale
			local res = app:easyRequest(L.EXIT_APPLICATION,
				L.ABOUT_TO_LOSE_CHANGES,
				L.SAVE, L.DISCARD, L.CANCEL)
			if res == 2 then
				finalizer()
			elseif res == 1 then
				win.EditInput:saveRequest()
				finalizer()
			end
		end)
	else
		finalizer()
	end
end

-------------------------------------------------------------------------------
--	EditWindow: places an editor with accompanying elements, menus and
--	shortcuts in a window
-------------------------------------------------------------------------------

function EditWindow.new(class, self)

	self = self or { }
	local window = self -- for use as an upvalue
	
	self.Center = true
	self.Orientation = "vertical"
	self.Running = true
	self.OpenPathName = self.OpenPathName or lfs.currentdir()
	self.OpenFileName = self.OpenFileName or ""
	
	local L = ui.getLocale("editwindow-class", "schulze-mueller.de")
	self.Locale = L
	
	self.CursorField = Text:new
	{
		Style = "text-align: left",
		Font = "ui-small",
		MaxWidth = 0,
		Text = "Line: 1 Col: 1",
	}
	
	self.StatusField = ui.ImageWidget:new 
	{ 
		Style = "border-style: inset",
		Mode = "button",
		MinWidth = 20,
		ImageAspectX = 2,
		ImageAspectY = 3,
		MaxWidth = 0,
		Height = "fill",
		Mode = "inert",
	}
	
	self.FilenameField = Text:new
	{
		Style = "text-align: left",
		Font = "ui-small",
		KeepMinWidth = true,
	}
	
	self.EditInput = EditInput:new
	{
		InitialFocus = true,
		Font = "ui-fixed",
		-- Style = "margin: 2",
		LineSpacing = 2,
		FixedFont = true,
		SmoothScroll = false,
		Locale = L,
	}
	
	self.EditCanvas = ui.Canvas:new
	{
		AutoPosition = true,
		-- Style = "border-width: 2; margin: 2",
		UseChildBG = true,
		Child = window.EditInput,
	}
	
	self.EditScrollGroup = ui.ScrollGroup:new
	{
		AcceptFocus = false,
		VSliderMode = "on",
		HSliderMode = "off",
		Child = self.EditCanvas
	}
	
	self.Children = 
	{
		Group:new
		{
			Class = "menubar",
			Children =
			{
				MenuItem:new
				{
					Text = L.MENU_FILE,
					Children =
					{
						MenuItem:new 
						{
							Text = L.MENU_NEW,
							Shortcut = "Ctrl+W",
							onClick = function(self)
								window.EditInput:checkChanges(function()
									window.EditInput:newText()
									window.EditInput:setEditing(true)
								end)
							end
						},
						Spacer:new { },
						MenuItem:new
						{
							Text = L.MENU_OPEN,
							Shortcut = "Ctrl+O",
							onClick = function(self)
								window.EditInput:checkChanges(function()
									window.EditInput:loadRequest()
								end)
							end
						},
						MenuItem:new
						{
							Text = L.MENU_SAVE_AS,
							Shortcut = "Ctrl+S",
							onClick = function(self)
								local editinput = window.EditInput
								self.Application:addCoroutine(function()
									editinput:saveRequest()
								end)
							end
						},
						Spacer:new { },
						MenuItem:new
						{
							Text = L.MENU_QUIT,
							Shortcut = "Ctrl+Q",
							onClick = function(self)
								window.EditInput:checkChanges(function()
									window:quit()
								end)
							end
						}
					}
				},
				MenuItem:new
				{
					Text = L.MENU_EDIT,
					Children =
					{
						MenuItem:new
						{
							Text = L.MENU_DELETE_LINE,
							Shortcut = "Ctrl+K",
							onClick = function(self)
								window.EditInput:deleteLine()
								self.Application:setLastKey()
							end
						}
					}
				},
				MenuItem:new
				{
					Text = L.MENU_OPTIONS,
					Children =
					{
						CheckMark:new 
						{ 
							Text = L.MENU_ACCEL_SCROLL,
							Class = "menuitem",
							Selected = window.EditInput.SmoothScroll,
							onSelect = function(self)
								CheckMark.onSelect(self)
								window.EditInput.SmoothScroll = self.Selected and 3
								window.EditInput:setValue("Focus", true)
							end
						},
						CheckMark:new 
						{ 
							Text = L.MENU_FULLSCREEN,
							Class = "menuitem",
							Selected = window.FullScreen,
							onSelect = function(self)
								CheckMark.onSelect(self)
								window.FullScreen = self.Selected
								window:hide()
							end
						}
					}
				}
			}
		},
		
		self.EditScrollGroup,
		
		Group:new
		{
			Children =
			{
				window.CursorField,
				window.StatusField,
				window.FilenameField,
			}
		}
	}
	
	return Window.new(class, self)
end


function EditWindow:onHide()
	self.EditInput:checkChanges(function()
		self:quit()
	end)
end


function EditWindow:quit()
	self.Running = false
	self.Application:quit()
end

function EditWindow:setup(app, win)
	Window.setup(self, app, win)
	if self.FileName then
		self.EditInput:loadText(self.FileName)
	end
end
