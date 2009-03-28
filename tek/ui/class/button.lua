-------------------------------------------------------------------------------
--
--	tek.ui.class.button
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
--		[[#tek.ui.class.gadget : Gadget]] /
--		[[#tek.ui.class.gadget : Text]] /
--		Button
--
--	OVERVIEW::
--		This gadget implements a Text with 'button' Mode (behavior)
--		and 'button' Class (appearance).
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Text = ui.Text

module("tek.ui.class.button", tek.ui.class.text)
_VERSION = "Button 1.0"

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Button = _M

function Button.init(self)
	self.Mode = self.Mode or "button"
	self.Class = self.Class or "button"
	return Text.init(self)
end
