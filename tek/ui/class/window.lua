-------------------------------------------------------------------------------
--
--	tek.ui.class.window
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
--		[[#tek.ui.class.group : Group]] /
--		Window
--
--	OVERVIEW::
--		This class implements a [[#tek.ui.class.group : Group]] which
--		fills up a window on the [[#tek.ui.class.display : Display]].
--
--	ATTRIBUTES::
--		- {{Center [IG]}} (boolean)
--			Instructs the Window to open centered.
--		- {{DblClickJitter [IG]}} (number)
--			Maximum sum of squared pixel deltas (dx² + dy²) between
--			mouse positions to be tolerated for a double click.
--			The default is 70. Large touchscreens require a much larger value.
--		- {{DblClickTimeout [IG]}} (number)
--			Maximum number of microseconds between events to be recognized as
--			a double click. Default: 32000. Use a larger value for
--			touchscreens.
--		- {{FullScreen [IG]}} (boolean)
--			Instructs the Window to open borderless and in fullscreen mode.
--		- {{HideOnEscape [IG]}} (boolean)
--			Instructs the window to invoke the Window:onHide() method
--			when the Escape key is pressed. Default: '''false'''
--		- {{Left [IG]}} (number)
--			The window's left offset on the display, in pixels
--		- {{Modal [IG]}} (boolean)
--			Instructs all other windows to reject input while this window is
--			open.
--		- {{MouseX [G]}} (number)
--		- {{MouseY [G]}} (number)
--			The current window coordinates of the pointing device.
--		- {{Status [ISG]}} (string)
--			Status of the Window, which can be:
--				- {{"initializing"}} - The window is initializing
--				- {{"hide"}} - The window is hidden or about to hide;
--				if you initialize the Window with this value, it will be
--				created in hidden state.
--				- {{"opening"}} - The window is about to open.
--				- {{"show"}} - The window is shown.
--				- {{"closing"}} - The Window is about to hide.
--			Changing this attribute invokes the Window:onChangeStatus()
--			method.
--		- {{Title [IG]}} (string)
--			The window's title
--		- {{Top [IG]}} (number)
--			The window's top offset on the display, in pixels
--
--	IMPLEMENTS::
--		- Window:addInputHandler() - Adds an input handler to the window
--		- Window:addInterval() - Adds an interval timer to the window
--		- Window:checkDblClickTime() - Checks a time for a doubleclick event
--		- Window:clickElement() - Simulates a click on an element
--		- Window:onChangeStatus() - Handler for {{Status}}
--		- Window:onHide() - Handler for when the window is about to be closed
--		- Window:postMsg() - Post an user message in the Window's message queue
--		- Window:remInputHandler() - Removes an input handler from the window
--		- Window:remInterval() - Removes an interval timer from the window
--		- Window:setActiveElement() - Sets the window's active element
--		- Window:setDblClickElement() - Sets the window's doubleclick element
--		- Window:setFocusElement() - Sets the window's focused element
--		- Window:setHiliteElement() - Sets the window's hover element
--		- Window:setMovingElement() - Sets the window's moving element
--
--	OVERRIDES::
--		- Area:hide()
--		- Object.init()
--		- Area:layout()
--		- Area:passMsg()
--		- Area:refresh()
--		- Area:rethinkLayout()
--		- Element:setup()
--		- Area:show()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"

local Drawable = ui.Drawable
local Gadget = ui.Gadget
local Group = ui.Group

local assert = assert
local floor = math.floor
local freeRegion = ui.freeRegion
local insert = table.insert
local max = math.max
local min = math.min
local pairs = pairs
local remove = table.remove
local sort = table.sort
local testflag = ui.testFlag
local type = type
local unpack = unpack

module("tek.ui.class.window", tek.ui.class.group)
_VERSION = "Window 16.0"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local HUGE = ui.HUGE

local NOTIFY_STATUS = { ui.NOTIFY_SELF, "onChangeStatus", ui.NOTIFY_VALUE }

-- Double click time limit, in microseconds:
local DEF_DBLCLICKTIMELIMIT = 320000 -- 600000 for touch screens
-- Max. square pixel distance between clicks:
local DEF_DBLCLICKJITTER = 70 -- 3000 for touch screens

local MSGTYPES = { ui.MSG_CLOSE, ui.MSG_FOCUS, ui.MSG_NEWSIZE, ui.MSG_REFRESH,
	ui.MSG_MOUSEOVER, ui.MSG_KEYDOWN, ui.MSG_MOUSEMOVE, ui.MSG_MOUSEBUTTON,
	ui.MSG_INTERVAL, ui.MSG_KEYUP }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Window = _M

function Window.init(self)
	self.ActiveElement = false
	-- Item in this window in which an active popup is anchored:
	self.ActivePopup = false
	self.CanvasStack = { }
	self.Center = self.Center or false
	self.CopyArea = { }
	self.CopyObjects = { }
	self.DblClickElement = false
	self.DblClickCheckInfo = { } -- check_element, sec, usec, mousex, mousey
	self.DblClickJitter = self.DblClickJitter or DEF_DBLCLICKJITTER
	self.DblClickTimeout = self.DblClickTimeout or DEF_DBLCLICKTIMELIMIT
	self.FocusElement = false
	self.FullScreen = self.FullScreen or ui.FullScreen == "true"
	self.HideOnEscape = self.HideOnEscape or false
	self.HiliteElement = false
	-- Active hold tick counter - number of ticks left to next hold event:
	self.HoldTickActive = 0
	-- Hold tick counter reinitialization (see below):
	self.HoldTickActiveInit = 0
	-- Number of ticks for first hold tick counter initialization:
	self.HoldTickInitFirst = 22
	-- Number of ticks for hold counter repeat initialization:
	self.HoldTickInitRepeat = 7
	self.HoverElement = false
	self.InputHandlers =
	{
		[ui.MSG_CLOSE] = { },
		[ui.MSG_FOCUS] = { },
		[ui.MSG_NEWSIZE] = { },
		[ui.MSG_REFRESH] = { },
		[ui.MSG_MOUSEOVER] = { },
		[ui.MSG_KEYDOWN] = { },
		[ui.MSG_MOUSEMOVE] = { },
		[ui.MSG_MOUSEBUTTON] = { },
		[ui.MSG_INTERVAL] = { },
		[ui.MSG_KEYUP] = { },
	}
	self.IntervalMsg = false
	self.IntervalMsgStore =
	{
		[2] = ui.MSG_INTERVAL,
		[3] = 0,
		[4] = 0,
		[5] = 0,
		[6] = 0,
	}
	self.IntervalNest = 0
	self.KeyShortcuts = { }
	self.LayoutGroup = { }
	self.Left = self.Left or false
	self.Modal = self.Modal or false
	self.MouseX = false
	self.MouseY = false
	self.MouseMoveMsg = false
	self.MouseMoveMsgStore =
	{
		[2] = ui.MSG_MOUSEMOVE,
		[3] = 0,
		[4] = 0,
		[5] = 0,
		[6] = 0,
	}
	self.MovingElement = false
	self.MsgQueue = { }
	self.NewSizeMsg = false
	self.NewSizeMsgStore =
	{
		[2] = ui.MSG_NEWSIZE,
		[3] = 0,
		[4] = 0,
		[5] = 0,
		[6] = 0,
	}
	-- Root window in a cascade of popup windows:
	self.PopupRootWindow = self.PopupRootWindow or false
	self.RefreshMsg = false
	self.RefreshMsgStore =
	{
		[2] = ui.MSG_REFRESH,
		[3] = 0,
		[4] = 0,
		[5] = 0,
		[6] = 0,
	}
	self.Status = self.Status or "initializing"
	self.Title = self.Title or false
	self.Top = self.Top or false
	self.WindowFocus = false
	self.WindowMinMax = { }
	return Group.init(self)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Window:setup(app)
	-- pass ourselves as the window argument:
	Group.setup(self, app, self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Window:show()
	assert(self.Application.Display)
	assert(not self.Drawable)
	local drawable = Drawable:new { Display = self.Application.Display } 
	self.Drawable = drawable
	-- window input handlers must be added before children can
	-- register themselves during show():
	self:addInputHandler(0x171f, self, self.handleInput)
	Group.show(self, drawable)
	-- notification handlers:
	self:addNotify("Status", ui.NOTIFY_ALWAYS, NOTIFY_STATUS)
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Window:hide()
	self:remNotify("Status", ui.NOTIFY_ALWAYS, NOTIFY_STATUS)
	self:remInputHandler(ui.MSG_INTERVAL, self, self.handleHold)
	self:remInputHandler(0x171f, self, self.handleInput)
	local d = self.Drawable
	assert(d)
	self:hideWindow()
	Group.hide(self)
	self.Drawable = false
	d:close()
end

-------------------------------------------------------------------------------
--	addInputHandler(msgtype, object, function): Adds an {{object}} and
--	a {{function}} to the window's chain of handlers for input of the
--	specified type. Multiple input types can be handled by one handler by
--	logically or'ing message types. Input handlers are invoked as follows:
--			message = function(object, message)
--	The handler is expected to return the message, which will in turn pass
--	it on to the next handler in the window's chain.
-------------------------------------------------------------------------------

function Window:addInputHandler(msgtype, object, func)
	local hnd = { object, func }
	for i = 1, #MSGTYPES do
		local mask = MSGTYPES[i]
		local ih = self.InputHandlers[mask]
		if ih then
			if testflag(msgtype, mask) then
				insert(ih, 1, hnd)
				if mask == ui.MSG_INTERVAL and #ih == 1 then
					self:addInterval()
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
--	remInputHandler(msgtype, object, func): Removes an input handler
--	that was previously registered with the window using
--	Window:addInputHandler().
-------------------------------------------------------------------------------

function Window:remInputHandler(msgtype, object, func)
	for i = 1, #MSGTYPES do
		local mask = MSGTYPES[i]
		local ih = self.InputHandlers[mask]
		if ih then
			if testflag(msgtype, mask) then
				for i = 1, #ih do
					local h = ih[i]
					if h[1] == object and h[2] == func then
						remove(ih, i)
						if mask == ui.MSG_INTERVAL and #ih == 0 then
							self:remInterval()
						end
						break
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
--	addInterval(): Adds an interval timer to the window, which will
--	furtheron generate MSG_INTERVAL messages 50 times per second. These
--	messages cause a considerable load to the application, therefore each call
--	to this function should be paired with an matching call to
--	Window:remInterval(), which will cause the interval timer to stop when
--	no clients are needing it anymore.
-------------------------------------------------------------------------------

function Window:addInterval()
	self.IntervalNest = self.IntervalNest + 1
	if self.IntervalNest == 1 then
		db.info("add interval")
		self.Drawable:setInterval(true)
	end
end

-------------------------------------------------------------------------------
--	remInterval(): Decreases the use counter for interval messages and
--	stops sending interval messages to the window when called by the last
--	client that has previously requested an interval timer using
--	Window:addInterval().
-------------------------------------------------------------------------------

function Window:remInterval()
	self.IntervalNest = self.IntervalNest - 1
	assert(self.IntervalNest >= 0)
	if self.IntervalNest == 0 then
		db.info("rem interval")
		self.Drawable:setInterval(false)
	end
end

-------------------------------------------------------------------------------
--	showWindow:
-------------------------------------------------------------------------------

function Window:showWindow()
	self:setValue("Status", "opening")
	self.Application:openWindow(self)
	-- necessary to setup a freeregion:
	self:layout()
	self:setValue("Status", "show")
	self:addLayoutGroup(self, 2)
end

-------------------------------------------------------------------------------
--	hideWindow:
-------------------------------------------------------------------------------

function Window:hideWindow()
	self.Application:closeWindow(self)
	self:setValue("Status", "hide")
	self.FreeRegion = false
end

-------------------------------------------------------------------------------
--	onChangeStatus(status): This method is invoked when the Window's
--	{{Status}} has changed.
-------------------------------------------------------------------------------

function Window:onChangeStatus(showhide)
	if showhide == "show" then
		self.Status = "hide"
		self:showWindow()
	elseif showhide == "hide" then
		self.Status = "show"
		self:hideWindow()
	end
end

-------------------------------------------------------------------------------
--	getWindowDimensions:
-------------------------------------------------------------------------------

function Window:getWindowDimensions()
	local mw, mh = self.MinWidth, self.MinHeight
	self.MinWidth, self.MinHeight = 0, 0
	local m1, m2, m3, m4 = self:askMinMax(0, 0, self.MaxWidth, self.MaxHeight)
	self.MinWidth = mw
	self.MinHeight = mh
	m1, m2 = max(mw, m1), max(mh, m2)
	local x, y, w, h = self.Left, self.Top, self.Width, self.Height
	w = type(w) == "number" and max(w, m1)
	h = type(h) == "number" and max(h, m2)
	m3 = (m3 and m3 > 0 and m3 < HUGE) and m3
	m4 = self.FullScreen and ui.HUGE or (m4 and m4 > 0 and m4 < HUGE) and m4
	w = w or self.MaxWidth == 0 and m1 or w
	h = h or self.MaxHeight == 0 and m2 or h
	return m1, m2, m3, m4, x, y, w, h
end

-------------------------------------------------------------------------------
--	openWindow:
-------------------------------------------------------------------------------

function Window:openWindow()
	if self.Status ~= "show" then
		local m1, m2, m3, m4, x, y, w, h = self:getWindowDimensions()
		if self.Drawable:open(self, self.Title or self.Application.ProgramName,
			w, h, m1, m2, m3, m4, x, y, self.Center, self.FullScreen) then
			local wm = self.WindowMinMax
			wm[1], wm[2], wm[3], wm[4] = m1, m2, m3, m4
			self.Status = "show"
		end
	end
	return self.Status
end

-------------------------------------------------------------------------------
--	closeWindow:
-------------------------------------------------------------------------------

function Window:closeWindow()
	local d = self.Drawable
	assert(d)
	if self.Status ~= "hide" then
		self:setValue("Status", "closing")
		if d:close() then
			self.Width, self.Height = d.Width, d.Height
			self:setValue("Status", "hide")
		end
	end
	return self.Status
end

-------------------------------------------------------------------------------
--	rethinkLayout: overrides
-------------------------------------------------------------------------------

function Window:rethinkLayout()
	if self.Status == "show" then
		local wm = self.WindowMinMax
		local m1, m2, m3, m4 = self:getWindowDimensions()
		if m1 ~= wm[1] or m2 ~= wm[2] or m3 ~= wm[3] or m4 ~= wm[4] then
			wm[1], wm[2], wm[3], wm[4] = m1, m2, m3, m4
			db.trace("New window minmax: %d %d %d %d", m1, m2, m3, m4)
			local w, h = self.Drawable:getAttrs()
			if (m1 and w < m1) or (m2 and h < m2) then
				-- window needs to grow; mark new region as damaged:
				w = max(w, m1 or w)
				h = max(h, m2 or h)
				self:damage(0, 0, w - 1, h - 1)
			end
			self.Drawable:setAttrs { MinWidth = m1, MinHeight = m2,
				MaxWidth = m3, MaxHeight = m4 }
			return true
		end
	end
end

-------------------------------------------------------------------------------
--	getMsg:
-------------------------------------------------------------------------------

function Window:getMsg(msg)
	local m = self.Status == "show" and remove(self.MsgQueue)
	if m then
		msg[-1], msg[0], msg[1], msg[2], msg[3], msg[4], msg[5],
			msg[6], msg[7], msg[8], msg[9], msg[10] = unpack(m, -1, 10)
		return true
	end
end

-------------------------------------------------------------------------------
--	postMsg(msg): This function adds an user message to the Window's message
--	queue.
-------------------------------------------------------------------------------

function Window:postMsg(msg)
	if self.Status == "show" then
		msg[-1] = self
		insert(self.MsgQueue, msg)
	end
end

-------------------------------------------------------------------------------
--	passMsg: overrides
-------------------------------------------------------------------------------

function Window:passMsg(msg)
	local handlers = { unpack(self.InputHandlers[msg[2]]) }
	for i = 1, #handlers do
		local hnd = handlers[i]
		msg = hnd[2](hnd[1], msg)
		if not msg then
			return false
		end
	end
	return msg
end

-------------------------------------------------------------------------------
--	finishPopup:
-------------------------------------------------------------------------------

function Window:finishPopup()
	local w = self.PopupRootWindow or self
	if w.ActivePopup then
		w.ActivePopup:setValue("Selected", false)
	end
end

-------------------------------------------------------------------------------
--	handleInput:
-------------------------------------------------------------------------------

local MsgHandlers =
{
	[ui.MSG_CLOSE] = function(self, msg)
		self:onHide()
		return msg
	end,
	[ui.MSG_FOCUS] = function(self, msg)
		self:setValue("WindowFocus", msg[3] == 1)
		self:setHiliteElement()
		self:setActiveElement()
		return msg
	end,
	[ui.MSG_NEWSIZE] = function(self, msg)
		self:addLayoutGroup(self, 0)
		return msg
	end,
	[ui.MSG_REFRESH] = function(self, msg)
		self:damage(msg[7], msg[8], msg[9], msg[10])
		return msg
	end,
	[ui.MSG_MOUSEOVER] = function(self, msg)
		self.MouseX, self.MouseY = msg[4], msg[5]
		self:setHiliteElement()
		return msg
	end,
	[ui.MSG_MOUSEBUTTON] = function(self, msg)
		self.MouseX, self.MouseY = msg[4], msg[5]
		if msg[3] == 1 then -- leftdown:
			-- send "Pressed" to window:
			self:setValue("Pressed", true, true)
		elseif msg[3] == 2 then -- leftup:
			local ae = self.ActiveElement
			local he = self.HoverElement
			-- release Hold state:
			if ae and ae.Active and ae.Hold and self.HoldTickActive > 0 then
				ae:setValue("Hold", false)
			end
			if not ae and he and he:checkFocus() then
				-- support releasing a button over a popup item that wasn't
				-- activated before, i.e. button was pressed all the time:
				he:setValue("Active", false, true)
			end
			self:setMovingElement()
			self:setActiveElement()
			-- release window:
			self:setValue("Pressed", false, true)
		end
		return msg
	end,
	[ui.MSG_KEYDOWN] = function(self, msg)
		self.MouseX, self.MouseY = msg[4], msg[5]
		-- pass message to active popup element:
		if self.ActivePopup then
			-- return
			db.info("propagating keydown to active popup...")
			msg = self.ActivePopup.PopupWindow:passMsg(msg)
			if not msg then
				return false
			end
		end
		local fe = self.FocusElement
		local key = msg[3]
		-- activate window:
		self:setValue("Active", true)
		if key == 27 then
			local pr = self.PopupRootWindow
			if pr then
				pr.ActivePopup:endPopup()
			elseif self.HideOnEscape then
				self:onHide()
			end
			return
		elseif key == 9 then -- tab key:
			if msg[6] == 0 then -- no qualifier:
				self:setFocusElement(self:getNextElement(fe))
			elseif msg[6] == 1 then -- shift qualifier:
				self:setFocusElement(self:getNextElement(fe, true))
			end
			return
		elseif key == 61459 or key == 61457 then -- cursor down, right:
			self:setFocusElement(self:getNextElement(fe))
			return
		elseif key == 61458 or key == 61456 then -- cursor up, left:
			self:setFocusElement(self:getNextElement(fe, true))
			return
		elseif key == 13 or key == 32 then -- space or enter key:
			if fe and not fe.Active then
				self:setHiliteElement(fe)
				self:setActiveElement(fe)
			end
			return
		end
		-- serve elements with keyboard shortcuts:
		db.trace("keydown: %s - qual: %d", msg[7], msg[6])
		local s = self:getShortcutElements(msg[7], msg[6])
		if s then
			for i = 1, #s do
				local e = s[i]
				if not e.Disabled and e.KeyCode then
					self:setHiliteElement(e)
					self:setFocusElement(e)
					self:setActiveElement(e)
				end
			end
		end
		return msg
	end,
	[ui.MSG_KEYUP] = function(self, msg)
		self.MouseX, self.MouseY = msg[4], msg[5]
		-- pass message to active popup element:
		if self.ActivePopup then
			-- return
			db.info("propagating keyup to active popup...")
			msg = self.ActivePopup.PopupWindow:passMsg(msg)
			if not msg then
				return false
			end
		end
		local key = msg[3]
		if key == 13 or key == 32 then
			self:setActiveElement()
			self:setHiliteElement(self.HoverElement)
		end
		-- serve elements with keyboard shortcuts:
		db.trace("keyup: %s - qual: %d", msg[7], msg[6])
		local s = self:getShortcutElements(msg[7], msg[6])
		if s then
			for i = 1, #s do
				local e = s[i]
				if not e.Disabled and e.KeyCode then
					self:setActiveElement()
				end
			end
			-- self:setHiliteElement(self.HoverElement)
		end
		return msg
	end,
	[ui.MSG_MOUSEMOVE] = function(self, msg)
		self.MouseX, self.MouseY = msg[4], msg[5]
		self.HoverElement = self:getHoverElementByXY(msg[4], msg[5])
		return msg
	end,
}

function Window:handleInput(msg)
	msg = MsgHandlers[msg[2]](self, msg)
	if msg then
		return Group.passMsg(self, msg)
	end
	return false
end

-------------------------------------------------------------------------------
--	getHoverElementByXY: returns the element hovered by the mouse pointer.
-------------------------------------------------------------------------------

function Window:getHoverElementByXY(mx, my)
	local he = self:getElementByXY(mx, my)
	return he and he:checkHover() and he or false
end

-------------------------------------------------------------------------------
--	addLayoutGroup: mark a group for relayout
--	markdamage = 0: do not mark as damaged
--	markdamage = 1: mark as damaged only if coodinates changed
--	markdamage = 2: unconditionally mark as damaged
-------------------------------------------------------------------------------

function Window:addLayoutGroup(group, markdamage)
	if group:getGroup() == group then
		local record = self.LayoutGroup[group]
		if not record then
			record = { group, markdamage }
			self.LayoutGroup[group] = record
			insert(self.LayoutGroup, record)
		elseif markdamage > record[2] then
			-- increase damage level in already existing group:
			record[2] = markdamage
		end
	else
		db.warn("Attempt to relayout non-group: %s", group:getClassName())
	end
end

-------------------------------------------------------------------------------
--	refresh: overrides
-------------------------------------------------------------------------------

local function sortcopies(a, b) return a[1] > b[1] end

local function insertcopy(t, r1, r2, r3, r4, dx, dy, dir)
	insert(t, { (dx == 0 and r2 or r1) * dir, dx, dy, r1, r2, r3, r4 })
end

function Window:refresh()
	-- handle copies:
	local ca = self.CopyArea
	local t = { }
	for key, e in pairs(ca) do
		local dx, dy, region = e[1], e[2], e[3]
		local dir = (dx == 0 and dy or dx) > 0 and 1 or -1
		region:forEach(insertcopy, t, dx, dy, dir)
		freeRegion(region)
		ca[key] = nil
	end
	sort(t, sortcopies)
	local d = self.Drawable
	for i = 1, #t do
		local r = t[i]
		local t = { }
		d:copyArea(r[4], r[5], r[6], r[7], r[4] + r[2], r[5] + r[3], t)
		for i = 1, #t, 4 do
			self:damage(t[i], t[i + 1], t[i + 2], t[i + 3])
		end
	end
	self.CopyObjects = { }
	Group.refresh(self)
end

-------------------------------------------------------------------------------
--	update:
-------------------------------------------------------------------------------

function Window:update()

	if self.Status == "show" then

		if #self.LayoutGroup > 0 then

			-- Handle partial relayouts. Note that new partial relayouts
			-- might be added while we process them

			while #self.LayoutGroup > 0 do
				local lg = self.LayoutGroup
				self.LayoutGroup = { }
				for i = 1, #lg do
					local record = lg[i]
					local group = record[1]
					local markdamage = record[2]
					group:calcWeights()
					local r1, r2, r3, r4 = group:getRect()
					if r1 then
						local m = group.MarginAndBorder
						self:relayout(group, r1 - m[1], r2 - m[2],
							r3 + m[3], r4 + m[4])
					else
						db.info("%s : layout not available",
							group:getClassName())
					end
					if markdamage == 1 then
						group.Redraw = true
					elseif markdamage == 2 then
						group:damage(r1, r2, r3, r4)
					end
				end
			end

			-- mouse could point to a different element now:
			if self.HoverElement then
				self.HoverElement = self:getHoverElementByXY(self.MouseX,
					self.MouseY)
			end

		end

		self:refresh()

	end

	return self.Status == "show"
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function Window:layout(_, _, _, _, markdamage)
	self.FreeRegion = false
	local w, h = self.Drawable:getAttrs()
	return Group.layout(self, 0, 0, w - 1, h - 1, markdamage)
end

-------------------------------------------------------------------------------
--	setHiliteElement(element): Sets/unsets the element which is being
--	hovered by the mouse pointer.
-------------------------------------------------------------------------------

function Window:setHiliteElement(e)
	local he = self.HiliteElement
	if e ~= he then
		if he then
			he:setValue("Hover", false)
		end
		self.HiliteElement = e or false
		if e and not e.Disabled then
			e:setValue("Hover", true)
		end
	end
end

-------------------------------------------------------------------------------
--	setFocusElement(element): Sets/unsets the element which is marked
--	for receiving the keyboard input.
-------------------------------------------------------------------------------

function Window:setFocusElement(e)
	local fe = self.FocusElement
	if e ~= fe then
		if fe then
			fe:setValue("Focus", false)
		end
		self.FocusElement = e or false
		if e then
			e:setValue("Focus", true)
		end
	end
end

-------------------------------------------------------------------------------
--	setActiveElement(element): Sets/unsets the element which is
--	currently active (or 'in use'). If {{element}} is '''nil''', the currently
--	active element will be deactivated.
-------------------------------------------------------------------------------

function Window:setActiveElement(e)
	local se = self.ActiveElement
	if e ~= se then
		if se then
			self:remInputHandler(ui.MSG_INTERVAL, self, self.handleHold)
			se:setValue("Active", false)
		end
		self.ActiveElement = e or false
		if e then
			self.HoldTickActive = self.HoldTickInitFirst
			self.HoldTickActiveInit = self.HoldTickInitFirst
			e:setValue("Active", true)
			self:addInputHandler(ui.MSG_INTERVAL, self, self.handleHold)
		end
	end
end


-------------------------------------------------------------------------------
--	handleHold: use interval messages to decrease a counter for hold events:
-------------------------------------------------------------------------------

function Window:handleHold(msg)
	local ae = self.ActiveElement
	if ae and ae.Active then
		assert(self.HoldTickActive > 0)
		self.HoldTickActive = self.HoldTickActive - 1
		if self.HoldTickActive == 0 then
			self.HoldTickActiveInit = self.HoldTickInitRepeat
			self.HoldTickActive = self.HoldTickInitRepeat
			ae:setValue("Hold", true, true)
		end
	end
	return msg
end

-------------------------------------------------------------------------------
--	dblclick = checkDblClickTime(as, au, bs, bu): Check if the two
--	given times (first a, second b) are within the doubleclick interval.
--	Each time is specified in seconds ({{s}}) and microseconds ({{u}}).
--	Returns '''true''' if the two times are indicative of a double click.
-------------------------------------------------------------------------------

local function subtime(as, au, bs, bu)
	if au < bu then
		return as - bs - 1, 1000000 - bu + au
	end
	return as - bs, au - bu
end

function Window:checkDblClickTime(as, au, bs, bu)
	bs, bu = subtime(bs, bu, as, au)
	return subtime(bs, bu, 0, self.DblClickTimeout) < 0
end

-------------------------------------------------------------------------------
--	setDblClickElement(element): Sets/unsets the element which is
--	candidate for double click detection. If the element is set twice in a
--	sufficiently short period of time and the pointing device did not move
--	too much since the first event, the double click is triggered by
--	notifying the {{DblClick}} attribute in the element. See also
--	[[#tek.ui.class.gadget : Gadget]] for further information.
-------------------------------------------------------------------------------

function Window:setDblClickElement(e)
	local di = self.DblClickCheckInfo
	local de = self.DblClickElement
	if de then
		de:setValue("DblClick", false)
		self.DblClickElement = false
	end
	local d = self.Drawable
	if e and d then
		de = di[1] -- check element
		local ts, tu = d.Display:getTime()
		if de == e and di[4] then
			local d1 = self.MouseX - di[4]
			local d2 = self.MouseY - di[5]
			if self:checkDblClickTime(di[2], di[3], ts, tu) and
				d1 * d1 + d2 * d2 < self.DblClickJitter then
				self.DblClickElement = e
				de:setValue("DblClick", true)
			end
		end
		di[1] = e or false
		di[2] = ts
		di[3] = tu
		di[4] = self.MouseX
		di[5] = self.MouseY
	end
end

-------------------------------------------------------------------------------
--	setMovingElement(element): Sets/unsets the element which is
--	being moved around by the user.
-------------------------------------------------------------------------------

function Window:setMovingElement(e)
	if e ~= self.MovingElement then
		self.MovingElement = e or false
	end
end

-------------------------------------------------------------------------------
--	getParent: overrides
-------------------------------------------------------------------------------

function Window:getParent()
end

-------------------------------------------------------------------------------
--	getSiblings: overrides
-------------------------------------------------------------------------------

function Window:getSiblings()
end

-------------------------------------------------------------------------------
--	getPrev: overrides
-------------------------------------------------------------------------------

function Window:getPrev()
	local c = self:getChildren()
	return c and c[#c]
end

-------------------------------------------------------------------------------
--	getNext: overrides
-------------------------------------------------------------------------------

function Window:getNext()
	local c = self:getChildren()
	return c and c[1]
end

-------------------------------------------------------------------------------
--	getNextElement: Cycles through elements, gets the next element that can
--	receive the focus.
-------------------------------------------------------------------------------

function Window:getNextElement(e, backward)
	local oe = e
	local ne
	repeat
		oe = oe or ne
		if oe then
			local c = e:getChildren()
			if backward then
				ne = c and c[#c] or e:getPrev()
			else
				ne = c and c[1] or e:getNext()
			end
		else
			local c = self:getChildren()
			if backward then
				ne = c and c[#c]
			else
				ne = c and c[1]
			end
		end
		if ne and ne:checkFocus() then
			return ne
		end
		e = ne
	until not e or e == oe
end

-------------------------------------------------------------------------------
--	addKeyShortcut:
-------------------------------------------------------------------------------

function Window:addKeyShortcut(keycode, element)
	local key, quals = ui.resolveKeyCode(keycode)
	db.info("binding shortcut: %s -> %s", key, element:getClassName())
	local keytab = self.KeyShortcuts[key]
	if not keytab then
		keytab = { }
		self.KeyShortcuts[key] = keytab
	end
	for i = 1, #quals do
		local qual = quals[i]
		local qualtab = keytab[qual]
		if not qualtab then
			qualtab = { }
			keytab[qual] = qualtab
		end
		db.trace("%s : adding qualifier %d", key, qual)
		insert(qualtab, element)
	end
end

-------------------------------------------------------------------------------
--	remKeyShortcut:
-------------------------------------------------------------------------------

function Window:remKeyShortcut(keycode, element)
	local key, quals = ui.resolveKeyCode(keycode)
	db.info("removing shortcut: %s -> %s", key, element:getClassName())
	local keytab = self.KeyShortcuts[key]
	if keytab then
		for i = 1, #quals do
			local qual = quals[i]
			local qualtab = keytab[qual]
			if qualtab then
				for idx = 1, #qualtab do
					local e = qualtab[idx]
					if element == e then
						db.trace("%s : removing qualifier %d", key, qual)
						remove(qualtab, idx)
						break
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
--	getShortcutElements:
-------------------------------------------------------------------------------

function Window:getShortcutElements(key, qual)
	local keytab = self.KeyShortcuts[key:lower()]
	return keytab and keytab[qual]
end

-------------------------------------------------------------------------------
--	clickElement(element): This function performs a simulated click on
--	the specified {{element}}; if {{element}} is a string, it will be looked up
--	using Application:getById(). This function is actually a shorthand
--	for Window:setHiliteElement(), followed by Window:setActiveElement() twice
--	(first to enable, then to disable it).
-------------------------------------------------------------------------------

function Window:clickElement(e)
	if type(e) == "string" then
		e = self.Application:getById(e)
		assert(e, "Unknown Id")
	end
	local he = self.HiliteElement
	self:setHiliteElement(e)
	self:setActiveElement(e)
	self:setActiveElement()
	self:setHiliteElement(he)
end

-------------------------------------------------------------------------------
--	onHide(): This handler is invoked when the window's close button
--	is clicked (or the Escape key is pressed and the {{HideOnEscape}} flag
--	is set). The standard behavior is to hide the window by setting the 
--	{{Status}} field to {{"hide"}}. When the last window is closed, the
--	application is closed down.
-------------------------------------------------------------------------------

function Window:onHide()
	self:setValue("Status", "hide")
end
