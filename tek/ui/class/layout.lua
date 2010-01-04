-------------------------------------------------------------------------------
--
--	tek.ui.class.layout
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		Layout ${subclasses(Layout)}
--
--		A layouter implements a group's
--		layouting strategy. The {{"default"}} layouter implements a dynamic,
--		scalable layout, which adapts to the free space available to the
--		group.
--
--	IMPLEMENTS::
--		- Layout:layout() - Layouts the group
--		- Layout:askMinMax() - Queries the group's minimum and maximum
--		size requirements
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Class = require "tek.class"
local error = error

module("tek.ui.class.layout", tek.class)
_VERSION = "Layout 1.0"

local Layout = _M

-------------------------------------------------------------------------------
--	Layout:layout(group, x0, y0, x1, y1[, markdamage]):
--	Layouts the [[#tek.ui.class.group : Group]] into the specified
--	rectangle and calculates the new sizes and positions of all of its
--	children. The optional boolean {{markdamage}} is passed to subsequent
--	invocations of [[child:layout()][#Area:layout]]. This function will
--	also call the [[punch()][#Area:punch]] method on each child for
--	subtracting their new outlines from the group's {{FreeRegion}}.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--	minw, minh, maxw, maxh = Layout:askMinMax(group, minw, minh, maxw, maxh):
--	This function queries the specified [[#tek.ui.class.group : Group]] for
--	its size requirements.
-------------------------------------------------------------------------------

