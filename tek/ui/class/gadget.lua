-------------------------------------------------------------------------------
--
--	tek.ui.class.gadget
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
--		Gadget
--
--	OVERVIEW::
--		This class implements interactivity.
--
--	ATTRIBUTES::
--		- {{Active [SG]}} (boolean)
--			Signifies a change of the Gadget's activation state. While active,
--			the position of the mouse pointer is being verified (which is also
--			reflected by the {{Hover}} attribute). When the {{Active}} state
--			changes, the Gadget's behavior depends on its {{Mode}} attribute:
--				* in "button" mode, the {{Selected}} attribute is set to
--				the value of the {{Hover}} attribute. The {{Pressed}} attribute
--				is set to the value of the {{Active}} attribute, if it caused a
--				change of the {{Selected}} state.
--				* in "toggle" mode, the {{Selected}} attribute of the
--				Gadget is logically toggled, and the {{Pressed}} attribute is
--				set to '''true'''.
--				* in "touch" mode, the {{Selected}} and {{Pressed}}
--				attributes are set to '''true''', if the Gadget wasn't selected
--				already.
--			Changing this attribute invokes the Gadget:onActivate() method.
--		- {{DblClick [SG]}} (boolean)
--			Signifies that the element was doubleclicked; is is set to
--			'''true''' when the element was doubleclicked and is still being
--			held, and '''false''' when it was doubleclicked and then released.
--			This attribute usually needs to get a notification handler attached
--			to it before it is useful.
--		- {{Disabled [ISG]}} (boolean)
--			Signifies a change of the Gadget's ability to interact with the
--			user. Invokes the Gadget:onDisable() method. When an element is
--			getting disabled, it loses its focus, too.
--		- {{FGPen [IG]}} (userdata)
--			A colored pen for rendering the foreground of the element
--		- {{Hilite [SG]}} (boolean)
--			Signifies a change of the Gadget's highligting state. Invokes
--			Gadget:onHilite().
--		- {{Hold [SG]}} (boolean)
--			Signifies that the element is being held. Invokes
--			Gadget:onHold().
--		- {{Hover [SG]}} (boolean)
--			Signifies a change of the Gadget being hovered by the pointing
--			device. Invokes Gadget:onHover().
--		- {{KeyCode [IG]}} (string)
--			If set, the keyboard equivalent that can be used to activate the
--			element while it is shown [default: '''false''']. See also
--			[[#tek.ui.class.popitem : PopItem]] for a discussion of
--			denoting qualifiers, which applies to the {{KeyCode}} attribute
--			as well.
--		- {{Mode [IG]}} (string)
--			Interaction mode of the Gadget; can be
--			- "inert": The element does not react to input,
--			- "toggle": The element does not rebound at all and keeps its
--			{{Selected}} state; it can't be unselected by the user.
--			- "touch": The element rebounds immediately and acts as a strobe,
--			submitting always '''true''' for {{Pressed}} and {{Selected}}.
--			- "button": The element sets the {{Pressed}} attribute only if
--			the mouse pointer is released when hovering it.
--			See also {{Active}}.
--		- {{Pressed [SG]}} (boolean)
--			Signifies that a button was pressed or released. Invokes
--			Gadget:onPress().
--		- {{Selected [ISG]}} (boolean)
--			Signifies a change of the gadget's selection state. Invokes
--			Gadget:onSelect().
--
--	STYLE PROPERTIES::
--		- {{color}} - color of text and details
--		- {{effect}} - name of an overlay effect
--
--	STYLE PSEUDO CLASSES::
--		- {{active}} - for elements in active state
--		- {{disabled}} - for elements in disabled state
--		- {{focus}} - for elements that have the focus
--		- {{hover}} - for elements that are being hovered by the mouse
--
--	IMPLEMENTS::
--		- Gadget:onActivate() - Handler for {{Active}}
--		- Gadget:onDisable() - Handler for {{Disabled}}
--		- Gadget:onFocus() - Handler for {{Focus}}
--		- Gadget:onHilite() - Handler for {{Hilite}}
--		- Gadget:onHold() - Handler for {{Hold}}
--		- Gadget:onHover() - Handler for {{Hover}}
--		- Gadget:onPress() - Handler for {{Pressed}}
--		- Gadget:onSelect() - Handler for {{Selected}}
--
--	OVERRIDES::
--		- Area:checkFocus()
--		- Element:cleanup()
--		- Area:hide()
--		- Object.init()
--		- Area:passMsg()
--		- Element:setup()
--		- Area:setState()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Frame = ui.Frame

module("tek.ui.class.gadget", tek.ui.class.frame)
_VERSION = "Gadget 10.2"

local Gadget = _M

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_HOVER = { ui.NOTIFY_SELF, "onHover", ui.NOTIFY_VALUE }
local NOTIFY_ACTIVE = { ui.NOTIFY_SELF, "onActivate", ui.NOTIFY_VALUE }
local NOTIFY_HILITE = { ui.NOTIFY_SELF, "onHilite", ui.NOTIFY_VALUE }
local NOTIFY_DISABLED = { ui.NOTIFY_SELF, "onDisable", ui.NOTIFY_VALUE }
local NOTIFY_SELECTED = { ui.NOTIFY_SELF, "onSelect", ui.NOTIFY_VALUE }
local NOTIFY_PRESSED = { ui.NOTIFY_SELF, "onPress", ui.NOTIFY_VALUE }
local NOTIFY_HOLD = { ui.NOTIFY_SELF, "onHold", ui.NOTIFY_VALUE }
local NOTIFY_FOCUS = { ui.NOTIFY_SELF, "onFocus", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Gadget.init(self)
	self.BGPenDisabled = self.BGPenDisabled or false
	self.BGPenSelected = self.BGPenSelected or false
	self.BGPenHilite = self.BGPenHilite or false
	self.BGPenFocus = self.BGPenFocus or false
	self.FGPenDisabled = self.FGPenDisabled or false
	self.FGPenSelected = self.FGPenSelected or false
	self.FGPenHilite = self.FGPenHilite or false
	self.FGPenFocus = self.FGPenFocus or false
	self.Active = false
	self.DblClick = false
	self.FGPen = self.FGPen or false
	self.Foreground = false
	self.Hold = false
	self.Hover = false
	self.KeyCode = self.KeyCode or false
	self.Mode = self.Mode or "inert"
	self.EffectName = self.EffectName or false
	self.EffectHook = false
	self.Pressed = false
	return Frame.init(self)
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function Gadget:getProperties(p, pclass)
	self.EffectName = self.EffectName or self:getProperty(p, pclass, "effect")
	self.FGPen = self.FGPen or self:getProperty(p, pclass, "color")
	self.BGPenDisabled = self.BGPenDisabled or
		self:getProperty(p, pclass or "disabled", "background-color")
	self.BGPenSelected = self.BGPenSelected or
		self:getProperty(p, pclass or "active", "background-color")
	self.BGPenHilite = self.BGPenHilite or
		self:getProperty(p, pclass or "hover", "background-color")
	self.BGPenFocus = self.BGPenFocus or
		self:getProperty(p, pclass or "focus", "background-color")
	self.FGPenDisabled = self.FGPenDisabled or
		self:getProperty(p, pclass or "disabled", "color")
	self.FGPenSelected = self.FGPenSelected or
		self:getProperty(p, pclass or "active", "color")
	self.FGPenHilite = self.FGPenHilite or
		self:getProperty(p, pclass or "hover", "color")
	self.FGPenFocus = self.FGPenFocus or
		self:getProperty(p, pclass or "focus", "color")
	Frame.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Gadget:setup(app, window)
	Frame.setup(self, app, window)
	if self.Mode ~= "inert" then
		-- add notifications:
		self:addNotify("Disabled", ui.NOTIFY_CHANGE, NOTIFY_DISABLED)
		self:addNotify("Hilite", ui.NOTIFY_CHANGE, NOTIFY_HILITE)
		self:addNotify("Selected", ui.NOTIFY_CHANGE, NOTIFY_SELECTED)
		self:addNotify("Hover", ui.NOTIFY_CHANGE, NOTIFY_HOVER)
		self:addNotify("Active", ui.NOTIFY_CHANGE, NOTIFY_ACTIVE)
		self:addNotify("Pressed", ui.NOTIFY_ALWAYS, NOTIFY_PRESSED)
		self:addNotify("Hold", ui.NOTIFY_ALWAYS, NOTIFY_HOLD)
		self:addNotify("Focus", ui.NOTIFY_CHANGE, NOTIFY_FOCUS)
	end
	-- create effect hook:
	self.EffectHook = ui.createHook("hook", self.EffectName, self,
		{ Style = self.Style })
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Gadget:cleanup()
	self.EffectHook = false
	if self.Mode ~= "inert" then
		self:remNotify("Focus", ui.NOTIFY_CHANGE, NOTIFY_FOCUS)
		self:remNotify("Hold", ui.NOTIFY_ALWAYS, NOTIFY_HOLD)
		self:remNotify("Pressed", ui.NOTIFY_ALWAYS, NOTIFY_PRESSED)
		self:remNotify("Active", ui.NOTIFY_CHANGE, NOTIFY_ACTIVE)
		self:remNotify("Hover", ui.NOTIFY_CHANGE, NOTIFY_HOVER)
		self:remNotify("Selected", ui.NOTIFY_CHANGE, NOTIFY_SELECTED)
		self:remNotify("Hilite", ui.NOTIFY_CHANGE, NOTIFY_HILITE)
		self:remNotify("Disabled", ui.NOTIFY_CHANGE, NOTIFY_DISABLED)
	end
	Frame.cleanup(self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Gadget:show(display, drawable)
	if self.KeyCode and self.Mode ~= "inert" then
		self.Window:addKeyShortcut(self.KeyCode, self)
	end
	if Frame.show(self, display, drawable) then
		if self.EffectHook then
			self.EffectHook:show()
		end
		return true
	end
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Gadget:hide()
	if self.EffectHook then
		self.EffectHook:hide()
	end
	Frame.hide(self)
	if self.KeyCode then
		self.Window:remKeyShortcut(self.KeyCode, self)
	end
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function Gadget:layout(x0, y0, x1, y1, markdamage)
	if Frame.layout(self, x0, y0, x1, y1, markdamage) then
		if self.EffectHook then
			local r = self.Rect
			self.EffectHook:layout(r[1], r[2], r[3], r[4])
		end
		return true
	end
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function Gadget:refresh()
	local redraw = self.EffectHook and self.Redraw
	Frame.refresh(self)
	if redraw then
		self.EffectHook:draw(self.Drawable)
	end
end

-------------------------------------------------------------------------------
--	onHover(hovered): This method is invoked when the gadget's {{Hover}}
--	attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onHover(hover)
	if self.Mode == "button" then
		self:setValue("Selected", self.Active and hover)
	end
	if self.Mode ~= "inert" then
		self:setValue("Hilite", hover)
	end
	self:setState()
end

-------------------------------------------------------------------------------
--	onActivate(active): This method is invoked when the gadget's {{Active}}
--	attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onActivate(active)
	local mode, selected, dblclick = self.Mode, self.Selected
	if mode == "toggle" then
		if active then
			self:setValue("Selected", not selected)
			self:setValue("Pressed", true)
			dblclick = self
		end
	elseif mode == "touch" then
		if active and not selected then
			self:setValue("Selected", true)
			self:setValue("Pressed", true)
			dblclick = self
		end
	elseif mode == "button" then
		self:setValue("Selected", active and self.Hover)
		if not selected ~= not active then
			self:setValue("Pressed", active)
			dblclick = active and self
		end
	end
	if dblclick ~= nil then
		local win = self.Window
		if win then
			win:setDblClickElement(dblclick)
		end
	end
	self:setState()
end

-------------------------------------------------------------------------------
--	onDisable(disabled): This method is invoked when the gadget's {{Disabled}}
--	attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onDisable(disabled)
	local win = self.Window
	if disabled and self.Focus and win then
		win:setFocusElement()
	end
	self.Redraw = true
	self:setState()
end

-------------------------------------------------------------------------------
--	onSelect(selected): This method is invoked when the gadget's {{Selected}}
--	attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onSelect(selected)
	self.RedrawBorder = true
	self:setState()
end

-------------------------------------------------------------------------------
--	onHilite(selected): This method is invoked when the gadget's {{Selected}}
--	attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onHilite(hilite)
	self:setState()
end

-------------------------------------------------------------------------------
--	onPress(pressed): This method is invoked when the gadget's {{Pressed}}
--	attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onPress(pressed)
end

-------------------------------------------------------------------------------
--	onHold(held): This method is invoked when the gadget's {{Hold}}
--	attribute is set. While the gadget is being held, repeated
--	{{Hold}} = '''true''' events are submitted in intervals of n/50 seconds
--	determined by the [[#tek.ui.class.window : Window]].HoldTickInitRepeat
--	attribute.
-------------------------------------------------------------------------------

function Gadget:onHold(hold)
end

-------------------------------------------------------------------------------
--	setState: overrides
-------------------------------------------------------------------------------

function Gadget:setState(bg, fg)
	if not bg then
		if self.Disabled then
			bg = self.BGPenDisabled
		elseif self.Selected then
			bg = self.BGPenSelected
		elseif self.Hilite then
			bg = self.BGPenHilite
		elseif self.Focus then
			bg = self.BGPenFocus
		end
	end
	if not fg then
		if self.Disabled then
			fg = self.FGPenDisabled
		elseif self.Selected then
			fg = self.FGPenSelected
		elseif self.Hilite then
			fg = self.FGPenHilite
		elseif self.Focus then
			fg = self.FGPenFocus
		end
	end
	fg = fg or self.FGPen or ui.PEN_DETAIL
	if fg ~= self.Foreground then
		self.Foreground = fg
		self.Redraw = true
	end
	Frame.setState(self, bg)
end

-------------------------------------------------------------------------------
--	passMsg: overrides
-------------------------------------------------------------------------------

function Gadget:passMsg(msg)
	local win = self.Window
	if win then -- might be gone if in a PopupWindow
		local he = win.HoverElement
		he = he == self and not he.Disabled and he
		if msg[2] == ui.MSG_MOUSEBUTTON then
			if msg[3] == 1 then -- leftdown:
				if he then
					win:setHiliteElement(self)
					if self:checkFocus() then
						win:setFocusElement(self)
					end
					win:setActiveElement(self)
				end
			elseif msg[3] == 2 then -- leftup:
				if he then
					win:setHiliteElement()
					win:setHiliteElement(self)
				end
			end
		elseif msg[2] == ui.MSG_MOUSEMOVE then
			if win.HiliteElement == self or he and not win.MovingElement then
				win:setHiliteElement(he)
				return false
			end
		end
	end
	return msg
end

-------------------------------------------------------------------------------
--	checkFocus: overrides
-------------------------------------------------------------------------------

function Gadget:checkFocus()
	local m = self.Mode
	return not self.Disabled and (m == "toggle" or m == "button" or
		(m == "touch" and not self.Selected))
end

-------------------------------------------------------------------------------
--	Gadget:onFocus(focused): This method is invoked when the element's
--	{{Focus}} attribute has changed (see also [[#tek.ui.class.area : Area]]).
-------------------------------------------------------------------------------

function Gadget:onFocus(focused)
	self.Window:setFocusElement(focused and self)
	self.RedrawBorder = true
	self:setState()
end
