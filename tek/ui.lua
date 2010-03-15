-------------------------------------------------------------------------------
--
--	tek.ui
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		This module is the user interface toolkit's base library. It implements
--		a class loader and support functions, and it provides a central place
--		for various constants and defaults. To invoke the class loader, simply
--		aquire a class from the {{tek.ui}} table, e.g. this will load the
--		[[#tek.ui.class.application]] class, as well as all subsequently
--		needed classes:
--				local ui = require "tek.ui"
--				ui.Application:new { ...
--
--	FUNCTIONS::
--		- ui.createHook() - Creates a hook object
--		- ui.destroyHook() - Destroys a hook object
--		- ui.getStockImage() - Gets a stock image object
--		- ui.extractKeyCode() - Extracts a keycode from a string
--		- ui.getLocale() - Gets a locale catalog
--		- ui.loadClass() - Loads a named class
--		- ui.loadImage() - Retrieves an image (possibly from an image cache)
--		- ui.loadLibrary() - Loads a library
--		- ui.loadStyleSheet() - Loads and parses a style sheet file
--		- ui.loadTable() - Loads a table from some standard path
--		- ui.require() - Loads an user interface class
--		- ui.resolveKeyCode() - Converts a keycode into keys and qualifiers
--
--	CONSTANTS::
--		- {{HUGE}}
--			- This constant is used to express a 'huge' spatial extent on a
--			given axis, e.g. {{Width = ui.HUGE}} indicates that you wish no
--			specific size limit on the X axis.
--
--	DEFAULTS::
--		- {{DBLCLICKJITTER}}
--			- Maximum sum of squared delta mouse positions (dx² + dy²) for
--			a pair of mouse clicks to be accepted as a double click. The
--			default is {{70}}. Large touchscreens may require a much larger
--			value.
--		- {{DBLCLICKTIME}} 
--			- Maximum number of microseconds between mouse clicks to be
--			recognized as a double click. Default: {{32000}}. Use a larger
--			value for touchscreens.
--
--	MESSAGE TYPES::
--		- {{MSG_CLOSE}}
--			- Message sent when a window was closed
--		- {{MSG_FOCUS}}
--			- A window has been activated or deactivated
--		- {{MSG_INTERVAL}}
--			- 50Hz Timer interval message
--		- {{MSG_KEYDOWN}}
--			- Key pressed down
--		- {{MSG_KEYUP}}
--			- Key released
--		- {{MSG_MOUSEBUTTON}}
--			- Mousebutton pressed or released
--		- {{MSG_MOUSEMOVE}}
--			- Mouse pointer moved
--		- {{MSG_MOUSEOVER}}
--			- Mouse pointer has entered or left the window
--		- {{MSG_NEWSIZE}}
--			- A window has been resized
--		- {{MSG_REFRESH}}
--			- A window needs a (partial) refresh
--		- {{MSG_USER}}
--			- User message
--
--	NOTIFICATIONS::
--		- {{NOTIFY_ALWAYS}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_VALUE}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_TOGGLE}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_FORMAT}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_SELF}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_OLDVALUE}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_FUNCTION}} - see [[Object][#tek.class.object]]
--		- {{NOTIFY_WINDOW}} - see [[Object][#tek.class.object]], 
--		defined in [[Element][#tek.ui.class.element]]
--		- {{NOTIFY_APPLICATION}} - see [[Object][#tek.class.object]],
--		defined in [[Element][#tek.ui.class.element]]
--		- {{NOTIFY_ID}} - see [[Object][#tek.class.object]],
--		defined in [[Element][#tek.ui.class.element]]
--		- {{NOTIFY_COROUTINE}} - see [[Object][#tek.class.object]],
--		defined in [[Element][#tek.ui.class.element]]
--
--	SEE ALSO::
--		- [[#ClassOverview]]
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local uisupport = require "tek.ui.support"
local Region = require "tek.lib.region"
local Object = require "tek.class.object"
local arg = arg
local assert = assert
local error = error
local floor = math.floor
local getenv = os.getenv
local getmetatable = getmetatable
local insert = table.insert
local loadstring = loadstring
local open = io.open
local package = package
local pairs = pairs
local pcall = pcall
local rawget = rawget
local regionnew = Region.new
local remove = table.remove
local int_require = require
local setfenv = setfenv
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type

module "tek.ui"
_VERSION = "tekUI 34.0"

-------------------------------------------------------------------------------
--	Initialization of globals:
-------------------------------------------------------------------------------

-- Old package path:
local OldPath = package and package.path or ""
local OldCPath = package and package.cpath or ""

-- Path Separator:
local p = package and package.config:sub(1, 1) or "/"
PathSeparator = p

-- Get executable path and name:
if arg and arg[0] then
	ProgDir, ProgName = arg[0]:match(("^(.-%s?)([^%s]*)$"):format(p, p))
	if ProgDir == "" then
		ProgDir = "." .. p
	end
end

-- Modified package path to find modules in the local program directory:
LocalPath = ProgDir and ProgDir .. "?.lua;" .. OldPath or OldPath
LocalCPath = ProgDir and ProgDir .. "?.so;" .. OldCPath or OldCPath

-- Name of the Default Theme:
ThemeName = getenv("THEME") or "default desktop"
-- Open in fullscreen mode by default?:
FullScreen = getenv("FULLSCREEN")
FullScreen = FullScreen or false
-- No mouse pointer:
NoCursor = getenv("NOCURSOR") == "true"
-- Standard shortcut marker:
ShortcutMark = "_"

-------------------------------------------------------------------------------
--	newFlags: Support for flag fields
-------------------------------------------------------------------------------

newFlags = uisupport.newFlags

-------------------------------------------------------------------------------
--	class = ui.loadClass(realm, classname[, min_version]):
--	Loads a class of the given {{classname}} from the specified {{realm}},
--	and optionally with a minimum version requirement.
--	Returns the loaded class or '''false''' if the class or realm is
--	unknown, if the version requirement cannot be satisfied, or if an error
--	occured in the module. Currently defined values for {{realm}} are:
--		- {{"border"}} - border classes
--		- {{"class"}} - user interface element classes
--		- {{"hook"}} - drawing hook classes
--		- {{"image"}} - image classes
--		- {{"layout"}} - group layouting classes
-------------------------------------------------------------------------------

local function requireVersion(name, version)
	local mod = int_require(name)
	local ver = rawget(mod, "_VER")
	if not ver then
		ver = mod._VERSION
		if ver then
			ver = ver:match(" (%d+)%.%d+$")
			ver = tonumber(ver)
		else
			ver = 999999
		end
		mod._VER = ver
		if ver then
			db.info("Loaded module %s, version %s", name, ver)
		else
			db.error("Module %s: illegal version", name)
		end
	end
	if version then
		if ver < version then
			local msg = ("%s : required major version %s, got %s"):
				format(name, version, ver)
			db.error("%s", msg)
			error(msg)
		end
	end
	return mod
end

local function loadProtected(name, version)
	return pcall(requireVersion, name, version)
end

local function loadSimple(name, version)
	local mod = requireVersion(name, version)
	return true, mod
end

local LoaderPaths =
{
	["class"] = "tek.ui.class.",
	["border"] = "tek.ui.border.",
	["layout"] = "tek.ui.layout.",
	["hook"] = "tek.ui.hook.",
	["image"] = "tek.ui.image.",
	["lib"] = "tek.lib.",
}

function loadClass(realm, name, version, loader)
	if name and name ~= "" and realm and LoaderPaths[realm] then
		if not version then
			local name2
			name2, version = name:match("^(.*)%-(%d+)$")
			if version then
				version = tonumber(version)
				name = name2
			end
		end
		name = LoaderPaths[realm] .. name
		db.trace("Loading module %s v%s...", name, version)
		package.path, package.cpath = LocalPath, LocalCPath
		local success, result = (loader or loadProtected)(name, version)
		package.path, package.cpath = OldPath, OldCPath
		if success then
			return result
		end
		db.error("Error loading class '%s': %s", name, result)
	end
	return false
end

-------------------------------------------------------------------------------
--	ui.require(name[, version]): Loads an user interface class with at least
--	the specified major version. This function is a shortcut for
--	{{ui.loadClass("class", ...)}} - see ui.loadClass() for more details.
-------------------------------------------------------------------------------

function require(name, version)
	return loadClass("class", name, version, loadSimple)
end

-------------------------------------------------------------------------------
--	ui.loadLibrary(name[, version]): Loads a library with at least the
--	specified major version, from a local or global path starting with
--	{{tek/lib}}.
-------------------------------------------------------------------------------

function loadLibrary(name, version)
	return loadClass("lib", name, version, loadSimple)
end

-------------------------------------------------------------------------------
--	imgobject = ui.getStockImage(name, ...): Creates an image object of a
--	named class, corresponding to classes found in {{tek/ui/image}}. Extra
--	arguments are passed on as {{imageclass:new(...)}}.
-------------------------------------------------------------------------------

function getStockImage(name, ...)
	local class = loadClass("image", name)
	if class then
		return class:new(...)
	end
end

-------------------------------------------------------------------------------
--	imgobject = ui.loadImage(name): Loads an image from a file or retrieves
--	it from the image cache. Note that currently only the PPM file format is
--	recognized.
-------------------------------------------------------------------------------

function loadImage(fname)
	local img, w, h, trans = Display.getPixmap(fname)
	if img then
		return Image:new { img, w, h, trans }
	end
end

-------------------------------------------------------------------------------
--	hookobject = ui.createHook(realm, classname, parent[, table]): Loads a
--	class of the given {{realm}} and {{classname}}, instantiates it (optionally
--	passing it {{table}} for initialization), connects it to the specified
--	{{parent}} element, and calls its {{setup()}} method. If {{classname}} is
--	the pre-defined name {{"none"}}, this function returns '''false'''. Refer
--	also to ui.loadClass() for further details.
-------------------------------------------------------------------------------

function createHook(realm, name, parent, object)
	local child = name ~= "none" and loadClass(realm, name)
	if child then
		local app = parent.Application
		child = child:new(object or { })
		child:connect(parent)
		app:decodeProperties(parent)
		child:setup(app, parent.Window)
		return child
	end
	return false
end

-------------------------------------------------------------------------------
--	false = ui.destroyHook([hookobject]): Destroys a hook object by invoking
--	its {{cleanup()}} and {{disconnect()}} methods. Always returns '''false'''.
-------------------------------------------------------------------------------

function destroyHook(object)
	if object then
		object:cleanup()
		object:disconnect()
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
--	table, msg = ui.sourceTable(file[, environment]) - Interprete a file as a
--	Lua source, containing the keys and values forming a table. If {{file}} is
--	a string, it will be used for opening and reading the named file, otherwise
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
--	table, msg = ui.loadTable(fname): This function tries to load a file from
--	the various possible locations as defined by {{ui.LocalPath}}, interpretes
--	it is as Lua source, and returns its contents as keys and values of a
--	table. If unsuccessful, returns '''nil''' followed by an error message.
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
--	catalog = ui.getLocale(appid[, vendordomain[, deflang[, language]]]):
--	Returns a table of locale strings for the given application Id and vendor
--	domain. {{deflang}} (default: {{"en"}}) is used as the default language 
--	code if a catalog for the requested language is unavailable. If no
--	{{language}} code is specified, then the preferred language will be
--	obtained from the operating system or desktop environment. If no catalog
--	file was found or non-existent keys are used to access the resulting
--	catalog, the key will be echoed with underscores turned into spaces; for
--	example, if {{catalog}} contained no string for the given key, accessing
--	{{catalog.HELLO_WORLD}} would return the string {{"HELLO WORLD"}}.
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
--	unpackProperty:
-------------------------------------------------------------------------------

local function adddirkeys(p, k, fmt, a, b, c, d)
	local key = fmt:format("top")
	p[key] = a -- p[key] or a
	key = fmt:format("right")
	p[key] = b --p[key] or b
	key = fmt:format("bottom")
	p[key] = c --p[key] or c
	key = fmt:format("left")
	p[key] = d --p[key] or d
-- 	p[k] = nil
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

-- local function addborder3(p, k, fmt, a, b, c)
-- 	p["border-top-width"] = p["border-top-width"] or a
-- 	p["border-right-width"] = p["border-right-width"] or a
-- 	p["border-bottom-width"] = p["border-bottom-width"] or a
-- 	p["border-left-width"] = p["border-left-width"] or a
-- 	p["border-style"] = p["border-style"] or b
-- 	p["border-top-color"] = p["border-top-color"] or c
-- 	p["border-right-color"] = p["border-right-color"] or c
-- 	p["border-bottom-color"] = p["border-bottom-color"] or c
-- 	p["border-left-color"] = p["border-left-color"] or c
-- end

local matchkeys =
{
	["background-image"] =
	{
		{ "^url%b()", function(p, k, r, a) p[r] = a end, "background-color" }
	},
	["padding"] =
	{
		{ "^(%d+)$", adddirkeys1, "padding-%s" },
		{ "^(%d+)%s+(%d+)$", adddirkeys2, "padding-%s" },
		{ "^(%d+)%s+(%d+)%s+(%d+)$", adddirkeys3, "padding-%s" },
		{ "^(%d+)%s+(%d+)%s+(%d+)%s+(%d+)$", adddirkeys4, "padding-%s" }
	},
	["margin"] =
	{
		{ "^(%d+)$", adddirkeys1, "margin-%s" },
		{ "^(%d+)%s+(%d+)$", adddirkeys2, "margin-%s" },
		{ "^(%d+)%s+(%d+)%s+(%d+)$", adddirkeys3, "margin-%s" },
		{ "^(%d+)%s+(%d+)%s+(%d+)%s+(%d+)$", adddirkeys4, "margin-%s" }
	},
	["border-width"] =
	{
		{ "^(%d+)$", adddirkeys1, "border-%s-width" },
		{ "^(%d+)%s+(%d+)$", adddirkeys2, "border-%s-width" },
		{ "^(%d+)%s+(%d+)%s+(%d+)$", adddirkeys3, "border-%s-width" },
		{ "^(%d+)%s+(%d+)%s+(%d+)%s+(%d+)$", adddirkeys4, "border-%s-width" }
	},
	
	["border-color"] =
	{
		{ "^(%S+)$", adddirkeys1, "border-%s-color" },
		{ "^(%S+)%s+(%S+)$", adddirkeys2, "border-%s-color" },
		{ "^(%S+)%s+(%S+)%s+(%S+)$", adddirkeys3, "border-%s-color" },
		{ "^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$", adddirkeys4, "border-%s-color" }
	},
-- 	["border"] = { { "^(%d+)%s+(%S+)%s+(%S+)$", addborder3 } },
}

function unpackProperty(props, key, value, pclass)
	local replace = matchkeys[key]
	if replace then
		value = tostring(value)
		for i = 1, #replace do
			local pattern = replace[i]
			local a, b, c, d = value:match(pattern[1])
			if a then
				if pattern[2](props, key .. pclass, pattern[3] .. pclass, a, b, c, d) then
-- 					db.warn("applied rule %s=%s", key, pattern[1])
					return
				end
			end
		end
	end
	props[key .. pclass] = value
end

-------------------------------------------------------------------------------
--	ui.unpackStyleSheet(stylesheet)
-------------------------------------------------------------------------------

function unpackStyleSheet(stylesheet)
	for name, props in pairs(stylesheet) do
		local newprops = { }
		for key, val in pairs(props) do
			unpackProperty(newprops, key, val, "")
		end
		stylesheet[name] = newprops
	end
	return stylesheet
end

-------------------------------------------------------------------------------
--	properties, msg = ui.loadStyleSheet(file): This function loads a style
--	sheet from the specified file (which can be a name or an open file handle),
--	and parses it into a table of style classes with properties. If parsing
--	failed, the return value is '''false''' and {{msg}} contains an error
--	message.
-------------------------------------------------------------------------------

function loadStyleSheet(file)
	local fh, msg
	if type(file) == "string" then
		fh, msg = openUIPath(("tek/ui/style/%s.css"):format(file))
		if not fh then
			return nil, msg
		end
	else
		fh = file
	end
	local s = { }
	local mode = { "waitclass" }
	local class
	local buf = ""
	local line = 0
	local res = true
	local pclass = ""
	local props
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
					local c, pc = a:match("^([^:]+)%:(.+)$")
					if c then
						class = c
						pclass = ":" .. pc
					else
						class = a
						pclass = ""
					end
					props = s[class]
					if not props then
						props = { }
						s[class] = props
					end
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
					local key, val, r =
						buf:match("^([%a%d%-%:]+)%s*%:%s*([^;]-)%s*;(.*)")
					if key then
						unpackProperty(props, key, val, pclass)
						buf = r
					else
						res = false
					end
				end
			end
		end
		if res then
			local nbuf = fh:read()
			if nbuf then
				buf = buf .. nbuf
				line = line + 1
			else
				if mode[1] == "waitclass" then
					if fh ~= file then
						fh:close()
					end
					return s
				end
				res = false
			end
		end
	end
	if fh ~= file then
		f:close()
	end
	return false, ("line %s : syntax error"):format(line)
end

-------------------------------------------------------------------------------
--	Internal default stylesheet:
-------------------------------------------------------------------------------

local DEF_STYLESHEET_DEFAULT =
{
	["tek.ui.class.checkmark"] = {
		["text-align"] = "left",
		["valign"] = "center",
		["background-color"] = "transparent",
		["border-width"] = 0,
	},
	["tek.ui.class.frame"] = {
		["border-width"] = 2,
		["border-style"] = "solid",
	},
	["tek.ui.class.widget"] = {
		["border-style"] = "outset",
		["border-style:active"] = "inset",
	},
	["tek.ui.class.gauge"] = {
		["height"] = "fill",
	},
	["tek.ui.class.group"] = {
		["border-width"] = 0,
	},
	["tek.ui.class.handle"] = {
		["padding"] = 3,
	},
	["tek.ui.class.imagewidget"] = {
		["color"] = "transparent",
	},
	["tek.ui.class.lister"] = {
		["border-style"] = "solid",
		["border-style:active"] = "solid",
	},
	["tek.ui.class.menuitem"] = {
		["text-align"] = "left",
	},
	["tek.ui.class.poplist"] = {
		["text-align"] = "left",
	},
	["tek.ui.class.popitem"] = {
		["width"] = "fill",
	},
	["tek.ui.class.scrollbar"] = {
		["valign"] = "center",
	},
	["tek.ui.class.slider"] = {
		["width"] = "fill",
		["height"] = "fill",
	},
	["tek.ui.class.spacer"] = {
		["border-width"] = 1,
	},
	["tek.ui.class.text"] = {
		["max-height"] = 0,
	},
	["tek.ui.class.textinput"] = {
		["font"] = "ui-fixed",
	},
	[".caption"] = {
		["valign"] = "center",
	},
	[".knob"] = {
		["padding"] = 5,
	},
	[".legend"] = {
		["border-style"] = "groove",
		["border-width"] = 2,
	},
	[".menuitem"] = {
		["width"] = "fill",
	},
	[".gauge-fill"] = {
		["padding"] = 5,
	},
	["_scrollbar-arrow"] = {
		["min-width"] = 10,
		["min-height"] = 10,
	},
}

-------------------------------------------------------------------------------
--	properties, errmsg = ui.getStyleSheet([name]): Aquires a style sheet
--	from memory, by loading it from disk, or by determining properties at
--	runtime. Predefined names are:
--		- {{"minimal"}} - the hardcoded internal ''user agent'' style sheet
--		- {{"desktop"}} - An external style sheet named "desktop.css",
--		overlayed with the color scheme (and possibly other properties) of
--		the running desktop (if applicable)
--	Any other name will cause this function to attempt to load an equally
--	named style sheet file.
-------------------------------------------------------------------------------

function getStyleSheet(themename)
	if not themename or themename == "minimal" then
		return unpackStyleSheet(DEF_STYLESHEET_DEFAULT)
	end
	local s, msg = loadStyleSheet(themename)
	if themename == "desktop" then
		local success, res = pcall(int_require, "tek.ui.style.desktop")
		if success then
			res.importConfiguration(s)
		else
			db.warn("Failed to import desktop style:\n%s", res)
		end
	end
	return s, msg
end

-------------------------------------------------------------------------------
--	On-demand class loader:
-------------------------------------------------------------------------------

setmetatable(_M, {
	__index = function(tab, key)
		local pname = key:lower()
		local class = loadClass("class", pname, nil, loadSimple)
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
	["IgnoreAltShift"] = { 0x0000, 0x00, 0x10, 0x20, 0x30 },
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
--	key, quals = ui.resolveKeyCode(code): Resolves a combined keycode specifier
--	(e.g. {{"Ctrl+Shift+Q"}}) into a key string and a table of qualifier codes.
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
		if s == "IgnoreCase" or s == "IgnoreAltShift" then
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
--	ui.extractKeyCode(string[, shortcutmark]): Extract a shortcut character
--	from a string. The default shortcut marker is an underscore.
-------------------------------------------------------------------------------

function extractKeyCode(s, m)
	m = m or "_"
	s = s:match("^[^" .. m .. "]*" .. m .. "(.)")
	return s and s:lower() or false
end

-------------------------------------------------------------------------------
--	Constants: 
-------------------------------------------------------------------------------

DEBUG = false
HUGE = 1000000

-- Double click time limit, in microseconds:
DBLCLICKTIME = 320000 -- 600000 for touch screens
-- Max. square pixel distance between clicks:
DBLCLICKJITTER = 70 -- 3000 for touch screens

-------------------------------------------------------------------------------
--	Placeholders for notifications
-------------------------------------------------------------------------------

local Element = require("element", 17)

NOTIFY_ALWAYS = Element.NOTIFY_ALWAYS
NOTIFY_VALUE = Element.NOTIFY_VALUE
NOTIFY_TOGGLE = Element.NOTIFY_TOGGLE
NOTIFY_FORMAT = Element.NOTIFY_FORMAT
NOTIFY_SELF = Element.NOTIFY_SELF
NOTIFY_OLDVALUE = Element.NOTIFY_OLDVALUE
NOTIFY_FUNCTION = Element.NOTIFY_FUNCTION
NOTIFY_WINDOW = Element.NOTIFY_WINDOW
NOTIFY_APPLICATION = Element.NOTIFY_APPLICATION
NOTIFY_ID = Element.NOTIFY_ID
NOTIFY_COROUTINE = Element.NOTIFY_COROUTINE

-------------------------------------------------------------------------------
--	Message types:
-------------------------------------------------------------------------------

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
MSG_ALL         = 0x171f -- all, not including MSG_INTERVAL

-------------------------------------------------------------------------------
--	Flags:
-------------------------------------------------------------------------------

FL_LAYOUT		= 0x0001
FL_REDRAW		= 0x0002
FL_REDRAWBORDER = 0x0004
FL_SETUP		= 0x0008
FL_SHOW			= 0x0010
FL_CHANGED		= 0x0020
FL_POPITEM      = 0x0040
