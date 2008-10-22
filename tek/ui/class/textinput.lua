-------------------------------------------------------------------------------
--
--	tek.ui.class.textinput
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		[[#tek.ui.class.frame : Frame]] /
--		[[#tek.ui.class.gadget : Gadget]] /
--		[[#tek.ui.class.text : Text]] /
--		TextInput
--
--	OVERVIEW::
--		This class implements a gadget for editing and entering text.
--
--	ATTRIBUTES::
--		- {{Enter [ISG]}} - Text that is being 'entered' (by pressing the
--		return key) into the TextInput field.
--
--	STYLE PROPERTIES::
--		- {{cursor-background-color}}
--		- {{cursor-color}}
--
--	IMPLEMENTS::
--		- TextInput:onEnter() - Handler invoked when {{Enter}} ist set
--		- TextInput:setCursor() - Set cursor position
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Element:cleanup()
--		- Area:draw()
--		- Element:hide()
--		- Object.init()
--		- Frame:onFocus()
--		- Gadget:onSelect()
--		- Text:onSetText()
--		- Area:passMsg()
--		- Area:setState()
--		- Element:setup()
--		- Element:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"

local Area = ui.Area
local Display = ui.Display
local Gadget = ui.Gadget
local Text = ui.Text
local UTF8String = require "tek.class.utf8string"

local char = string.char
local floor = math.floor
local min = math.min
local max = math.max
local unpack = unpack

module("tek.ui.class.textinput", tek.ui.class.text)
_VERSION = "TextInput 6.0"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_ENTER = { ui.NOTIFY_SELF, "onEnter", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local TextInput = _M

function TextInput.init(self)
	self.FGPenCursor = false
	self.BGPenCursor = false
	self.BlinkState = false
	self.BlinkTick = false
	self.BlinkTickInit = false
	self.Editing = false
	self.Enter = false
	self.FHeight = false
	self.FontSpec = self.FontSpec or false
	self.FWidth = false
	self.Text = self.Text or ""
	self.TextBuffer = UTF8String:new(self.Text)
	self.Mode = "touch"
	self.ShortcutMark = false
	-- cursor position in characters:
	self.TextCursor = self.TextCursor or self.TextBuffer:len() + 1
	-- character offset in displayed text:
	self.TextOffset = false
	-- rectangle of text:
	self.TextRect = false
	-- max. visible width in characters:
	self.TextWidth = false
	return Text.init(self)
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function TextInput:getProperties(p, pclass)
	self.FGPenCursor = self:getProperty(p, pclass, "cursor-color")
	self.BGPenCursor = self:getProperty(p, pclass, "cursor-background-color")
	Text.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function TextInput:setup(app, window)
	Text.setup(self, app, window)
	self:addNotify("Enter", ui.NOTIFY_ALWAYS, NOTIFY_ENTER)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function TextInput:cleanup()
	self:remNotify("Enter", ui.NOTIFY_ALWAYS, NOTIFY_ENTER)
	Text.cleanup(self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function TextInput:show(display, drawable)
	if Text.show(self, display, drawable) then
		self.FWidth, self.FHeight =
			Display:getTextSize(self.TextRecords[1][2], " ")
		self.TextRect = { }
		self.TextOffset = 0
		self.BlinkTick = 0
		self.BlinkTickInit = 18
		return true
	end
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function TextInput:hide()
	Text.hide(self)
	self.TextOffset = 0
	self.TextCursor = 0
	self.TextRect = false
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function TextInput:askMinMax(m1, m2, m3, m4)
	local w, h = self.FWidth * 2, self.FHeight -- +1 char for cursor
	m1 = m1 + w + 1 -- +1 for disabled state
	m2 = m2 + h + 1
	m3 = m3 + w + 1
	m4 = m4 + h + 1
	return Gadget.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function TextInput:draw()

	local r = self.Rect
	local d = self.Drawable
	local pens = d.Pens

	local tr = self.TextRect
	local to = self.TextOffset
	local tc = self.TextCursor

	local text = self.TextRecords[1]
	d:setFont(text[2])

	local fw, fh = self.FWidth, self.FHeight
	local p = self.Padding
	local w = r[3] - r[1] + 1 - p[1] - p[3]
	local h = r[4] - r[2] + 1 - p[2] - p[4]

	-- total len of text, in characters:
	local len = self.TextBuffer:len()

	-- max. visible width in characters:
	local tw = floor(w / fw)

	if tc >= tw then
		to = to + (tc - tw + 1)
		tc = tw - 1
	end
	tc = min(tc, len - to)

	self.TextWidth = tw
	self.TextOffset = to
	self.TextCursor = tc

	-- total len of text, including space required for cursor:
	local clen = len
	if to + tc >= len then
		clen = clen + 1
	end

	-- actual visible TextWidth (including cursor) in characters:
	local twc = min(tw, clen)

	-- actual visible TextWidth in pixels:
	tw = twc * fw

	-- the visible text:
	text = self.TextBuffer:sub(to + 1, to + twc)

	-- visible text rect, left aligned:
	tr[1] = r[1] + p[1] -- centered: + (w - tw) / 2
	tr[2] = r[2] + p[2] + floor((h - fh) / 2)
	tr[3] = tr[1] + tw - 1
	tr[4] = tr[2] + fh - 1

	local x, y = tr[1], tr[2]

	local tpen = pens[self.Foreground]

	self:erase()

	if self.Disabled then
		local tpen2 = d.Pens[self.FGPenDisabled2 or ui.PEN_DISABLEDDETAIL2]
		d:drawText(x + 1, y + 1, text, tpen2)
	end
	d:drawText(x, y, text, tpen)
	if not self.Disabled and self.Editing then
		local s = self.TextBuffer:sub(tc + to + 1, tc + to + 1)
		s = s == "" and " " or s
		if self.BlinkState == 1 then
			d:drawText(tr[1] + tc * fw, tr[2], s,
				pens[self.FGPenCursor or ui.PEN_CURSORDETAIL],
				pens[self.BGPenCursor or ui.PEN_CURSOR])
		else
			d:drawText(tr[1] + tc * fw, tr[2], s, tpen)
		end
	end
end

-------------------------------------------------------------------------------
--	clickMouse: internal
-------------------------------------------------------------------------------

function TextInput:clickMouse(x, y)
	if x and y then
		local tr, tc = self.TextRect, self.TextCursor
		local fw, fh = self.FWidth, self.FHeight
		if x >= tr[1] and x <= tr[3] and y >= tr[2] and y <= tr[4] then
			tc = floor((x - tr[1]) / fw)
		elseif x < tr[1] then
			tc = 0
		elseif x > tr[3] then
			tc = floor((tr[3] - tr[1]) / fw) + 1
		end
		if tc ~= self.TextCursor then
			self.TextCursor = tc
			self.BlinkTick = 0
			self.BlinkState = 0
		end
	end
end

-------------------------------------------------------------------------------
--	setEditing: internal
-------------------------------------------------------------------------------

function TextInput:setEditing(onoff)
	if onoff and not self.Editing then
		self.Editing = true
		self.Window:addInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
		self.Window:addInputHandler(ui.MSG_KEYUP + ui.MSG_KEYDOWN,
			self, self.handleInput)
		self:clickMouse()
		self:setValue("Focus", true)
	elseif not onoff and self.Editing then
		self:setValue("Selected", false)
		self.Window:remInputHandler(ui.MSG_KEYUP + ui.MSG_KEYDOWN,
			self, self.handleInput)
		self.Window:remInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
		self.Editing = false
	end
end

-------------------------------------------------------------------------------
--	onSelect: overrides
-------------------------------------------------------------------------------

function TextInput:onSelect(selected)
	self:setEditing(selected)
	Text.onSelect(self, selected)
end

-------------------------------------------------------------------------------
--	onFocus: overrides
-------------------------------------------------------------------------------

function TextInput:onFocus(focused)
	if not focused then
		-- auto unselect with lost focus:
		self:setEditing(focused)
	end
	Text.onFocus(self, focused)
end

function TextInput:updateInterval(msg)
	self.BlinkTick = self.BlinkTick - 1
	if self.BlinkTick < 0 then
		self.BlinkTick = self.BlinkTickInit
		local bs = ((self.BlinkState == 1) and 0) or 1
		if bs ~= self.BlinkState then
			self.BlinkState = bs
			self.Redraw = true
		end
	end
	return msg
end

local function crsrleft(self)
	self.TextCursor = self.TextCursor - 1
	if self.TextCursor < 0 then
		self.TextCursor = 0
		if self.TextOffset > 0 then
			self.TextOffset = self.TextOffset - 1
		else
			return false
		end
	end
	return true
end

local function crsrright(self)
	self.TextCursor = self.TextCursor + 1
	if self.TextCursor >= self.TextWidth then
		self.TextCursor = self.TextWidth - 1
		if self.TextOffset < self.TextBuffer:len() - self.TextWidth + 1 then
			self.TextOffset = self.TextOffset + 1
		else
			return false
		end
	end
	return true
end

-------------------------------------------------------------------------------
--	msg = passMsg(msg)
-------------------------------------------------------------------------------

function TextInput:passMsg(msg)
	local win = self.Window
	if win then
		if msg[2] == ui.MSG_MOUSEBUTTON then
			if msg[3] == 1 then -- leftdown:
				if win.HoverElement == self and not self.Disabled then
					self:clickMouse(msg[4], msg[5])
				end
			end
		end
	end
	return Text.passMsg(self, msg)
end

-------------------------------------------------------------------------------
--	self:setCursor(pos): Set cursor position, absolute
-------------------------------------------------------------------------------

function TextInput:setCursor(tc)
	local to = self.TextOffset
	local tw = self.TextWidth
	local len = self.TextBuffer:len()
	if tc >= tw + to then
		to = to + (tc - tw + 1)
		to = min(to, len - 1)
		tc = tw - 1
	end
	tc = min(tc, len - to)
	self.TextOffset = to
	self.TextCursor = tc
end

-------------------------------------------------------------------------------
--	msg = handleInput(msg)
-------------------------------------------------------------------------------

function TextInput:handleInput(msg)
	if self.Editing then
		if msg[2] == ui.MSG_KEYDOWN then
			local code = msg[3]
			local utf8code = msg[7]
			local t = self.TextBuffer
			local to = self.TextOffset
			local tc = self.TextCursor
			while true do
				if code == 0xf010 then
					crsrleft(self)
				elseif code == 0xf011 then
					crsrright(self)
				elseif code == 0xf012 then
					-- up
				elseif code == 0xf013 then
					-- down
				elseif code == 8 then -- backspace:
					if crsrleft(self) then
						t:erase(to + tc, to + tc)
					end
				elseif code == 127 then -- del:
					if t:len() > 0 then
						t:erase(to + tc + 1, to + tc + 1)
					end
				elseif code == 13 then
					self:setEditing(false)
					self:setValue("Text", t:get())
					self:setValue("Enter", t:get())
					return false
				elseif code == 27 then
					self:setEditing(false)
					return false
				elseif code == 0xf025 then -- pos1
					self.TextCursor = 0
					self.TextOffset = 0
				elseif code == 0xf026 then -- posend
					self:setCursor(self.TextBuffer:len() + 1)
				elseif code > 31 and code < 256 then
					t:insert(utf8code, to + tc + 1)
					crsrright(self)
				else
					break
				end
				-- something changed:
				self.BlinkTick = 0
				self.BlinkState = 0
				self.Text = t:get() -- make the updated text available
				return false
			end
		elseif msg[2] == ui.MSG_KEYUP then
			-- swallow this key event:
			return false
		end
	end
	return msg
end

-------------------------------------------------------------------------------
--	onSetText: overrides
-------------------------------------------------------------------------------

function TextInput:onSetText(text)
	-- intercept notification and do not pass the control back
	-- to Text, as it performs a rethinkLayout() on text changes
	self:makeTextRecords(text)
	self.TextBuffer = UTF8String:new(text)
	self.TextOffset = 0 -- TODO
	self.Redraw = true
end

-------------------------------------------------------------------------------
--	onEnter(text): This method is called when the {{Enter}} attribute is
--	set. It can be overridden for reacting on entering text by pressing
--	the return key. This method also sets the {{Text}} attribute (see
--	[[#tek.ui.class.text : Text]]).
-------------------------------------------------------------------------------

function TextInput:onEnter(text)
	self:setValue("Text", text)
end
