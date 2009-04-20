-------------------------------------------------------------------------------
--
--	tek.ui.class.radiobutton
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
--		[[#tek.ui.class.checkmark : CheckMark]] /
--		RadioButton
--
--	OVERVIEW::
--		Specialization of a [[#tek.ui.class.checkmark : CheckMark]] to
--		implement mutually exclusive 'radio buttons'; they really make
--		sense only if more than one of their kind are grouped together.
--
--	OVERRIDES::
--		- Object.init()
--		- Gadget:onSelect()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local CheckMark = ui.CheckMark
local VectorImage = ui.VectorImage
local ipairs = ipairs

module("tek.ui.class.radiobutton", tek.ui.class.checkmark)
_VERSION = "RadioButton 2.7"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local RadioImage1 = ui.createImage("radio")
local RadioImage2 = ui.createImage("radio", 2)

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local RadioButton = _M

function RadioButton.init(self)
	self.Image = self.Image or RadioImage1
	self.AltImage = self.AltImage or RadioImage2
	self.Mode = self.Mode or "touch"
	return CheckMark.init(self)
end

-------------------------------------------------------------------------------
--	onSelect:
-------------------------------------------------------------------------------

function RadioButton:onSelect(selected)
	if selected then
		-- unselect siblings in group:
		local myclass = self:getClass()
		for _, e in ipairs(self:getElement("siblings")) do
			if e ~= self and e:getClass() == myclass and e.Selected then
				e:setValue("Selected", false) -- no notify
			end
		end
	end
	CheckMark.onSelect(self, selected)
end
