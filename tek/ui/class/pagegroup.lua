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
--		- {{PageNumber [ISG]}} (number)
--			Number of the page that is initally selected. [Default: 1]
--			Setting this attribute invokes the PageGroup:onSetPageNumber()
--			method.
--
--	IMPLEMENTS::
--		- PageGroup:onSetPageNumber() - handler for {{PageNumber}}
--
--	OVERRIDES::
--		- Element:cleanup()
--		- Object.init()
--		- Class.new()
--		- Element:setup()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local Frame = ui.Frame
local Gadget = ui.Gadget
local Group = ui.Group
local Region = require "tek.lib.region"
local Text = ui.Text

local assert = assert
local ipairs = ipairs
local max = math.max
local min = math.min
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

module("tek.ui.class.pagegroup", tek.ui.class.group)
_VERSION = "PageGroup 7.0"
local PageGroup = _M

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_PAGENUMBER = { ui.NOTIFY_SELF, "onSetPageNumber",
	ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	PageContainerGroup:
-------------------------------------------------------------------------------

local PageContainerGroup = Group:newClass { _NAME = "_pagecontainer" }

function PageContainerGroup.init(self)
	self.PageElement = self.PageElement or false
	self.PageNumber = self.PageNumber or 1
	return Group.init(self)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:setup(app, window)
	Gadget.setup(self, app, window)
	self.PageElement:setup(app, window)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

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
--	markDamage: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:markDamage(r1, r2, r3, r4)
	Gadget.markDamage(self, r1, r2, r3, r4)
	self.Redraw = self.Redraw or self.FreeRegion:checkOverlap(r1, r2, r3, r4)
	self.PageElement:markDamage(r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	refresh: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:refresh()
	Gadget.refresh(self)
	self.PageElement:refresh()
end

-------------------------------------------------------------------------------
--	getElementByXY: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:getElementByXY(x, y)
	return self.PageElement:getElementByXY(x, y)
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:askMinMax(m1, m2, m3, m4)
	m1, m2, m3, m4 = self.PageElement:askMinMax(m1, m2, m3, m4)
	return Gadget.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	punch: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:punch(region)
	self.PageElement:punch(region)
end

-------------------------------------------------------------------------------
--	layout: overrides
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
--	relayout: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:relayout(e, r1, r2, r3, r4)
	local res, changed = Gadget.relayout(self, e, r1, r2, r3, r4)
	if res then
		return res, changed
	end
	return self.PageElement:relayout(e, r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	onSetDisable: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:onDisable(onoff)
	return self.PageElement:setValue("Disabled", onoff)
end

-------------------------------------------------------------------------------
--	passMsg: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:passMsg(msg)
	return self.PageElement:passMsg(msg)
end

-------------------------------------------------------------------------------
--	getElement: overrides
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

-------------------------------------------------------------------------------
--	changeTab:
-------------------------------------------------------------------------------

function PageContainerGroup:changeTab(pagebuttons, newtabn)
	pagebuttons[self.PageNumber]:setValue("Selected", false)
	self.PageNumber = newtabn
	self.PageElement:hide()
	self.PageElement:cleanup()
	self.PageElement = self.Children[newtabn]
	ui.Application.connect(self.PageElement, self)
	self.PageElement:connect(self)
	self.Application:decodeProperties(self.PageElement)
	self.PageElement:setup(self.Application, self.Window)
	self.PageElement:show(self.Display, self.Drawable)
	self:askMinMax(0, 0, self.MaxWidth, self.MaxHeight)
	local r = self.Rect
	local m = self.MarginAndBorder
	self:relayout(self, r[1] - m[1], r[2] - m[2], r[3] + m[3], r[4] + m[4])
	self.PageElement:rethinkLayout(2)
end

-------------------------------------------------------------------------------
--	PageGroup:
-------------------------------------------------------------------------------

function PageGroup.new(class, self)

	self = self or { }

	self.PageNumber = self.PageNumber or 1

	local children = self.Children or { }

	local pagenumber = type(self.PageNumber) == "number" and
		self.PageNumber or 1
	pagenumber = max(1, min(pagenumber, #children))

	local pageelement = children[pagenumber] or ui.Area:new { }

	local pagegroup = PageContainerGroup:new
	{
		Children = children,
		PageNumber = pagenumber,
		PageElement = pageelement
	}

	self.PageCaptions = self.PageCaptions or { }

	local pagebuttons = { }
	if #children == 0 then
		pagebuttons[1] = ui.Text:new
		{
			Class = "page-button",
			Mode = "inert",
			Width = "auto",
		}
	else
		for i, c in ipairs(children) do
			local text = self.PageCaptions[i] or tostring(i)
			pagebuttons[i] = ui.Text:new
			{
				Class = "page-button",
				Mode = "touch",
				Width = "auto",
				Text = text,
				Notifications =
				{
					["Pressed"] =
					{
						[true] =
						{
							{ pagegroup, "changeTab", pagebuttons, i }
						}
					}
				}
			}
		end
	end

	pagebuttons[#pagebuttons + 1] = ui.Text:new
	{
		Class = "page-button-fill",
		Height = "fill",
	}

	if pagebuttons[pagenumber] then
		pagebuttons[pagenumber]:setValue("Selected", true)
	end

	self.TabButtons = pagebuttons

	self.Orientation = "vertical"

	self.Children =
	{
		Group:new
		{
			Class = "page-button-group",
			Width = "fill",
			MaxHeight = 0,
			Children = pagebuttons,
		},
		pagegroup
	}

	return Group.new(class, self)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function PageGroup:setup(app, window)
	Group.setup(self, app, window)
	self:addNotify("PageNumber", ui.NOTIFY_CHANGE, NOTIFY_PAGENUMBER)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function PageGroup:cleanup()
	self:remNotify("PageNumber", ui.NOTIFY_CHANGE, NOTIFY_PAGENUMBER)
	Group.cleanup(self)
end

-------------------------------------------------------------------------------
--	onsetPageNumber(number): This method is invoked when the element's
--	{{PageNumber}} attribute has changed.
-------------------------------------------------------------------------------

function PageGroup:onSetPageNumber(val)
	local n = tonumber(val)
	local b = self.TabButtons
	if n >= 1 and n < #b then
		self.TabButtons[n]:setValue("Selected", true)
		self.Children[2]:changeTab(self.TabButtons, n)
	else
		db.warn("invalid page number: %s", val)
	end
end
