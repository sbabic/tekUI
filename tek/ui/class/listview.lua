-------------------------------------------------------------------------------
--
--	tek.ui.class.listview
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
--		ListView
--
--	OVERVIEW::
--		This class implements a [[#tek.ui.class.group : Group]] containing
--		a [[#tek.ui.class.scrollgroup : ScrollGroup]] and optionally a
--		group of column headers; its main purpose is to automate the somewhat
--		complicated setup of multi-column lists with headers, but it can be
--		used for single-column lists and lists without column headers as well.
--
--	ATTRIBUTES::
--		- {{Headers [I]}} (table)
--			An array of strings containing the captions of column headers.
--			[Default: unspecified]
--		- {{HSliderMode [I]}} (string)
--			This attribute is passed on the
--			[[#tek.ui.class.scrollgroup : ScrollGroup]] - see there.
--		- {{VSliderMode [I]}} (string)
--			This attribute is passed on the
--			[[#tek.ui.class.scrollgroup : ScrollGroup]] - see there.
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local List = require "tek.class.list"
local Canvas = ui.Canvas
local Gadget = ui.Gadget
local Group = ui.Group
local ListGadget = ui.ListGadget
local ScrollBar = ui.ScrollBar
local ScrollGroup = ui.ScrollGroup
local Text = ui.Text

local ipairs = ipairs

module("tek.ui.class.listview", tek.ui.class.group)
_VERSION = "ListView 4.4"

-------------------------------------------------------------------------------
--	HeadItem:
-------------------------------------------------------------------------------

local HeadItem = Text:newClass { _NAME = "_listviewheaditem" }

function HeadItem.init(self)
	self = self or { }
	self.Border = ui.NULLOFFS
	self.Margin = ui.NULLOFFS
	self.Mode = "inert"
	self.TextHAlign = "left"
	self.Width = "auto"
	return Text.init(self)
end

function HeadItem:askMinMax(m1, m2, m3, m4)
	local w, h = self:getTextSize()
	return Gadget.askMinMax(self, m1 + w, m2 + h, m3 + w, m4 + h)
end

-------------------------------------------------------------------------------

local LVScrollGroup = ScrollGroup:newClass { _NAME = "_lvscrollgroup" }

function LVScrollGroup:onSetCanvasHeight(h)
	ScrollGroup.onSetCanvasHeight(self, h)
	local c = self.Child
	local r = c.Rect
	local sh = r[4] - r[2] + 1
	local en = self.VSliderGroupMode == "on" or
		self.VSliderGroupMode == "auto" and (sh < h)
	if en ~= self.VSliderGroupEnabled then
		if en then
			self.ExternalGroup:addMember(self.VSliderGroup, 2)
		else
			self.ExternalGroup:remMember(self.VSliderGroup, 2)
		end
		self.VSliderGroupEnabled = en
	end
end

-------------------------------------------------------------------------------
--	ListView:
-------------------------------------------------------------------------------

local ListView = _M

function ListView.new(class, self)
	self = self or { }

	self.Child = self.Child or ListGadget:new()
	self.HeaderGroup = self.HeaderGroup or false
	self.Headers = self.Headers or false
	self.HSliderMode = self.HSliderMode or "on"
	self.VSliderGroup = false
	self.VSliderMode = self.VSliderMode or "on"

	if self.Headers and not self.HeaderGroup then
		local c = { }
		for i, caption in ipairs(self.Headers) do
			c[i] = HeadItem:new { Text = caption }
		end
		self.HeaderGroup = Group:new { Width = "fill", Children = c }
	end

	if self.HeaderGroup then
		self.VSliderGroup = ScrollBar:new { Orientation = "vertical", Min = 0 }
		self.Child.HeaderGroup = self.HeaderGroup
		self.Children =
		{
			ScrollGroup:new
			{
				Margin = ui.NULLOFFS,
				VSliderMode = "off",
				HSliderMode = self.HSliderMode,
				KeepMinHeight = true,
				Child = Canvas:new
				{
					passMsg = function(self, msg)
						-- pass input unmodified:
						return self.Child:passMsg(msg)
					end,
					AutoHeight = true,
					AutoWidth = true,
					Child = Group:new
					{
						Orientation = "vertical",
						Children =
						{
							self.HeaderGroup,
							LVScrollGroup:new
							{
								Margin = ui.NULLOFFS,

								-- our own sliders are always off:
								VSliderMode = "off",
								HSliderMode = "off",

								-- data to service the external slider:
								VSliderGroupMode = self.VSliderMode,
								VSliderGroup = self.VSliderGroup,
								VSliderGroupEnabled = true,
								ExternalGroup = self,

								Child = Canvas:new
								{
									Child = self.Child
								}
							}
						}
					}
				}
			},
			self.VSliderGroup
		}
		-- point element that determines listgadget alignment to outer canvas:
		self.Child.AlignElement = self.Children[1].Child
	else
		self.Children =
		{
			ScrollGroup:new
			{
				VSliderMode = self.VSliderMode,
				HSliderMode = self.HSliderMode,
				Child = Canvas:new
				{
					Child = self.Child
				}
			}
		}
	end

	return Group.new(class, self)
end
