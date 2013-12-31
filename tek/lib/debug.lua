-------------------------------------------------------------------------------
--
--	tek.lib.debug
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		Debug library - implements debug output and debug levels:
--
--		2  || TRACE || used for trace messages
--		4  || INFO  || informational messages, notices
--		5  || WARN  || something unexpected happened
--		10 || ERROR || something went wrong, e.g. resource unavailable
--		20 || FAIL  || something went wrong that cannot be coped with
--
--		The default debug level is {{WARN}}. To set the debug level
--		globally, e.g.:
--				db = require "tek.lib.debug"
--				db.level = db.INFO
--
--		The default debug output stream is {{stderr}}.
--		To override it globally, e.g.:
--				db = require "tek.lib.debug"
--				db.out = io.open("logfile", "w")
--
--	FUNCTIONS::
--		- debug.console() - Enters the debug console
--		- debug.dump() - Dumps a table recursively
--		- debug.error() - Prints a text in the {{ERROR}} debug level
--		- debug.execute() - Executes a function in the specified debug level
--		- debug.fail() - Prints a text in the {{FAIL}} debug level
--		- debug.info() - Prints a text in the {{INFO}} debug level
--		- debug.print() - Prints a text in the specified debug level
--		- debug.stacktrace() - Prints a stacktrace in the specified debug level
--		- debug.trace() - Prints a text in the {{TRACE}} debug level
--		- debug.warn() - Prints a text in the {{WARN}} debug level
--		- debug.wrout() - Output function
--
--	VALUES::
--		- {{level}} - Debug level, default 5 ({{WARN}})
--		- {{out}} - Output stream, default {{io.stderr}}
--
-------------------------------------------------------------------------------

local debug = require "debug"
local getinfo = debug.getinfo
local stderr = io.stderr
local pairs = pairs
local select = select
local tonumber = tonumber
local tostring = tostring
local traceback = debug.traceback
local type = type
local unpack = unpack or table.unpack

module "tek.lib.debug"
_VERSION = "Debug 5.2"

-- symbolic:

TRACE = 2
INFO = 4
WARN = 5
ERROR = 10
FAIL = 20

-- global defaults:

level = WARN
out = stderr

-------------------------------------------------------------------------------
--	debug.wrout(...): Debug output function, by default
--			function(...) out:write(...) end
-------------------------------------------------------------------------------

wrout = function(...) out:write(...) end

-------------------------------------------------------------------------------
--	debug.format(lvl, msg, ...): Format error message
-------------------------------------------------------------------------------

function format(lvl, msg, ...)
	local t = getinfo(4, "lS")
	return ("(%02d %s:%d) " .. msg .. "\n"):format(lvl, t.short_src,
		t.currentline, ...)
end

-------------------------------------------------------------------------------
--	debug.print(lvl, msg, ...): Prints formatted text if the global debug level
--	is less or equal the specified level.
-------------------------------------------------------------------------------

function print(lvl, msg, ...)
	if level and lvl >= level then
		local arg = { }
		for i = 1, select('#', ...) do
			local v = select(i, ...)
			arg[i] = v ~= nil and tostring(v) or v or "<nil>"
		end
		wrout(format(lvl, msg, unpack(arg)))
	end
end

-------------------------------------------------------------------------------
--	debug.execute(lvl, func, ...): Executes the specified function if the
--	global debug level is less or equal the specified level.
-------------------------------------------------------------------------------

function execute(lvl, func, ...)
	if level and lvl >= level then
		return func(...)
	end
end

-------------------------------------------------------------------------------
--	debug.trace(msg, ...): Prints formatted debug info with {{TRACE}} debug
--	level
-------------------------------------------------------------------------------

function trace(msg, ...) print(2, msg, ...) end

-------------------------------------------------------------------------------
--	debug.info(msg, ...): Prints formatted debug info with {{INFO}} debug level
-------------------------------------------------------------------------------

function info(msg, ...) print(4, msg, ...) end

-------------------------------------------------------------------------------
--	debug.warn(msg, ...): Prints formatted debug info with {{WARN}} debug level
-------------------------------------------------------------------------------

function warn(msg, ...) print(5, msg, ...) end

-------------------------------------------------------------------------------
--	debug.error(msg, ...): Prints formatted debug info with {{ERROR}} debug
--	level
-------------------------------------------------------------------------------

function error(msg, ...) print(10, msg, ...) end

-------------------------------------------------------------------------------
--	debug.fail(msg, ...): Prints formatted debug info with {{FAIL}} debug level
-------------------------------------------------------------------------------

function fail(msg, ...) print(20, msg, ...) end

-------------------------------------------------------------------------------
--	debug.stacktrace(debuglevel[, stacklevel]): Prints a stacktrace starting at
--	the function of the given level on the stack (excluding the
--	{{stracktrace}} function itself) if the global debug level is less
--	or equal the specified {{debuglevel}}.
-------------------------------------------------------------------------------

function stacktrace(lvl, level)
	print(lvl, traceback("", level or 1 + 1))
end

-------------------------------------------------------------------------------
--	debug.console(): Enters debug console.
-------------------------------------------------------------------------------

function console()
	wrout('Entering the debug console.\n')
	wrout('To redirect the output, e.g.:\n')
	wrout('  tek.lib.debug.out = io.open("logfile", "w")\n')
	wrout('To dump a table, e.g.:\n')
	wrout('  tek.lib.debug.dump(app)\n')
	wrout('Use "cont" to continue.\n')
	debug.debug()
end

-------------------------------------------------------------------------------
--	debug.dump(table[, outfunc]): Dumps a table as Lua source using
--	{{outfunc}}. Cyclic references are silently dropped. The default output
--	function is debug.wrout().
-------------------------------------------------------------------------------

local function f_encodenascii(c)
	return ("\\%03d"):format(c:byte())
end

local function encode(s)
	return s:gsub('([%z\001-\031\092"])', f_encodenascii)
end

local function dumpr(tab, indent, outfunc, saved)
	saved[tab] = tab
	local is = ("\t"):rep(indent)
	for key, val in pairs(tab) do
		if not saved[val] then
			outfunc(is)
			local t = type(key)
			if t == "number" or t == "boolean" then
				outfunc('[' .. tostring(key) .. '] = ')
			elseif t == "string" then
				if key:match("[^%a_]") then
					outfunc('["' .. encode(key) .. '"] = ')
				else
					outfunc(key .. ' = ')
				end
			else
				outfunc('["' .. tostring(key) .. '"] = ')
			end
			t = type(val)
			if t == "table" then
				outfunc('{\n')
				dumpr(val, indent + 1, outfunc, saved)
				outfunc(is .. '},\n')
			elseif t == "string" then
				outfunc('"' .. encode(val) .. '",\n')
			elseif t == "number" or t == "boolean" then
				outfunc(tostring(val) .. ',\n')
			else
				outfunc('"' .. tostring(val) .. '",\n')
			end
		end
	end
end

function dump(tab, outf)
	dumpr(tab, 0, outf or wrout, { })
end
