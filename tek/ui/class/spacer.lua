-------------------------------------------------------------------------------
--
--	tek.ui.class.spacer
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		[[#tek.ui.class.frame : Frame]] /
--		Spacer ${subclasses(Spacer)}
--
--		This class implements a separator that helps to arrange elements in
--		a group.
--
--	OVERRIDES::
--		- Element:setup()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Frame = ui.require("frame", 21)

module("tek.ui.class.spacer", tek.ui.class.frame)
_VERSION = "Spacer 2.1"

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Spacer = _M

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Spacer:setup(app, win)
	Frame.setup(self, app, win)
	if self:getGroup().Orientation == "horizontal" then
		self.MaxWidth = 0
		self.MaxHeight = ui.HUGE
		self.Height = "fill"
	else
		self.MaxWidth = ui.HUGE
		self.MaxHeight = 0
		self.Width = "fill"
	end
end
