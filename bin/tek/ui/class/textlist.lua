
local ui = require "tek.ui"
local db = require "tek.lib.debug"
local ScrollGroup = ui.ScrollGroup

module("tek.ui.class.textlist", tek.ui.class.scrollgroup)
_VERSION = "TextList 1.0"
local TextList = _M
ScrollGroup:newClass(TextList)

function TextList.new(class, self)
	
	self = self or { }
	
	if self.HardScroll == nil then
		self.HardScroll = true
	end
	local hardscroll = self.HardScroll
	
	self.ListText = ui.TextEdit:new
	{
		Class = "textlist",
		LineSpacing = self.LineSpacing or 0,
		DragScroll = false,
		EditScrollGroup = false,
		ReadOnly = true,
		ScrollGroup = self,
		BGPens = self.BGPens,
		FGPens = self.FGPens,
		UseFakeCanvasWidth = false,
		Data = self.Data,
		setup = function(self, app, window)
			ui.TextEdit.setup(self, app, window)
			if hardscroll then
				local h = self.LineHeight
				local s = self.ScrollGroup.VSliderGroup.Slider
				s.Increment = h
				s.Step = h
			end
		end,
	}
	
	local group = self -- for use as an upvalue
	self.ListCanvas = ui.Canvas:new
	{
		Class = "textlist",
		AutoPosition = true,
		-- Style = "border-width: 2; margin: 2",
		Child = group.ListText,
		Style = self.Style or "",
	}
		
	self.AcceptFocus = false
	self.VSliderMode = "auto"
	self.HSliderMode = "auto"
	self.Child = self.ListCanvas
	
	return ScrollGroup.new(class, self)
	
end

function TextList:getLatch()
	local top = self.VSliderGroup.Value == self.VSliderGroup.Min
	local bot = self.VSliderGroup.Value == self.VSliderGroup.Max
	return top ~= bot and top and "top" or bot and "bottom"
end

function TextList:addLine(text, lnr)
	local input = self.ListText
	local latch = self.Latch and self:getLatch()
	input:suspendWindowUpdate()
	local data = input.Data
	local numl = input:getNumLines()
	lnr = lnr or numl + 1
	local empty = numl == 1 and input:getLineLength(1) == 0
	if not empty then
		if lnr > numl then
			input:setCursor(0, -1, numl)
			input:enter(0) -- do not follow
		else
			input:setCursor(0, 1, lnr)
			input:enter(0) -- do not follow
			input:setCursor(0, 1, lnr, 0) -- do not follow
		end
	end
	input:addChar(text)
	if latch == "bottom" then
		input:setCursor(0, 1, input:getNumLines(), 1) -- follow
		input:followCursor()
	end
	input:releaseWindowUpdate()
end

function TextList:changeLine(lnr, text)
	local input = self.ListText
	local line = input:getLine(lnr)
	line[1] = input:newString(text)
	input:changeLine(lnr)
	input:damageLine(lnr)
	input:updateWindow()
end

function TextList:getNumLines()
	return self.ListText:getNumLines()
end

function TextList:clear()
	return self.ListText:newText()
end
