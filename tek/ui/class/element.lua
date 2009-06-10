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
--		- {{Style [IG]}} (string)
--			Direct style formattings of the element, overriding class-wide
--			formattings in a style sheet. Example:
--					"background-color: #880000; color: #ffff00"
--		- {{Window [G]}} ([[#tek.ui.class.window : Window]])
--			The Window the element is registered with. This
--			attribute is set during Element:setup().
--
--	IMPLEMENTS::
--		- Element:cleanup() - Unlinks the element from its environment
--		- Element:connect() - Connects the element to a parent element
--		- Element:disconnect() - Disconnects the element from its parent
--		- Element:getAttr() - Gets an attribute from an element
--		- Element:getById() - Get Id of any registered element
--		- Element:getNumProperty() - Retrieves a numerical style property
--		- Element:getProperties() - Retrieves an element's style properties
--		- Element:getProperty() - Retrieves a single style property
--		- Element:setup() - Links the element to its environment
--
--	OVERRIDES::
--		- Object.init()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Object = require "tek.class.object"
local assert = assert
local insert = table.insert
local tonumber = tonumber
local type = type

module("tek.ui.class.element", tek.class.object)
_VERSION = "Element 14.2"
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
--	Element:decodeProperties(props) - Invokes the element's
--	Element:getProperties() function, possibly multiple times, passing it
--	(in turn) the decoded properties from the element's {{Style}} attribute,
--	and global properties from one or more style sheets. [internal]
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
	assert(not self.Application)
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

function Element:getProperty(props, pclass, attr)

	if pclass == true then
		-- direct formatting:
		return props[attr] or false
	end

	local id = self.Id
	local classname = self._NAME
	local styleclass = self.Class
	local key
	if pclass then
		if id then
			key = props[classname .. "#" .. id .. ":" .. pclass]
			if key and key[attr] then return key[attr] end
			key = props[classname .. "#" .. id]
			if key and key[attr] then return key[attr] end
			key = props["#" .. id .. ":" .. pclass]
			if key and key[attr] then return key[attr] end
			key = props["#" .. id]
			if key and key[attr] then return key[attr] end		
		end
		if styleclass then
			for class in styleclass:gmatch("%S+") do
				key = props[classname .. "." .. class .. ":" .. pclass]
				if key and key[attr] then return key[attr] end
				key = props[classname .. "." .. class]
				if key and key[attr] then return key[attr] end
				key = props["." .. class .. ":" .. pclass]
				if key and key[attr] then return key[attr] end
				key = props["." .. class]
				if key and key[attr] then return key[attr] end
			end
		end
		local class = self:getClass()
		while class ~= Element do
			local n = class._NAME
			key = props[n .. ":" .. pclass]
			if key and key[attr] then return key[attr] end
			key = props[n]
			if key and key[attr] then return key[attr] end
			class = class:getSuper()
		end
	else
		if id then
			key = props[classname .. "#" .. id]
			if key and key[attr] then return key[attr] end
			key = props["#" .. id]
			if key and key[attr] then return key[attr] end
		end
		if styleclass then
			for class in styleclass:gmatch("%S+") do
				key = props[classname .. "." .. class]
				if key and key[attr] then return key[attr] end
				key = props["." .. class]
				if key and key[attr] then return key[attr] end
			end
		end
		local class = self:getClass()
		while class ~= Element do
			key = props[class._NAME]
			if key and key[attr] then return key[attr] end
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
--	(''direct formatting''). It can be invoked multiple times with different
--	{{properties}} and pseudo classes.
--	When overriding this function, among the reasonable things to do is to
--	query properties using the Element:getProperty() function, passing it the
--	{{properties}} and {{pseudoclass}} arguments. First recurse into your
--	super class with the pseudo classes your class defines (if any), and
--	finally pass the call to your super class with the {{pseudoclass}} you
--	received.
-------------------------------------------------------------------------------

function Element:getProperties(p, pclass)
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
