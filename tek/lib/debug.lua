-------------------------------------------------------------------------------
--
--	tek.lib.debug
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--	Debug library - implements debug output and debug levels:
--
--	2  || TRACE || used for tracking bugs
--	4  || INFO  || informational messages
--	5  || WARN  || something unexpected happened
--	10 || ERROR || something went wrong, e.g. resource unavailable
--	20 || FAIL  || something went wrong that can't be coped with
--
--	The default debug level is 10 {{ERROR}}. To set the debug level
--	globally, e.g.:
--			db = require "tek.lib.debug"
--			db.level = db.INFO
--
--	The default debug output stream is {{stderr}}.
--	To override it globally, e.g.:
--			db = require "tek.lib.debug"
--			db.out = io.open("logfile", "w")
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
--
-------------------------------------------------------------------------------

local debug = require "debug"
local getinfo = debug.getinfo
local stderr = io.stderr
local pairs = pairs
local select = select
local time = os.time
local tonumber = tonumber
local tostring = tostring
local traceback = debug.traceback
local type = type
local unpack = unpack

module "tek.lib.debug"
_VERSION = "Debug 4.1"

-- symbolic:

TRACE = 2
INFO = 4
WARN = 5
ERROR = 10
FAIL = 20

-- global defaults:

level = WARN
out = stderr
wrout = function(...) out:write(...) end

-------------------------------------------------------------------------------
--	print(lvl, msg, ...): Prints formatted text if the global debug level
--	is less or equal the specified level.
-------------------------------------------------------------------------------

function print(lvl, msg, ...)
	if level and lvl >= level then
		local t = getinfo(3, "lS")
		local arg = { }
		for i = 1, select('#', ...) do
			local v = select(i, ...)
			arg[i] = v and type(v) ~= "number" and tostring(v) or v or 0
		end
		wrout(("(%02d %d %s:%d) " .. msg):format(lvl,
			time(), t.short_src, t.currentline, unpack(arg)) .. "\n")
	end
end

-------------------------------------------------------------------------------
--	execute(lvl, func, ...): Executes the specified function if the global
--	debug library is less or equal the specified level.
-------------------------------------------------------------------------------

function execute(lvl, func, ...)
	if level and lvl >= level then
		return func(...)
	end
end

-------------------------------------------------------------------------------
--	trace(msg, ...): Prints formatted debug info with {{TRACE}} level
-------------------------------------------------------------------------------
function trace(msg, ...) print(2, msg, ...) end

-------------------------------------------------------------------------------
--	info(msg, ...): Prints formatted debug info with {{INFO}} level
-------------------------------------------------------------------------------
function info(msg, ...) print(4, msg, ...) end

-------------------------------------------------------------------------------
--	warn(msg, ...): Prints formatted debug info with {{WARN}} level
-------------------------------------------------------------------------------
function warn(msg, ...) print(5, msg, ...) end

-------------------------------------------------------------------------------
--	error(msg, ...): Prints formatted debug info with {{ERROR}} level
-------------------------------------------------------------------------------
function error(msg, ...) print(10, msg, ...) end

-------------------------------------------------------------------------------
--	fail(msg, ...): Prints formatted debug info with {{FAIL}} level
-------------------------------------------------------------------------------
function fail(msg, ...) print(20, msg, ...) end

-------------------------------------------------------------------------------
--	stacktrace(debuglevel, stacklevel): Prints a stacktrace starting at
--	the function of the given {{level}} on the stack (excluding the
--	{{stracktrace}} function itself) if the global debug level is less
--	or equal the specified {{debuglevel}}.
-------------------------------------------------------------------------------

function stacktrace(lvl, level)
	print(lvl, traceback("", level or 1 + 1))
end

-------------------------------------------------------------------------------
--	console(): Enter the debug console.
-------------------------------------------------------------------------------

function console()
	stderr:write('Entering the debug console.\n')
	stderr:write('To redirect the output, e.g.:\n')
	stderr:write('  tek.lib.debug.out = io.open("logfile", "w")\n')
	stderr:write('To dump a table, e.g.:\n')
	stderr:write('  tek.lib.debug.dump(app)\n')
	stderr:write('Use "cont" to continue.\n')
	debug.debug()
end

-------------------------------------------------------------------------------
--	dump(table): Dump a table as Lua source using {{out}} as the output
--	stream. Cyclic references are silently dropped.
-------------------------------------------------------------------------------

local function encodenonascii(c)
	return ("\\%03d"):format(c:byte())
end

local function encode(s)
	return s:gsub('([%z\001-\031\092"])', encodenonascii)
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
