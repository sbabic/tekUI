-------------------------------------------------------------------------------
--
--	tek.ui.class.poplist
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
--		PopList
--
--	OVERVIEW::
--		This class is a specialization of a PopItem allowing the user
--		to choose an item from a list.
--
--	ATTRIBUTES::
--		- {{ListObject [IG]}} ([[#tek.class.list : List]])
--			List object
--		- {{SelectedLine [ISG]}} (number)
--			Number of the selected entry, or 0 if none is selected. Changing
--			this attribute invokes the PopList:onSelectLine() method.
--
--	IMPLEMENTS::
--		- PopList:onSelectLine() - Handler for the {{SelectedLine}} attribute
--		- PopList:setList() - Sets a new list object
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Area:cleanup()
--		- Area:draw()
--		- Object.init()
--		- Class.new()
--		- Area:setup()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local List = require "tek.class.list"
local ui = require "tek.ui"

local Canvas = ui.require("canvas", 20)
local Gadget = ui.require("gadget", 17)
local ListGadget = ui.require("listgadget", 22)
local PopItem = ui.require("popitem", 10)
local ScrollGroup = ui.require("scrollgroup", 11)
local Text = ui.require("text", 20)

local assert = assert
local insert = table.insert
local max = math.max

module("tek.ui.class.poplist", tek.ui.class.popitem)
_VERSION = "PopList 9.0"

-------------------------------------------------------------------------------
--	Constants and class data:
-------------------------------------------------------------------------------

local ArrowImage = ui.Image:new
{
	{ 0x2000,0xa000, 0xe000,0xa000, 0x8000,0x4000 }, false, false, true,
	{ { 0x1000, 3, { 1, 2, 3 }, ui.PEN_MENUDETAIL } },
}

local NOTIFY_SELECT = { ui.NOTIFY_SELF, "onSelectLine", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	PopListGadget:
-------------------------------------------------------------------------------

local PopListGadget = ListGadget:newClass()

function PopListGadget:passMsg(msg)
	if msg[2] == ui.MSG_MOUSEMOVE or
		(msg[2] == ui.MSG_MOUSEBUTTON and msg[3] == 1) then
		local lnr = self:findLine(msg[5])
		if lnr then
			if lnr ~= self.SelectedLine then
				self:setValue("CursorLine", lnr)
				self:setValue("SelectedLine", lnr)
			end
		end
	elseif msg[2] == ui.MSG_MOUSEBUTTON and msg[3] == 2 then
		if not self.Active then
			-- emulate click:
			db.warn("need to emulate click")
			self:setValue("Active", true)
		end
		-- let it collapse:
		self:setValue("Active", false)
	end
end

function PopListGadget:onActivate(active)
	if active == false then
		local lnr = self.CursorLine
		local entry = self:getItem(lnr)
		if entry then
			local popitem = self.Window.PopupBase
			popitem:setValue("SelectedLine", lnr)
			popitem:setValue("Text", entry[1][1])
		end
		-- needed to unregister input-handler:
		self:setValue("Focus", false)
		self.Window:finishPopup()
	end
	ListGadget.onActivate(self, active)
end

function PopListGadget:askMinMax(m1, m2, m3, m4)
	m1 = m1 + self.MinWidth
	m2 = m2 + self.CanvasHeight
	m3 = ui.HUGE
	m4 = m4 + self.CanvasHeight
	return Gadget.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	PopList:
-------------------------------------------------------------------------------

local PopList = _M

function PopList.init(self)
	self.ImageRect = { 0, 0, 0, 0 }
	self.Image = self.Image or ArrowImage
	self.TextHAlign = self.TextHAlign or "left"
	self.Width = self.Width or "fill"
	self.SelectedLine = self.SelectedLine or 0
	return PopItem.init(self)
end

function PopList.new(class, self)
	self = self or { }
	self.ListObject = self.ListObject or List:new()
	self.ListGadget = PopListGadget:new { ListObject = self.ListObject,
		Class = self.Class, Style = self.Style }
	self.Children =
	{
		ScrollGroup:new
		{
			-- VSliderMode = "auto",
			Child = Canvas:new
			{
				Class = "poplist-canvas",
				KeepMinWidth = true,
				KeepMinHeight = true,
				AutoWidth = true,
				Child = self.ListGadget
			}
		}
	}
	return PopItem.new(class, self)
end

function PopList:setup(app, window)
	PopItem.setup(self, app, window)
	self:addNotify("SelectedLine", ui.NOTIFY_ALWAYS, NOTIFY_SELECT)
end

function PopList:cleanup()
	self:remNotify("SelectedLine", ui.NOTIFY_ALWAYS, NOTIFY_SELECT)
	PopItem.cleanup(self)
end

function PopList:show(drawable)
	PopList.onSelectLine(self, self.SelectedLine)
	PopItem.show(self, drawable)
end

function PopList:askMinMax(m1, m2, m3, m4)
	local lo = self.ListObject
	if lo and not self.KeepMinWidth then
		local tr = { }
		local font = self.Application.Display:openFont(self.Font)
		for lnr = 1, lo:getN() do
			local entry = lo:getItem(lnr)
			local t = self:newTextRecord(entry[1][1], font, self.TextHAlign,
				self.TextVAlign, 0, 0, 0, 0)
			insert(tr, t)
		end
		local lw = self:getTextSize(tr) -- max width of items in list
		local w, h = self:getTextSize() -- width/height of our own text
		w = max(w, lw) - w -- minus own width, as it gets added in super class
		m1 = m1 + w -- + iw
		m3 = m3 + w -- + iw
	end
	return PopItem.askMinMax(self, m1, m2, m3, m4)
end

function PopList:beginPopup()
	PopItem.beginPopup(self)
	self.ListGadget:setValue("Focus", true)
end

-------------------------------------------------------------------------------
--	onSelectLine(line): This method is invoked when the {{SelectedLine}}
--	attribute is set.
-------------------------------------------------------------------------------

function PopList:onSelectLine(lnr)
	local entry = self.ListGadget:getItem(lnr)
	if entry then
		self:setValue("Text", entry[1][1])
	end
end

-------------------------------------------------------------------------------
--	setList(listobject): Sets a new [[#tek.class.list : List]]
--	object.
-------------------------------------------------------------------------------

function PopList:setList(listobject)
	assert(not listobject or listobject:instanceOf(List))
	self.ListObject = listobject
	self.ListGadget:setList(listobject)
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function PopList:getProperties(p, pclass)
	self.ListGadget:getProperties(p, pclass)
	PopItem.getProperties(self, p, pclass)
end
