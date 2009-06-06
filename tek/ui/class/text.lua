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
--		- {{Font [IG]}} (string)
--			A font specification in the form
--					"[fontname1,fontname2,...][:][size]"
--			Font names, if specified, will be probed in the order of their
--			occurence in the string; the first font that can be opened will be
--			used. For the font names, the following placeholders with
--			predefined meanings are supported:
--				- {{"ui-fixed"}}: The default fixed font
--				- {{"ui-main"}} or {{""}}: The default main font, e.g. for
--				buttons and menus
--				- {{"ui-small"}}: The default small font, e.g. for group
--				captions
--				- {{"ui-large"}}: The default 'large' font
--				- {{"ui-huge"}}: The default 'huge' font
--			If no font name is specified, the main font will be used.
--			The size specification (in pixels) is optional as well; if absent,
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
--		- {{Text [ISG]}} (string)
--			The text that will be displayed on the element; it may span
--			multiple lines (see also Text:makeTextRecords()). Setting this
--			attribute invokes the Text:onSetText() method.
--		- {{TextHAlign [IG]}} ({{"left"}}, {{"center"}}, {{"right"}})
--			The text's horizontal alignment, which will be used in
--			Text:makeTextRecords(). If '''false''' during initialization,
--			the class' default will be used. [Default:  {{"center"}}]
--		- {{TextVAlign [IG]}} ({{"top"}}, {{"center"}}, {{"bottom"}})
--			The text's vertical alignment, which will be used in
--			Text:makeTextRecords(). If '''false''' during initialization, the
--			class' default will be used. [Default: {{"center"}}]
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

local ui = require "tek.ui"
local Gadget = ui.Gadget
local floor = math.floor
local insert = table.insert
local max = math.max
local min = math.min
local remove = table.remove
local type = type

