-------------------------------------------------------------------------------
--
--	tek.ui.class.pagegroup
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
--		[[#tek.ui.class.group : Group]] /
--		PageGroup
--
--	OVERVIEW::
--		Implements a group whose children are layouted in individual
--		pages.
--
--	ATTRIBUTES::
--		- {{PageCaptions [IG]}} (table)
--			An array of strings containing captions for each page in
--			the group.
--		- {{PageNumber [IG]}} (number)
--			Number of the page that is initally selected. [Default: 1]
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Area:getElement()
--		- Area:getElementByXY()
--		- Area:hide()
--		- Area:layout()
--		- Area:markDamage()
--		- Class.new()
--		- Area:passMsg()
--		- Area:punch()
--		- Area:refresh()
--		- Area:relayout()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Frame = ui.Frame
local Gadget = ui.Gadget
local Group = ui.Group
local Region = require "tek.lib.region"
local Text = ui.Text

local assert = assert
local ipairs = ipairs
local tostring = tostring
local type = type
local unpack = unpack

module("tek.ui.class.pagegroup", tek.ui.class.group)
_VERSION = "PageGroup 6.1"
local PageGroup = _M

-------------------------------------------------------------------------------
--	class implementation:
-------------------------------------------------------------------------------

local PageContainerGroup = Group:newClass { _NAME = "_pagecontainer" }

function PageContainerGroup.init(self)
	self.PageElement = false
	self.PageNumber = self.PageNumber or 1
	return Group.init(self)
end

local PageButtonGroup = Group:newClass { _NAME = "_pagebuttongroup" }

function PageButtonGroup:draw()
	Group.draw(self)
	local d = self.Drawable
	local r = self.Rect
	local c = self.Children
	if #c > 0 then
		local pens = d.Pens
		local e = c[#c]
		local b = e.BorderHook
-- 		if b then
-- 			local x0 = r[1]
-- 			local _, _, b3, b4 = e:getBorder()
-- 			local p = b.Colors
-- 			local p1, p2, p3, p4 = pens[p[1]], pens[p[2]], pens[p[3]],
-- 				pens[p[4]]
-- 			b.drawBorderRect(d, e.Rect[3] + b3 + 1,
-- 				r[2], r[3], r[4] - b4,
-- 				0, 0, 0, b4,
-- 				0, 0, 0, b4,
-- 				p1, p2, p3, p4)
-- 			e = c[1]
-- 			local b1 = e:getBorder()
-- 			b.drawBorderRect(d, r[1],
-- 				r[2], e.Rect[1] - b1 - 1, r[4] - b4,
-- 				0, 0, 0, b4,
-- 				0, 0, 0, b4,
-- 				p1, p2, p3, p4)
-- 		end
	end
end

-------------------------------------------------------------------------------
--	new:
-------------------------------------------------------------------------------

local function changeTab(group, tabbuttons, newtabn)
	tabbuttons[group.PageNumber]:setValue("Selected", false)
	group.PageNumber = newtabn
	group.PageElement:hide()
	group.PageElement:cleanup()

	group.PageElement = group.Children[newtabn]

	ui.Application.connect(group.PageElement, group)
	group.PageElement:connect(group)

	group.PageElement:getProperties(group.Application.InternalProperties)
	
	group.PageElement:setup(group.Application, group.Window)
	group.PageElement:show(group.Display, group.Drawable)
	group:askMinMax(0, 0, group.MaxWidth, group.MaxHeight)
	local r = group.Rect
	local m = group.MarginAndBorder
	group:relayout(group, r[1] - m[1], r[2] - m[2], r[3] + m[3], r[4] + m[4])
	group.PageElement:rethinkLayout(2)
end

function PageGroup.new(class, self)

	self = self or { }

	local pagegroup = PageContainerGroup:new {
		PageNumber = self.PageNumber,
	}

	self.PageCaptions = self.PageCaptions or { }

	pagegroup.PageElement = type(self.PageNumber) == "number" and
		(self.PageNumber >= 1 and self.PageNumber <= #self.Children) and
		self.Children[self.PageNumber]
	if not pagegroup.PageElement and #self.Children > 0 then
		pagegroup.PageNumber = 1
		pagegroup.PageElement = self.Children[1]
	end

	local tabbuttons = { }
	for i, c in ipairs(self.Children) do
		local text = self.PageCaptions[i] or tostring(i)
		tabbuttons[i] = ui.Text:new
		{
			Class = "page-button",
			Mode = "touch",
			Width = "auto",
			Text = text,
			Notifications = {
				["Pressed"] = {
					[true] = {
						{ pagegroup, ui.NOTIFY_FUNCTION, changeTab,
							tabbuttons, i }
					}
				}
			}
		}
	end

	if pagegroup.PageNumber then
		tabbuttons[pagegroup.PageNumber]:setValue("Selected", true)
	end

	pagegroup.Children = self.Children
	self.Orientation = "vertical"

	self.Children =
	{
		PageButtonGroup:new
		{
			Width = "fill",
			MaxHeight = 0,
			Children = tabbuttons,
		},
		pagegroup
	}

	return Group.new(class, self)

end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:setup(app, window)
	Gadget.setup(self, app, window)
	self.PageElement:setup(app, window)
end

function PageContainerGroup:cleanup()
	self.PageElement:cleanup()
	Gadget.cleanup(self)
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:getProperties(p, pclass)
	Gadget.getProperties(self, p, pclass)
	self.PageElement:getProperties(p, pclass)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:show(display, drawable)
	if Gadget.show(self, display, drawable) then
		if not self.PageElement:show(display, drawable) then
			return self:hide()
		end
		return true
	end
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:hide()
	self.PageElement:hide()
	Gadget.hide(self)
end

-------------------------------------------------------------------------------
--	markDamage: mark damage in self and Children
-------------------------------------------------------------------------------

function PageContainerGroup:markDamage(r1, r2, r3, r4)
	Gadget.markDamage(self, r1, r2, r3, r4)
	self.Redraw = self.Redraw or self.FreeRegion:checkOverlap(r1, r2, r3, r4)
	self.PageElement:markDamage(r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	refresh: traverse tree, redraw if damaged
-------------------------------------------------------------------------------

function PageContainerGroup:refresh()
	Gadget.refresh(self)
	self.PageElement:refresh()
end

-------------------------------------------------------------------------------
--	getElementByXY: probe element for all Children
-------------------------------------------------------------------------------

function PageContainerGroup:getElementByXY(x, y)
	return self.PageElement:getElementByXY(x, y)
end

-------------------------------------------------------------------------------
--	askMinMax: returns minx, miny[, maxx[, maxy]]
-------------------------------------------------------------------------------

function PageContainerGroup:askMinMax(m1, m2, m3, m4)
	m1, m2, m3, m4 = self.PageElement:askMinMax(m1, m2, m3, m4)
	return Gadget.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	punch: Punch a a hole into the background for the element
-------------------------------------------------------------------------------

function PageContainerGroup:punch(region)
	self.PageElement:punch(region)
end

-------------------------------------------------------------------------------
--	layout: note that layouting takes place unconditionally here
-------------------------------------------------------------------------------

function PageContainerGroup:layout(r1, r2, r3, r4, markdamage)
	Gadget.layout(self, r1, r2, r3, r4, markdamage)
	self.FreeRegion = self.Parent.FreeRegion
	local f = self.FreeRegion
	local m = self.Margin
	local b = Region.new(r1 + m[1], r2 + m[2], r3 - m[3], r4 - m[4])
	local q1, q2, q3, q4 = self:getBorder()
	b:subRect(r1 + m[1] + q1, r2 + m[2] + q2, r3 - m[3] - q3, r4 - m[4] - q4)
	f:subRegion(b)
	local p = self.Padding
	local m = self.MarginAndBorder
	return self.PageElement:layout(
		r1 + p[1] + m[1],
		r2 + p[2] + m[2],
		r3 - p[3] - m[3],
		r4 - p[4] - m[4],
		markdamage)
end

-------------------------------------------------------------------------------
--	relayout:
-------------------------------------------------------------------------------

function PageContainerGroup:relayout(e, r1, r2, r3, r4)
	local res, changed = Gadget.relayout(self, e, r1, r2, r3, r4)
	if res then
		return res, changed
	end
	return self.PageElement:relayout(e, r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	onSetDisable:
-------------------------------------------------------------------------------

function PageContainerGroup:onDisable(onoff)
	return self.PageElement:setValue("Disabled", onoff)
end

-------------------------------------------------------------------------------
--	passMsg(msg)
-------------------------------------------------------------------------------

function PageContainerGroup:passMsg(msg)
	return self.PageElement:passMsg(msg)
end

-------------------------------------------------------------------------------
--	getElement(mode)
-------------------------------------------------------------------------------

function PageContainerGroup:getElement(mode)
	if mode == "parent" then
		return self.Parent
	elseif mode == "nextorparent" then
		return self.Parent:getElement("nextorparent")
	elseif mode == "prevorparent" then
		return self.Parent.Children[1]
	elseif mode == "children" then
		return { self.PageElement }
	elseif mode == "firstchild" or mode == "lastchild" then
		return self.PageElement
	end
	return self.PageElement:getElement(mode)
end
