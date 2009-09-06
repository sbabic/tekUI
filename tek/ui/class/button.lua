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
--		[[#tek.ui.class.text : Text]] /
--		Button
--
--	OVERVIEW::
--		The Button class implements a Text element with a ''button mode''
--		(behavior) and ''button class'' (appearance). In addition to that,
--		it enables the initialization of a possible keyboard shortcut from
--		a special initiatory character (by default an underscore) preceding
--		a letter in the element's {{Text}} attribute.
--
--	NOTES::
--		This class adds redundancy, because it differs from the
--		[[#tek.ui.class.text : Text]] class only in that it specifies a few
--		attributes differently in its {{new()}} method. To avoid this overhead,
--		use the Text class directly, or create a ''Button factory'' like this:
--				function newButton(text)
--				  return ui.Text:new { Mode = "button", Class = "button",
--				    Text = text, KeyCode = true }
--				end
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Text = ui.require("text", 20)

module("tek.ui.class.button", tek.ui.class.text)
_VERSION = "Button 1.5"

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Button = _M

function Button.init(self)
	self.Mode = self.Mode or "button"
	self.Class = self.Class or "button"
	if self.KeyCode == nil then
		self.KeyCode = true
	end
	return Text.init(self)
end
