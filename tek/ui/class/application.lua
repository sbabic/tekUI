-------------------------------------------------------------------------------
--
--	tek.ui.class.application
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.ui.class.family : Family]] /
--		Application
--
--	OVERVIEW::
--		This class implements the framework's entrypoint and main loop.
--
--	MEMBERS::
--		- {{ApplicationId [IG]}}
--			Name of the application, normally used as an unique identifier
--			in combination with the {{VendorDomain}} attribute. Default is
--			"unknown".
--		- {{Author [IG]}}
--			Name of the application's author(s)
--		- {{Copyright [IG]}}
--			Copyright notice applying to the application
--		- {{ProgramName [IG]}}
--			Name of the application, as displayed to the user. This is
--			also the fallback for the {{Title}} attribute.
--		- {{Status [G]}}
--			Status of the application, can be "connected", "connecting",
--			"disconnected", "disconnecting", "initializing", "error",
--			"running".
--		- {{ThemeName [IG]}}
--			Name of a theme, which usually maps to an equally named
--			style sheet file (with the extension ".css") in the file system.
--			Themes with reserved meaning are:
--				- "internal": Uses the hardcoded internal style properties
--				and does not try to load a style sheet file.
--				- "desktop": Tries to import the desktop's color scheme
--				(besides trying to load a style sheet named "desktop.css").
--		- {{Title [IG]}}
--			Title of the application, which will also be inherited by Window
--			objects; if unspecified, {{ProgramName}} will be used.
--		- {{VendorDomain [IG]}}
--			An uniquely identifying domain name of the vendor, organization
--			or author manufacturing the application, preferrably without
--			domain parts like "www.", if they are nonsignificant for
--			identification. Default is "unknown".
--		- {{VendorName [IG]}}
--			Name of the vendor or organization responsible for producing
--			the application, as displayed to the user.
--
--	NOTES::
--		The {{VendorDomain}} and {{ApplicationId}} attributes are
--		UTF-8 encoded strings, so any international character sequence is
--		valid for them. Anyhow, it is recommended to avoid too adventurous
--		symbolism, as its end up in a hardly decipherable, UTF8- plus
--		URL-encoded form in the file system, e.g. for loading catalog files
--		under {{tek/ui/locale/<vendordomain>/<applicationid>}}.
--
--	IMPLEMENTS::
--		- Application:addCoroutine() - adds a coroutine to the application
--		- Application:connect() - connects children recursively
--		- Application:easyRequest() - opens a message box
--		- Application:getElementById() - returns an element by Id
--		- Application:run() - runs the application
--		- Application:suspend() - suspends the caller's coroutine
--		- Application:requestFile() - opens a file requester
--
--	OVERRIDES::
--		- Family:addMember()
--		- Object.init()
--		- Class.new()
--		- Family:remMember()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"

local Display = ui.Display
local Family = ui.Family
local Group = ui.Group
local Window = ui.Window

local assert = assert
local cocreate = coroutine.create
local collectgarbage = collectgarbage
local coresume = coroutine.resume
local corunning = coroutine.running
local costatus = coroutine.status
local coyield = coroutine.yield
local insert = table.insert
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs
local remove = table.remove
local select = select
local traceback = debug.traceback
local unpack = unpack

module("tek.ui.class.application", tek.ui.class.family)
_VERSION = "Application 10.1"

-------------------------------------------------------------------------------
--	class implementation:
-------------------------------------------------------------------------------

local Application = _M

function Application.new(class, self)
	self = Family.new(class, self)
	self.MsgDispatch =
	{
		[ui.MSG_CLOSE] = self.passMsgNoModal,
		[ui.MSG_FOCUS] = self.passMsgAlways,
		[ui.MSG_NEWSIZE] = self.passMsgNewSize,
		[ui.MSG_REFRESH] = self.passMsgRefresh,
		[ui.MSG_MOUSEOVER] = self.passMsgNoModal,
		[ui.MSG_KEYDOWN] = self.passMsgNoModal,
		[ui.MSG_MOUSEMOVE] = self.passMsgNoModal,
		[ui.MSG_MOUSEBUTTON] = self.passMsgNoModal,
		[ui.MSG_INTERVAL] = self.passMsgAlways,
		[ui.MSG_KEYUP] = self.passMsgNoModal,
	}
	-- Check linkage of members and connect them recursively:
	if self:connect() then
		self.Status = "disconnected"
		self.Display = self.Display or Display:new { }
		self:decodeProperties()
		self:setup()
		self:show(self.Display)
	else
		db.error("Could not connect elements")
		self.Status = "error"
	end
	return self