module("tek.ui.class.text", tek.ui.class.gadget)
_VERSION = "Text 19.0"

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_SETTEXT = { ui.NOTIFY_SELF, "onSetText", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local Text = _M

function Text.init(self)
	self.FGDisabled2 = self.FGDisabled2 or false
	self.Font = self.Font or false
	self.KeepMinHeight = self.KeepMinHeight or false
	self.KeepMinWidth = self.KeepMinWidth or false
	self.Mode = self.Mode or "inert"
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
		self.FGDisabled2 = self.FGDisabled2 or
			self:getProperty(p, "disabled", "color2")
	end
	self.Font = self.Font or self:getProperty(p, pclass, "font")
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
	if self.KeyCode == true then
		local sc = ui.ShortcutMark
		local keycode = self.Text:match("^[^" .. sc .. "]*" .. sc .. "(.)")
		self.KeyCode = keycode and "IgnoreCase+" .. keycode or false
	end
	Gadget.setup(self, app, window)
	self:addNotify("Text", ui.NOTIFY_ALWAYS, NOTIFY_SETTEXT)
	if not self.TextRecords then
		self:makeTextRecords(self.Text)
	end
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Text:cleanup()
	self:remNotify("Text", ui.NOTIFY_ALWAYS, NOTIFY_SETTEXT)
	self.TextRecords = false
	Gadget.cleanup(self)
end

-------------------------------------------------------------------------------
--	width, height = getTextSize([textrecord]): This function calculates
--	the total space occupied by the object's text records. Optionally, the
--	user can pass a table of text records which are to be evaluated.
-------------------------------------------------------------------------------

function Text:getTextSize(tr)
	tr = tr or self.TextRecords
	local totw, toth = 0, 0
	local x, y
	for i = 1, #tr do
		local t = tr[i]
		local tw, th = t[9], t[10]
		totw = max(totw, tw + t[5] + t[7])
		toth = max(toth, th + t[6] + t[8])
		if t[15] then
			x = min(x or 1000000, t[15])
		end
		if t[16] then
			y = min(y or 1000000, t[16])
		end
	end
	return totw, toth, x, y
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
			self.MinWidth = w
		end
		minw = self.MinWidth
	end
	if self.KeepMinHeight then
		if self.MinHeight == 0 then
			self.MinHeight = h
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
--	layout: overrides
-------------------------------------------------------------------------------

local function aligntext(align, opkey, x0, w1, w0)
	if not align or align == "center" then
		return x0 + floor((w1 - w0) / 2)
	elseif align == opkey then
		return x0 + w1 - w0
	end
	return x0
end

function Text:layoutText()
	local r1, r2, r3, r4 = self:getRect()
	if r1 then
		local p = self.Padding
		local w0, h0 = self:getTextSize()
		local w = r3 - r1 + 1 - p[3] - p[1]
		local h = r4 - r2 + 1 - p[4] - p[2]
		local x0 = aligntext(self.TextHAlign, "right", r1 + p[1], w, w0)
		local y0 = aligntext(self.TextVAlign, "bottom", r2 + p[2], h, h0)
		local tr = self.TextRecords
		for i = 1, #tr do
			local t = tr[i]
			local x = x0 + t[5]
			local y = y0 + t[6]
			local w = w0 - t[7] - t[5]
			local h = h0 - t[8] - t[6]
			local tw, th = t[9], t[10]
			t[15] = aligntext(t[3], "right", x, w, tw)
			t[16] = aligntext(t[4], "bottom", y, h, th)
		end
	end
end

function Text:layout(x0, y0, x1, y1, markdamage)
	local res = Gadget.layout(self, x0, y0, x1, y1, markdamage)
	self:layoutText()
	return res
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function Text:draw()
	Gadget.draw(self)
	local d = self.Drawable
	local r = self.Rect
	local p = self.Padding
	d:pushClipRect(r[1] + p[1], r[2] + p[2], r[3] - p[3], r[4] - p[4])
	local fp = d.Pens[self.FGPen]
	local tr = self.TextRecords
	for i = 1, #tr do
		local t = tr[i]
		local x, y = t[15], t[16]
		d:setFont(t[2])
		if self.Disabled then
			local fp2 = d.Pens[self.FGDisabled2 or ui.PEN_DISABLEDDETAIL2]
			d:drawText(x + 2, y + 2, x + t[9] + 1, y + t[10] + 1, t[1], fp2)
			if t[11] then
				-- draw underline:
				d:fillRect(x + t[11] + 2, y + t[12] + 2,
					x + t[11] + t[13] + 1, y + t[12] + t[14] + 1, fp2)
			end
		end
		d:drawText(x + 1, y + 1, x + t[9], y + t[10], t[1], fp)
		if t[11] then
			-- draw underline:
			d:fillRect(x + t[11] + 1, y + t[12] + 1,
				x + t[11] + t[13], y + t[12] + t[14], fp)
		end
	end
	d:popClipRect()
end

-------------------------------------------------------------------------------
--	newTextRecord: Note that this function might get called before the element
--	has a Drawable, therefore we must open the font from Application.Display
-------------------------------------------------------------------------------

function Text:newTextRecord(line, font, halign, valign, m1, m2, m3, m4)
	local keycode, _
	local r = { line, font, halign or "center", valign or "center",
		m1 or 0, m2 or 0, m3 or 0, m4 or 0 }
	if self.KeyCode then
		local sc = ui.ShortcutMark
		local a, b = line:match("([^" .. sc .. "]*)" .. sc ..
			"?([^" .. sc .. "]*)")
		if b ~= "" then
			keycode = b:sub(1, 1)
			-- insert underline rectangle:
			r[11] = font:getTextSize(a)
			_, r[12], r[14] = self.Application.Display:getFontAttrs(font)
			r[13] = font:getTextSize(keycode)
			r[1] = a .. b
		end
	end
	local w, h = font:getTextSize(r[1])
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
	self:layoutText()
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
--	from opening the font specified in the object's {{Font}} attribute,
--	which also determines {{font-height}} and is used for calculating the
--	{{text-width}} (in pixels). The alignment parameters are taken from the
--	object's {{TextHAlign}} and {{TextVAlign}} attributes, respectively.
-------------------------------------------------------------------------------

function Text:makeTextRecords(text)
	text = text or ""
	local tr = { }
	self.TextRecords = tr
	local y, nl = 0, 0
	local font = self.Application.Display:openFont(self.Font)
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
end

-------------------------------------------------------------------------------
--	onSetText(text): This handler is invoked when the element's {{Text}}
--	attribute has changed.
-------------------------------------------------------------------------------

function Text:onSetText(text)
	self:makeTextRecords(text)
	self.Redraw = true
	self:rethinkLayout(self.KeepMinWidth and 0 or 1)
end
