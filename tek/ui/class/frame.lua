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
--		This class implements an element's borders. The "default" border
--		class (which is selected by default) handles up to three sub borders:
--			* The 'main' border is the innermost of the sub borders. It is
--			used to render the border style, which can currently be "inset",
--			"outset", "ridge", "groove", or "solid".
--			* The 'rim' border seperates the two other borders and
--			may give the border composition a more contrastful look.
--			* The 'focus' border, in addition to the element's focus
--			highlighting style, can be used to visualize that the element
--			is currently receiving the input. This border is designed as
--			the outermost of the three sub borders. When the element is
--			in unfocused state, this border should appear in the same color
--			as the surrounding group, making it indistinguishable from the
--			background.
--		Border classes (which are organized as plug-ins) do not need to
--		implement all sub borders; in fact, their properties are all
--		internally handled by the "default" border class, and more (and other)
--		sub borders and properties may be defined and implemented in the
--		future (or in other border classes). As the Frame class has no
--		notion of sub borders, their respective widths are subtracted
--		from the Element's total border width, leaving only the remaining
--		width for the 'main' border.
--
--	ATTRIBUTES::
--		- {{Border [IG]}} (table)
--			An array of four widths (in pixels) for the element's
--			border, in the order left, right, top, bottom.
--		- {{BorderClass [IG]}} (table)
--			Name of the border class used to implement this element's
--			border. Default: "default"
--		- {{BorderRegion [G]}} ([[#tek.lib.region : Region]])
--			Region object holding the outline of the element's border
--		- {{Legend [IG]}} (string)
--			Border legend text [Default: '''false''']
--
--	STYLE PROPERTIES::
--		- {{border-bottom-color}}
--		- {{border-bottom-width}}
--		- {{border-class}}
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
--		- Frame:drawBorder() - Draws the element's border
--		- Frame:getBorder() - Queries the element's border
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
_VERSION = "Frame 6.1"

local Frame = _M

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Frame.init(self)
	self.Legend = self.Legend or false
	if self.Legend then
		self.Class = self.Class and self.Class .. " legend" or "legend"
	end
	self.BorderObject = false
	self.BorderClass = self.BorderClass or false
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
	self.BorderClass = self.BorderClass or self:getProperty(p, pclass,
		"border-class")
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
		self.BorderObject = ui.createHook("border", self.BorderClass or
			"default", self,
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
	if self.BorderObject then
		self.BorderObject:show(display, drawable)
	end
	return Area.show(self, display, drawable)
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Frame:hide()
	if self.BorderObject then
		self.BorderObject:hide()
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
	if self.BorderObject then
		return self.BorderObject:getBorder()
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
	if res and self.BorderObject then
		-- getBorderRegion() implies layout():
		self.BorderRegion = self.BorderObject:getBorderRegion()
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
--	drawBorder(): Draws an element's border.
-------------------------------------------------------------------------------

function Frame:drawBorder()
	if self.BorderObject then
		self.BorderObject:draw(self.Drawable)
	end
end

-------------------------------------------------------------------------------
--	refresh: overrides
-------------------------------------------------------------------------------

function Frame:refresh()
	Area.refresh(self)
	if self.RedrawBorder then
		self:drawBorder()
	end
	self.RedrawBorder = false
end

-------------------------------------------------------------------------------
--	getElementByXY: overrides
-------------------------------------------------------------------------------

function Frame:getElementByXY(x, y)
	local r1, r2, r3, r4 = self:getRectangle()
	if r1 then
		local b1, b2, b3, b4 = self:getBorder()
		return x >= r1 - b1 and x <= r3 + b3 and y >= r2 - b2 and
			y <= r4 + b4 and self
	end
end
