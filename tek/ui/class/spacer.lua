-------------------------------------------------------------------------------
--
--	tek.ui.class.spacer
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		[[#tek.ui.class.frame : Frame]] /
--		Spacer
--
--	OVERVIEW::
--		This class implements a separator
--		that helps to arrange elements in a group visually.
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Frame = ui.Frame

module("tek.ui.class.spacer", tek.ui.class.frame)
_VERSION = "Spacer 1.5"

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Spacer = _M

-------------------------------------------------------------------------------
--	askMinMax:
-------------------------------------------------------------------------------

function Spacer:askMinMax(m1, m2, m3, m4)
	local o = self.Parent:getStructure()
	if o == 1 then
		self.Height = "fill"
		self.Width = "auto"
	else
		self.Width = "fill"
		self.Height = "auto"
	end
	return Frame.askMinMax(self, m1, m2, m3, m4)
end
