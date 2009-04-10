-------------------------------------------------------------------------------
--
--	tek.ui.class.menuitem
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
--		[[#tek.ui.class.popitem : PopItem]] /
--		MenuItem
--
--	OVERVIEW::
--		This class implements the basic items for window menus and popups.
--		In particular, it displays a [[#tek.ui.class.popitem : PopItem]]'s
--		{{Shortcut}} attribute and an arrow to indicate that there is a
--		sub menu.
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

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local PopItem = ui.PopItem
local VectorImage = ui.VectorImage
local max = math.max
local floor = math.floor

module("tek.ui.class.menuitem", tek.ui.class.popitem)
_VERSION = "MenuItem 5.1"

-------------------------------------------------------------------------------
--	Constants and class data:
-------------------------------------------------------------------------------

local prims = { { 0x1000, 3, Points = { 1, 2, 3 }, Pen = ui.PEN_MENUDETAIL } }

local ArrowImage = VectorImage:new
{
	ImageData =
	{
		Coords = { 0x7000,0x4000, 0x7000,0xc000, 0xc000,0x8000 },
		Primitives = prims,
	}
}

-------------------------------------------------------------------------------
--	MenuItem class:
-------------------------------------------------------------------------------

local MenuItem = _M

function MenuItem.new(class, self)
	self = self or { }
	-- prevent superclass from filling in text records:
	self.TextRecords = self.TextRecords or { }
	return PopItem.new(class, self)
end

function MenuItem.init(self)
	self.MaxHeight = self.MaxHeight or 0
	if self.Children then
		self.Mode = "toggle"
	else
		self.Mode = "button"
	end
	self.ShortcutMark = self.ShortcutMark or ui.ShortcutMark
	self.TextHAlign = "left"
	return PopItem.init(self)
end

function MenuItem:show(display, drawable)
	if self.Children then
		if self.PopupBase then
			self.Image = ArrowImage
			self.ImageRect = { 0, 0, 0, 0 }
		end
	end
	if PopItem.show(self, display, drawable) then
		self:setTextRecord(1, self.Text, self.Font, "left")
		if self.Shortcut and -- self.Parent.Class ~= "menubar" and
			not self.Children then
			self:setTextRecord(2, self.Shortcut, self.Font, "left")
		end
		return true
	end
end

function MenuItem:submenu(val)
	-- subitems are handled in baseclass:
	PopItem.submenu(self, val)
	-- handle baseitem:
	if self.Window then
		local popup = self.Window.ActivePopup
		if popup then
			-- hilite over baseitem while another open popup in menubar:
			if val == true and popup ~= self then
				db.info("have another popup open")
				self:beginPopup()
				self:setValue("Selected", true)
			end
		end
	end
end

function MenuItem:beginPopup()
	if self.Window and self.Window.ActivePopup and
		self.Window.ActivePopup ~= self then
		-- close already open menu in same group:
		self.Window.ActivePopup:endPopup()
	end
	-- subitems are handled in baseclass:
	PopItem.beginPopup(self)
	-- handle baseitem:
	if self.Window then
		self.Window.ActivePopup = self
	end
end

function MenuItem:endPopup()
	-- subitems are handled in baseclass:
	PopItem.endPopup(self)
	-- handle baseitem:
	if self.Window then
		self.Window.ActivePopup = false
	end
end
