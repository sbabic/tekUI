-------------------------------------------------------------------------------
--
--	tek.ui
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		This is the base library of the user interface toolkit. It implements
--		a class loader and provides a central place for various toolkit
--		constants. To invoke the class loader, simply aquire a class from
--		the {{tek.ui}} table, e.g. this will load the
--		[[#tek.ui.class.application]] class (as well as all subsequently
--		needed classes):
--				ui = require "tek.ui"
--				ui.Application:new { ...
--
--	FUNCTIONS::
--		- ui.createHook() - Create a hook object
--		- ui.extractKeyCode() - Extract keycode from a string
--		- ui.getLocale() - Get a locale catalog
--		- ui.loadClass() - Load a named class
--		- ui.loadStyleSheet() - Load and parse a style sheet file
--		- ui.resolveKeyCode() - Convert keycode into keys and qualifiers
--		- ui.testFlag() - Test a bit flag in a flags field
--
--	CONSTANTS::
--		- {{NOTIFY_ALWAYS}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_CHANGE}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_VALUE}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_TOGGLE}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_FORMAT}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_SELF}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_OLDVALUE}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_FUNCTION}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_WINDOW}} - see [[Object][#tek.class.object]] -
--		defined in [[#tek.ui.class.element]]
--		- {{NOTIFY_APPLICATION}} - see [[Object][#tek.class.object]] -
--		defined in [[#tek.ui.class.element]]
--		- {{NOTIFY_ID}} - see [[Object][#tek.class.object]] -
--		defined in [[#tek.ui.class.element]]
--		- {{NOTIFY_COROUTINE}} - see [[Object][#tek.class.object]] -
--		defined in [[#tek.ui.class.element]]
--		- {{HUGE}} - use this value to express a "huge" spatial extent
--		- {{NULLOFFS}} - table {{ { 0, 0, 0, 0 } }} (read-only)
--		- {{MSG_CLOSE}} - Input message type: Window closed
--		- {{MSG_FOCUS}} - Window activated/deactivated
--		- {{MSG_NEWSIZE}} - Window resized
--		- {{MSG_REFRESH}} - Window needs (partial) refresh
--		- {{MSG_MOUSEOVER}} - Mouse pointer entered/left window
--		- {{MSG_KEYDOWN}} - Key pressed down
--		- {{MSG_MOUSEMOVE}} - Mouse pointer moved
--		- {{MSG_MOUSEBUTTON}} - Mousebutton pressed/released
--		- {{MSG_INTERVAL}} - Timer interval message (default: 50Hz)
--		- {{MSG_KEYUP}} - Key released
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local Object = require "tek.class.object"
local arg = arg
local assert = assert
local error = error
local floor = math.floor
local getenv = os.getenv
local getmetatable = getmetatable
local insert = table.insert
local ipairs = ipairs
local loadstring = loadstring
local open = io.open
local package = package
local pairs = pairs
local pcall = pcall
local remove = table.remove
local require = require
local setmetatable = setmetatable
local tostring = tostring
local type = type

module "tek.ui"
_VERSION = "tekUI 18.0"

-------------------------------------------------------------------------------
--	Initialization of globals:
-------------------------------------------------------------------------------

-- Old package path:
local OldPath = package and package.path or ""
local OldCPath = package and package.cpath or ""

-- Get executable path and name:
if arg and arg[0] then
	local p = package and package.config:sub(1, 1) or "/"
	ProgDir, ProgName = arg[0]:match(("^(.-%s?)([^%s]*)$"):format(p, p))
end

-- Modified package path to find modules in the local program directory:
LocalPath = ProgDir and ProgDir .. "?.lua;" .. OldPath or OldPath
LocalCPath = ProgDir and ProgDir .. "?.so;" .. OldCPath or OldCPath

-- Name of the Default Theme:
ThemeName = getenv("THEME") or false
-- Open in fullscreen mode by default?:
FullScreen = getenv("FULLSCREEN")
FullScreen = FullScreen or false
-- No mouse pointer:
NoCursor = getenv("NOCURSOR") == "true"
-- Standard shortcut marker:
ShortcutMark = "_"

-------------------------------------------------------------------------------
--	class = loadClass(domain, classname):
--	Loads a class of the specified {{domain}} and the given {{classname}}.
--	Returns the loaded class or '''false''' if the class or domain name is
--	unknown or if an error was detected in the module. Possible values for
--	{{domain}}, as currently defined, are:
--		- "class" - user interface element classes
--		- "border" - border classes
--		- "layout" - classes used for layouting a group
--		- "hook" - drawing hooks
-------------------------------------------------------------------------------

local function loadProtected(name)
	return pcall(require, name)
end

local function loadSimple(name)
	return true, require(name)
end

local LoaderPaths =
{
	["class"] = "tek.ui.class.",
	["border"] = "tek.ui.border.",
	["layout"] = "tek.ui.layout.",
	["hook"] = "tek.ui.hook.",
}

function loadClass(domain, name, pat, loader)
	if name and name ~= "" and domain and LoaderPaths[domain] then
		if not pat or name:match(pat) then
			name = LoaderPaths[domain] .. name
			db.trace("Loading class '%s'...", name)
			package.path, package.cpath = LocalPath, LocalCPath
			local success, result = (loader or loadProtected)(name)
			package.path, package.cpath = OldPath, OldCPath
			if success then
				return result
			end
			db.error("Error loading class '%s'", name)
			db.warn("%s", result)
		else
			db.error("Invalid (or prohibited) class name '%s'", name)
		end
	end
	return false
end

-------------------------------------------------------------------------------
--	hookobject = createHook(domain, classname, parent[, object]): Loads a
--	class of the given {{domain}} and {{classname}}, instantiates it
--	(optionally passing it {{object}} for initialization), connects it to
--	the specified {{parent}} element, and initializes it using its
--	{{setup()}} method. Refer also to loadClass() for further details.
-------------------------------------------------------------------------------

function createHook(domain, name, parent, object)
	local child = loadClass(domain, name)
	if child then
		local app = parent.Application
		child = child:new(object or { })
		child:connect(parent)
		app:decodeProperties(child)
		child:setup(app, parent.Window)
		return child
	end
	return false
end

-------------------------------------------------------------------------------
--	encodeURL:
-------------------------------------------------------------------------------

local function f_encodeurl(c)
	return ("%%%02x"):format(c:byte())
end

function encodeURL(s)
	s = s:gsub(
	'[%z\001-\032\127-\255%$%&%+%,%/%:%;%=%?%@%"%<%>%#%%%{%}%|%\%^%~%[%]%`%]]',
		f_encodeurl)
	return s
end

-------------------------------------------------------------------------------
--	table, msg = sourceTable(file[, environment]): Interprete a file as a Lua
--	source, containing the keys and values forming a table. If {{file}} is a
--	string, it will be used for opening and reading the named file, otherwise
--	it will be assumed to be an open file handle. Either way, the file will
--	be read using the {{file:read("*a")}} method and closed afterwards.
--	By default, the source will be executed in an empty environment, unless
--	an environment is specified. The resulting table is returned to the
--	caller, or '''nil''' followed by an error message.
-------------------------------------------------------------------------------

function sourceTable(file, env)
	local msg
	if type(file) == "string" then
		file = open(file)
	end
	if file then
		local chunk = file:read("*a")
		file:close()
		if chunk then
			chunk, msg = loadstring(("do return { %s } end"):format(chunk))
			if chunk then
				if env then
					setfenv(chunk, env)
				end
				return chunk()
			end
		end
	end
	return nil, msg
end

-------------------------------------------------------------------------------
--	openUIPath: internal
-------------------------------------------------------------------------------

local function openUIPath(fname)
	local fullname, f, msg
	for p in LocalPath:gmatch("([^;]-)%?%.lua;?") do
		fullname = p .. fname
		db.info("Trying to open '%s'", fullname)
		f, msg = open(fullname)
		if f then
			return f
		end
	end
	return nil, msg
end

-------------------------------------------------------------------------------
--	table, msg = loadTable(fname): This function tries to load a file from
--	the various possible locations as defined by {{ui.LocalPath}}, to
--	interprete is as Lua source, and to return its contents as keys and
--	values of a table. If unsuccessful, returns '''nil''' followed by an
--	erro message.
-------------------------------------------------------------------------------

function loadTable(fname)
	local f, msg = openUIPath(fname)
	if f then
		db.info("Trying to load table '%s'", fname)
		local tab
		tab, msg = sourceTable(f)
		if tab then
			return tab
		end
	end
	return nil, msg
end

-------------------------------------------------------------------------------
--	lang = getLanguage()
-------------------------------------------------------------------------------

function getLanguage()
	local lang
	lang = getenv("LC_MESSAGES")
	lang = lang or getenv("LC_ALL")
	lang = lang or getenv("LANG")
	if lang then
		lang = lang:lower()
		lang = lang:match("^(%l%l)")
	end
	lang = lang or "en"
	db.info("Language suggested by the system seems to be '%s'", lang)
	return lang
end

-------------------------------------------------------------------------------
--	success, msg = loadLocale(locale, lang)
-------------------------------------------------------------------------------

local LocaleCache = { }

function loadLocale(l, lang)
	local msg
	local m1 = getmetatable(l)
	local keys = m1.__index
	local m2 = getmetatable(keys)
	if m2.lang ~= lang then
		local app = m2.app
		local vendor = m2.vendor
		local key = ("tek/ui/locale/%s/%s/%s"):format(vendor, app, lang)
		keys = LocaleCache[key]
		if keys then
			db.trace("Found cache copy for locale '%s'", key)
		else
			keys, msg = loadTable(key)
		end
		if keys then
			setmetatable(keys, m2)
			m1.__index = keys
			m2.lang = lang
			LocaleCache[key] = keys
			return true
		end
		db.error("Failed to load locale '%s' : %s", key, msg)
	end
	return nil, msg
end

-------------------------------------------------------------------------------
--	catalog = getLocale(appid[, vendordomain[, deflang[, language]]]): Returns
--	a table of locale strings for the given application Id and vendor domain.
--	{{deflang}} (default: "en") is used as the default language code if a
--	catalog for the requested language is unavailable. If no {{language}}
--	code is specified, then the preferred language will be obtained from the
--	operating system or desktop environment. If no catalog file was found
--	or otherwise non-existent keys are used to access the resulting catalog,
--	the key will be mirrored with underscores turned into spaces; for
--	example, if {{catalog}} contained no string for the given key, accessing
--	{{catalog.HELLO_WORLD}} would return the string "HELLO WORLD".
-------------------------------------------------------------------------------

function getLocale(appname, vendorname, deflang, lang)
	local l = { }
	local m1 = { }
	local keys = { }
	m1.__index = keys
	setmetatable(l, m1)
	local m2 = { }
	m2.vendor = encodeURL(vendorname or "unknown")
	m2.app = encodeURL(appname or "unnown")
	m2.__index = function(tab, key)
		db.warn("Locale key not found: %s", key)
		return key and key:gsub("_", " ") or ""
	end
	setmetatable(keys, m2)
	lang = lang or getLanguage()
	if not loadLocale(l, lang) then
		db.warn("Preferred locale not found: '%s'", lang)
		deflang = deflang or "en"
		if lang ~= deflang then
			loadLocale(l, deflang)
		end
	end
	return l
end

-------------------------------------------------------------------------------
--	properties, msg = loadStyleSheet(name): This function loads a style sheet
--	and parses it into a table of style classes with properties. If
--	parsing failed, the return value is '''false''' and {{msg}} contains
--	an error message.
-------------------------------------------------------------------------------

function loadStyleSheet(fname)
	local f, msg = openUIPath(fname)
	if not f then
		return false, msg
	end

	local s = { }
	local mode = { "waitclass" }
	local class
	local buf = ""
	local line = 0
	local res = true
	while res do
		while res do
			buf = buf:match("^%s*(.*)")
			if buf == "" then
				break
			end
			if mode[1] == "comment" then
				local a = buf:match("^.-%*%/(.*)")
				if a then
					remove(mode, 1)
					buf = a
				end
				break
			else
				local a = buf:match("^%/%*(.*)")
				if a then
					insert(mode, 1, "comment")
					buf = a
				end
			end
			if mode[1] == "waitclass" then
				local a, b = buf:match("^([%a._:#][%a%d._:#-]+)%s*(.*)")
				if a then
					class = a
					buf = b
					mode[1] = "waitbody"
				else
					res = false
				end
			elseif mode[1] == "waitbody" then
				local a = buf:match("^%{(.*)")
				if a then
					mode[1] = "body"
					buf = a
				else
					res = false
				end
			elseif mode[1] == "body" then
				local a = buf:match("^%}(.*)")
				if a then
					buf = a
					mode[1] = "waitclass"
				else
					local k, v, r =
						buf:match("^([%a%d%-]+)%s*%:%s*([^;]+)%s*;(.*)")
					if k then
						s[class] = s[class] or { }
						s[class][k] = v
						buf = r
					else
						res = false
					end
				end
			end
		end
		if res then
			local nbuf = f:read()
			if nbuf then
				buf = buf .. nbuf
				line = line + 1
			else
				if mode[1] == "waitclass" then
					f:close()
					return s
				end
				res = false
			end
		end
	end
	f:close()
	return false, ("line %s : syntax error"):format(line)
end

-------------------------------------------------------------------------------
--	prepareProperties: 'unpacks' various properties in style sheets;
-------------------------------------------------------------------------------

local function adddirkeys(p, k, fmt, a, b, c, d)
	local key = fmt:format("top")
	p[key] = p[key] or a
	key = fmt:format("right")
	p[key] = p[key] or b
	key = fmt:format("bottom")
	p[key] = p[key] or c
	key = fmt:format("left")
	p[key] = p[key] or d
	p[k] = nil
	return true
end

local function adddirkeys1(p, k, fmt, a)
	return adddirkeys(p, k, fmt, a, a, a, a)
end

local function adddirkeys2(p, k, fmt, a, b)
	return adddirkeys(p, k, fmt, a, b, a, b)
end

local function adddirkeys3(p, k, fmt, a, b, c)
	return adddirkeys(p, k, fmt, a, b, c, b)
end

local function adddirkeys4(p, k, fmt, a, b, c, d)
	return adddirkeys(p, k, fmt, a, b, c, d)
end

local function addborder3(p, k, fmt, a, b, c)
	p["border-top-width"] = p["border-top-width"] or a
	p["border-right-width"] = p["border-right-width"] or a
	p["border-bottom-width"] = p["border-bottom-width"] or a
	p["border-left-width"] = p["border-left-width"] or a
	p["border-style"] = p["border-style"] or b
	p["border-top-color"] = p["border-top-color"] or c
	p["border-right-color"] = p["border-right-color"] or c
	p["border-bottom-color"] = p["border-bottom-color"] or c
	p["border-left-color"] = p["border-left-color"] or c
end

local function addborder3dir(p, k, fmt, a, b, c)
	local key = ("border-%s-width"):format(fmt)
	p[key] = p[key] or a
	key = ("border-style"):format(fmt)
	p[key] = p[key] or b
	key = ("border-%s-color"):format(fmt)
	p[key] = p[key] or c
end

local matchkeys =
{
	["background-color"] =
	{
		{ "^parent%-group$", function(p, k) p[k] = 0 end }
	},
	["border-width"] =
	{
		{ "^%s*(%d+)%s*$", adddirkeys1, "border-%s-width" },
		{ "^%s*(%d+)%s+(%d+)%s*$", adddirkeys2, "border-%s-width" },
		{ "^%s*(%d+)%s+(%d+)%s+(%d+)%s*$", adddirkeys3, "border-%s-width" },
		{ "^%s*(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*$", adddirkeys4,
			"border-%s-width" }
	},
	["border-color"] =
	{
		{ "^%s*(%S+)%s*$", adddirkeys1, "border-%s-color" },
		{ "^%s*(%S+)%s+(%S+)%s*$", adddirkeys2, "border-%s-color" },
		{ "^%s*(%S+)%s+(%S+)%s+(%S+)%s*$", adddirkeys3, "border-%s-color" },
		{ "^%s*(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*$", adddirkeys4,
			"border-%s-color" }
	},
	["border"] = { { "^%s*(%d+)%s+(%S+)%s+(%S+)%s*$", addborder3 } },
	["border-top"] =
	{
		{ "^%s*(%d+)%s+(%S+)%s+(%S+)%s*$", addborder3dir, "top" }
	},
	["border-right"] =
	{
		{ "^%s*(%d+)%s+(%S+)%s+(%S+)%s*$", addborder3dir, "right" }
	},
	["border-bottom"] =
	{
		{ "^%s*(%d+)%s+(%S+)%s+(%S+)%s*$", addborder3dir, "bottom" }
	},
	["border-left"] =
	{
		{ "^%s*(%d+)%s+(%S+)%s+(%S+)%s*$", addborder3dir, "left" }
	},
	["margin"] =
	{
		{ "^%s*(%d+)%s*$", adddirkeys1, "margin-%s" },
		{ "^%s*(%d+)%s+(%d+)%s*$", adddirkeys2, "margin-%s" },
		{ "^%s*(%d+)%s+(%d+)%s+(%d+)%s*$", adddirkeys3, "margin-%s" },
		{ "^%s*(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*$", adddirkeys4, "margin-%s" }
	},
	["padding"] =
	{
		{ "^(%d+)%s*$", adddirkeys1, "padding-%s" },
		{ "^(%d+)%s+(%d+)%s*$", adddirkeys2, "padding-%s" },
		{ "^(%d+)%s+(%d+)%s+(%d+)%s*$", adddirkeys3, "padding-%s" },
		{ "^(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*$", adddirkeys4, "padding-%s" }
	},
}

function prepareProperties(props)
	if props then
		for class, props in pairs(props) do
			local done
			repeat
				done = true
				local found
				for key, val in pairs(props) do
					local replkey = matchkeys[key]
					if replkey then
						val = tostring(val)
						for _, pattern in ipairs(replkey) do
							local a, b, c, d = val:match(pattern[1])
							if a then
								if pattern[2](props, key, pattern[3],
									a, b, c, d) then
									done = false
									break
								end
							end
						end
					end
					if not done then
						break
					end
				end
			until done
		end
	end
	return props
end

-------------------------------------------------------------------------------
--	On-demand class loader:
-------------------------------------------------------------------------------

setmetatable(_M, {
	__index = function(tab, key)
		local pname = key:lower()
		local class = loadClass("class", pname, "^%a+$", loadSimple)
		if class then
			db.info("Loaded class '%s'", pname)
			tab[pname] = class
			tab[key] = class
			return class
		else
			error("Failed to load class '" .. pname .. "'")
		end
	end
})

-------------------------------------------------------------------------------
--	Keycode aliases:
-------------------------------------------------------------------------------

KeyAliases =
{
	["IgnoreCase"] = { 0x0000, 0x00, 0x01, 0x02 },
	["Shift"] = { 0x0000, 0x01, 0x02 },
	["LShift"] = { 0x0000, 0x01 },
	["RShift"] = { 0x0000, 0x02 },
	["Ctrl"] = { 0x0000, 0x04, 0x08 },
	["LCtrl"] = { 0x0000, 0x04 },
	["RCtrl"] = { 0x0000, 0x08 },
	["Alt"] = { 0x0000, 0x10, 0x20 },
	["LAlt"] = { 0x0000, 0x10 },
	["RAlt"] = { 0x0000, 0x20 },
	["Del"] = { 0x007f },
	["F1"] = { 0xf001 },
	["F2"] = { 0xf002 },
	["F3"] = { 0xf003 },
	["F4"] = { 0xf004 },
	["F5"] = { 0xf005 },
	["F6"] = { 0xf006 },
	["F7"] = { 0xf007 },
	["F8"] = { 0xf008 },
	["F9"] = { 0xf009 },
	["F10"] = { 0xf00a },
	["F11"] = { 0xf00b },
	["F12"] = { 0xf00c },
	["Left"] = { 0xf010 },
	["Right"] = { 0xf011 },
	["Up"] = { 0xf012 },
	["Down"] = { 0xf013 },
	["BackSpc"] = { 0x0008 },
	["Tab"] = { 0x0009 },
	["Esc"] = { 0x001b },
	["Insert"] = { 0xf021 },
	["Overwrite"] = { 0xf022 },
	["PageUp"] = { 0xf023 },
	["PageDown"] = { 0xf024 },
	["Pos1"] = { 0xf025 },
	["End"] = { 0xf026 },
	["Print"] = { 0xf027 },
	["Scroll"] = { 0xf028 },
	["Pause"] = { 0xf029 },
}

-------------------------------------------------------------------------------
--	key, quals = resolveKeyCode: resolves a combined keycode specifier (e.g.
--	"Ctrl+Shift+Q" into a key string and a table of qualifier codes.
-------------------------------------------------------------------------------

local function addqual(key, quals, s)
	local a = KeyAliases[s]
	if a then
		if a[1] ~= 0 then
			key = a[1]
		end
		local n = #quals
		for i = 3, #a do
			for j = 1, n do
				insert(quals, quals[j] + a[i])
			end
		end
		if a[2] then
			for j = 1, n do
				quals[j] = quals[j] + a[2]
			end
		end
	else
		key = s
	end
	return key
end

function resolveKeyCode(code)
	local quals, key = { 0 }, ""
	local ignorecase
	for s in ("+" .. code):gmatch("%+(.[^+]*)") do
		if s == "IgnoreCase" then
			ignorecase = true
		end
		key = addqual(key, quals, s)
	end
	local lkey = key:lower()
	if not ignorecase and key == key:upper() and key ~= lkey then
		addqual(lkey, quals, "Shift")
	end
	return lkey, quals
end

-------------------------------------------------------------------------------
--	extractKeyCode(string[, shortcutmark]): Extract a shortcut character
--	from a string. The default shortcut marker is an underscore.
-------------------------------------------------------------------------------

function extractKeyCode(s, m)
	m = m or "_"
	s = s:match("^[^" .. m .. "]*" .. m .. "(.)")
	return s and s:lower() or false
end

-------------------------------------------------------------------------------
--	testFlag(flag, field): Test a bit flag in a flags field
-------------------------------------------------------------------------------

function testFlag(flag, mask)
	return floor(flag % (mask + mask) / mask) ~= 0
end

-------------------------------------------------------------------------------
--	Constants: Note that 'Object' and 'Element' trigger the class loader
-------------------------------------------------------------------------------

DEBUG = false
HUGE = 1000000
NULLOFFS = { 0, 0, 0, 0 }

-- Notification placeholders:

NOTIFY_ALWAYS = Object.NOTIFY_ALWAYS
NOTIFY_CHANGE = Object.NOTIFY_CHANGE
NOTIFY_VALUE = Object.NOTIFY_VALUE
NOTIFY_TOGGLE = Object.NOTIFY_TOGGLE
NOTIFY_FORMAT = Object.NOTIFY_FORMAT
NOTIFY_SELF = Object.NOTIFY_SELF
NOTIFY_OLDVALUE = Object.NOTIFY_OLDVALUE
NOTIFY_FUNCTION = Object.NOTIFY_FUNCTION
NOTIFY_GETFIELD = Object.NOTIFY_GETFIELD
NOTIFY_WINDOW = Element.NOTIFY_WINDOW
NOTIFY_APPLICATION = Element.NOTIFY_APPLICATION
NOTIFY_ID = Element.NOTIFY_ID
NOTIFY_COROUTINE = Element.NOTIFY_COROUTINE

-- Symbolic colors:

PEN_PARENTGROUP = 0 -- pseudo color: use the group's background color
PEN_BACKGROUND = 1
PEN_DARK = 2
PEN_LIGHT = 3
PEN_FILL = 4
PEN_ACTIVE = 5
PEN_FOCUS = 6
PEN_HOVER = 7
PEN_DISABLED = 8
PEN_DETAIL = 9
PEN_ACTIVEDETAIL = 10
PEN_FOCUSDETAIL = 11
PEN_HOVERDETAIL = 12
PEN_DISABLEDDETAIL = 13
PEN_DISABLEDDETAIL2 = 14
PEN_BORDERSHINE = 15
PEN_BORDERSHADOW = 16
PEN_BORDERRIM = 17
PEN_BORDERFOCUS = 18
PEN_BORDERLEGEND = 19
PEN_MENU = 20
PEN_MENUDETAIL = 21
PEN_MENUACTIVE = 22
PEN_MENUACTIVEDETAIL = 23
PEN_LIST = 24
PEN_LIST2 = 25
PEN_LISTDETAIL = 26
PEN_LISTACTIVE = 27
PEN_LISTACTIVEDETAIL = 28
PEN_CURSOR = 29
PEN_CURSORDETAIL = 30
PEN_GROUP = 31
PEN_SHADOW = 32
PEN_SHINE = 33
PEN_HALFSHADOW = 34
PEN_HALFSHINE = 35

-- Message types:

MSG_CLOSE       = 0x0001
MSG_FOCUS       = 0x0002
MSG_NEWSIZE     = 0x0004
MSG_REFRESH     = 0x0008
MSG_MOUSEOVER   = 0x0010
MSG_KEYDOWN     = 0x0100
MSG_MOUSEMOVE   = 0x0200
MSG_MOUSEBUTTON = 0x0400
MSG_INTERVAL    = 0x0800
MSG_KEYUP       = 0x1000
MSG_USER        = 0x2000
MSG_ALL         = 0x1f1f
