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
--		- {{SelectedEntry [ISG]}} (number)
--			Number of the selected entry, or 0 if none is selected. Changing
--			this attribute invokes the PopList:onSelectEntry() method.
--
--	IMPLEMENTS::
--		- PopList:onSelectEntry() - Handler for the {{SelectedEntry}}
--		attribute
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

local ui = require "tek.ui"
local Canvas = ui.Canvas
local Gadget = ui.Gadget
local List = require "tek.class.list"
local ListGadget = ui.ListGadget
local PopItem = ui.PopItem
local ScrollGroup = ui.ScrollGroup
local Text = ui.Text
local VectorImage = ui.VectorImage

local assert = assert
local insert = table.insert
local max = math.max

module("tek.ui.class.poplist", tek.ui.class.popitem)
_VERSION = "PopList 5.0"

-------------------------------------------------------------------------------
--	Constants and class data:
-------------------------------------------------------------------------------

local prims = { { 0x1000, 3, Points = { 1, 2, 3 }, Pen = ui.PEN_DETAIL } }

local ArrowImage = VectorImage:new
{
	ImageData =
	{
		Coords = { -2, 1, 3, 1, 0, -1 },
		Primitives = prims,
		MinMax = { -3, -3, 5, 4 },
	}
}

local NOTIFY_SELECT = { ui.NOTIFY_SELF, "onSelectEntry", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	PopListGadget:
-------------------------------------------------------------------------------

local PopListGadget = ListGadget:newClass()

function PopListGadget:passMsg(msg)
	if msg[2] == ui.MSG_MOUSEMOVE then
		local lnr = self:findLine(msg[5])
		if lnr then
			if lnr ~= self.SelectedLine then
				self:setValue("CursorLine", lnr)
				self:setValue("SelectedLine", lnr)
			end
		end
	end
end

function PopListGadget:onActivate(active)
	if active == false then
		local lnr = self.CursorLine
		local entry = self:getItem(lnr)
		if entry then
			local popitem = self.Window.PopupBase
			popitem:setValue("SelectedEntry", lnr)
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
	self.Image = ArrowImage
	self.TextHAlign = "left"
	self.Width = "fill"
	self.SelectedEntry = self.SelectedEntry or 0
	return PopItem.init(self)
end

function PopList.new(class, self)
	self = self or { }
	self.ListObject = self.ListObject or List:new()
	self.ListGadget = PopListGadget:new { ListObject = self.ListObject }
	self.Children =
	{
		ScrollGroup:new
		{
			VSliderMode = "auto",
			Child = Canvas:new
			{
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
	self:addNotify("SelectedEntry", ui.NOTIFY_CHANGE, NOTIFY_SELECT)
end

function PopList:cleanup()
	self:remNotify("SelectedEntry", ui.NOTIFY_CHANGE, NOTIFY_SELECT)
	PopItem.cleanup(self)
end

function PopList:show(display, drawable)
	self:setValue("SelectedEntry", self.SelectedEntry, true)
	return PopItem.show(self, display, drawable)
end

function PopList:askMinMax(m1, m2, m3, m4)
	local lo = self.ListObject
	if lo and not self.KeepMinWidth then
		local tr = { }
		local font = self.Display:openFont(self.FontSpec)
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
--	PopList:onSelectEntry(line): This method is invoked when the
--	{{SelectedEntry}} attribute is set.
-------------------------------------------------------------------------------

function PopList:onSelectEntry(lnr)
	local entry = self.ListGadget:getItem(lnr)
	if entry then
		self:setValue("Text", entry[1][1])
	end
end

-------------------------------------------------------------------------------
--	PopListt:setList(listobject): Sets a new [[#tek.class.list : List]]
--	object.
-------------------------------------------------------------------------------

function PopList:setList(listobject)
	assert(not listobject or listobject:checkDescend(List))
	self.ListObject = listobject
	self.ListGadget:setList(listobject)
	self:setValue("SelectedEntry", 1)
end
