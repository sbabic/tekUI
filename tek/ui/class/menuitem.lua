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
--		This class implements basic, recursive items for window and popup
--		menus with a typical menu look; in particular, it displays the
--		[[#tek.ui.class.popitem : PopItem]]'s {{Shortcut}} string and an
--		arrow to indicate the presence of a sub menu.
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
local PopItem = ui.require("popitem", 10)

local max = math.max
local floor = math.floor

module("tek.ui.class.menuitem", tek.ui.class.popitem)
_VERSION = "MenuItem 7.1"

-------------------------------------------------------------------------------
--	Constants and class data:
-------------------------------------------------------------------------------

local ArrowImage = ui.Image:new
{
	{ 0x7000,0x4000, 0x7000,0xc000, 0xb000,0x8000 }, false, false, true,
	{ { 0x1000, 3, { 1, 2, 3 }, ui.PEN_MENUDETAIL } },
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
	self.TextHAlign = "left"
	return PopItem.init(self)
end

function MenuItem:setup(app, win)
	if self.Children then
		if self.PopupBase then
			self.Image = ArrowImage
			self.ImageRect = { 0, 0, 0, 0 }
		end
	end
	PopItem.setup(self, app, win)
	local font = self.Application.Display:openFont(self.Font)
	self:setTextRecord(1, self.Text, font, "left")
	if self.Shortcut and not self.Children then
		self:setTextRecord(2, self.Shortcut, font, "left")
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
