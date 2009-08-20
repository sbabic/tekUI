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
--		[[#tek.ui.class.element : Element]] / Area
--
--		This is the base class of all visible user interface elements.
--		It implements an outer margin, layouting, drawing, and the
--		relationships to its neighbours.
--
--	ATTRIBUTES::
--		- {{AutoPosition [IG]}} (boolean)
--			When the element receives the focus, this flag instructs it to
--			position itself automatically into the visible area of any Canvas
--			that may contain it. An affected [[#tek.ui.class.canvas : Canvas]]
--			must have its {{AutoPosition}} attribute enabled as well for this
--			option to take effect, but unlike the Area class, the Canvas
--			disables it by default.
--		- {{BGColor [IG]}} (color specification)
--			A color specification for painting the background of the element.
--			Valid are predefined color numbers (e.g. {{ui.PEN_DETAIL}}),
--			predefined color names (e.g. {{"detail"}}, see also 
--			[[#tek.ui.class.display : Display]] for more), or a direct
--			hexadecimal RGB specification (e.g. {{"#334455"}}, {{"#f0f"}}.
--			This attribute is controllable via the {{background-color}} style
--			property.
--		- {{BGPosition [IG]}} (boolean or string)
--			Kind of anchoring for a possible background image or texture:
--				* {{"scollable"}} or '''false''' - The texture is anchored to
--				the element and during scrolling moves with it.
--				* {{"fixed"}} - The texture is anchored to the Window.
--			Note that repainting elements with {{"fixed"}} anchoring can be
--			expensive. This variant should be used sparingly, and some classes
--			may implement it incompletely or incorrectly. This attribute can
--			be controlled using the {{background-position}} attribute.
--		- {{DamageRegion [G]}} ([[#tek.lib.region : Region]])
--			see {{TrackDamage}}
--		- {{Disabled [ISG]}} (boolean)
--			If '''true''', the element is in disabled state. This attribute is
--			handled by the [[#tek.ui.class.gadget : Gadget]] class.
--		- {{EraseBG [IG]}} (boolean)
--			If '''true''', the element's background is painted automatically
--			using the Area:erase() method. Set this attribute to '''false''' to
--			indicate that you wish to paint the background yourself.
--		- {{Focus [SG]}} (boolean)
--			If '''true''', the element has the input focus. This attribute
--			is handled by the [[#tek.ui.class.gadget : Gadget]] class. Note:
--			The {{Focus}} attribute cannot be initialized; see also the
--			[[#tek.ui.class.gadget : InitialFocus]] attribute.
--		- {{HAlign [IG]}} ({{"left"}}, {{"center"}}, {{"right"}})
--			Horizontal alignment of the element in its group. This attribute
--			can be controlled using the {{horizontal-grid-align}} attribute.
--		- {{Height [IG]}} (number, '''false''', {{"auto"}}, {{"fill"}}, 
--		{{"free"}})
--			Height of the element, in pixels, or
--				- '''false''' - unspecified; during initialization, the class'
--				default will be used
--				- {{"auto"}} - Reserves the minimal height needed for the
--				element.
--				- {{"free"}} - Allows the element's height to grow to any size.
--				- {{"fill"}} - Completely fills up the height that other
--				elements in the same group have left, but does not claim more.
--				This value is useful only once per group.
--			This attribute can be controlled using the {{height}} style
--			property.
--		- {{Hilite [SG]}} (boolean)
--			If '''true''', the element is in highlighted state. This
--			attribute is handled by the [[#tek.ui.class.gadget : Gadget]]
--			class.
--		- {{Margin [IG]}} (table)
--			An array of four offsets for the element's outer margin in the
--			order left, right, top, bottom [pixels]. If unspecified during
--			initialization, the class' default margins are used. This
--			attribute is controllable via the {{margin}} style property.
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
--		- {{Padding [IG]}} (table)
--			An array of four offsets for the element's inner padding in the
--			order left, right, top, bottom [pixels]. If unspecified during
--			initialization, the class' default paddings are used.
--			This attribute is controllable via the {{padding}} style
--			property.
--		- {{Selected [ISG]}} (boolean)
--			If '''true''', the element is in selected state. This attribute
--			is handled by the [[#tek.ui.class.gadget : Gadget]] class.
--		- {{TrackDamage [IG]}} (boolean)
--			If '''true''', the element collects intra-area damages in a
--			[[#tek.lib.region : Region]] named {{DamageRegion}}, which can be
--			used by class writers to implement minimally invasive repaints.
--			Default: '''false''', the element is repainted in its entirety.
--		- {{VAlign [IG]}} ({{"top"}}, {{"center"}}, {{"bottom"}})
--			Vertical alignment of the element in its group. This attribute
--			can be controlled using the {{vertical-grid-align}} attribute.
--		- {{Weight [IG]}} (number)
--			Determines the weight that is attributed to the element relative
--			to its siblings in its group. Note: By recommendation, the weights
--			in a group should sum up to 0x10000.
--		- {{Width [IG]}} (number, '''false''', {{"auto"}}, {{"fill"}},
--		{{"free"}})
--			Width of the element, in pixels, or
--				- '''false''' - unspecified; during initialization, the class'
--				default will be used
--				- {{"auto"}} - Reserves the minimal width needed for the
--				element
--				- {{"free"}} - Allows the element's width to grow to any size
--				- {{"fill"}} - Completely fills up the width that other
--				elements in the same group have left, but does not claim more.
--			Note: Normally, "fill" is useful only once per group.
--
--	STYLE PROPERTIES::
--		- ''background-color'' || controls the {{Area.BGColor}} attribute
--		- ''background-position'' || controls the {{Area.BGPosition}} attribute
--		- ''height'' || controls the {{Area.Height}} attribute
--		- ''horizontal-grid-align'' || controls the {{Area.HAlign}} attribute
--		- ''margin'' || controls the {{Area.Margin}} attribute
--		- ''margin-bottom'' || controls the {{Area.Margin}} attribute
--		- ''margin-left'' || controls the {{Area.Margin}} attribute
--		- ''margin-right'' || controls the {{Area.Margin}} attribute
--		- ''margin-top'' || controls the {{Area.Margin}} attribute
--		- ''max-height'' || controls the {{Area.MaxHeight}} attribute
--		- ''max-width'' || controls the {{Area.MaxWidth}} attribute
--		- ''min-height'' || controls the {{Area.MinHeight}} attribute
--		- ''min-width'' || controls the {{Area.MinWidth}} attribute
--		- ''padding'' || controls the {{Area.Padding}} attribute
--		- ''padding-bottom'' || controls the {{Area.Padding}} attribute
--		- ''padding-left'' || controls the {{Area.Padding}} attribute
--		- ''padding-right'' || controls the {{Area.Padding}} attribute
--		- ''padding-top'' || controls the {{Area.Padding}} attribute
--		- ''vertical-grid-align'' || controls the {{Area.VAlign}} attribute
--		- ''width'' || controls the {{Area.Width}} attribute
--
--	IMPLEMENTS::
--		- Area:askMinMax() - Queries element's minimum and maximum dimensions
--		- Area:checkFocus() - Checks if the element can receive the input focus
--		- Area:checkHover() - Checks if the element can be hovered over
--		- Area:damage() - Notifies the element of a damage
--		- Area:draw() - Paints the element
--		- Area:erase() - Erases the element's background
--		- Area:focusRect() - Make the element fully visible
--		- Area:getBG() - Gets the element's background properties
--		- Area:getBGElement() - Gets the element's background element
--		- Area:getChildren() - Gets the element's children
--		- Area:getByXY() - Checks if the element covers a coordinate
--		- Area:getGroup() - Gets the element's group
--		- Area:getNext() - Gets the element's successor in its group
--		- Area:getParent() - Gets the element's parent element
--		- Area:getPrev() - Gets the element's predecessor in its group
--		- Area:getRect() - Returns the element's layouted coordinates
--		- Area:getSiblings() - Gets the element's siblings
--		- Area:hide() - Disconnects the element from a Drawable
--		- Area:layout() - Layouts the element into a rectangle
--		- Area:passMsg() - Passes an input message to the element
--		- Area:punch() - Subtracts the outline of the element from a
--		[[#tek.lib.region : Region]]
--		- Area:refresh() - Repaints the element if necessary
--		- Area:relayout() - Relayouts the element if necessary
--		- Area:rethinkLayout() - Causes a relayout of the element and its group
--		- Area:setState() - Sets the background attribute of an element
--		- Area:show() - Connects the element to a Drawable
--
--	OVERRIDES::
--		- Element:cleanup()
--		- Element:getProperties()
--		- Object.init()
--		- Class.new()
--		- Element:setup()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local Element = ui.Element
local Region = require "tek.lib.region"

local freeRegion = ui.freeRegion
local intersect = Region.intersect
local max = math.max
local min = math.min
local newRegion = ui.newRegion
local tonumber = tonumber
local unpack = unpack

module("tek.ui.class.area", tek.ui.class.element)
_VERSION = "Area 27.0"
local Area = _M

-------------------------------------------------------------------------------
--	new:
-------------------------------------------------------------------------------

function Area.new(class, self)
	self = self or { }
	-- Combined margin and border offsets of the element:
	self.MarginAndBorder = { }
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
	self.BGColor = self.BGColor or false
	self.BGPosition = false
	self.DamageRegion = false
	self.Disabled = self.Disabled or false
	self.Drawable = false
	if self.EraseBG == nil then
		self.EraseBG = true
	end
	self.Focus = false
	self.HAlign = self.HAlign or false
	self.Height = self.Height or false
	self.Hilite = false
	self.Margin = self.Margin or { }
	self.MaxHeight = self.MaxHeight or false
	self.MaxWidth = self.MaxWidth or false
	self.MinHeight = self.MinHeight or false
	self.MinWidth = self.MinWidth or false
	self.Padding = self.Padding or { }
	self.Redraw = false
	self.Selected = self.Selected or false
	self.TrackDamage = self.TrackDamage or false
	self.VAlign = self.VAlign or false
	self.Weight = self.Weight or false
	self.Width = self.Width or false
	return Element.init(self)
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function Area:getProperties(p, pclass)
	self.BGPosition = self.BGPosition or
		self:getProperty(p, pclass, "background-position")
	self.BGColor = self.BGColor or 
		self:getProperty(p, pclass, "background-color")
	self.HAlign = self.HAlign or
		self:getProperty(p, pclass, "horizontal-grid-align")
	self.VAlign = self.VAlign or
		self:getProperty(p, pclass, "vertical-grid-align")
	self.Width = self.Width or self:getProperty(p, pclass, "width")
	self.Height = self.Height or self:getProperty(p, pclass, "height")

	local m = self.Margin
	m[1] = m[1] or self:getNumProperty(p, pclass, "margin-left")
	m[2] = m[2] or self:getNumProperty(p, pclass, "margin-top")
	m[3] = m[3] or self:getNumProperty(p, pclass, "margin-right")
	m[4] = m[4] or self:getNumProperty(p, pclass, "margin-bottom")

	self.MaxHeight = self.MaxHeight or
		self:getProperty(p, pclass, "max-height")
	self.MaxWidth = self.MaxWidth or self:getProperty(p, pclass, "max-width")
	self.MinHeight = self.MinHeight or
		self:getProperty(p, pclass, "min-height")
	self.MinWidth = self.MinWidth or self:getProperty(p, pclass, "min-width")

	local q = self.Padding
	q[1] = q[1] or self:getNumProperty(p, pclass, "padding-left")
	q[2] = q[2] or self:getNumProperty(p, pclass, "padding-top")
	q[3] = q[3] or self:getNumProperty(p, pclass, "padding-right")
	q[4] = q[4] or self:getNumProperty(p, pclass, "padding-bottom")

	Element.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Area:setup(app, win)
	Element.setup(self, app, win)
	-- consolidation of properties:
	self.Width = tonumber(self.Width) or self.Width
	self.Height = tonumber(self.Height) or self.Height
	local m, p = self.Margin, self.Padding
	m[1], m[2], m[3], m[4] = m[1] or 0, m[2] or 0, m[3] or 0, m[4] or 0
	p[1], p[2], p[3], p[4] = p[1] or 0, p[2] or 0, p[3] or 0, p[4] or 0
	if not self.MaxHeight then
		self.MaxHeight = ui.HUGE
	end
	if not self.MaxWidth then
		self.MaxWidth = ui.HUGE
	end
	self.MinHeight = self.MinHeight or 0
	self.MinWidth = self.MinWidth or 0
	-- initialize margin_and_border:
	local d, s = self.MarginAndBorder, self.Margin
	d[1], d[2], d[3], d[4] = s[1], s[2], s[3], s[4]
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Area:cleanup()
	self.MarginAndBorder = { }
	self.DamageRegion = freeRegion(self.DamageRegion)
	self.MinMax = { }
	self.Rect = { }
	Element.cleanup(self)
end

-------------------------------------------------------------------------------
--	show(drawable): This function passes an element the
--	[[#tek.ui.class.drawable : Drawable]] that it will be rendered to. This
--	function is called when the element's window is opened.
-------------------------------------------------------------------------------

function Area:show(drawable)
	self:setState()
	self.Drawable = drawable
end

-------------------------------------------------------------------------------
--	hide(): Clears a drawable from an element. Override this method to free
--	all display-related resources previously allocated in Area:show().
-------------------------------------------------------------------------------

function Area:hide()
	self.Drawable = false
end

-------------------------------------------------------------------------------
--	rethinkLayout([damage]): This method causes a relayout of the element and
--	possibly the [[#tek.ui.class.group : Group]] in which it resides (and even
--	parent groups thereof if necessary). The optional numeric argument
--	{{damage}} indicates the kind of damage to apply to the element:
--		- {{0}} - do not mark the element as damaged
--		- {{1}} - slate the group (not its contents) for repaint [default]
--		- {{2}} - mark the whole group and its contents as damaged
-------------------------------------------------------------------------------

function Area:rethinkLayout(damage)
	-- must be on a display and layouted previously:
	if self.Drawable and self.Rect[1] then
		local pgroup = self:getGroup(true) -- get parent group
		self.Window:addLayoutGroup(pgroup, damage or 1)
		-- cause the rethink to bubble up until it reaches the Window:
		pgroup:rethinkLayout(0)
	else
		db.info("%s : Cannot rethink layout - not connected/layouted",
			self:getClassName())
	end
end

-------------------------------------------------------------------------------
--	minw, minh, maxw, maxh = askMinMax(minw, minh, maxw, maxh): This
--	method is called during the layouting process for adding the required
--	spatial extents (width and height) of this object to the min/max values
--	passed from a child class, before passing them on to its super class.
--	{{minw}}, {{minh}} are cumulative of the minimal size of the element,
--	while {{maxw}}, {{maxw}} collect the size the element is allowed to
--	expand to. Use {{ui.HUGE}} to indicate a (practically) unlimited size.
-------------------------------------------------------------------------------

function Area:askMinMax(m1, m2, m3, m4)
	local p, m, mm = self.Padding, self.MarginAndBorder, self.MinMax
	m1 = max(self.MinWidth, m1 + p[1] + p[3])
	m2 = max(self.MinHeight, m2 + p[2] + p[4])
	m3 = max(min(self.MaxWidth, m3 + p[1] + p[3]), m1)
	m4 = max(min(self.MaxHeight, m4 + p[2] + p[4]), m2)
	m1 = m1 + m[1] + m[3]
	m2 = m2 + m[2] + m[4]
	m3 = m3 + m[1] + m[3]
	m4 = m4 + m[2] + m[4]
	mm[1], mm[2], mm[3], mm[4] = m1, m2, m3, m4
	return m1, m2, m3, m4
end

-------------------------------------------------------------------------------
--	changed = layout(x0, y0, x1, y1[, markdamage]): Layouts the element
--	into the specified rectangle. If the element's (or any of its childrens')
--	coordinates change, returns '''true''' and marks the element as damaged,
--	unless the optional argument {{markdamage}} is set to '''false'''.
-------------------------------------------------------------------------------

function Area:layout(x0, y0, x1, y1, markdamage)

	local r = self.Rect
	local m = self.MarginAndBorder

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
	markdamage = markdamage ~= false

	if not r1 then
		-- this is the first layout:
		self.Redraw = self.Redraw or markdamage
		return true
	end

	-- delta shift, delta size:
	local dx = x0 - r1
	local dy = y0 - r2
	local dw = x1 - x0 - r3 + r1
	local dh = y1 - y0 - r4 + r2
	
	-- get element transposition:
	local sx, sy = self.Drawable:getShift()
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
		
		local c1, c2, c3, c4 = self.Drawable:getClipRect()
		if c1 then
			-- if we have a cliprect, check if parts become visible that
			-- were previously obscured (including borders and shift):
			local r = newRegion(r1 + sx - m[1], r2 + sy - m[2], r3 + sx + m[3],
				r4 + sy + m[4])
			r:subRect(c1, c2, c3, c4)
			r:trans(dx, dy)
			r:andRect(c1, c2, c3, c4)
			if r:isNull() then
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
				-- something changed, no Redraw. second value: border_ok hack
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
			local d = self.DamageRegion
			if d then
				r:forEach(d.orRect, d)
				freeRegion(r)
			else
				self.DamageRegion = r
			end
		end
	end
	
	self.Redraw = self.Redraw or markdamage -- mark damage (if requested)
	return true
end

-------------------------------------------------------------------------------
--	found[, changed] = relayout(element, x0, y0, x1, y1):
--	Traverses the element tree searching for the specified element, and if
--	this class (or the class of one of its children) is responsible for it,
--	layouts it to the specified rectangle. Returns '''true''' if the element
--	was found and its layout updated. A secondary return value of '''true'''
--	indicates whether relayouting actually caused a change, i.e. a damage to
--	the object.
-------------------------------------------------------------------------------

function Area:relayout(e, r1, r2, r3, r4)
	if self == e then
		return true, self:layout(r1, r2, r3, r4)
	end
end

-------------------------------------------------------------------------------
--	punch(region): Subtracts the element from (punching a
--	hole into) the specified Region. This function is called by the layouter.
-------------------------------------------------------------------------------

function Area:punch(region)
	region:subRect(unpack(self.Rect))
end

-------------------------------------------------------------------------------
--	damage(x0, y0, x1, y1): If the element overlaps with the given
--	rectangle, this function marks it as damaged.
-------------------------------------------------------------------------------

function Area:damage(r1, r2, r3, r4)
	if self.TrackDamage or not self.Redraw then
		local s1, s2, s3, s4 = self:getRect()
		if s1 then
			r1, r2, r3, r4 = intersect(r1, r2, r3, r4, s1, s2, s3, s4)
			if r1 then
				self.Redraw = true
				if self.DamageRegion then
					self.DamageRegion:orRect(r1, r2, r3, r4)
				elseif self.TrackDamage then
					self.DamageRegion = newRegion(r1, r2, r3, r4)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
--	draw(): Draws the element into the rectangle assigned to it by
--	the layouter; the coordinates can be found in the element's {{Rect}}
--	table. Note: Applications are not allowed to call this function directly.
-------------------------------------------------------------------------------

function Area:draw()
	if self.EraseBG then
		self:erase()
	end
end

-------------------------------------------------------------------------------
--	bgpen[, tx, ty] = getBG(): Gets the element's background properties.
--	{{bgpen}} is the background pen (which may be a texture). If the element
--	background is scrollable, then {{tx}} and {{ty}} are the coordinates of
--	the texture origin, otherwise (if the background is fixed) '''nil'''.
-------------------------------------------------------------------------------

function Area:getBG()
	local bgpen = self.BGPen
	if self.BGPosition ~= "fixed" then
		local r = self.Rect
		return bgpen, r[1], r[2]
	end
	return bgpen
end	

-------------------------------------------------------------------------------
--	element = getBGElement(): Returns the element that is responsible for
--	painting the surroundings (or the background) of the element. This
--	information is useful for painting transparent or translucent parts of
--	the element, e.g. an inactive focus border.
-------------------------------------------------------------------------------

function Area:getBGElement()
	return self:getParent():getBGElement()
end

-------------------------------------------------------------------------------
--	erase(): Clears the element's background.
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
		local r = self.Rect
		d:fillRect(r[1], r[2], r[3], r[4], bgpen, tx, ty)
	end
end

-------------------------------------------------------------------------------
--	refresh(): Redraws the element (and all possible children)
--	if they are marked as damaged. This function is called in the Window's
--	update procedure.
-------------------------------------------------------------------------------

function Area:refresh()
	if self.Redraw then
		self:draw()
		self.Redraw = false
		self.DamageRegion = freeRegion(self.DamageRegion)
	end
end

-------------------------------------------------------------------------------
--	self = getByXY(x, y): Returns {{self}} if the element covers
--	the specified coordinate.
-------------------------------------------------------------------------------

function Area:getByXY(x, y)
	local r1, r2, r3, r4 = self:getRect()
	if r1 and x >= r1 and x <= r3 and y >= r2 and y <= r4 then
		return self
	end
end

-------------------------------------------------------------------------------
--	msg = passMsg(msg): This function filters the specified input
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
--	setState(bg): Sets the {{BGPen}} attribute according to
--	the state of the element, and if it changed, slates the element
--	for repainting.
-------------------------------------------------------------------------------

function Area:setState(bg, fg)
	bg = bg or self.BGColor or ui.PEN_BACKGROUND
	if bg == ui.PEN_PARENTGROUP then
		bg = self:getBGElement().BGPen
	end
	if bg ~= self.BGPen then
		self.BGPen = bg
		self.Redraw = true
	end
end

-------------------------------------------------------------------------------
--	can_receive = checkFocus(): Returns '''true''' if this element can
--	receive the input focus.
-------------------------------------------------------------------------------

function Area:checkFocus()
end

-------------------------------------------------------------------------------
--	can_hover = checkHover(): Returns '''true''' if this element can
--	react on being hovered over by the pointing device.
-------------------------------------------------------------------------------

function Area:checkHover()
end

-------------------------------------------------------------------------------
--	element = getNext(): Returns the next element in the group, or, if
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
--	element = getPrev(): Returns the previous element in the group, or,
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
--	element = getGroup(parent): Returns the element's closest
--	[[#tek.ui.class.group : Group]] containing it. If the {{parent}} argument
--	is '''true''', this function will start looking for the closest group at
--	its parent (otherwise it returns itself if it is a group already). Returns
--	'''nil''' if the element is not currently connected.
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
--	element = getSiblings(): Returns a table containing the element's
--	siblings (including the element itself). Returns '''nil''' if the element
--	is not currently connected. Note: The returned table must be treated
--	read-only. 
-------------------------------------------------------------------------------

function Area:getSiblings()
	local p = self:getParent()
	return p and p:getChildren()
end

-------------------------------------------------------------------------------
--	element = getParent(): Returns the element's parent element, or
--	'''false''' if it currently has no parent.
-------------------------------------------------------------------------------

function Area:getParent()
	return self.Parent
end

-------------------------------------------------------------------------------
--	element = getChildren(init): Returns a table containing the element's
--	children, or '''nil''' if this element cannot have children. If the
--	optional {{init}} argument is '''true''', this signals that this function
--	is called during initialization or deinitialization.
-------------------------------------------------------------------------------

function Area:getChildren()
end

-------------------------------------------------------------------------------
--	x0, y0, x1, y1 = getRect(): This function returns the
--	rectangle which the element has been layouted to, or '''false'''
--	if the element has not been layouted yet.
-------------------------------------------------------------------------------

function Area:getRect()
	if self.Drawable then
		return unpack(self.Rect)
	end
	db.info("Layout not available")
	return false
end

-------------------------------------------------------------------------------
--	reached = focusRect([x0, y0, x1, y1]): Tries to shift any Canvas
--	containing the element into a position that makes the element fully
--	visible. Optionally, a rectangle can be specified that is to be made
--	visible. If the return value is not '''true''', the destination rectangle
--	cannot be reached or has not been reached (yet).
-------------------------------------------------------------------------------

function Area:focusRect(r1, r2, r3, r4)
	if not r1 then
		r1, r2, r3, r4 = self:getRect()
		if not r1 then
			return
		end
		local m = self.MarginAndBorder
		r1 = r1 - m[1]
		r2 = r2 - m[2]
		r3 = r3 + m[3]
		r4 = r4 + m[4]
	end
	local parent = self:getParent()
	if parent then
		return parent:focusRect(r1, r2, r3, r4)
	end
	return true
end
