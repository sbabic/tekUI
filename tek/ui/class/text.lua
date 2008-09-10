-------------------------------------------------------------------------------
--
--	tek.ui.class.text
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
--		Text
--
--	OVERVIEW::
--		This gadget implements text rendering.
--
--	ATTRIBUTES::
--		- {{FontSpec [IG]}} (string)
--			A font specification in the form
--					"[fontname1,fontname2,...][:][size]"
--			Font names, if specified, will be probed in the order of their
--			occurence in the string; the first font that can be opened will be
--			used. For the font names, the following placeholders with
--			predefined meanings are supported:
--				- "__fixed": The default fixed font
--				- "__main": The default main font, e.g. for buttons and menus
--				- "__small": The default small font, e.g. for group captions
--				- "__large": The default 'large' font
--				- "__huge": The default 'huge' font
--			If no font name is specified, the main font will be assumed.
--			The size specification (in pixels) is optional as well, if absent,
--			the respective font's default size will be used.
--		- {{KeepMinHeight [IG]}} (boolean)
--			After the initial size calculation, keep the minimal height of
--			the element and do not rethink the layout in regard to a
--			possible new minimal height (e.g. resulting from a newly set
--			text).
--		- {{KeepMinWidth [IG]}} (boolean)
--			After the initial size calculation, keep the minimal width of
--			the element and do not rethink the layout in regard to a
--			possible new minimal width (e.g. resulting from a newly set text).
--		- {{ShortcutMark [IG]}} (string)
--			The initiatory character for keyboard shortcuts in the Text, used
--			during initial text setup. The first character following the marker
--			will be used as the gadget's {{KeyCode}} attribute (see also
--			[[#tek.ui.class.gadget : Gadget]]). By setting this attribute
--			to '''false''', the text is left unmodified and no attempts are
--			made for extracting a keyboard shortcut. [Default: "_"]
--		- {{Text [ISG]}} (string)
--			The text that will be displayed on the element; it may span
--			multiple lines (see also Text:makeTextRecords()). Setting this
--			attribute invokes the Text:onSetText() method.
--		- {{TextHAlign [IG]}} ("left", "center", "right")
--			The text's horizontal alignment, which will be used in
--			Text:makeTextRecords(). If '''false''' during initialization,
--			the class' default will be used. [Default:  "center"]
--		- {{TextVAlign [IG]}} ("top", "center", "bottom")
--			The text's vertical alignment, which will be used in
--			Text:makeTextRecords(). If '''false''' during initialization, the
--			class' default will be used. [Default: "center"]
--
--	IMPLEMENTS::
--		- Text:getTextSize() - Get total size of text records
--		- Text:makeTextRecords() - Break text into multiple text records
--		- Text:onSetText() - handler for the {{Text}} attribute
--
--	STYLE PROPERTIES::
--		- {{color2}} - secondary color used in disabled state
--		- {{font}}
--		- {{text-align}}
--		- {{vertical-align}}
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Object.init()
--		- Element:setup()
--		- Element:cleanup()
--		- Element:show()
--		- Element:hide()
--		- Area:setState()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"

local Display = ui.Display
local Gadget = ui.Gadget

local floor = math.floor
local insert = table.insert
local ipairs = ipairs
local max = math.max
local remove = table.remove
local type = type

module("tek.ui.class.text", tek.ui.class.gadget)
_VERSION = "Text 12.2"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_SETTEXT = { ui.NOTIFY_SELF, "onSetText", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Text = _M

function Text.init(self)
	self.FGPenDisabled2 = self.FGPenDisabled2 or false
	self.FontSpec = self.FontSpec or false
	self.KeepMinHeight = self.KeepMinHeight or false
	self.KeepMinWidth = self.KeepMinWidth or false
	self.Mode = self.Mode or "inert"
	self.ShortcutMark = self.ShortcutMark == nil and "_" or self.ShortcutMark
	self.Text = self.Text or ""
	self.TextHAlign = self.TextHAlign or false
	self.TextRecords = self.TextRecords or false
	self.TextVAlign = self.TextVAlign or false
	return Gadget.init(self)
end

-------------------------------------------------------------------------------
--	getProperties:
-------------------------------------------------------------------------------

function Text:getProperties(p, pclass)
	if not pclass then
		self.FGPenDisabled2 = self.FGPenDisabled2 or
			self:getProperty(p, "disabled", "color2")
	end
	self.FontSpec = self.FontSpec or self:getProperty(p, pclass, "font")
	self.TextHAlign = self.TextHAlign or
		self:getProperty(p, pclass, "text-align")
	self.TextVAlign = self.TextVAlign or
		self:getProperty(p, pclass, "vertical-align")
	Gadget.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Text:setup(app, window)
	self.TextHAlign = self.TextHAlign or "center"
	self.TextVAlign = self.TextVAlign or "center"
	local sc = self.ShortcutMark
	if sc and not self.KeyCode then
		local keycode = self.Text:match("^[^" .. sc .. "]*" .. sc .. "(.)")
		if keycode then
			self.KeyCode = "IgnoreCase+" .. keycode
		end
	end
	Gadget.setup(self, app, window)
	self:addNotify("Text", ui.NOTIFY_CHANGE, NOTIFY_SETTEXT)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Text:cleanup()
	self:remNotify("Text", ui.NOTIFY_CHANGE, NOTIFY_SETTEXT)
	Gadget.cleanup(self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Text:show(display, drawable)
	if Gadget.show(self, display, drawable) then
		if not self.TextRecords then
			self:makeTextRecords(self.Text)
		end
		return true
	end
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function Text:hide()
	self.TextRecords = false
	Gadget.hide(self)
end

-------------------------------------------------------------------------------
--	width, height = getTextSize([textrecord]): This function calculates the
--	total space occupied by the object's text records. Optionally, the user
--	can pass a table of text records which are to be evaluated.
-------------------------------------------------------------------------------

function Text:getTextSize(tr)
	tr = tr or self.TextRecords
	local totw, toth = 0, 0
	if tr then
		for _, tr in ipairs(tr) do
			local tw, th = tr[9], tr[10]
			totw = max(totw, tw + tr[5] + tr[7])
			toth = max(toth, th + tr[6] + tr[8])
		end
	end
	return totw, toth
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function Text:askMinMax(m1, m2, m3, m4)
	local p = self.Padding
	local w, h = self:getTextSize()
	local minw, minh = w, h
	if self.KeepMinWidth then
		if self.MinWidth == 0 then
			self.MinWidth = w + p[1] + p[3]
		end
		minw = self.MinWidth
	end
	if self.KeepMinHeight then
		if self.MinHeight == 0 then
			self.MinHeight = h + p[2] + p[4]
		end
		minh = self.MinHeight
	end
	m1 = m1 + minw
	m2 = m2 + minh
	m3 = m3 + w
	m4 = m4 + h
	return Gadget.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

local function aligntext(align, opkey, x0, w1, w0)
	if not align or align == "center" then
		return x0 + floor((w1 - w0) / 2)
	elseif align == opkey then
		return x0 + w1 - w0
	end
	return x0
end

function Text:draw()
	Gadget.draw(self)
	local d = self.Drawable
	local r = self.Rect
	local p = self.Padding
	d:pushClipRect(r[1] + p[1], r[2] + p[2], r[3] - p[3], r[4] - p[4])
	local fp = d.Pens[self.Foreground]
	local x0 = r[1] + p[1]
	local y0 = r[2] + p[2]
	local w0, h0 = self:getTextSize()
	local w = r[3] - r[1] + 1 - p[3] - p[1]
	local h = r[4] - r[2] + 1 - p[4] - p[2]
	x0 = aligntext(self.TextHAlign, "right", x0, w, w0)
	y0 = aligntext(self.TextVAlign, "bottom", y0, h, h0)
	for _, tr in ipairs(self.TextRecords) do
		local x = x0 + tr[5]
		local y = y0 + tr[6]
		local w = w0 - tr[7] - tr[5]
		local h = h0 - tr[8] - tr[6]
		local tw, th = tr[9], tr[10]
		x = aligntext(tr[3], "right", x, w, tw)
		y = aligntext(tr[4], "bottom", y, h, th)
		d:setFont(tr[2])
		if self.Disabled then
			local fp2 = d.Pens[self.FGPenDisabled2 or ui.PEN_DISABLEDDETAIL2]
			d:drawText(x + 2, y + 2, tr[1], fp2)
			if tr[11] then
				-- draw underline:
				d:fillRect(x + tr[11] + 2, y + tr[12] + 2,
					x + tr[11] + tr[13] + 1, y + tr[12] + tr[14] + 1, fp2)
			end
		end
		d:drawText(x + 1, y + 1, tr[1], fp)
		if tr[11] then
			-- draw underline:
			d:fillRect(x + tr[11] + 1, y + tr[12] + 1,
				x + tr[11] + tr[13], y + tr[12] + tr[14], fp)
		end
	end
	d:popClipRect()
end

-------------------------------------------------------------------------------
--	newTextRecord: internal
-------------------------------------------------------------------------------

function Text:newTextRecord(line, font, halign, valign, m1, m2, m3, m4)
	font = type(font) ~= "string" and font or self.Display:openFont(font)
	local keycode
	local r = { line, font, halign or "center", valign or "center",
		m1 or 0, m2 or 0, m3 or 0, m4 or 0 }
	local sc = self.ShortcutMark
	if sc then
		local a, b = line:match("([^" .. sc .. "]*)" .. sc ..
			"?([^" .. sc .. "]*)")
		if b ~= "" then
			keycode = b:sub(1, 1)
			-- insert underline rectangle:
			r[11] = Display:getTextSize(font, a)
			_, r[12], r[14] = self.Display:getFontAttrs(font)
			r[13] = Display:getTextSize(font, keycode)
			r[1] = a .. b
		end
	end
	local w, h = Display:getTextSize(font, r[1])
	r[9], r[10] = w + 2, h + 2 -- for disabled state
	return r, keycode
end

-------------------------------------------------------------------------------
--	addTextRecord: internal
-------------------------------------------------------------------------------

function Text:addTextRecord(...)
	return self:setTextRecord(#self.TextRecords + 1, ...)
end

-------------------------------------------------------------------------------
--	setTextRecord: internal
-------------------------------------------------------------------------------

function Text:setTextRecord(pos, ...)
	local record, keycode = self:newTextRecord(...)
	self.TextRecords[pos] = record
	return record, keycode
end

-------------------------------------------------------------------------------
--	makeTextRecords(text): This function parses a string and breaks it
--	along the encountered newline characters into single-line records.
--	Each record has the form
--			{ [1]=text, [2]=font, [3]=align-horizontal, [4]=align-vertical,
--			  [5]=margin-left, [6]=margin-right, [7]=margin-top,
--			  [8]=margin-bottom, [9]=font-height, [10]=text-width }
--	More undocumented fields may follow at higher indices. {{font}} is taken
--	from opening the font specified in the object's {{FontSpec}} attribute,
--	which also determines {{font-height}} and is used for calculating the
--	{{text-width}} (in pixels). The alignment parameters are taken from the
--	object's {{TextHAlign}} and {{TextVAlign}} attributes, respectively.
-------------------------------------------------------------------------------

function Text:makeTextRecords(text)
	local d = self.Display
	if d then
		text = text or ""
		local tr = { }
		self.TextRecords = tr
		local y, nl = 0, 0
		local font = d:openFont(self.FontSpec)
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			local r = self:addTextRecord(line, font, self.TextHAlign,
				self.TextVAlign, 0, y, 0, 0)
			y = y + r[10]
			nl = nl + 1
		end
		y = 0
		for i = nl, 1, -1 do
			tr[i][8] = y
			y = y + tr[i][10]
		end
	else
		db.info("%s : Cannot set text - not connected to a display",
			self:getClassName())
	end
end

-------------------------------------------------------------------------------
--	onSetText(text): This handler is invoked when the element's {{Text}}
--	attribute has changed.
-------------------------------------------------------------------------------

function Text:onSetText(text)
	self:makeTextRecords(text)
	self.Redraw = true
	self:rethinkLayout(1)
end
