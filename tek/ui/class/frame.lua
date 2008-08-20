-------------------------------------------------------------------------------
--
--	tek.ui.class.frame
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		Frame
--
--	OVERVIEW::
--		This class implements an element's borders. There are up to three
--		borders implemented per element:
--		Besides the main border, there is a 'focus' border that (in addition
--		to the element's focus highlighting style) can be used to visualize
--		that the element is currently receiving the input. Between main
--		border and 'focus' border, there is an additional 'rim' border that
--		can help to separate these two visually.
--		Note that borders (which are organized as plug-ins) don't have to
--		implement all sub borders; in fact, these properties are all
--		internally handled by the default border hook, and more and other
--		sub borders and properties may be defined and implemented in the
--		future (or in other hooks). As the Frame class has no knowledge of
--		sub borders, their respective widths are subtracted from the
--		Element's total border width, leaving only the remaining width
--		for the main border.
--
--	ATTRIBUTES::
--		- {{Border [IG]}} (table)
--			An array of four widths (in pixels) for the element's
--			border, in the order left, right, top, bottom.
--		- {{BorderRegion [G]}} ([[#tek.lib.region : Region]])
--			Region object holding the outline of the element's border
--		- {{Legend [IG]}} (string)
--			Border legend text [Default: '''false''']
--
--	STYLE PROPERTIES::
--		- {{border-bottom-color}}
--		- {{border-bottom-width}}
--		- {{border-color}}
--		- {{border-focus-color}}
--		- {{border-focus-width}}
--		- {{border-left-color}}
--		- {{border-left-width}}
--		- {{border-legend-font}}
--		- {{border-right-color}}
--		- {{border-right-width}}
--		- {{border-rim-color}}
--		- {{border-rim-width}}
--		- {{border-style}}
--		- {{border-top-color}}
--		- {{border-top-width}}
--		- {{border-width}}
--
--	IMPLEMENTS::
--		- Frame:drawBorder() - Draws one of the element's borders
--		- Frame:getBorder() - Returns one of the element's borders
--
--	OVERRIDES::
--		- Element:cleanup()
--		- Area:draw()
--		- Area:hide()
--		- Object.init()
--		- Area:layout()
--		- Area:markDamage()
--		- Class.new()
--		- Area:punch()
--		- Area:refresh()
--		- Element:setup()
--		- Area:show()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local Area = ui.Area
local Region = require "tek.lib.region"
local floor = math.floor
local min = math.min
local max = math.max
local newRegion = Region.new
local tonumber = tonumber
local unpack = unpack

module("tek.ui.class.frame", tek.ui.class.area)
_VERSION = "Frame 4.1"

local Frame = _M

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Frame.init(self)
	self.Legend = self.Legend or false
	if self.Legend then
		self.Class = self.Class and self.Class .. " legend" or "legend"
	end
	self.BorderHook = false
	self.Border = self.Border or { }
	self.BorderRegion = false
	self.RedrawBorder = false
	return Area.init(self)
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function Frame:getProperties(p, pclass)
	local b = self.Border
	b[1] = b[1] or tonumber(self:getProperty(p, pclass, "border-left-width"))
	b[2] = b[2] or tonumber(self:getProperty(p, pclass, "border-top-width"))
	b[3] = b[3] or tonumber(self:getProperty(p, pclass, "border-right-width"))
	b[4] = b[4] or tonumber(self:getProperty(p, pclass, "border-bottom-width"))
	Area.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Frame:setup(app, window)
	Area.setup(self, app, window)
	local b = self.Border
	if (b[1] and b[1] > 0) or (b[2] and b[2] > 0) or
		(b[3] and b[3] > 0) or (b[4] and b[4] > 0) then
		self.BorderHook = ui.createHook("border", "default", self,
			{ Border = b, Legend = self.Legend, Style = self.Style })
	end
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Frame:show(display, drawable)
	if self.Focus then
		self:onFocus(self.Focus)
	end
	if self.BorderHook then
		self.BorderHook:show(display, drawable)
	end
	return Area.show(self, display, drawable)
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Frame:hide()
	if self.BorderHook then
		self.BorderHook:hide()
	end
	self.BorderRegion = false
	Area.hide(self)
end

-------------------------------------------------------------------------------
--	calcOffsets: overrides
-------------------------------------------------------------------------------

function Frame:calcOffsets()
	local b1, b2, b3, b4 = self:getBorder()
	local m = self.Margin
	local d = self.MarginAndBorder
	d[1], d[2], d[3], d[4] = b1 + m[1], b2 + m[2], b3 + m[3], b4 + m[4]
end

-------------------------------------------------------------------------------
--	border = Frame:getBorder(): Returns an element's border widths in the
--	order left, top, right, bottom.
-------------------------------------------------------------------------------

function Frame:getBorder()
	if self.BorderHook then
		return self.BorderHook:getBorder()
	end
	return 0, 0, 0, 0
end

-------------------------------------------------------------------------------
--	markDamage: overrides
-------------------------------------------------------------------------------

function Frame:markDamage(r1, r2, r3, r4)
	Area.markDamage(self, r1, r2, r3, r4)
	if self.BorderRegion and
		self.BorderRegion:checkOverlap(r1, r2, r3, r4) then
		self.RedrawBorder = true
	end
end

-------------------------------------------------------------------------------
--	layout: overrides - additionally maintains a border region
-------------------------------------------------------------------------------

function Frame:layout(r1, r2, r3, r4, markdamage)
	local res = Area.layout(self, r1, r2, r3, r4, markdamage)
	if res and self.BorderHook then
		-- getBorderRegion() implies layout():
		self.BorderRegion = self.BorderHook:getBorderRegion()
		self.RedrawBorder = markdamage ~= false
	end
	return res
end

-------------------------------------------------------------------------------
--	punch: overrides
-------------------------------------------------------------------------------

function Frame:punch(region)
	Area.punch(self, region)
	region:subRegion(self.BorderRegion)
end

-------------------------------------------------------------------------------
--	refresh: overrides
-------------------------------------------------------------------------------

function Frame:refresh()
	Area.refresh(self)
	if self.RedrawBorder and self.BorderHook then
		self.BorderHook:draw(self.Drawable)
	end
	self.RedrawBorder = false
end

-------------------------------------------------------------------------------
--	getElementByXY: overrides
-------------------------------------------------------------------------------

function Frame:getElementByXY(x, y)
	local r = self.Rect
	if r[1] then
		local b1, b2, b3, b4 = self:getBorder()
		return x >= r[1] - b1 and x <= r[3] + b3 and y >= r[2] - b2 and 
			y <= r[4] + b4 and self
	end
	db.warn("%s : layout not available", self:getClassName())
end
