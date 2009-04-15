-------------------------------------------------------------------------------
--
--	tek.ui.class.scrollbar
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
--		[[#tek.ui.class.group: : Group]] /
--		ScrollBar
--
--	OVERVIEW::
--		Implements a group containing a
--		[[#tek.ui.class.slider : Slider]] and arrow buttons.
--
--	ATTRIBUTES::
--		- {{Integer [IG]}} (boolean)
--			If '''true''', integer steps are enforced. By default, the
--			slider moves continuously.
--		- {{Max [ISG]}} (number)
--			The maximum value the slider can accept. Setting this value
--			invokes the ScrollBar:onSetMax() method.
--		- {{Min [ISG]}} (number)
--			The minimum value the slider can accept. Setting this value
--			invokes the ScrollBar:onSetMin() method.
--		- {{Orientation [IG]}} (string)
--			The orientation of the scrollbar, which can be "horizontal"
--			or "vertical"
--		- {{Range [ISG]}} (number)
--			The range of the slider, i.e. the size it represents. Setting
--			this value invokes the ScrollBar:onSetRange() method.
--		- {{Value [ISG]}} (number)
--			The value of the slider. Setting this value invokes the
--			ScrollBar:onSetValue() method.
--
--	IMPLEMENTS::
--		- ScrollBar:onSetMax() - Handler for the {{Max}} attribute
--		- ScrollBar:onSetMin() - Handler for the {{Min}} attribute
--		- ScrollBar:onSetRange() - Handler for the {{Range}} attribute
--		- ScrollBar:onSetValue() - Handler for the {{Value}} attribute
--
--	OVERRIDES::
--		- Element:cleanup()
--		- Class.new()
--		- Element:setup()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Group = ui.Group
local ImageGadget = ui.ImageGadget
local Slider = ui.Slider
local VectorImage = ui.VectorImage

local max = math.max
local min = math.min

module("tek.ui.class.scrollbar", tek.ui.class.group)
_VERSION = "ScrollBar 8.1"

local ScrollBar = _M

-------------------------------------------------------------------------------
--	Data:
-------------------------------------------------------------------------------

local ARROWBORDER1_HORIZ = { 1, 1, 0, 1 }
local ARROWBORDER2_HORIZ = { 0, 1, 1, 1 }
local ARROWBORDER1_VERT = { 1, 1, 1, 0 }
local ARROWBORDER2_VERT = { 1, 0, 1, 0 }

local coordx = { 0,0, 10,10, 10,-10 }
local coordy = { 0,0, 10,10, -10,10 }
local prims = { { 0x1000, 3, Points = { 1, 2, 3 }, Pen = ui.PEN_DETAIL } }

local ArrowUpImage = VectorImage:new {
	Coords = { 0x1000,0x4000, 0xf000,0x4000, 0x8000,0xc000 },
	Transparent = true,
	Primitives = prims }
local ArrowDownImage = VectorImage:new {
	Coords = { 0x1000,0xc000, 0xf000,0xc000, 0x8000,0x4000 },
	Transparent = true,
	Primitives = prims }
local ArrowLeftImage = VectorImage:new {
	Coords = { 0xc000,0x1000, 0xc000,0xf000, 0x4000,0x8000 },
	Transparent = true,
	Primitives = prims }
local ArrowRightImage = VectorImage:new {
	Coords = { 0x4000,0x1000, 0x4000,0xf000, 0xc000,0x8000 },
	Transparent = true,
	Primitives = prims }

local NOTIFY_VALUE = { ui.NOTIFY_SELF, "onSetValue", ui.NOTIFY_VALUE }
local NOTIFY_MIN = { ui.NOTIFY_SELF, "onSetMin", ui.NOTIFY_VALUE }
local NOTIFY_MAX = { ui.NOTIFY_SELF, "onSetMax", ui.NOTIFY_VALUE }
local NOTIFY_RANGE = { ui.NOTIFY_SELF, "onSetRange", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	ArrowButton:
-------------------------------------------------------------------------------

local ArrowButton = ImageGadget:newClass { _NAME = "_scrollbar-arrow" }

function ArrowButton.init(self)
	self.Width = "fill"
	self.Height = "fill"
	self.Mode = "button"
	self.Increase = self.Increase or 1
	return ImageGadget.init(self)
end

function ArrowButton:draw()
	-- TODO: static data modified (ugly):
	prims[1].Pen = self.Foreground
	ImageGadget.draw(self)
end

function ArrowButton:onPress(pressed)
	if pressed then
		self.Slider:increase(self.Increase)
	end
	ImageGadget.onPress(self, pressed)
end

function ArrowButton:onHold(hold)
	if hold then
		self.Slider:increase(self.Increase)
	end
	ImageGadget.onHold(self, hold)
end

-------------------------------------------------------------------------------
--	Slider:
-------------------------------------------------------------------------------

local SBSlider = Slider:newClass { _NAME = "_scrollbar-slider" }

function SBSlider:onSetValue(v)
	Slider.onSetValue(self, v)
	self.ScrollBar:setValue("Value", self.Value)
end

local function updateSlider(self)
	local disabled = self.Min == self.Max
	local sb = self.ScrollBar.Children
	if disabled ~= sb[1].Disabled then
		sb[1]:setValue("Disabled", disabled)
		sb[2]:setValue("Disabled", disabled)
		sb[3]:setValue("Disabled", disabled)
	end
end

function SBSlider:onSetRange(r)
	Slider.onSetRange(self, r)
	self.ScrollBar:setValue("Range", self.Range)
	updateSlider(self)
end

function SBSlider:onSetMin(m)
	Slider.onSetMin(self, m)
	self.ScrollBar:setValue("Min", self.Min)
	updateSlider(self)
end

function SBSlider:onSetMax(m)
	Slider.onSetMax(self, m)
	self.ScrollBar:setValue("Max", self.Max)
	updateSlider(self)
end

-------------------------------------------------------------------------------
--	ScrollBar:
-------------------------------------------------------------------------------

function ScrollBar.new(class, self)
	self = self or { }
	self.Min = self.Min or 1
	self.Max = self.Max or 100
	self.Default = max(self.Min, min(self.Max, self.Default or self.Min))
	self.Value = max(self.Min, min(self.Max, self.Value or self.Default))
	self.Range = max(self.Max, self.Range or self.Max)
	self.Step = self.Step or 1
	self.Integer = self.Integer or false
	self.Child = self.Child or false
	self.ArrowOrientation = self.ArrowOrientation or self.Orientation
	self.Kind = self.Kind or "scrollbar"

	self.Slider = self.Slider or SBSlider:new
	{
		Child = self.Child,
		ScrollBar = self,
		Min = self.Min,
		Max = self.Max,
		Value = self.Value,
		Range = self.Range,
		Step = self.Step,
		Notifications = self.Notifications,
		Orientation = self.Orientation,
		Integer = self.Integer,
		Kind = self.Kind,
	}
	self.Notifications = false

	local img1, img2
	local class1, class2 = "scrollbar-arrowleft", "scrollbar-arrowright"
	local increase = self.Step

	if self.Orientation == "vertical" then
		if self.ArrowOrientation == "horizontal" then
			img1, img2 = ArrowLeftImage, ArrowRightImage
			increase = -self.Step
		else
			img1, img2 = ArrowUpImage, ArrowDownImage
			class1, class2 = "scrollbar-arrowup", "scrollbar-arrowdown"
		end
	else
		if self.ArrowOrientation == "vertical" then
			img1, img2 = ArrowUpImage, ArrowDownImage
			increase = -self.Step
			class1, class2 = "scrollbar-arrowup", "scrollbar-arrowdown"
		else
			img1, img2 = ArrowLeftImage, ArrowRightImage
		end
	end

	self.ArrowButton1 = ArrowButton:new
	{
		Image = img1,
		Class = class1,
		Slider = self.Slider,
		Increase = -increase,
	}
	self.ArrowButton2 = ArrowButton:new
	{
		Image = img2,
		Class = class2,
		Slider = self.Slider,
		Increase = increase,
	}

	if self.ArrowOrientation ~= self.Orientation then
		self.Children =
		{
			self.Slider,
			Group:new
			{
				Orientation = "horizontal" and "vertical" or self.Orientation,
				Children =
				{
					self.ArrowButton1,
					self.ArrowButton2
				}
			}
		}
	else
		self.Children =
		{
			self.Slider,
			self.ArrowButton1,
			self.ArrowButton2
		}
	end
	return Group.new(class, self)

end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function ScrollBar:setup(app, window)

	Group.setup(self, app, window)

	if self.Orientation == "vertical" then
		self.Width = self.Width or "auto"
		self.Height = self.Height or "fill"
	else
		self.Width = self.Width or "fill"
		self.Height = self.Height or "auto"
	end

	self:addNotify("Value", ui.NOTIFY_CHANGE, NOTIFY_VALUE, 1)
	self:addNotify("Min", ui.NOTIFY_CHANGE, NOTIFY_MIN, 1)
	self:addNotify("Max", ui.NOTIFY_CHANGE, NOTIFY_MAX, 1)
	self:addNotify("Range", ui.NOTIFY_CHANGE, NOTIFY_RANGE, 1)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function ScrollBar:cleanup()
	self:remNotify("Range", ui.NOTIFY_CHANGE, NOTIFY_RANGE)
	self:remNotify("Max", ui.NOTIFY_CHANGE, NOTIFY_MAX)
	self:remNotify("Min", ui.NOTIFY_CHANGE, NOTIFY_MIN)
	self:remNotify("Value", ui.NOTIFY_CHANGE, NOTIFY_VALUE)
	Group.cleanup(self)
end

-------------------------------------------------------------------------------
--	onSetMin(min): This handler is invoked when the ScrollBar's {{Min}}
--	attribute has changed. See also Numeric:onSetMin().
-------------------------------------------------------------------------------

function ScrollBar:onSetMin(v)
	self.Slider:setValue("Min", v)
	self.Min = self.Slider.Min
end

-------------------------------------------------------------------------------
--	onSetMax(max): This handler is invoked when the ScrollBar's {{Max}}
--	attribute has changed. See also Numeric:onSetMax().
-------------------------------------------------------------------------------

function ScrollBar:onSetMax(v)
	self.Slider:setValue("Max", v)
	self.Max = self.Slider.Max
end

-------------------------------------------------------------------------------
--	onSetValue(val): This handler is invoked when the ScrollBar's {{Value}}
--	attribute has changed. See also Numeric:onSetValue().
-------------------------------------------------------------------------------

function ScrollBar:onSetValue(v)
	self.Slider:setValue("Value", v)
	self.Value = self.Slider.Value
end

-------------------------------------------------------------------------------
--	onSetRange(range): This handler is invoked when the ScrollBar's {{Range}}
--	attribute has changed. See also Slider:onSetRange().
-------------------------------------------------------------------------------

function ScrollBar:onSetRange(v)
	self.Slider:setValue("Range", v)
	self.Range = self.Slider.Range
end
