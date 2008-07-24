-------------------------------------------------------------------------------
--
--	tek.ui.class.border
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		Border
--
--	OVERVIEW::
--		This is the base class of all border classes. Border classes are
--		located in the directory {{tek/ui/border}}.
--
--	IMPLEMENTS::
--		- Border:draw() - Draw a border
--		- Border:getBorder() - Get a border class' border thicknesses
--		- Border:getRegion() - Get a region representing the border outline
--		- Border.loadClass() - Load a border class
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Object = require "tek.class.object"
local Region = require "tek.lib.region"
local newRegion = Region.new
local unpack = unpack

module("tek.ui.class.border", tek.class.object)
_VERSION = "Border 4.0"

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Border = _M

-------------------------------------------------------------------------------
--	Border.loadClass(stylename): This function tries to load the named
--	border class; if the class cannot be found, returns the base class.
-------------------------------------------------------------------------------

function Border.loadClass(style)
	local class
	if style and style ~= "" then
		class = ui.loadClass("border", style)
	end
	return class or Border
end

-------------------------------------------------------------------------------
--	left, right, top, bottom = Border:getBorder(element[, borders]):
--	If specified, unpacks and returns the table {{borders}}, otherwise
--	returns the class' default border thicknesses (with possible style
--	variations for the given element) in the order left, right, top, bottom.
-------------------------------------------------------------------------------

function Border:getBorder()
	return 0, 0, 0, 0
end

-------------------------------------------------------------------------------
--	Border:draw(element, bordertab, x0, y0, x1, y1[, nr]): Draws the
--	specified table of border thicknesses into the given rectangle, with
--	possible style variations for the given element. The optional {{nr}}
--	argument determines which border to draw; {{1}} (default) is indicative
--	of the the outer border, {{2}} specifies the element's inner border.
-------------------------------------------------------------------------------

function Border:draw()
end

-------------------------------------------------------------------------------
--	region = Border:getRegion(element, border, x0, y0, x1, y1[, inner]):
--	Returns a [[#tek.lib.region : Region]] representing the outline of the
--	specified border for the given rectangle, with possible style variations
--	for the given element. The optional boolean {{inner}} specifies whether
--	the region is representative of the element's inner border. By default,
--	the region applies to the outer border.
-------------------------------------------------------------------------------

function Border:getRegion(element, border, x0, y0, x1, y1, inner)
	local b1, b2, b3, b4 = self:getBorder(element, border)
	if b1 > 0 or b2 > 0 or b3 > 0 or b4 > 0 then
		if inner then
			local b = newRegion(x0, y0, x1, y1)
			b:subRect(x0 + b1, y0 + b2, x1 - b3, y1 - b4)
			return b
		else
			local b = newRegion(x0 - b1, y0 - b2, x1 + b3, y1 + b4)
			b:subRect(x0, y0, x1, y1)
			return b
		end
	end
	return false
end
