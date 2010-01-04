-------------------------------------------------------------------------------
--
--	tek.ui.class.area
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] / 
--		Area ${subclasses(Area)}
--
--		This is the base class of all visible user interface elements.
--		It implements an outer margin, layouting, painting, and the
--		relationships to its neighbour elements.
--
--	ATTRIBUTES::
--		- {{AutoPosition [IG]}} (boolean)
--			When the element receives the focus, this flag instructs it to
--			automatically position itself into the visible area of any Canvas
--			that may contain it. An affected [[#tek.ui.class.canvas : Canvas]]
--			must have its {{AutoPosition}} attribute enabled as well for this
--			option to take effect (but unlike the Area class, in a Canvas it
--			is disabled by default).
--		- {{BGPen [G]}} (color specification)
--			The current color (or texture) for painting the element's
--			background. This value is set in Area:setState(), where it is
--			derived from the element's current state and the
--			''background-color'' style property. Valid are color names (e.g. 
--			{{"detail"}}, {{"fuchsia"}}, see also
--			[[#tek.ui.class.display : Display]] for more), a hexadecimal RGB
--			specification (e.g. {{"#334455"}}, {{"#f0f"}}), or an image URL
--			in the form {{"url(...)"}}.
--		- {{DamageRegion [G]}} ([[#tek.lib.region : Region]])
--			see {{TrackDamage}}
--		- {{Disabled [ISG]}} (boolean)
--			If '''true''', the element is in disabled state. This attribute is
--			handled by the [[#tek.ui.class.gadget : Gadget]] class.
--		- {{Drawable [G]}} ([[#tek.ui.class.drawable : Drawable]])
--			The Drawable for rendering, set during Area:show() and cleared
--			during Area:hide().
--		- {{EraseBG [IG]}} (boolean)
--			If '''true''', the element's background is painted automatically
--			using the Area:erase() method. Set this attribute to '''false''' to
--			indicate that you wish to paint the background yourself in the
--			Area:draw() method.
--		- {{Flags [SG]}} (Flags field)
--			This attribute holds various status flags:
--			- {{FL_SETUP}} - Set in Area:setup() and cleared in Area:cleanup()
--			- {{FL_LAYOUT}} - Set in Area:layout(), cleared in Area:cleanup()
--			- {{FL_SHOW}} - Set in Area:show(), cleared in Area:hide()
--			- {{FL_REDRAW}} - Set in Area:layout(), Area:damage(),
--			Area:setState() and possibly other places to indicate that the
--			element needs to be repainted. Cleared in Area:draw().
--			- {{FL_CHANGED}} - This flag indicates that the contents of an
--			element have changed, i.e. when children were added to a group,
--			or when setting a new text or image should cause a recalculation
--			of its size.
--		- {{Focus [SG]}} (boolean)
--			If '''true''', the element has the input focus. This attribute
--			is handled by the [[#tek.ui.class.gadget : Gadget]] class. Note:
--			The {{Focus}} attribute represents the current state, if you want
--			to place the initial focus on an element, use the {{InitialFocus}}
--			attribute in the [[#tek.ui.class.gadget : Gadget]] class.
--		- {{HAlign [IG]}} ({{"left"}}, {{"center"}}, {{"right"}})
--			Horizontal alignment of the element in its group. This attribute
--			can be controlled using the {{halign}} attribute.
--		- {{Height [IG]}} (number, '''false''', {{"fill"}}, {{"free"}})
--			Height of the element, in pixels, or
--				- '''false''' - unspecified; during initialization, the class'
--				default will be used
--				- {{"free"}} - Allows the element's height to grow to any size.
--				- {{"fill"}} - Completely fills up the height that is available
--				in the group, but does not claim more.
--			This attribute can be controlled using the {{height}} style
--			property.
--		- {{Hilite [SG]}} (boolean)
--			If '''true''', the element is in highlighted state. This
--			attribute is handled by the [[#tek.ui.class.gadget : Gadget]]
--			class.
--		- {{MaxHeight [IG]}} (number)
--			Maximum height of the element, in pixels [default: {{ui.HUGE}}].
--			This attribute is controllable via the {{max-height}} style
--			property.
--		- {{MaxWidth [IG]}} (number)
--			Maximum width of the element, in pixels [default: {{ui.HUGE}}].
--			This attribute is controllable via the {{max-width}} style
--			property.
--		- {{MinHeight [IG]}} (number)
--			Minimum height of the element, in pixels [default: 0].
--			This attribute is controllable via the {{min-height}} style
--			property.
--		- {{MinWidth [IG]}} (number)
--			Minimum width of the element, in pixels [default: 0].
--			This attribute is controllable via the {{min-width}} style
--			property.
--		- {{Selected [ISG]}} (boolean)
--			If '''true''', the element is in selected state. This attribute
--			is handled by the [[#tek.ui.class.gadget : Gadget]] class.
--		- {{TrackDamage [IG]}} (boolean)
--			If '''true''', the element collects intra-area damages in a
--			[[#tek.lib.region : Region]] named {{DamageRegion}}, which can be
--			used by class writers to implement minimally invasive repainting.
--			Default: '''false''', the element is repainted in its entirety.
--		- {{VAlign [IG]}} ({{"top"}}, {{"center"}}, {{"bottom"}})
--			Vertical alignment of the element in its group. This attribute
--			can be controlled using the {{valign}} attribute.
--		- {{Weight [IG]}} (number)
--			Determines the weight that is attributed to the element relative
--			to its siblings in its group. Note: By recommendation, the weights
--			in a group should sum up to 0x10000.
--		- {{Width [IG]}} (number, '''false''', {{"fill"}}, {{"free"}})
--			Width of the element, in pixels, or
--				- '''false''' - unspecified; during initialization, the class'
--				default will be used
--				- {{"free"}} - Allows the element's width to grow to any size
--				- {{"fill"}} - Completely fills up the width that is available
--				in the group, but does not claim more.
--			This attribute can be controlled using the {{width}} style
--			property.
--
--	STYLE PROPERTIES::
--		''background-attachment'' || {{"scollable"}} or {{"fixed"}}
--		''background-color'' || Controls {{Area.BGPen}}
--		''fixed'' || fixed layouter coordinates: {{"left top right bottom"}}
--		''halign'' || controls the {{Area.HAlign}} attribute
--		''height'' || controls the {{Area.Height}} attribute
--		''margin-bottom'' || the element's bottom margin, in pixels
--		''margin-left'' || the element's left margin, in pixels
--		''margin-right'' || the element's right margin, in pixels
--		''margin-top'' || the element's top margin, in pixels
--		''max-height'' || controls the {{Area.MaxHeight}} attribute
--		''max-width'' || controls the {{Area.MaxWidth}} attribute
--		''min-height'' || controls the {{Area.MinHeight}} attribute
--		''min-width'' || controls the {{Area.MinWidth}} attribute
--		''padding-bottom'' || the element's bottom padding
--		''padding-left'' || the element's left padding
--		''padding-right'' || the element's right padding
--		''padding-top'' || the element's top padding
--		''valign'' || controls the {{Area.VAlign}} attribute
--		''width'' || controls the {{Area.Width}} attribute
--
--		Note that repainting elements with a {{"fixed"}}
--		''background-attachment'' can be expensive. This variant should be
--		used sparingly, and some classes may implement it incompletely or
--		incorrectly.
--
--	IMPLEMENTS::
--		- Area:askMinMax() - Queries element's minimum and maximum dimensions
--		- Area:checkFocus() - Checks if the element can receive the input focus
--		- Area:checkHover() - Checks if the element can be hovered over
--		- Area:damage() - Notifies the element of a damage
--		- Area:draw() - Paints the element
--		- Area:drawBegin() - Prepares the rendering context
--		- Area:drawEnd() - Reverts the changes made in drawBegin()
--		- Area:erase() - Erases the element's background
--		- Area:focusRect() - Make the element fully visible
--		- Area:getBG() - Gets the element's background properties
--		- Area:getBGElement() - Gets the element's background element
--		- Area:getChildren() - Gets the element's children
--		- Area:getByXY() - Checks if the element covers a coordinate
--		- Area:getGroup() - Gets the element's group
--		- Area:getNext() - Gets the element's successor in its group
--		- Area:getPadding() - Gets the element's paddings
--		- Area:getParent() - Gets the element's parent element
--		- Area:getPrev() - Gets the element's predecessor in its group
--		- Area:getRect() - Returns the element's layouted coordinates
--		- Area:getSiblings() - Gets the element's siblings
--		- Area:hide() - Disconnects the element from a Drawable
--		- Area:layout() - Layouts the element into a rectangle
--		- Area:passMsg() - Passes an input message to the element
--		- Area:punch() - Subtracts the outline of the element from a
--		[[#tek.lib.region : Region]]
--		- Area:rethinkLayout() - Causes a relayout of the element and its group
--		- Area:setState() - Sets the background attribute of an element
--		- Area:show() - Connects the element to a Drawable, prepares drawing
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
local Element = ui.require("element", 16)
local Region = ui.loadLibrary("region", 9)

local assert = assert
local newFlags = ui.newFlags
local intersect = Region.intersect
local max = math.max
local min = math.min
local newRegion = ui.newRegion
local tonumber = tonumber
local type = type
local unpack = unpack

module("tek.ui.class.area", tek.ui.class.element)
_VERSION = "Area 36.0"
local Area = _M

local FL_REDRAW = ui.FL_REDRAW
local FL_LAYOUT = ui.FL_LAYOUT
local FL_SETUP = ui.FL_SETUP
local FL_SHOW = ui.FL_SHOW
local FL_CHANGED = ui.FL_CHANGED

local HUGE = ui.HUGE

-------------------------------------------------------------------------------
--	new:
-------------------------------------------------------------------------------

function Area.new(class, self)
	self = self or { }
	-- Combined margin and border offsets of the element:
	self.Margin = { }
	-- Calculated minimum/maximum sizes of the element:
	self.MinMax = { }
	-- The layouted rectangle of the element on the display:
	self.Rect = { }
	return Element.new(class, self)
end

-------------------------------------------------------------------------------
--	init:
-------------------------------------------------------------------------------

function Area.init(self)
	if self.AutoPosition == nil then
		self.AutoPosition = true
	end
	self.BGPen = false
	self.DamageRegion = false
	self.Disabled = self.Disabled or false
	self.Drawable = false
	if self.EraseBG == nil then
		self.EraseBG = true
	end
	self.Flags = newFlags()
	self.Focus = false
	self.HAlign = self.HAlign or false
	self.Height = self.Height or false
	self.Hilite = false
	self.MaxHeight = self.MaxHeight or false
	self.MaxWidth = self.MaxWidth or false
	self.MinHeight = self.MinHeight or false
	self.MinWidth = self.MinWidth or false
	self.Selected = self.Selected or false
	self.TrackDamage = self.TrackDamage or false
	self.VAlign = self.VAlign or false
	self.Weight = self.Weight or false
	self.Width = self.Width or false
	return Element.init(self)
end

-------------------------------------------------------------------------------
--	Area:setup(app, win): After passing the call on and returning from
--	Element:setup(), initializes fields which are being used by Area:layout(),
--	and sets {{FL_SETUP}} in the {{Flags}} field to indicate that the element
--	underwent its setup procedure.
-------------------------------------------------------------------------------

function Area:setup(app, win)
	Element.setup(self, app, win)
	local props = self.Properties
	self.HAlign = self.HAlign or props["halign"] or false
	self.VAlign = self.VAlign or props["valign"] or false
	local w = self.Width or props["width"]
	local h = self.Height or props["height"]
	local minw = self.MinWidth or props["min-width"]
	local minh = self.MinHeight or props["min-height"]
	local maxw = self.MaxWidth or props["max-width"]
	local maxh = self.MaxHeight or props["max-height"]
	if maxw == "none" then
		maxw = HUGE
	end
	if maxh == "none" then
		maxh = HUGE
	end
	minw = tonumber(minw) or tonumber(w) or minw
	minh = tonumber(minh) or tonumber(h) or minh
	maxw = tonumber(maxw) or tonumber(w) or maxw
	maxh = tonumber(maxh) or tonumber(h) or maxh
	self.Width = tonumber(w) or w or false
	self.Height = tonumber(h) or h or false
	self.MinWidth = tonumber(minw) or 0
	self.MinHeight = tonumber(minh) or 0
	self.MaxWidth = tonumber(maxw) or HUGE
	self.MaxHeight = tonumber(maxh) or HUGE
	local m = self.Margin
	m[1] = tonumber(props["margin-left"]) or 0
	m[2] = tonumber(props["margin-top"]) or 0
	m[3] = tonumber(props["margin-right"]) or 0
	m[4] = tonumber(props["margin-bottom"]) or 0
	self.Flags:set(FL_SETUP)
end

-------------------------------------------------------------------------------
--	Area:cleanup(): Clears all temporary layouting data and the {{FL_LAYOUT}}
--	and {{FL_SETUP}} flags, before passing on the call to Element:cleanup().
-------------------------------------------------------------------------------

function Area:cleanup()
	self.Margin = { }
	self.DamageRegion = false
	self.MinMax = { }
	self.Rect = { }
	self.Flags:clear(FL_LAYOUT + FL_SETUP + FL_REDRAW)
	Element.cleanup(self)
end

-------------------------------------------------------------------------------
--	Area:show(drawable): This function passes an element the
--	[[#tek.ui.class.drawable : Drawable]] that it will be rendered to. This
--	function is called when the element's window is opened.
-------------------------------------------------------------------------------

function Area:show(drawable)
	self:setState()
	self.Drawable = drawable
	self.Flags:set(FL_SHOW)
end

-------------------------------------------------------------------------------
--	Area:hide(): Clears a drawable from an element. Override this method to
--	free all display-related resources previously allocated in Area:show().
-------------------------------------------------------------------------------

function Area:hide()
	self.Drawable = false
	self.Flags:clear(FL_SHOW)
end

-------------------------------------------------------------------------------
--	Area:rethinkLayout([repaint[, check_size]]): Slates an element (and its
--	children) for relayouting, which will occur during the next Window update
--	cycle. If the element's coordinates change, this will cause it to be
--	repainted. The parent element (usually a Group) will be checked as well,
--	so that it has the opportunity to update its FreeRegion.
--	The optional argument {{repaint}} can be used to specify additional hints:
--		- {{1}} - marks the element for repainting unconditionally (not
--		implying possible children)
--		- {{2}} - marks the element (and all possible children) for repainting
--		unconditionally
--	The optional argument {{check_size}} (a boolean) can be used to
--	recalculate the element's minimum and maximum size requirements.
-------------------------------------------------------------------------------

function Area:rethinkLayout(repaint, check_size)
	if self.Flags:check(FL_SETUP) then
		if check_size then
			-- indicate possible change of group structure:
			self:getGroup().Flags:set(FL_CHANGED)
		end
		self.Window:addLayout(self, repaint or 0, check_size or false)
	end
end

-------------------------------------------------------------------------------
--	minw, minh, maxw, maxh = Area:askMinMax(minw, minh, maxw, maxh): This
--	method is called during the layouting process for adding the required
--	width and height to the minimum and maximum size of this object, before
--	passing the result on to its super class. {{minw}}, {{minh}} are
--	cumulative of the minimal size of the element, while {{maxw}}, {{maxw}}
--	collect the size the element is allowed to expand to.
-------------------------------------------------------------------------------

function Area:askMinMax(m1, m2, m3, m4)
	assert(self.Flags:check(FL_SETUP), "Element not set up")
	local p1, p2, p3, p4 = self:getPadding()
	local m, mm = self.Margin, self.MinMax
	m1 = max(self.MinWidth, m1 + p1 + p3)
	m2 = max(self.MinHeight, m2 + p2 + p4)
	m3 = max(min(self.MaxWidth, m3 + p1 + p3), m1)
	m4 = max(min(self.MaxHeight, m4 + p2 + p4), m2)
	m1 = m1 + m[1] + m[3]
	m2 = m2 + m[2] + m[4]
	m3 = m3 + m[1] + m[3]
	m4 = m4 + m[2] + m[4]
	mm[1], mm[2], mm[3], mm[4] = m1, m2, m3, m4
	return m1, m2, m3, m4
end

-------------------------------------------------------------------------------
--	changed = Area:layout(x0, y0, x1, y1[, markdamage]): Layouts the element
--	into the specified rectangle. If the element's (or any of its childrens')
--	coordinates change, returns '''true''' and marks the element as damaged,
--	unless the optional argument {{markdamage}} is set to '''false'''.
-------------------------------------------------------------------------------

function Area:layout(x0, y0, x1, y1, markdamage)

	local r = self.Rect
	local m = self.Margin

	x0 = x0 + m[1]
	y0 = y0 + m[2]
	x1 = x1 - m[3]
	y1 = y1 - m[4]

	local r1, r2, r3, r4 = unpack(r)
	if r1 == x0 and r2 == y0 and r3 == x1 and r4 == y1 then
		-- nothing changed:
		return
	end

	r[1], r[2], r[3], r[4] = x0, y0, x1, y1
	self.Flags:set(FL_LAYOUT)
	markdamage = markdamage ~= false

	if not r1 then
		-- this is the first layout:
		if markdamage then
			self.Flags:set(FL_REDRAW)
		end
		return true
	end

	-- delta shift, delta size:
	local dx = x0 - r1
	local dy = y0 - r2
	local dw = x1 - x0 - r3 + r1
	local dh = y1 - y0 - r4 + r2

	-- get element transposition:
	local d = self.Drawable
	local sx, sy = d:getShift()
	local win = self.Window

	local samesize = dw == 0 and dh == 0
	local validmove = (dx == 0) ~= (dy == 0)

	-- refresh element by copying if:
	-- * shifting occurs only on one axis
	-- * size is unchanged OR TrackDamage enabled
	-- * object is not already slated for copying

	if validmove and (samesize or self.TrackDamage) and
		not win.BlitObjects[self] then

		-- get source rect, incl. border:
		local s1 = x0 - dx - m[1]
		local s2 = y0 - dy - m[2]
		local s3 = x1 - dx + m[3]
		local s4 = y1 - dy + m[4]

		local can_copy

		local c1, c2, c3, c4 = d:getClipRect()
		if c1 then
			-- if we have a cliprect, check if parts become visible that
			-- were previously obscured (including borders and shift):
			local r = newRegion(r1 + sx - m[1], r2 + sy - m[2], r3 + sx + m[3],
				r4 + sy + m[4])
			r:subRect(c1, c2, c3, c4)
			r:shift(dx, dy)
			r:andRect(c1, c2, c3, c4)
			if r:isEmpty() then
				-- completely visible before and after:
				can_copy = true
			elseif self.TrackDamage then
				db.warn("partially visible (masked by cliprect)")
			end
		else
			can_copy = true
		end

		if can_copy then
			win.BlitObjects[self] = true
			win:addBlit(s1 + sx, s2 + sy, s3 + sx, s4 + sy, dx, dy,
				c1, c2, c3, c4)
			if samesize then
				-- something changed, no redraw. second value: border_ok hack
				return true, true
			end
			r1 = r1 + dx
			r2 = r2 + dy
			r3 = r3 + dx
			r4 = r4 + dy
		end
	end

	if x0 == r1 and y0 == r2 then
		-- did not move, size changed:
		if markdamage and self.TrackDamage then
			-- if damage is to be marked and can be tracked:
			local r = newRegion(x0, y0, x1, y1):subRect(r1, r2, r3, r4)
			-- clip new damage through current cliprect, correct by shift:
			local c1, c2, c3, c4 = d:getClipRect()
			if c1 then
				r:andRect(c1 - sx, c2 - sy, c3 - sx, c4 - sy)
			end
			r:forEach(self.damage, self)
		end
	end

	if markdamage then
		self.Flags:set(FL_REDRAW)
	end
	return true
end

-------------------------------------------------------------------------------
--	Area:punch(region): Subtracts the element from (by punching a hole into)
--	the specified Region. This function is called by the layouter.
-------------------------------------------------------------------------------

function Area:punch(region)
	region:subRect(unpack(self.Rect))
end

-------------------------------------------------------------------------------
--	Area:damage(x0, y0, x1, y1): If the element overlaps with the given
--	rectangle, this function marks it as damaged by setting {{ui.FL_REDRAW}}
--	in the element's {{Flag}} field. Additionally, if the element's
--	{{TrackDamage}} attribute is '''true''', intra-area damage rectangles are
--	collected in {{DamageRegion}}.
-------------------------------------------------------------------------------

function Area:damage(r1, r2, r3, r4)
	if self.Flags:check(FL_LAYOUT) then
		local s1, s2, s3, s4 = self:getRect()
		r1, r2, r3, r4 = intersect(r1, r2, r3, r4, s1, s2, s3, s4)
		local track = self.TrackDamage
		if r1 and (track or not self.Flags:check(FL_REDRAW)) then
			local dr = self.DamageRegion
			if dr then
				dr:orRect(r1, r2, r3, r4)
			elseif track then
				self.DamageRegion = newRegion(r1, r2, r3, r4)			
			end
			self.Flags:set(FL_REDRAW)
		end
	end
end

-------------------------------------------------------------------------------
--	success = Area:draw(): If the element is slated for a repaint (indicated
--	by the presence of the flag {{ui.FL_REDRAW}} in the {{Flags}} field),
--	draws the element into the rectangle that was assigned to it by the
--	layouter, clears {{ui.FL_REDRAW}}, and returns '''true'''. If the
--	atttribute {{EraseBG}} is set, this function also clears the element's
--	background by calling Area:erase().
--
--	When overriding this function, the control flow is roughly as follows:
--
--			function ElementClass:draw()
--			  if SuperClass.draw(self) then
--			    -- your rendering here
--			    return true
--			  end
--			end
--
--	There are rare occasions in which a class modifies the drawing context,
--	e.g. by setting a coordinate displacement. Such modifications must
--	be performed in Area:drawBegin() and undone in Area:drawEnd(). Then, the
--	control flow looks like this:
--
--			function ElementClass:draw()
--			  if SuperClass.draw(self) and self:drawBegin() then
--			    -- your rendering here
--			    self:drawEnd()
--			    return true
--			  end
--			end
-------------------------------------------------------------------------------

local FL_REDRAW_OK = FL_LAYOUT + FL_SHOW + FL_SETUP + FL_REDRAW

function Area:draw()
	-- check layout, show, setup, redraw, and clear redraw:
	if self.Flags:checkClear(FL_REDRAW_OK, FL_REDRAW) then
		if self.EraseBG and self:drawBegin() then
			self:erase()
			self:drawEnd()
		end
		self.DamageRegion = false
		return true
	end
end

-------------------------------------------------------------------------------
--	bgpen[, tx, ty] = Area:getBG(): Gets the element's background properties.
--	{{bgpen}} is the background pen (which may be a texture). If the element's
--	''background-attachment'' is {{"scrollable"}}, then {{tx}} and {{ty}} are
--	the coordinates of the texture origin, otherwise (if the attachment is
--	{{"fixed"}}) '''nil'''.
-------------------------------------------------------------------------------

function Area:getBG()
	local r1, r2 = self:getRect()
	if r1 then
		local bgpen = self.BGPen
		if self.Properties["background-attachment"] ~= "fixed" then
			return bgpen, r1, r2
		end
		return bgpen
	end
end

-------------------------------------------------------------------------------
--	element = Area:getBGElement(): Returns the element that is responsible for
--	painting the surroundings (or the background) of the element. This
--	information is useful for painting transparent or translucent parts of
--	the element, e.g. an inactive focus border.
-------------------------------------------------------------------------------

function Area:getBGElement()
	return self:getParent():getBGElement()
end

-------------------------------------------------------------------------------
--	Area:erase(): Clears the element's background. This method is invoked by
--	Area:draw() if the {{EraseBG}} attribute is set, and when a repaint is
--	both possible and necessary. Area:drawBegin() has been called already
--	when this function is called, and Area:drawEnd() will be called afterwards.
-------------------------------------------------------------------------------

function Area:erase()
	local d = self.Drawable
	local dr = self.DamageRegion
	local bgpen, tx, ty = self:getBG()
	bgpen = d.Pens[bgpen]
	if dr then
		-- repaint intra-area damagerects:
		dr:forEach(d.fillRect, d, bgpen, tx, ty)
	else
		local r1, r2, r3, r4 = self:getRect()
		d:fillRect(r1, r2, r3, r4, bgpen, tx, ty)
	end
end

-------------------------------------------------------------------------------
--	self = Area:getByXY(x, y): Returns {{self}} if the element covers
--	the specified coordinate.
-------------------------------------------------------------------------------

function Area:getByXY(x, y)
	local r1, r2, r3, r4 = self:getRect()
	if r1 and x >= r1 and x <= r3 and y >= r2 and y <= r4 then
		return self
	end
end

-------------------------------------------------------------------------------
--	msg = Area:passMsg(msg): This function filters the specified input
--	message. After processing, it is free to return the message unmodified
--	(thus passing it on to the next message handler), to return a copy that
--	has certain fields in the message modified, or to 'swallow' the message
--	by returning '''false'''. If you override this function, you are not
--	allowed to modify any data inside the original message; to alter a
--	message, you must operate on and return a copy.
-------------------------------------------------------------------------------

function Area:passMsg(msg)
	return msg
end

-------------------------------------------------------------------------------
--	Area:setState(bg): Sets the {{BGPen}} attribute according to
--	the state of the element, and if it changed, slates the element
--	for repainting.
-------------------------------------------------------------------------------

function Area:setState(bg, fg)
	local props = self.Properties
	bg = bg or props["background-color"] or "background"
	if bg == "transparent" then
		bg = self:getBGElement().BGPen
	end
	if bg ~= self.BGPen then
		self.BGPen = bg
		self.Flags:set(FL_REDRAW)
	end
end

-------------------------------------------------------------------------------
--	can_receive = Area:checkFocus(): Returns '''true''' if this element can
--	receive the input focus.
-------------------------------------------------------------------------------

function Area:checkFocus()
end

-------------------------------------------------------------------------------
--	can_hover = Area:checkHover(): Returns '''true''' if this element can
--	react on being hovered over by the pointing device.
-------------------------------------------------------------------------------

function Area:checkHover()
end

-------------------------------------------------------------------------------
--	table = Area:getNext(): Returns the next element in the group, or, if
--	the element has no successor, the next element in the parent group (and
--	so forth, until it reaches the topmost group). Returns '''nil''' if the
--	element is not currently connected.
-------------------------------------------------------------------------------

local function findelement(self)
	local g = self:getSiblings()
	if g then
		local n = #g
		for i = 1, n do
			if g[i] == self then
				return g, n, i
			end
		end
	end
end

function Area:getNext()
	local g, n, i = findelement(self)
	if g then
		if i == n then
			return self:getParent():getNext()
		end
		return g[i % n + 1]
	end
end

-------------------------------------------------------------------------------
--	element = Area:getPrev(): Returns the previous element in the group, or,
--	if the element has no predecessor, the next element in the parent group
--	(and so forth, until it reaches the topmost group). Returns '''nil''' if
--	the element is not currently connected.
-------------------------------------------------------------------------------

function Area:getPrev()
	local g, n, i = findelement(self)
	if g then
		if i == 1 then
			return self:getParent():getPrev()
		end
		return g[(i - 2) % n + 1]
	end
end

-------------------------------------------------------------------------------
--	element = Area:getGroup(parent): Returns the closest
--	[[#tek.ui.class.group : Group]] containing the element. If the {{parent}}
--	argument is '''true''', this function will start looking for the closest
--	group at its parent - otherwise, the element itself is returned if it is
--	a group already. Returns '''nil''' if the element is not currently
--	connected.
-------------------------------------------------------------------------------

function Area:getGroup()
	local p = self:getParent()
	if p then
		if p:getGroup() == p then
			return p
		end
		return p:getGroup(true)
	end
end

-------------------------------------------------------------------------------
--	table = Area:getSiblings(): Returns a table containing the element's
--	siblings, which includes the element itself. Returns '''nil''' if the
--	element is not currently connected. Note: The returned table must be
--	treated read-only.
-------------------------------------------------------------------------------

function Area:getSiblings()
	local p = self:getParent()
	return p and p:getChildren()
end

-------------------------------------------------------------------------------
--	element = Area:getParent(): Returns the element's parent element, or
--	'''false''' if it currently has no parent.
-------------------------------------------------------------------------------

function Area:getParent()
	return self.Parent
end

-------------------------------------------------------------------------------
--	element = Area:getChildren(init): Returns a table containing the element's
--	children, or '''nil''' if this element cannot have children. The optional
--	argument {{init}} is '''true''' when this function is called during
--	initialization or deinitialization - this can be used by some classes
--	that prefer hiding their children until they are needed. [TODO]
-------------------------------------------------------------------------------

function Area:getChildren()
end

-------------------------------------------------------------------------------
--	x0, y0, x1, y1, drawable = Area:getRect(): This function returns the
--	rectangle which the element has been layouted to, or '''nil'''
--	if the element has not been layouted yet.
-------------------------------------------------------------------------------

function Area:getRect()
	if self.Flags:check(FL_LAYOUT + FL_SHOW + FL_SETUP) then
		return unpack(self.Rect)
	end
end

-------------------------------------------------------------------------------
--	moved = Area:focusRect([x0, y0, x1, y1]): Tries to shift any Canvas
--	containing the element into a position that makes the element fully
--	visible. Optionally, a rectangle can be specified that is to be made
--	visible. Returns '''true''' to indicate that some kind of repositioning
--	has taken place.
-------------------------------------------------------------------------------

function Area:focusRect(r1, r2, r3, r4)
	if not r1 then
		r1, r2, r3, r4 = self:getRect()
	end
	local parent = self:getParent()
	if r1 and parent then
		local m = self.Margin
		return parent:focusRect(r1 - m[1], r2 - m[2], r3 - m[3], r4 - m[4])
	end
end

-------------------------------------------------------------------------------
--	can_draw = Area:drawBegin(): Prepares the drawing context, returning a
--	boolean indicating success. This function must be overridden if a class
--	wishes to modify the drawing context, e.g. by installing a coordinate
--	displacement.
-------------------------------------------------------------------------------

function Area:drawBegin()
	return self.Flags:check(FL_LAYOUT + FL_SHOW + FL_SETUP)
end

-------------------------------------------------------------------------------
--	Area:drawEnd(): Reverts the changes made to the drawing context during
--	Area:drawBegin().
-------------------------------------------------------------------------------

function Area:drawEnd()
end

-------------------------------------------------------------------------------
--	left, top, right, bottom = Area:getPadding(): Returns the element's
--	padding style properties.
-------------------------------------------------------------------------------

function Area:getPadding()
	local props = self.Properties
	return tonumber(props["padding-left"]) or 0,
		tonumber(props["padding-top"]) or 0,
		tonumber(props["padding-right"]) or 0, 
		tonumber(props["padding-bottom"]) or 0
end