end

function Application.init(self)
	self.Application = self
	self.ApplicationId = self.ApplicationId or "unknown"
	self.Author = self.Author or false
	self.Copyright = self.Copyright or false
	self.Coroutines = { }
	self.Display = false
	self.ElementById = { }
	self.ModalWindows = { } -- stack of
	self.MsgDispatch = false
	self.OpenWindows = { }
	self.ProgramName = self.ProgramName or self.Title or false
	self.Status = "initializing"
	self.Title = self.Title or self.ProgramName or false
	self.ThemeName = self.ThemeName or "desktop"
	self.VendorName = self.VendorName or "unknown"
	self.VendorDomain = self.VendorDomain or "unknown"
	self.Properties = { ui.Theme.getStyleSheet("internal") }
	if self.ThemeName and self.ThemeName ~= "internal" then
		local s = ui.prepareProperties(ui.Theme.getStyleSheet(self.ThemeName))
		if s then
			insert(self.Properties, 1, s)
		end
	end
	return Family.init(self)
end

-------------------------------------------------------------------------------
--	Application:connect(parent): Checks member linkage and connects all
--	children by invoking their [[connect()][#Element:connect]]
--	methods. Note that unlike Element:connect(), this function is recursive.
-------------------------------------------------------------------------------

function Application:connect(parent)
	local c = self:getElement("children")
	if c then
		for _, child in ipairs(c) do
			if child:checkDescend(Group) then
				-- descend into group:
				if not connect(child, self) then
					return false
				end
			else
				if not child:connect(self, parent) then
					db.error("Connection failed: %s <- %s",
						self:getClassName(), child:getClassName())
					return false
				end
			end
		end
		if parent then
			return self:connect(parent)
		end
		return true
	else
		db.info("%s : has no children", self:getClassName())
	end
end

-------------------------------------------------------------------------------
--	addMember: overrides
-------------------------------------------------------------------------------

function Application:addMember(child, pos)
	self:decodeProperties(child)
	child:setup(self, child)
	if child:show(self.Display) then
		if Family.addMember(self, child, pos) then
			return child
		end
		child:hide()
	end
	child:cleanup()
end

-------------------------------------------------------------------------------
--	remMember: overrides
-------------------------------------------------------------------------------

function Application:remMember(child)
	assert(child.Parent == self)
	Family.remMember(self, child)
	child:hide()
	child:cleanup()
end

-------------------------------------------------------------------------------
-- 	addElement:
-------------------------------------------------------------------------------

function Application:addElement(e)
	assert(not self.ElementById[e.Id], ("Id '%s' already exists"):format(e.Id))
	self.ElementById[e.Id] = e
end

-------------------------------------------------------------------------------
-- 	remElement:
-------------------------------------------------------------------------------

function Application:remElement(e)
	assert(self.ElementById[e.Id])
	self.ElementById[e.Id] = nil
end

-------------------------------------------------------------------------------
-- 	element = Application:getElementById(): Returns the element that was
--	registered with the Application under its unique {{Id}}. Returns
--	'''nil''' if the Id was not found.
-------------------------------------------------------------------------------

function Application:getElementById(Id)
	return self.ElementById[Id]
end

-------------------------------------------------------------------------------
--	decodeProperties:
-------------------------------------------------------------------------------

function Application:decodeProperties(child)
	local app = self.Application
	for _, p in ipairs(self.Properties) do
		self.Display:decodeProperties(p)
		if child then
			child:decodeProperties(p)
		else
			for _, child in ipairs(self.Children) do
				child:decodeProperties(p)
			end
		end
	end
end

-------------------------------------------------------------------------------
--	setup: internal
-------------------------------------------------------------------------------

function Application:setup()
	if self.Status == "disconnected" then
		self.Status = "connecting"
		for _, child in ipairs(self.Children) do
			child:setup(self, child)
		end
		self.Status = "connected"
	end
end

-------------------------------------------------------------------------------
--	cleanup: internal
-------------------------------------------------------------------------------

function Application:cleanup()
	assert(self.Status == "connected")
	self.Status = "disconnecting"
	for _, child in ipairs(self.Children) do
		child:cleanup()
	end
	self.Status = "disconnected"
end

-------------------------------------------------------------------------------
--	show: internal
-------------------------------------------------------------------------------

function Application:show(display)
	self.Display = display
	for _, w in ipairs(self.Children) do
		w:show(display)
	end
	return true
end

-------------------------------------------------------------------------------
--	hide: internal
-------------------------------------------------------------------------------

function Application:hide()
	for _, w in ipairs(self.Children) do
		w:hide()
	end
	self.Display = nil
end

-------------------------------------------------------------------------------
--	openWindow: internal
-------------------------------------------------------------------------------

function Application:openWindow(window)
	local status = window.Status
	if status ~= "show" then
		status = window:openWindow()
		if status == "show" then
			if window.Modal then
				insert(self.ModalWindows, 1, window)
			end
			insert(self.OpenWindows, window)
		end
	end
	return status
end

-------------------------------------------------------------------------------
--	closeWindow: internal
-------------------------------------------------------------------------------

function Application:closeWindow(window)
	local status = window.Status
	if status ~= "hide" then
		status = window:closeWindow()
		if window == self.ModalWindows[1] then
			remove(self.ModalWindows, 1)
		end
		-- NOTE: windows are purged from OpenWindows list during wait()
	end
	return status
end

-------------------------------------------------------------------------------
--	showWindow: make a window visible.
--	if no window is specified, show all windows that aren't of Status "hide"
-------------------------------------------------------------------------------

function Application:showWindow(window)
	if window then
		window:showWindow()
	else
		for _, window in ipairs(self.Children) do
			if window.Status ~= "hide" then
				window:showWindow()
			end
		end
	end
end

-------------------------------------------------------------------------------
--	hideWindow: hide a window. if no window is specified, hide all windows.
-------------------------------------------------------------------------------

function Application:hideWindow(window)
	if window then
		return window:hideWindow()
	else
		for _, window in ipairs(self.Children) do
			window:hideWindow()
		end
	end
end

-------------------------------------------------------------------------------
-- 	Message handlers: passAlways() passes a message always, passMsgNoModal()
--	passes a message only to the modal window (if there is one),
--	passMsgNewSize() bundles new sizes, passMsgRefresh() bundles damages for
--	the current window.
-------------------------------------------------------------------------------

function Application:passMsgAlways(win, msg)
	win:passMsg(msg)
end

function Application:passMsgNoModal(win, msg)
	local mw = self.ModalWindows[1]
	if not mw or mw == win then
		win:passMsg(msg)
	end
end

function Application:passMsgNewSize(win, msg)
	-- bundle newsizes:
	local newsize = win.NewSizeMsg
	if not newsize then
		newsize = win.NewSizeMsgStore
		win.NewSizeMsg = newsize
	else
	end
	newsize[0] = msg[0] -- update timestamp
	newsize[1] = msg[1]
end

function Application:passMsgRefresh(win, msg)
	-- bundle damage rects:
	local refresh = win.RefreshMsg
	if not refresh then
		refresh = win.RefreshMsgStore
		win.RefreshMsg = refresh
		refresh[7] = msg[7]
		refresh[8] = msg[8]
		refresh[9] = msg[9]
		refresh[10] = msg[10]
	else
		refresh[7] = min(refresh[7], msg[7])
		refresh[8] = min(refresh[8], msg[8])
		refresh[9] = max(refresh[9], msg[9])
		refresh[10] = max(refresh[10], msg[10])
	end
	refresh[0] = msg[0] -- update timestamp
	refresh[1] = msg[1]
end

-------------------------------------------------------------------------------
-- 	success, status = Application:run(): Runs the application. Returns when
--	all child windows are closed or when the application's {{Status}} is set
--	to "quit".
-------------------------------------------------------------------------------

function Application:run()

	-- assert(self.Status == "connected", "Application not in connected state")

	-- open all windows that aren't in "hide" state:
	self:showWindow()

	self.Status = "running"

	local d = self.Display
	local ow = self.OpenWindows
	local msg = { }
	local msgdispatch = self.MsgDispatch

	-- the main loop:

	while self.Status == "running" and #ow > 0 do

		local idle = self:serviceCoroutines()

		-- update open windows, spool out refreshes and newsizes:
		for _, win in ipairs(ow) do
			while win:getMsg(msg) do
				msgdispatch[msg[2]](self, win, msg)
			end
			if win.RefreshMsg then
				win:passMsg(win.RefreshMsg)
				win.RefreshMsg = false
			end
			if win.NewSizeMsg then
				win:passMsg(win.NewSizeMsg)
				win.NewSizeMsg = false
			end
			win:update()
		end

		-- purge (now) hidden windows from list:
		for i = #ow, 1, -1 do
			if ow[i].Status ~= "show" then
				remove(ow, i)
			end
		end

		-- wait if no coroutines are running and windows are open:
		if idle and #ow > 0 then
			if collectgarbage then
				collectgarbage("step")
			end
			d:wait()
		end

		while d:getmsg(msg) do
			msgdispatch[msg[2]](self, msg[-1]:getuserdata(), msg)
		end

	end

	-- hide all windows:
	self:hideWindow()

	-- self:hide()
	-- self:cleanup()

	return true, self.Status
end

-------------------------------------------------------------------------------
--	Application:addCoroutine(function, arg1, ...): Adds a new coroutine to
--	the application's list of serviced coroutines. The new coroutine is not
--	immediately started, but at a later time during the application's
--	update procedure. This gives the application an opportunity to service
--	all pending messages and updates before the coroutine is actually started.
-------------------------------------------------------------------------------

function Application:addCoroutine(func, ...)
	local arg = { ... }
	insert(self.Coroutines, { cocreate(function() func(unpack(arg)) end) } )
end

-------------------------------------------------------------------------------
--	idle = serviceCoroutines() - internal
-------------------------------------------------------------------------------

function Application:serviceCoroutines()
	local crt = self.Coroutines
	local c = remove(crt, 1)
	if c then
		local success, res = coresume(c[1])
		local s = costatus(c[1])
		if s == "suspended" then
			c[2] = res or false -- extra argument from yield
			insert(crt, c)
		else
			if success then
				db.info("Coroutine finished successfully")
			else
				db.error("Error in coroutine:\n%s\n%s", res, traceback(c[1]))
			end
		end
	end
	for _, c in ipairs(crt) do
		if not c[2] then
			return false -- a coroutine is running
		end
	end
	return true -- all coroutines are idle
end

-------------------------------------------------------------------------------
--	Application:suspend([window]): Suspends the caller (which must be running
--	in a coroutine) until it is getting rescheduled by the application.
--	Coroutines can use this as a cooperation point, which gives the
--	application an opportunity to service all pending messages and updates.
--	If no argument is given, the application returns to the caller as quickly
--	as possible. If an optional {{window}} is specified, the coroutine is put
--	to sleep until something happens in the application, or an interval timer
--	event is present at the window (i.e. the suspended coroutine is
--	rescheduled after no longer than 1/50th of a second).
-------------------------------------------------------------------------------

function Application:suspend(window)
	if window then
		window:addInterval()
		coyield(window)
		window:remInterval()
	else
		coyield()
	end
end

-------------------------------------------------------------------------------
--	status[, path, selection] = Application:requestFile(args):
--	Requests a single or multiple files or directories. Possible keys in
--	the {{args}} table are:
--		- {{Center}} - Boolean, whether requester should be opened centered
--		- {{Height}} - Height of the requester window
--		- {{Lister}} - External lister to operate on
--		- {{Path}} - The initial path
--		- {{SelectMode}} - "multi" or "single" [default "single"]
--		- {{Title}} - Window title [default "Select file or directory..."]
--		- {{Width}} - Width of the requester window
--	The first return value is a string reading either "selected" or
--	"cancelled". If the status is "selected", the second return value is
--	the path where the requester was left, and the third value is a table
--	of the items that were selected.
--	Note: The caller of this function must be running in a coroutine
--	(see Application:addCoroutine()).
-------------------------------------------------------------------------------

function Application:requestFile(args)

	assert(corunning(), "Must be called in a coroutine")

	args = args or { }

	local dirlist = args.Lister or ui.DirList:new
	{
		Path = args.Path or "/",
		Kind = "requester",
		SelectMode = args.SelectMode or "single",
	}

	local window = Window:new
	{
		Title = args.Title or dirlist.Locale.SELECT_FILE_OR_DIRECTORY,
		Modal = true,
		Width = args.Width or 400,
		Height = args.Height or 500,
		Center = args.Center or true,
		Children = { dirlist }
	}

	Application.connect(window)
	self:addMember(window)
	window:setValue("Status", "show")

	dirlist:showDirectory()

	repeat
		self:suspend(window)
		if window.Status ~= "show" then
			-- window closed:
			dirlist.Status = "cancelled"
		end
	until dirlist.Status ~= "running"

	dirlist:abortScan()

	self:remMember(window)

	if dirlist.Status == "selected" then
		return dirlist.Status, dirlist.Path, dirlist.Selection
	end

	return dirlist.Status

end

-------------------------------------------------------------------------------
--	selected = Application:easyRequest(title, text, buttontext1[, ...]):
--	Show requester. {{title}} will be displayed as the window title; if this
--	argument is '''false''', the application's {{ProgramName}} will be used
--	for the title. {{text}} (which may contain line breaks) will be used as
--	the requester's body. Buttons are ordered from left to right. The first
--	button has the number 1. If the window is closed using the Escape key
--	or close button, the return value will be {{false}}.
--	Note: The caller of this function must be running in a coroutine
--	(see Application:addCoroutine()).
-------------------------------------------------------------------------------

function Application:easyRequest(title, text, ...)

	assert(corunning(), "Must be called in a coroutine")

	local result = false
	local buttons = { }
	local window

	local numb = select("#", ...)
	for i = 1, numb do
		local button = ui.Text:new
		{
			Class = "button",
			Mode = "button",
			Text = select(i, ...),
			onPress = function(self, pressed)
				if pressed == false then
					result = i
					window:setValue("Status", "hide")
				end
				ui.Text.onPress(self, pressed)
			end
		}
		if i == numb then
			button.Focus = true
		end
		insert(buttons, button)
	end

	window = Window:new
	{
		Title = title or self.ProgramName,
		Modal = true,
		Center = true,
		Orientation = "vertical",
		Children =
		{
			ui.Text:new { Width = "fill", Text = text },
			ui.Group:new { Width = "fill", SameSize = true,
				Children = buttons }
		}
	}

	Application.connect(window)
	self:addMember(window)
	window:setValue("Status", "show")

	repeat
		self:suspend(window)
	until window.Status ~= "show"

	self:remMember(window)

	return result
end

-------------------------------------------------------------------------------
--	getElement(mode) - equivalent to Area:getElement(), see there
-------------------------------------------------------------------------------

function Application:getElement(mode)
	if mode == "children" then
		return self.Children
	end
end

-------------------------------------------------------------------------------
--	getLocale([deflang[, language]]): Returns a table of locale strings for
--	{{ApplicationId}} and {{VendorDomain}}. See ui.getLocale() for more
--	information.
-------------------------------------------------------------------------------

function Application:getLocale(deflang, lang)
	return ui.getLocale(self.ApplicationId, self.VendorDomain, deflang, lang)
end
