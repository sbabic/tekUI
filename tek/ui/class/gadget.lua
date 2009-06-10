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
--		This class implements interactions with the user.
--
--	ATTRIBUTES::
--		- {{Active [SG]}} (boolean)
--			Signifies a change of the Gadget's activation state. While active,
--			the position of the pointing device is being verified (which is
--			also reflected by the {{Hover}} attribute, see below). When the
--			{{Active}} state changes, the Gadget's behavior depends on its
--			{{Mode}} attribute (see below):
--				* in ''button'' mode, the {{Selected}} attribute is set to
--				the value of the {{Hover}} attribute. The {{Pressed}} attribute
--				is set to the value of the {{Active}} attribute, if it caused a
--				change of the {{Selected}} state.
--				* in ''toggle'' mode, the {{Selected}} attribute of the
--				Gadget is inverted logically, and the {{Pressed}} attribute is
--				set to '''true'''.
--				* in ''touch'' mode, the {{Selected}} and {{Pressed}}
--				attributes are set to '''true''', if the Gadget was not
--				selected already.
--			Changing this attribute invokes the Gadget:onActivate() method.
--		- {{DblClick [SG]}} (boolean)
--			Signifies that the element was double-clicked; it is set to
--			'''true''' when the element was double-clicked and is still being
--			held, and '''false''' when it was double-clicked and then released.
--			This attribute normally needs to get a notification handler
--			attached to it before it can be reacted on; see also
--			Object:addNotify().
--		- {{Disabled [ISG]}} (boolean)
--			Determines the Gadget's ability to interact with the user. When
--			changed, it invokes the Gadget:onDisable() method. When an element
--			is getting disabled, it loses its focus, too.
--		- {{EffectClass [IG]}} (string)
--			Name of a hook class for rendering an overlay effect. This
--			attribute is controllable via the ''effect-class'' style property.
--			A possible overlay effect is named ''ripple''. As its name
--			suggests, it can paint various ripple effects (e.g. for slider
--			knobs and bar handles). Effect hooks are loaded from
--			{{tek.ui.hook}} and may define their own style properties.
--		- {{FGColor [IG]}} (color specification)
--			A color specification for rendering the foreground details of the
--			element. This attribute is controllable via the ''color'' style
--			property.
--		- {{Hilite [SG]}} (boolean)
--			Signifies a change of the Gadget's highligting state. Invokes
--			Gadget:onHilite().
--		- {{Hold [SG]}} (boolean)
--			Signifies that the element is being held. While being held, the
--			value is repeatedly set to '''true''' in intervals of {{n/50}}
--			seconds, with {{n}} being determined by the 
--			[[#tek.ui.class.window : Window]].HoldTickRepeat attribute.
--			When the element is getting released, this value is set to
--			'''false'''. This attribute normally needs to get a notification
--			handler attached to it before it can be reacted on; see also
--			Object:addNotify().
--		- {{Hover [SG]}} (boolean)
--			Signifies a change of the Gadget being hovered by the pointing
--			device. Invokes Gadget:onHover().
--		- {{InitialFocus [IG]}} (boolean)
--			Specifies that the element should receive the focus initially.
--			If '''true''', the element will set the element's {{Focus}}
--			attribute to '''true''' upon invocation of the
--			[[#Area:show : show]] method.
--		- {{KeyCode [IG]}} (string or boolean)
--			If set, a keyboard equivalent for activating the element. See
--			[[#tek.ui.class.popitem : PopItem]] for a discussion of denoting
--			keyboard qualifiers. The [[#tek.ui.class.text : Text]] class allows
--			setting this attribute to '''true''', in which case the element's
--			{{Text}} will be examined during setup for an initiatory character
--			(by default an underscore), and if found, the {{KeyCode}} attribute
--			will be replaced by the character following this marker.
--		- {{Mode [IG]}} (string)
--			The element's interaction mode:
--				* {{"inert"}}: The element does not react to input
--				* {{"touch"}}: The element does not rebound and keeps its
--				{{Selected}} state; it cannot be unselected by the user and
--				always submits '''true''' for the {{Pressed}} and {{Selected}}
--				attributes.
--				* {{"toggle"}}: The element does not rebound immediately
--				and keeps its {{Selected}} state until the next activation.
--				* {{"button"}}: The element rebounds when the mouse button is
--				released or when it is no longer hovering it.
--			See also the {{Active}} attribute.
--		- {{Pressed [SG]}} (boolean)
--			Signifies that a button was pressed or released. Invokes
--			Gadget:onPress().
--		- {{Selected [ISG]}} (boolean)
--			Signifies a change of the Gadget's selection state. Invokes
--			Gadget:onSelect().
--
--	STYLE PROPERTIES::
--		- ''color'' || controls the {{Gadget.FGColor}} attribute
--		- ''effect-class'' || controls the {{Gadget.EffectClass}} attribute
--		- ''effect-color'' || controls the ''ripple'' effect hook
--		- ''effect-color2'' || controls the ''ripple'' effect hook
--		- ''effect-kind'' || controls the ''ripple'' effect hook
--		- ''effect-maxnum'' || controls the ''ripple'' effect hook
--		- ''effect-maxnum2'' || controls the ''ripple'' effect hook
--		- ''effect-orientation'' || controls the ''ripple'' effect hook
--		- ''effect-padding'' || controls the ''ripple'' effect hook
--		- ''effect-ratio'' || controls the ''ripple'' effect hook
--		- ''effect-ratio2'' || controls the ''ripple'' effect hook
--
--	STYLE PSEUDO CLASSES::
--		- ''active'' || for elements in active state
--		- ''disabled'' || for elements in disabled state
--		- ''focus'' || for elements that have the focus
--		- ''hover'' || for elements that are being hovered by the mouse
--
--	IMPLEMENTS::
--		- Gadget:onActivate() - Handler for {{Active}}
--		- Gadget:onDisable() - Handler for {{Disabled}}
--		- Gadget:onFocus() - Handler for {{Focus}}
--		- Gadget:onHilite() - Handler for {{Hilite}}
--		- Gadget:onHover() - Handler for {{Hover}}
--		- Gadget:onPress() - Handler for {{Pressed}}
--		- Gadget:onSelect() - Handler for {{Selected}}
--
--	OVERRIDES::
--		- Area:checkFocus()
--		- Area:checkHover()
--		- Element:cleanup()
--		- Element:getProperties()
--		- Object.init()
--		- Area:layout()
--		- Area:passMsg()
--		- Area:refresh()
--		- Area:setState()
--		- Element:setup()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Frame = ui.Frame

module("tek.ui.class.gadget", tek.ui.class.frame)
_VERSION = "Gadget 17.0"

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
local NOTIFY_FOCUS = { ui.NOTIFY_SELF, "onFocus", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Gadget.init(self)
	self.Active = false
	self.BGDisabled = self.BGDisabled or false
	self.BGFocus = self.BGFocus or false
	self.BGHilite = self.BGHilite or false
	self.BGSelected = self.BGSelected or false
	self.DblClick = false
	self.EffectHook = false
	self.EffectClass = self.EffectClass or false
	self.FGColor = self.FGColor or false
	self.FGDisabled = self.FGDisabled or false
	self.FGFocus = self.FGFocus or false
	self.FGHilite = self.FGHilite or false
	self.FGSelected = self.FGSelected or false
	self.FGPen = false
	self.Hold = false
	self.Hover = false
	self.InitialFocus = self.InitialFocus or false
	self.KeyCode = self.KeyCode or false
	self.Mode = self.Mode or "inert"
	self.OldActive = false
	self.Pressed = false
	return Frame.init(self)
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function Gadget:getProperties(p, pclass)
	self.EffectClass = self.EffectClass or 
		self:getProperty(p, pclass, "effect-class")
	self.FGColor = self.FGColor or self:getProperty(p, pclass, "color")
	self.BGDisabled = self.BGDisabled or
		self:getProperty(p, pclass or "disabled", "background-color")
	self.BGSelected = self.BGSelected or
		self:getProperty(p, pclass or "active", "background-color")
	self.BGHilite = self.BGHilite or
		self:getProperty(p, pclass or "hover", "background-color")
	self.BGFocus = self.BGFocus or
		self:getProperty(p, pclass or "focus", "background-color")
	self.FGDisabled = self.FGDisabled or
		self:getProperty(p, pclass or "disabled", "color")
	self.FGSelected = self.FGSelected or
		self:getProperty(p, pclass or "active", "color")
	self.FGHilite = self.FGHilite or
		self:getProperty(p, pclass or "hover", "color")
	self.FGFocus = self.FGFocus or
		self:getProperty(p, pclass or "focus", "color")
	Frame.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Gadget:setup(app, window)
	Frame.setup(self, app, window)
	-- add notifications:
	self:addNotify("Disabled", ui.NOTIFY_ALWAYS, NOTIFY_DISABLED)
	self:addNotify("Hilite", ui.NOTIFY_ALWAYS, NOTIFY_HILITE)
	self:addNotify("Selected", ui.NOTIFY_ALWAYS, NOTIFY_SELECTED)
	self:addNotify("Hover", ui.NOTIFY_ALWAYS, NOTIFY_HOVER)
	self:addNotify("Active", ui.NOTIFY_ALWAYS, NOTIFY_ACTIVE)
	self:addNotify("Pressed", ui.NOTIFY_ALWAYS, NOTIFY_PRESSED)
	self:addNotify("Focus", ui.NOTIFY_ALWAYS, NOTIFY_FOCUS)
	-- create effect hook:
	self.EffectHook = ui.createHook("hook", self.EffectClass, self,
		{ Style = self.Style })
	local interactive = self.Mode ~= "inert"
	local keycode = self.KeyCode
	if interactive and keycode then
		self.Window:addKeyShortcut(keycode, self)
	end
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Gadget:cleanup()
	self.EffectHook = ui.destroyHook(self.EffectHook)
	self.Window:remKeyShortcut(self.KeyCode, self)
	self:remNotify("Focus", ui.NOTIFY_ALWAYS, NOTIFY_FOCUS)
	self:remNotify("Pressed", ui.NOTIFY_ALWAYS, NOTIFY_PRESSED)
	self:remNotify("Active", ui.NOTIFY_ALWAYS, NOTIFY_ACTIVE)
	self:remNotify("Hover", ui.NOTIFY_ALWAYS, NOTIFY_HOVER)
	self:remNotify("Selected", ui.NOTIFY_ALWAYS, NOTIFY_SELECTED)
	self:remNotify("Hilite", ui.NOTIFY_ALWAYS, NOTIFY_HILITE)
	self:remNotify("Disabled", ui.NOTIFY_ALWAYS, NOTIFY_DISABLED)
	Frame.cleanup(self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Gadget:show(drawable)
	Frame.show(self, drawable)
	if self.Mode ~= "inert" and self.InitialFocus then
		self:setValue("Focus", true)
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
--	refresh: overrides
-------------------------------------------------------------------------------

function Gadget:refresh()
	local redraw = self.EffectHook and self.Redraw
	Frame.refresh(self)
	if redraw then
		self.EffectHook:draw(self.Drawable)
	end
end

-------------------------------------------------------------------------------
--	Gadget:onHover(hovered): This method is invoked when the Gadget's {{Hover}}
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
--	Gadget:onActivate(active): This method is invoked when the Gadget's
--	{{Active}} attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onActivate(active)

	-- released over a popup which was entered with the button held?
	local win = self.Window
	local collapse = active == false and self.OldActive == false
		and win and win.PopupRootWindow
	self.OldActive = active

	local mode, selected, dblclick = self.Mode, self.Selected
	if mode == "toggle" then
		if active or collapse then
			self:setValue("Selected", not selected)
			self:setValue("Pressed", true, true)
			dblclick = self
		end
	elseif mode == "touch" then
		if (active and not selected) or collapse then
			self:setValue("Selected", true)
			self:setValue("Pressed", true, true)
			dblclick = self
		end
	elseif mode == "button" then
		self:setValue("Selected", active and self.Hover)
		if (not selected ~= not active) or collapse then
			self:setValue("Pressed", active, true)
			dblclick = active and self
		end
	end
	
	win = self.Window
	
	if dblclick ~= nil and win then
		win:setDblClickElement(dblclick)
	end
		
	if collapse and win then
		win:finishPopup()
	end
	
	self:setState()
end

-------------------------------------------------------------------------------
--	Gadget:onDisable(disabled): This method is invoked when the Gadget's
--	{{Disabled}} attribute has changed.
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
--	Gadget:onSelect(selected): This method is invoked when the Gadget's
--	{{Selected}} attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onSelect(selected)

	--	HACK for better touchpad support -- unfortunately an element is
	--	deselected also when the mouse is leaving the window, so this is
	--	not entirely satisfactory.

	-- if not selected then
	-- 	if self.Active then
	-- 		db.warn("Element deselected, forcing inactive")
	-- 		self.Window:setActiveElement()
	-- 	end
	-- end

	self.RedrawBorder = true
	self:setState()
end

-------------------------------------------------------------------------------
--	Gadget:onHilite(selected): This method is invoked when the Gadget's
--	{{Hilite}} attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onHilite(hilite)
	self:setState()
end

-------------------------------------------------------------------------------
--	Gadget:onPress(pressed): This method is invoked when the Gadget's
--	{{Pressed}} attribute has changed.
-------------------------------------------------------------------------------

function Gadget:onPress(pressed)
end

-------------------------------------------------------------------------------
--	setState: overrides
-------------------------------------------------------------------------------

function Gadget:setState(bg, fg)
	if not bg then
		if self.Disabled then
			bg = self.BGDisabled
		elseif self.Selected then
			bg = self.BGSelected
		elseif self.Hilite then
			bg = self.BGHilite
		elseif self.Focus then
			bg = self.BGFocus
		end
	end
	if not fg then
		if self.Disabled then
			fg = self.FGDisabled
		elseif self.Selected then
			fg = self.FGSelected
		elseif self.Hilite then
			fg = self.FGHilite
		elseif self.Focus then
			fg = self.FGFocus
		end
	end
	fg = fg or self.FGColor or ui.PEN_DETAIL
	if fg ~= self.FGPen then
		self.FGPen = fg
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
				if not self.Disabled and
					self:getByXY(msg[4], msg[5]) == self then
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
--	checkHover: overrides
-------------------------------------------------------------------------------

function Gadget:checkHover()
	return not self.Disabled and self.Mode ~= "inert"
end

-------------------------------------------------------------------------------
--	Gadget:onFocus(focused): This method is invoked when the element's
--	{{Focus}} attribute has changed (see also [[#tek.ui.class.area : Area]]).
-------------------------------------------------------------------------------

function Gadget:onFocus(focused)
	if focused and self.AutoPosition then
		self:focusRect()
	end
	self.Window:setFocusElement(focused and self)
	self.RedrawBorder = true
	self:setState()
end
