-------------------------------------------------------------------------------
--
--	tek.ui.class.checkmark
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
--		[[#tek.ui.class.gadget : Gadget]] /
--		[[#tek.ui.class.text : Text]] /
--		CheckMark ${subclasses(CheckMark)}
--
--		Specialization of the [[#tek.ui.class.text : Text]] class,
--		implementing a toggle button with a graphical check mark.
--
--	ATTRIBUTES::
--		- {{Image [IG]}} ([[#tek.ui.class.image : Image]])
--			Image to be displayed when the CheckMark element is unselected.
--		- {{SelectImage [IG]}} ([[#tek.ui.class.image : Image]])
--			Image to be displayed when the CheckMark element is selected.
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Area:draw()
--		- Object.init()
--		- Area:layout()
--		- Class.new()
--		- Area:setState()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"

local Text = ui.require("text", 24)

local floor = math.floor
local max = math.max
local unpack = unpack

module("tek.ui.class.checkmark", tek.ui.class.text)
_VERSION = "CheckMark 7.0"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local CheckImage1 = ui.getStockImage("checkmark")
local CheckImage2 = ui.getStockImage("checkmark", 2)

local DEF_IMAGEMINHEIGHT = 18

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local CheckMark = _M

function CheckMark.new(class, self)
	self = self or { }
	self.ImageRect = { 0, 0, 0, 0 }
	return Text.new(class, self)
end

function CheckMark.init(self)
	self.SelectImage = self.SelectImage or CheckImage2
	self.Image = self.Image or CheckImage1
	self.ImageHeight = false
	self.ImageMinHeight = self.ImageMinHeight or DEF_IMAGEMINHEIGHT
	self.ImageWidth = false
	if self.KeyCode == nil then
		self.KeyCode = true
	end
	self.Mode = self.Mode or "toggle"
	self.OldSelected = false
	return Text.init(self)
end

-------------------------------------------------------------------------------
--	askMinMax:
-------------------------------------------------------------------------------

function CheckMark:askMinMax(m1, m2, m3, m4)
	local tr = self.TextRecords and self.TextRecords[1]
	if tr then
		local w, h = tr[9], tr[10]
		local ih, iw = max(h, self.ImageMinHeight or h)
		iw, ih = self.Application.Display:fitMinAspect(ih, ih, 1, 1, 0)
		self.ImageWidth = iw
		self.ImageHeight = ih
		h = max(0, ih - h)
		local h2 = floor(h / 2)
		tr[5] = iw
		tr[6] = h2
		tr[7] = 0
		tr[8] = h - h2
	end
	return Text.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	layout:
-------------------------------------------------------------------------------

function CheckMark:layout(x0, y0, x1, y1, markdamage)
	if Text.layout(self, x0, y0, x1, y1, markdamage) then
		local i = self.ImageRect
		local r = self.Rect
		local p1, p2, p3, p4 = self:getPadding()
		local eh = r[4] - r[2] - p4 - p2 + 1
		local iw = self.ImageWidth
		local ih = self.ImageHeight
		i[1] = r[1] + p1
		i[2] = r[2] + p2 + floor((eh - ih) / 2)
		i[3] = i[1] + iw - 1
		i[4] = i[2] + ih - 1
		return true
	end
end

-------------------------------------------------------------------------------
--	draw:
-------------------------------------------------------------------------------

function CheckMark:draw()
	if Text.draw(self) then
		local img = self.Selected and self.SelectImage or self.Image
		if img then
			img:draw(self.Drawable, unpack(self.ImageRect))
		end
		return true
	end
end

-------------------------------------------------------------------------------
--	setState:
-------------------------------------------------------------------------------

function CheckMark:setState(bg, fg)
	local props = self.Properties

	-- in checkmarks, Hilite has precedence over Selected:
	if not bg and self.Hilite then
		bg = props["background-color:hover"]
	end
	if not fg and self.Hilite then
		fg = props["color:hover"]
	end

	if not bg and self.Focus then
		bg = props["background-color:focus"]
	end
	if not fg and self.Focus then
		fg = props["color:focus"]
	end


	if self.Selected ~= self.OldSelected then
		self.OldSelected = self.Selected
		self.Flags:set(ui.FL_REDRAW)
	end
	Text.setState(self, bg, fg)
end
