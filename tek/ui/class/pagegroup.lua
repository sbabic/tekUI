-------------------------------------------------------------------------------
--
--	tek.ui.class.pagegroup
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
--		[[#tek.ui.class.group : Group]] /
--		PageGroup ${subclasses(PageGroup)}
--
--		Implements a group whose children are layouted in individual
--		pages.
--
--	ATTRIBUTES::
--		- {{PageCaptions [IG]}} (table)
--			An array of strings containing captions for each page in
--			the group. If '''false''', no page captions will be displayed.
--			[Default: '''false''']
--		- {{PageNumber [ISG]}} (number)
--			Number of the page that is initially selected. [Default: 1]
--			Setting this attribute invokes the PageGroup:onSetPageNumber()
--			method.
--
--	IMPLEMENTS::
--		- PageGroup:disablePage() - Enables a Page
--		- PageGroup:onSetPageNumber() - Handler for {{PageNumber}}
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

local Frame = ui.require("frame", 16)
local Gadget = ui.require("gadget", 19)
local Group = ui.require("group", 27)
local Region = ui.loadLibrary("region", 9)
local Text = ui.require("text", 24)

local assert = assert
local insert = table.insert
local max = math.max
local min = math.min
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

module("tek.ui.class.pagegroup", tek.ui.class.group)
_VERSION = "PageGroup 16.0"
local PageGroup = _M

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_PAGENUMBER = { ui.NOTIFY_SELF, "onSetPageNumber",
	ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	PageContainerGroup:
-------------------------------------------------------------------------------

local PageContainerGroup = Group:newClass { _NAME = "_page-container" }

function PageContainerGroup.init(self)
	self.PageElement = self.PageElement or false
	self.PageNumber = self.PageNumber or 1
	return Group.init(self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:show(drawable)
	Gadget.show(self, drawable)
	self.PageElement:show(drawable)
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:hide()
	self.PageElement:hide()
	Gadget.hide(self)
end

-------------------------------------------------------------------------------
--	damage: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:damage(r1, r2, r3, r4)
	Gadget.damage(self, r1, r2, r3, r4)
	local f = self.FreeRegion
	if f and f:checkIntersect(r1, r2, r3, r4) then
		self.Flags:set(ui.FL_REDRAW)
	end
	self.PageElement:damage(r1, r2, r3, r4)
end

-------------------------------------------------------------------------------
--	getByXY: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:getByXY(x, y)
	return self.PageElement:getByXY(x, y)
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:askMinMax(m1, m2, m3, m4)
	local c = self.Children
	self.Children = { self.PageElement }
	m1, m2, m3, m4 = Group.askMinMax(self, m1, m2, m3, m4)
	self.Children = c
	return m1, m2, m3, m4
end

-------------------------------------------------------------------------------
--	punch: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:punch(region)
	Group.punch(self, region)
	self.PageElement:punch(region)
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:layout(r1, r2, r3, r4, markdamage)
	local c = self.Children
	self.Children = { self.PageElement }
	local res = Group.layout(self, r1, r2, r3, r4, markdamage)
	self.Children = c
	return res
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
--	getParent: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:getParent()
	return self.Parent
end

-------------------------------------------------------------------------------
--	getGroup: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:getGroup(parent)
	return parent and self.Parent or self
end

-------------------------------------------------------------------------------
--	getNext: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:getNext()
	return self:getParent():getNext()
end

-------------------------------------------------------------------------------
--	getPrev: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:getPrev()
	local c = self:getParent():getChildren()
	return c and c[1]
end

-------------------------------------------------------------------------------
--	getChildren: overrides
-------------------------------------------------------------------------------

function PageContainerGroup:getChildren(init)
	return init and self.Children or { self.PageElement }
end

-------------------------------------------------------------------------------
--	changeTab:
-------------------------------------------------------------------------------

function PageContainerGroup:changeTab(pagebuttons, tabnr)
	if self.Children[tabnr] then
		if pagebuttons and pagebuttons[self.PageNumber + 1] then
			pagebuttons[self.PageNumber + 1]:setValue("Selected", false)
		end
		self.PageNumber = tabnr
		self.PageElement:hide()
		self.PageElement = self.Children[tabnr]
		local d = self.Drawable
		if d then
			self.PageElement:show(d)
			self:getParent():rethinkLayout(2, true)
		else
			db.error("pagegroup not connected to display")
		end
	end
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
		PageElement = pageelement,
		Width = self.Width,
		Height = self.Height,
		Layout = self.Layout
	}
	self.Layout = false

	self.PageCaptions = self.PageCaptions or false

	local pagebuttons = false

	if self.PageCaptions then

		pagegroup.Class = "page-container"

		pagebuttons =
		{
			ui.Frame:new
			{
				Class = "page-button-fill",
				Style = "border-left-width: 0",
				MinWidth = 3,
				MaxWidth = 3,
				Width = 3,
				Height = "fill",
			}
		}

		if #children == 0 then
			insert(pagebuttons, ui.Text:new
			{
				Class = "page-button",
				Mode = "inert",
				MaxWidth = 0,
			})
		else
			if self.PageCaptions then
				for i = 1, #children do
					local pc = self.PageCaptions[i]
					if type(pc) == "table" then
						-- element
					else
						local text = pc or tostring(i)
						pc = ui.Text:new
						{
							Class = "page-button",
							Mode = "touch",
							MaxWidth = 0,
							Text = text,
							KeyCode = true
						}
						pc:addNotify("Pressed", true, 
							{ self, "setValue", "PageNumber", i })
					end
					insert(pagebuttons, pc)
				end
			end
		end

		insert(pagebuttons, ui.Frame:new
		{
			Class = "page-button-fill",
			Height = "fill",
		})

		if pagebuttons[pagenumber + 1] then
			pagebuttons[pagenumber + 1]:setValue("Selected", true)
		end

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
	else
		self.Children =
		{
			pagegroup
		}
	end

	self.TabButtons = pagebuttons
	self.Orientation = "vertical"

	return Group.new(class, self)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function PageGroup:setup(app, window)
	Group.setup(self, app, window)
	self:addNotify("PageNumber", ui.NOTIFY_ALWAYS, NOTIFY_PAGENUMBER)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function PageGroup:cleanup()
	self:remNotify("PageNumber", ui.NOTIFY_ALWAYS, NOTIFY_PAGENUMBER)
	Group.cleanup(self)
end

-------------------------------------------------------------------------------
--	onsetPageNumber(number): This method is invoked when the element's
--	{{PageNumber}} attribute has changed.
-------------------------------------------------------------------------------

function PageGroup:onSetPageNumber(val)
	local n = tonumber(val)
	local b = self.TabButtons
	if b then
		if b[n + 1] then
			b[n + 1]:setValue("Selected", true)
		end
		self.Children[2]:changeTab(self.TabButtons, n)
	else
		self.Children[1]:changeTab(self.TabButtons, n)
	end
end

-------------------------------------------------------------------------------
--	disablePage(pagenum, onoff): This function allows to disable or re-enable
--	a page button identified by {{pagenum}}.
-------------------------------------------------------------------------------

function PageGroup:disablePage(num, onoff)
	local numc = #self.Children[2].Children
	if num >= 1 and num <= numc then
		self.TabButtons[num + 1]:setValue("Disabled", onoff or false)
	end
end
