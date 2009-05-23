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
--		This class implements an element's borders. The {{"default"}} border
--		class handles up to three sub borders:
--			* The 'main' border is the innermost of the three sub borders.
--			It is used to render the primary border style, which can be
--			{{"inset"}}, {{"outset"}}, {{"ridge"}}, {{"groove"}}, or
--			{{"solid"}}. This border has priority over the other two.
--			* The 'rim' border seperates the two other borders and
--			may give the composition a more contrastful appearance. This
--			border has the lowest priority.
--			* The 'focus' border (in addition to the element's focus
--			highlighting style) can be used to visualize that the element
--			is currently receiving the input. This border is designed as
--			the outermost of the three sub borders. When the element is
--			in unfocused state, this border often appears in the same color
--			as the surrounding group, which makes it indistinguishable from
--			the background.
--		Border classes (which are organized as plug-ins) do not need to
--		implement all sub borders; in fact, these properties are all
--		internally handled by the {{"default"}} border class, and more (and
--		other) sub borders and properties may be defined and implemented in
--		the future (or in other border classes). As the Frame class has no
--		notion of sub borders, their respective widths are subtracted
--		from the Element's total border width, leaving only the remaining
--		width for the 'main' border.
--
--	ATTRIBUTES::
--		- {{Border [IG]}} (table)
--			An array of four widths (in pixels) for the element's
--			border, in the order left, right, top, bottom. This attribute
--			is controllable via the {{border-width}} style property.
--		- {{BorderClass [IG]}} (table)
--			Name of the border class used to implement this element's
--			border. This attribute is controllable via the {{border-class}}
--			style property. Default: {{"default"}}
--		- {{BorderRegion [G]}} ([[#tek.lib.region : Region]])
--			Region object holding the outline of the element's border
--		- {{Legend [IG]}} (string)
--			Border legend text [Default: '''false''']
--
--	STYLE PROPERTIES::
--		- {{border-bottom-color}} - controls the {{"default"}} border class
--		- {{border-bottom-width}} - controls {{Frame.Border}}
--		- {{border-class}} - controls {{Frame.BorderClass}}
--		- {{border-color}} - controls the {{"default"}} border class
--		- {{border-focus-color}} - controls the {{"default"}} border class
--		- {{border-focus-width}} - controls the {{"default"}} border class
--		- {{border-left-color}} - controls the {{"default"}} border class
--		- {{border-left-width}} - controls {{Frame.Border}}
--		- {{border-legend-font}} - controls the {{"default"}} border class
--		- {{border-right-color}} - controls the {{"default"}} border class
--		- {{border-right-width}} - controls {{Frame.Border}}
--		- {{border-rim-color}} - controls the {{"default"}} border class
--		- {{border-rim-width}} - controls the {{"default"}} border class
--		- {{border-style}} - controls the {{"default"}} border class
--		- {{border-top-color}} - controls the {{"default"}} border class
--		- {{border-top-width}} - controls {{Frame.Border}}
--		- {{border-width}} - controls {{Frame.Border}}
--
--	IMPLEMENTS::
--		- Frame:drawBorder() - Draws the element's border
--		- Frame:getBorder() - Queries the element's border
--
--	OVERRIDES::
--		- Element:getProperties()
--		- Area:hide()
--		- Object.init()
--		- Area:layout()
--		- Area:damage()
--		- Area:punch()
--		- Area:refresh()
--		- Element:setup()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Area = ui.Area
local allocRegion = ui.allocRegion
local freeRegion = ui.freeRegion

module("tek.ui.class.frame", tek.ui.class.area)
_VERSION = "Frame 8.0"

local Frame = _M

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Frame.init(self)
	self.Legend = self.Legend or false
	if self.Legend then
		local t = self.Class
		if t then
			t = t .. " legend"
		else
			t = "legend"
		end
		self.Class = t
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
	b[1] = b[1] or self:getNumProperty(p, pclass, "border-left-width")
	b[2] = b[2] or self:getNumProperty(p, pclass, "border-top-width")
	b[3] = b[3] or self:getNumProperty(p, pclass, "border-right-width")
	b[4] = b[4] or self:getNumProperty(p, pclass, "border-bottom-width")
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
--	cleanup: overrides
-------------------------------------------------------------------------------

function Frame:cleanup()
	self.BorderObject = ui.destroyHook(self.BorderObject)
	Area.cleanup(self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Frame:show(drawable)
	local b = self.BorderObject
	if b then
		b:show(drawable)
	end
	Area.show(self, drawable)
	if self.Focus then
		self:setValue("Focus", true, true)
	end
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Frame:hide()
	local b = self.BorderObject
	if b then
		b:hide()
	end
	self.BorderRegion = freeRegion(self.BorderRegion)
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
--	border = getBorder(): Returns an element's border widths in the
--	order left, top, right, bottom.
-------------------------------------------------------------------------------

function Frame:getBorder()
	if self.BorderObject then
		return self.BorderObject:getBorder()
	end
	return 0, 0, 0, 0
end

-------------------------------------------------------------------------------
--	damage: overrides
-------------------------------------------------------------------------------

function Frame:damage(r1, r2, r3, r4)
	Area.damage(self, r1, r2, r3, r4)
	if self.BorderRegion and
		self.BorderRegion:checkIntersect(r1, r2, r3, r4) then
		self.RedrawBorder = true
	end
end

-------------------------------------------------------------------------------
--	layout: overrides. Additionally maintains a border region.
-------------------------------------------------------------------------------

function Frame:layout(r1, r2, r3, r4, markdamage)
	local changed, border_ok = Area.layout(self, r1, r2, r3, r4, markdamage)
	if changed and self.BorderObject then
		-- getRegion() implies layout(); also, reuse existing region:
		self.BorderRegion = self.BorderObject:getRegion(self.BorderRegion or
			allocRegion())
		-- using the border_ok hack, we avoid redrawing the border when the
		-- object was just copied:
		if not border_ok and markdamage ~= false then
			self.RedrawBorder = true
		end
	end
	return changed
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
		self.RedrawBorder = false
	end
end

-------------------------------------------------------------------------------
--	getElementByXY: overrides
-------------------------------------------------------------------------------

function Frame:getElementByXY(x, y)
	local r1, r2, r3, r4 = self:getRect()
	if r1 then
		local b1, b2, b3, b4 = self:getBorder()
		return x >= r1 - b1 and x <= r3 + b3 and y >= r2 - b2 and
			y <= r4 + b4 and self
	end
end
