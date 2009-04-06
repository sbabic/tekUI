-------------------------------------------------------------------------------
--
--	tek.ui.class.popupwindow
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
--		[[#tek.ui.class.group : Window]] /
--		PopupWindow
--
--	OVERVIEW::
--		This class specializes a Window for the use by a
--		[[#tek.ui.class.popitem : PopItem]].
--
--	OVERRIDES::
--		- Object.init()
--		- Area:show()
--		- Area:passMsg()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Window = ui.Window
local ipairs = ipairs
local max = math.max

module("tek.ui.class.popupwindow", tek.ui.class.window)
_VERSION = "PopupWindow 1.7"

local PopupWindow = _M

-------------------------------------------------------------------------------
--	PopupWindow class:
-------------------------------------------------------------------------------

function PopupWindow.init(self)
	self.PopupBase = self.PopupBase or false
	self.BeginPopupTicks = 0
	self.DelayedBeginPopup = false
	self.DelayedEndPopup = false
	self.Margin = self.Margin or ui.NULLOFFS
	self.MaxWidth = self.MaxWidth or 0
	self.MaxHeight = self.MaxHeight or 0
	self = Window.init(self)
	self.FullScreen = false
	return self
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function PopupWindow:show(display)
	if Window.show(self, display) then
		local miclass = ui.PopItem
		if miclass then
			-- determine width of menuitems in group:
			local maxw = 0
			for _, e in ipairs(self.Children) do
				if e:checkDescend(miclass) then
					maxw = max(maxw, e:getTextSize())
				end
			end
			for _, e in ipairs(self.Children) do
				-- align shortcut text (if present):
				if e:checkDescend(miclass) and e.TextRecords[2] then
					e.TextRecords[2][5] = maxw
				end
			end
		end
		self.Window:addInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
		return true
	end
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function PopupWindow:hide()
	self.Window:remInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
	Window.hide(self)
end

-------------------------------------------------------------------------------
--	passMsg: overrides
-------------------------------------------------------------------------------

function PopupWindow:passMsg(msg)
	if msg[2] == ui.MSG_MOUSEOVER then
		if msg[3] == 0 then
			if self.DelayedEndPopup then
				self:setHiliteElement(self.DelayedEndPopup)
				self.DelayedEndPopup = false
			end
		end
		-- do not pass control back to window msg handler:
		return false
	end
	return Window.passMsg(self, msg)
end

-------------------------------------------------------------------------------
--	updateInterval:
-------------------------------------------------------------------------------

function PopupWindow:updateInterval(msg)
	self.BeginPopupTicks = self.BeginPopupTicks - 1
	if self.BeginPopupTicks < 0 then
		if self.DelayedBeginPopup then
			if not self.DelayedBeginPopup.PopupWindow then
				self.DelayedBeginPopup:beginPopup()
			end
			self.DelayedBeginPopup = false
		elseif self.DelayedEndPopup then
			if self.DelayedEndPopup.PopupWindow then
				self.DelayedEndPopup:endPopup()
			end
			self.DelayedEndPopup = false
		end
	end
	return msg
end
