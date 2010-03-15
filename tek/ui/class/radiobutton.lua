-------------------------------------------------------------------------------
--
--	tek.ui.class.radiobutton
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
--		[[#tek.ui.class.widget : Widget]] /
--		[[#tek.ui.class.text : Text]] /
--		[[#tek.ui.class.checkmark : CheckMark]] /
--		RadioButton ${subclasses(RadioButton)}
--
--		Specialization of a [[#tek.ui.class.checkmark : CheckMark]] to
--		implement mutually exclusive 'radio buttons'.
--
--	OVERRIDES::
--		- Object.init()
--		- Widget:onSelect()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local CheckMark = ui.require("checkmark", 9)

module("tek.ui.class.radiobutton", tek.ui.class.checkmark)
_VERSION = "RadioButton 6.0"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local RadioImage1 = ui.getStockImage("radiobutton")
local RadioImage2 = ui.getStockImage("radiobutton", 2)

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local RadioButton = _M

function RadioButton.init(self)
	self.Image = self.Image or RadioImage1
	self.SelectImage = self.SelectImage or RadioImage2
	self.Mode = self.Mode or "touch"
	return CheckMark.init(self)
end

-------------------------------------------------------------------------------
--	onSelect:
-------------------------------------------------------------------------------

function RadioButton:onSelect()
	local selected = self.Selected
	if selected then
		-- unselect siblings in group:
		local myclass = self:getClass()
		local c = self:getSiblings()
		for i = 1, #c do
			local e = c[i]
			if e ~= self and e:getClass() == myclass and e.Selected then
				e:setValue("Selected", false) -- no notify
			end
		end
	end
	CheckMark.onSelect(self)
end
