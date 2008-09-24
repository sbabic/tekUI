-------------------------------------------------------------------------------
--
--	tek.ui.class.popitem
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
--		PopItem
--
--	OVERVIEW::
--		This class provides an anchorage for popups. This also works
--		recursively, i.e. elements of the PopItem class may contain other
--		PopItems as their children. The most notable child class of the
--		PopItem is the [[#tek.ui.class.menuitem : MenuItem]].
--
--	ATTRIBUTES::
--		- {{Children [I]}} (table)
--			Array of child objects - will be connected to the application
--			while the popup is open.
--		- {{Shortcut [IG]}} (string)
--			Keyboard shortcut for the object; unlike
--			[[#tek.ui.class.gadget : Gadget]].KeyCode, this shortcut is
--			also enabled while the object is invisible. By convention, only
--			combinations with a qualifier should be used here, e.g.
--			"Alt+C", "Shift+Ctrl+Q". Qualifiers are separated by "+" and
--			must precede the key. Valid qualifiers are:
--				- "Alt", "LAlt", "RAlt"
--				- "Shift", "LShift", "RShift"
--				- "Ctrl", "LCtrl", "RCtrl"
--				- "IgnoreCase"
--			Alias names for keys are
--				- "F1" ... "F12" (function keys),
--				- "Left", "Right", "Up", "Down" (cursor keys)
--				- "BckSpc", "Tab", "Esc", "Insert", "Overwrite",
--				"PageUp", "PageDown", "Pos1", "End", "Print", "Scroll",
--				and "Pause".
--
--	STYLE PSEUDO CLASSES::
--		- {{popup-root}} - for the root element in a popup tree
--		- {{popup-children}} - for an element that has children
--
--	OVERRIDES::
--		- Element:cleanup()
--		- Object.init()
--		- Gadget:onPress()
--		- Area:passMsg()
--		- Element:setup()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local Application = ui.Application
local PopupWindow = ui.PopupWindow
local Text = ui.Text

local floor = math.floor
local ipairs = ipairs
local max = math.max

module("tek.ui.class.popitem", tek.ui.class.text)
_VERSION = "PopItem 6.0"

-------------------------------------------------------------------------------
--	Constants and class data:
-------------------------------------------------------------------------------

local DEF_POPUPFADEINDELAY = 6
local DEF_POPUPFADEOUTDELAY = 10

local NOTIFY_SUBMENU = { ui.NOTIFY_SELF, "submenu", ui.NOTIFY_VALUE }
local NOTIFY_ONSELECT = { ui.NOTIFY_SELF, "selectPopup" }
local NOTIFY_ONUNSELECT = { ui.NOTIFY_SELF, "unselectPopup" }
local NOTIFY_ONRELEASE = { ui.NOTIFY_SELF, "onPress", false }
local NOTIFY_ONRELEASEITEM = { ui.NOTIFY_SELF, "setValue", "Pressed", false }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local PopItem = _M

function PopItem.init(self)
	self.Children = self.Children or false
	self.EraseBackground = true
	self.Image = self.Image or false
	self.ImageRect = self.ImageRect or false
	self.PopupBase = false
	self.PopupWindow = false
	self.DelayedBeginPopup = false
	self.DelayedEndPopup = false
	self.ShiftX = false
	self.ShiftY = false
	if self.Children then
		self.Mode = "toggle"
		self.FocusNotification = { self, "unselectPopup" }
	else
		self.Mode = "button"
	end
	self.Shortcut = self.Shortcut or false
	return Text.init(self)
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function PopItem:getProperties(p, pclass)
	if not pclass then
		if not self.PopupBase then
			Text.getProperties(self, p, "popup-root")
		elseif self.Children then
			Text.getProperties(self, p, "popup-children")
		end
	end
	Text.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function PopItem:setup(app, window)
	Text.setup(self, app, window)
	if window:getClass() ~= PopupWindow then
		self:connectPopItems(app, window)
	end
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function PopItem:cleanup()
	local app, window = self.Application, self.Window
	if self.Window:getClass() ~= PopupWindow then
		self:disconnectPopItems(self.Window)
	end
	Text.cleanup(self)
	-- restore application and window, as they are needed in
	-- popitems' notification handlers even when they are not visible:
	self.Application, self.Window = app, window
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function PopItem:hide()
	self:unselectPopup()
	Text.hide(self)
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function PopItem:askMinMax(m1, m2, m3, m4)
	local n1, n2, n3, n4 = Text.askMinMax(self, m1, m2, m3, m4)
	if self.Image then
		local p = self.Padding
		local m = self.MarginAndBorder
		local d = self.Drawable
		local ih = n2 - m2 - p[2] - p[4] - m[2] - m[4]
		local iw = ih * d.AspectX / d.AspectY -- image width
		n1 = n1 + iw
		n3 = n3 + iw
	end
	return n1, n2, n3, n4
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function PopItem:layout(x0, y0, x1, y1, markdamage)
	if Text.layout(self, x0, y0, x1, y1, markdamage) then
		if self.Image then
			local r = self.Rect
			local p = self.Padding
			local ih = r[4] - r[2] - p[4] - p[2] + 1
			local d = self.Drawable
			local iw = ih * d.AspectX / d.AspectY
			-- use half the padding that was granted for the right edge:
			local x = r[3] - floor(p[3] / 2) - iw
			local y = r[2] + p[2]
			local i = self.ImageRect
			i[1], i[2], i[3], i[4] = x, y, x + iw - 1, y + ih - 1
		end
		return true
	end
end

-------------------------------------------------------------------------------
--	refresh: overrides
-------------------------------------------------------------------------------

function PopItem:refresh()
	--	Store the item's absolute coordinates (needed if the popitem
	--	rests in a canvas):
	self.ShiftX, self.ShiftY = self.Drawable:getShift()
	return Text.refresh(self)
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function PopItem:draw()
	self:erase()
	local i = self.Image
	if i then
		local d = self.Drawable
		local r = self.Rect
		local ir = self.ImageRect
		d:pushClipRect(r[1], r[2], ir[1], r[4])
		Text.draw(self)
		d:popClipRect()
		i.ImageData.Primitives[1].Pen = self.Foreground
		i:draw(d, self.ImageRect)
	else
		Text.draw(self)
	end
end

-------------------------------------------------------------------------------
--	calcPopup:
-------------------------------------------------------------------------------

function PopItem:calcPopup()
	local _, _, x, y = self.Drawable:getAttrs()
	local w
	local r = self.Rect
	local sx, sy = self.ShiftX, self.ShiftY
	if self.PopupBase then
		x =	x + r[3] + sx
		y = y + r[2] + sy
	else
		x =	x + r[1] + sx
		y = y + r[4] + sy
		w = r[3] - r[1] + 1
	end
	return x, y, w
end

-------------------------------------------------------------------------------
--	beginPopup:
-------------------------------------------------------------------------------

function PopItem:beginPopup()

	local winx, winy, winw, winh = self:calcPopup()

	if self.Window.ActivePopup then
		db.info("Killed active popup")
		self.Window.ActivePopup:endPopup()
	end

	-- prepare children for being used in a popup window:
	for _, c in ipairs(self.Children) do
		c:init()
		c.Selected = false
		c.Focus = false
		if c:checkDescend(PopItem) then
			c.PopupBase = self.PopupBase or self
		end
		-- c:setState()
	end

	self.PopupWindow = PopupWindow:new
	{
		-- window in which the popup cascade is rooted:
		PopupRootWindow = self.Window.PopupRootWindow or self.Window,
		-- item in which this popup window is rooted:
		PopupBase = self.PopupBase or self,
		Children = self.Children,
		Orientation = "vertical",
		Left = winx,
		Top = winy,
		Width = winw,
		Height = winh,
	}

	-- connect children recursively:
	Application.connect(self.PopupWindow)

	self.Window.ActivePopup = self

	self.Application:addMember(self.PopupWindow)

	self.PopupWindow:setValue("Status", "show")

	self.Window:addNotify("Status", "hide", self.FocusNotification)
	self.Window:addNotify("WindowFocus", ui.NOTIFY_CHANGE,
		self.FocusNotification)

end

-------------------------------------------------------------------------------
--	endPopup:
-------------------------------------------------------------------------------

function PopItem:endPopup()
	self:setValue("Selected", false, false) -- must not invoke notification!
	self:setValue("Focus", false)
	self:setState()
	self.Window:remNotify("WindowFocus", ui.NOTIFY_CHANGE,
		self.FocusNotification)
	self.Window:remNotify("Status", "hide", self.FocusNotification)
	self.PopupWindow:setValue("Status", "hide")
	self.Application:remMember(self.PopupWindow)
	self.Window.ActivePopup = false
	self.PopupWindow = false
end

-------------------------------------------------------------------------------
--	unselectPopup:
-------------------------------------------------------------------------------

function PopItem:unselectPopup()
	db.trace("unselectpopup: %s", self:getClassName())
	if self.PopupWindow then
		self:endPopup()
		self.Window:setActiveElement()
	end
end

function PopItem:passMsg(msg)
	if msg[2] == ui.MSG_MOUSEBUTTON then
		if msg[3] == 1 then -- leftdown:
			if self.PopupWindow and self.Window.ActiveElement ~= self and
				not self.PopupBase and self.Window.HoverElement == self then
				self:endPopup()
				-- swallow event, don't let ourselves get reactivated:
				return false
			end
		elseif msg[3] == 2 then -- leftup:
			if self.PopupWindow and self.Window.HoverElement ~= self and
				not self.Disabled then
				self:endPopup()
			end
		end
	end
	return Text.passMsg(self, msg)
end


function PopItem:submenu(val)
	-- check if not the baseitem:
	if self.PopupBase then
		self.Window.DelayedBeginPopup = false
		if val == true then
			if not self.PopupWindow then
				db.trace("Begin beginPopup delay")
				self.Window.BeginPopupTicks = DEF_POPUPFADEINDELAY
				self.Window.DelayedBeginPopup = self
			elseif self.Window.DelayedEndPopup == self then
				self.Window.DelayedEndPopup = false
			end
		elseif val == false and self.PopupWindow then
			db.trace("Begin endPopup delay")
			self.Window.BeginPopupTicks = DEF_POPUPFADEOUTDELAY
			self.Window.DelayedEndPopup = self
		end
	end
end

-------------------------------------------------------------------------------
--	selectPopup:
-------------------------------------------------------------------------------

function PopItem:selectPopup()
	if self.Children then
		if not self.PopupWindow then
			self:beginPopup()
		end
		if self.PopupBase then
			self.Selected = false
			self.Redraw = true
		end
	end
end

-------------------------------------------------------------------------------
--	onPress:
-------------------------------------------------------------------------------

function PopItem:onPress(pressed)
	if not pressed and self.PopupBase then
		-- unselect base item, causing the tree to collapse:
		self.PopupBase:setValue("Selected", false)
	end
end

-------------------------------------------------------------------------------
--	connectPopItems:
-------------------------------------------------------------------------------

function PopItem:connectPopItems(app, window)
	if self:checkDescend(PopItem) then
		db.info("adding %s", self:getClassName())
		local c = self:getElement("children")
		if c then
			self:addNotify("Hilite", ui.NOTIFY_CHANGE, NOTIFY_SUBMENU)
			self:addNotify("Selected", true, NOTIFY_ONSELECT)
			self:addNotify("Selected", false, NOTIFY_ONUNSELECT)
			for _, child in ipairs(c) do
				connectPopItems(child, app, window)
			end
		else
			if self.Shortcut then
				window:addKeyShortcut("IgnoreCase+" .. self.Shortcut, self)
			end
			self.Application = app
			self.Window = window
			self:addNotify("Active", false, NOTIFY_ONRELEASEITEM)
			self:addNotify("Pressed", false, NOTIFY_ONRELEASE)
		end
	end
end

-------------------------------------------------------------------------------
--	disconnectPopItems:
-------------------------------------------------------------------------------

function PopItem:disconnectPopItems(window)
	if self:checkDescend(PopItem) then
		db.info("removing popitem %s", self:getClassName())
		local c = self:getElement("children")
		if c then
			for _, child in ipairs(c) do
				disconnectPopItems(child, window)
			end
			self:remNotify("Selected", false, NOTIFY_ONUNSELECT)
			self:remNotify("Selected", true, NOTIFY_ONSELECT)
			self:remNotify("Hilite", ui.NOTIFY_CHANGE, NOTIFY_SUBMENU)
		else
			if self.Shortcut then
				window:remKeyShortcut(self.Shortcut, self)
			end
			self:remNotify("Pressed", false, NOTIFY_ONRELEASE)
			self:remNotify("Active", false, NOTIFY_ONRELEASEITEM)
		end
	end
end

-------------------------------------------------------------------------------
--	getElement: overrides
-------------------------------------------------------------------------------

function PopItem:getElement(mode)
	if mode == "children" then
		return self.Children
	end
	return Text.getElement(self, mode)
end
