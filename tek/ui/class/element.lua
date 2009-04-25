-------------------------------------------------------------------------------
--
--	tek.ui.class.element
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		Element
--
--	OVERVIEW::
--		This class implements the connection to a global environment and
--		the registration by Id.
--
--	ATTRIBUTES:
--		- {{Application [G]}} ([[#tek.ui.class.application : Application]])
--			The application the element is registered with, or '''false''';
--			this attribute is set in the Element:setup() method.
--		- {{Class [IG]}} (string)
--			The name of the element's style class, which can be referenced
--			in a style sheet, or '''false'''.
--		- {{Id [IG]}} (string)
--			An unique Id identifying the element, or '''false'''. If present,
--			this Id will be registered with the Application during
--			Element:setup().
--		- {{Parent [G]}} (object)
--			Parent object of the element, or '''false'''. This attribute
--			is set in the Element:connect() method.
--		- {{Style [IG]}} (string)
--			Direct style formattings of the element, overriding class-wide
--			formattings in a style sheet, or '''false'''
--		- {{Window [G]}} ([[#tek.ui.class.window : Window]])
--			The window the element is registered with, or '''false'''. This
--			attribute is set when the Element:setup() method is called.
--
--	IMPLEMENTS::
--		- Element:cleanup() - Unlinks the element from its environment
--		- Element:connect() - Connects the element to a parent element
--		- Element:decodeProperties() - Decodes the element's style attributes
--		- Element:disconnect() - Disconnects the element from its parent
--		- Element:getId() - Shortcut for self.Application:getElementById()
--		- Element:getNumProperty() - Retrieves a numerical style property
--		- Element:getProperties() - Retrieves an element's style properties
--		- Element:getProperty() - Retrieves a single style property
--		- Element:setup() - Links the element to its environment
--
--	OVERRIDES::
--		- Object.init()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local Object = require "tek.class.object"
local assert = assert
local insert = table.insert
local tonumber = tonumber
local type = type

module("tek.ui.class.element", tek.class.object)
_VERSION = "Element 12.0"
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
	insert(a, a[-1].Application:getElementById(n[i + 1]))
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
	assert(parent)
	-- assert(not self.Parent)
	self.Parent = parent
	return true
end

-------------------------------------------------------------------------------
--	Element:disconnect(): Disconnects the formerly connected element
--	from its parent.
-------------------------------------------------------------------------------

function Element:disconnect()
	self.Parent = false
end

-------------------------------------------------------------------------------
--	Element:decodeProperties(props): [Internal] Invokes the element's
--	Element:getProperties() function, possibly multiple times, passing it
--	(in turn) the decoded properties from the element's {{Style}} attribute,
--	and global properties from one or more style sheets.
-------------------------------------------------------------------------------

function Element:decodeProperties(props)
	if self.Style then
		-- properties for direct formatting:
		local props = { }
		for key, val in self.Style:gmatch("%s*([^;:]+)%s*:%s*([^;]+);?") do
			props[key:lower()] = val
		end
		ui.prepareProperties { props }
		-- 'true' is the marker for direct formatting:
		self:getProperties(props, true)
	end
	-- global properties:
	self:getProperties(props)
end

-------------------------------------------------------------------------------
--	Element:setup(app, window): This function is used to pass the element the
--	environment determined by an [[#tek.ui.class.application : Application]]
--	and a [[#tek.ui.class.window : Window]].
-------------------------------------------------------------------------------

function Element:setup(app, window)
	if self.Application then
		db.warn("Element already initialized: %s", self:getClassName())
	end
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
	assert(self.Application)
	if self.Id then
		self.Application:remElement(self)
	end
	self.Application = false
	self.Window = false
end

-------------------------------------------------------------------------------
--	value = Element:getProperty(properties, pseudoclass, attribute): Returns
--	the value of a style {{attribute}} from the specified {{properties}}
--	table, or '''false''' if the attribute is undefined. {{pseudoclass}} can
--	be the name of a pseudo class, '''false''' if no pseudo class is used, or
--	'''true''' for looking up the {{attribute}} in the {{properties}} table
--	directly (rather than in a sub table determined by the element's class -
--	this is used for direct formattings).
-------------------------------------------------------------------------------

local function getpropfmt(props, attr, fmt, ...)
	local key = fmt:format(...)
	return props[key] and props[key][attr]
end

function Element:getProperty(props, pclass, attr)

	if pclass == true then
		-- direct formatting:
		return props[attr] or false
	end

	local id = self.Id
	local classname = self._NAME
	local styleclass = self.Class
	local val
	if pclass then
		if id then
			val = getpropfmt(props, attr, "%s#%s:%s", classname, id,
				pclass) or
				getpropfmt(props, attr, "%s#%s", classname, id) or
				getpropfmt(props, attr, "#%s:%s", id, pclass) or
				getpropfmt(props, attr, "#%s", id)
			if val then 
				return val 
			end
		end
		if styleclass then
			for class in styleclass:gmatch("%S+") do
				val = getpropfmt(props, attr, "%s.%s:%s", classname, class,
					pclass) or
					getpropfmt(props, attr, "%s.%s", classname, class) or
					getpropfmt(props, attr, ".%s:%s", class, pclass) or
					getpropfmt(props, attr, ".%s", class)
				if val then 
					return val
				end
			end
		end
		local class = self:getClass()
		while class ~= Element do
			local n = class._NAME
			val = getpropfmt(props, attr, "%s:%s", n, pclass)
				or props[n] and props[n][attr]
			if val then
				return val
			end
			class = class:getSuper()
		end
	else
		if id then
			val = getpropfmt(props, attr, "%s#%s", classname, id) or
				getpropfmt(props, attr, "#%s", id)
			if val then
				return val
			end
		end
		if styleclass then
			for class in styleclass:gmatch("%S+") do
				val = getpropfmt(props, attr, "%s.%s", classname, class) or
					getpropfmt(props, attr, ".%s", class)
				if val then
					return val
				end
			end
		end
		local class = self:getClass()
		while class ~= Element do
			local n = props[class._NAME]
			if n and n[attr] then
				return n[attr]
			end
			class = class:getSuper()
		end
	end
	return false
end

-------------------------------------------------------------------------------
--	value = Element:getNumProperty(properties, pseudoclass, attribute): Gets a
--	property and converts it to a number value. See also Element:getProperty().
-------------------------------------------------------------------------------

function Element:getNumProperty(props, pclass, attr)
	return tonumber(self:getProperty(props, pclass, attr))
end

-------------------------------------------------------------------------------
--	Element:getProperties(properties, pseudoclass): This function is called
--	after connecting the element, for retrieving style properties from a
--	style sheet or from decoding the element's {{Style}} attribute
--	("direct formatting"). It can be invoked multiple times with different
--	pseudo classes and {{properties}}.
--	When you override this function, among the reasonable things to do is to
--	query properties using the Element:getProperty() function, passing it the
--	{{properties}} and {{pseudoclass}} arguments. First recurse into your
--	super class with your own new pseudo classes (if any), and finally pass
--	the call to your super class with the {{pseudoclass}} you received.
-------------------------------------------------------------------------------

function Element:getProperties(p, pclass)
end

-------------------------------------------------------------------------------
--	Element:getId(id): Gets the element with the specified id, under which it
--	was previously registered with the Application. See
--	Application:getElementById(), for which this function is a shortcut.
-------------------------------------------------------------------------------

function Element:getId(id)
	return self.Application:getElementById(id)
end

