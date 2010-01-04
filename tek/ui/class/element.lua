-------------------------------------------------------------------------------
--
--	tek.ui.class.element
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		Element ${subclasses(Element)}
--
--		This class implements the connection to a global environment and
--		the registration by Id.
--
--	ATTRIBUTES:
--		- {{Application [G]}} ([[#tek.ui.class.application : Application]])
--			The Application the element is registered with.
--			This attribute is set during Element:setup().
--		- {{Class [IG]}} (string)
--			The name of the element's style class, which can be referenced
--			in a style sheet. Multiple classes can be specified by separating
--			them with spaces, e.g. {{"button knob warn"}}
--		- {{Id [IG]}} (string)
--			An unique Id identifying the element. If present, this Id will be
--			registered with the Application during Element:setup().
--		- {{Parent [G]}} (object)
--			Parent object of the element. This attribute is set during
--			Element:connect().
--		- {{Properties [G]}} (table)
--			A table of properties, resulting from element and user style
--			classes, overlaid with individual and direct formattings, and
--			finally from hardcoded element properties. This table is set up
--			during Element:decodeProperties().
--		- {{Style [IG]}} (string)
--			Direct style formattings of the element, overriding class-wide
--			formattings in a style sheet. Example:
--					"background-color: #880000; color: #ffff00"
--		- {{Window [G]}} ([[#tek.ui.class.window : Window]])
--			The Window the element is registered with. This
--			attribute is set during Element:setup().
--
--	IMPLEMENTS::
--		- Element:addStyleClass() - Appends a style class to an element
--		- Element:cleanup() - Unlinks the element from its environment
--		- Element:connect() - Connects the element to a parent element
--		- Element:decodeProperties() - Decode the element's style properties
--		- Element:disconnect() - Disconnects the element from its parent
--		- Element:getAttr() - Gets an attribute from an element
--		- Element:getById() - Get Id of any registered element
--		- Element:setup() - Links the element to its environment
--
--	OVERRIDES::
--		- Object.init()
--
-------------------------------------------------------------------------------

local Object = require "tek.class.object"
local ui = require "tek.ui"
local db = require "tek.lib.debug"

local assert = assert
local concat = table.concat
local getmetatable = getmetatable
local insert = table.insert
local pairs = pairs
local setmetatable = setmetatable
local sort = table.sort
local tonumber = tonumber
local type = type

module("tek.ui.class.element", tek.class.object)
_VERSION = "Element 16.1"
local Element = _M

-------------------------------------------------------------------------------
--	Placeholders for notification arguments:
-------------------------------------------------------------------------------

-- inserts the Window:
NOTIFY_WINDOW = function(a, n, i)
	insert(a, a[-1].Window)
	return 1
end

-- inserts the Application:
NOTIFY_APPLICATION = function(a, n, i)
	insert(a, a[-1].Application)
	return 1
end

-- inserts an object of the given Id:
NOTIFY_ID = function(a, n, i)
	insert(a, a[-1].Application:getById(n[i + 1]))
	return 2
end

-- denotes insertion of a function value as a new coroutine:
NOTIFY_COROUTINE = function(a, n, i)
	insert(a, function(...) a[-1].Application:addCoroutine(n[i + 1], ...) end)
	return 2
end

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Element.init(self)
	self.Application = false
	self.Class = self.Class or false
	self.Id = self.Id or false
	self.Parent = false
	self.Properties = false
	self.Style = self.Style or false
	self.Window = false
	return Object.init(self)
end

-------------------------------------------------------------------------------
--	success = Element:connect(parent): Attempts to connect the element to the
--	{{parent}} element; returns a boolean indicating whether the connection
--	succeeded.
-------------------------------------------------------------------------------

function Element:connect(parent)
	self.Parent = parent
	return true
end

-------------------------------------------------------------------------------
--	Element:disconnect(): Disconnects the element from its parent.
-------------------------------------------------------------------------------

function Element:disconnect()
	self.Parent = false
end

-------------------------------------------------------------------------------
--	Element:connectProperties: Connect an element's element style properties
-------------------------------------------------------------------------------

function Element:connectProperties(stylesheets)
	local class = self:getClass()
	local ups
	local topclass
	while class ~= Element do
		for i = 1, #stylesheets do
			local s = stylesheets[i][class._NAME]
			if s then
				if not topclass then
					topclass = s
				end
				if ups then
					if getmetatable(ups) == s then
						-- already connected
						return topclass
					else
						setmetatable(ups, s)
						s.__index = s
					end
				end
				ups = s
			end
		end
		class = class:getSuper()
	end
	return topclass
end

-------------------------------------------------------------------------------
--	Element:decodeUserClasses:
-------------------------------------------------------------------------------

local function mergeprops(source, dest)
	if source then
		for key, val in pairs(source) do
			if not dest[key] then
				dest[key] = val
			end
		end
	end
end

function Element:decodeUserClasses(stylesheets, props)
	local class = self.Class
	if class then
		local classname = self._NAME
		local cachekey = classname .. "." .. class
		-- do we have a this combination in our cache?
		local record = stylesheets[0][cachekey]
		if not record then
			-- create new record and cache it:
			record = { }
			stylesheets[0][cachekey] = record
			-- elementclass.class is more specific than just .class,
			-- so they must be treated in that order:
			class:gsub("(%S+)", function(c)
				for i = 1, #stylesheets, 1 do
					mergeprops(stylesheets[i][classname .. "." .. c], record)
				end
			end)
			class:gsub("(%S+)", function(c)
				for i = 1, #stylesheets, 1 do
					mergeprops(stylesheets[i]["." .. c], record)
				end
			end)
			record.__index = record
		end
		if props then
			props = setmetatable(record, props)
		else
			props = record
		end
	end
	return props
end

-------------------------------------------------------------------------------
--	Element:decodeIndividualFormats:
-------------------------------------------------------------------------------

function Element:decodeIndividualFormats(stylesheets, props)
	local individual_formats
	local id = self.Id
	if id then
		individual_formats = { }
		for i = #stylesheets, 1, -1 do
			local s = stylesheets[i]["#" .. id]
			if s then
				for key, val in pairs(s) do
					individual_formats[key] = val
				end
			end
		end
	end
	if self.Style then
		individual_formats = individual_formats or { }
		for key, val in self.Style:gmatch("%s*([^;:]+)%s*:%s*([^;]+);?") do
			ui.unpackProperty(individual_formats, key, val, "")
		end
	end
	if individual_formats then
		if props then
			props = setmetatable(individual_formats, props)
		else
			props = individual_formats
		end
	end
	return props
end

-------------------------------------------------------------------------------
--	Element:decodeProperties(stylesheets): This function decodes the element's
--	style properties and places them in the {{Properties}} table.
-------------------------------------------------------------------------------

local empty = { }

function Element:decodeProperties(stylesheets)
	-- connect element style classes:
	local props = self:connectProperties(stylesheets)
	if props then
		props.__index = props
	end
	-- overlay with user classes:
	props = self:decodeUserClasses(stylesheets, props)
	-- overlay with individual and direct formattings:
	props = self:decodeIndividualFormats(stylesheets, props)
	-- hardcoded class properties:
	local cprops = self:getClass().Properties
	if cprops then
		props.__index = props
		props = setmetatable(cprops, props or empty)
	end
	self.Properties = props or empty
end

-------------------------------------------------------------------------------
--	Element:setup(app, window): This function is used to pass the element the
--	environment determined by an [[#tek.ui.class.application : Application]]
--	and a [[#tek.ui.class.window : Window]].
-------------------------------------------------------------------------------

function Element:setup(app, window)
-- 	assert(app and app:instanceOf(ui.Application), "No Application")
-- 	assert(window and window:instanceOf(ui.Window), "No Window")
-- 	assert(not self.Application, 
-- 		("%s: Application already set"):format(self:getClassName()))
-- 	assert(not self.Window,
-- 		("%s: Window already set"):format(self:getClassName()))
	self.Application = app
	self.Window = window
	if self.Id then
		self.Application:addElement(self)
	end
end

-------------------------------------------------------------------------------
--	Element:cleanup(): This function is used to unlink the element from its
--	[[#tek.ui.class.application : Application]] and
--	[[#tek.ui.class.window : Window]].
-------------------------------------------------------------------------------

function Element:cleanup()
	if self.Id then
		self.Application:remElement(self)
	end
	self.Application = false
	self.Window = false
end

-------------------------------------------------------------------------------
--	Element:getById(id): Gets the element with the specified {{id}}, that was
--	previously registered with the [[#tek.ui.class.application : Application]].
--	This function is a shortcut for Application:getById(), applied to
--	{{self.Application}}.
-------------------------------------------------------------------------------

function Element:getById(id)
	return self.Application:getById(id)
end

-------------------------------------------------------------------------------
--	ret1, ... = Element:getAttr(attribute, ...): This function gets a named
--	{{attribute}} from an element, and returns '''nil''' if it is unknown.
--	This mechanism can be used by classes for exchanging data without having
--	to add a getter method in their common base class (which may not be under
--	the author's control).
-------------------------------------------------------------------------------

function Element:getAttr()
end

-------------------------------------------------------------------------------
--	Element:addStyleClass(styleclass) - Appends a style class to an element's
--	{{Class}} attribute, if it is not already present.
-------------------------------------------------------------------------------

function Element:addStyleClass(styleclass)
	local class = self.Class
	if class then
		for c in class:gmatch("%S+") do
			if c == styleclass then
				return
			end
		end
		class = class .. " " .. styleclass
	else
		class = styleclass
	end
	self.Class = class
end
