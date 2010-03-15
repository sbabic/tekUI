
local db = require "tek.lib.debug"
local UTF8String = require "tek.class.utf8string"
local ui = require "tek.ui"
local Region = ui.loadLibrary("region", 9)
local Sizeable = ui.require("sizeable", 6)

local assert = assert
local concat = table.concat
local floor = math.floor
local insert = table.insert
local intersect = Region.intersect
local max = math.max
local min = math.min
local open = io.open
local remove = table.remove
local tonumber = tonumber
local type = type
local unpack = unpack

module("tek.ui.class.input", tek.ui.class.sizeable)
_VERSION = "Input 15.0"
local Input = _M

-------------------------------------------------------------------------------
--	Constants & Class data:
-------------------------------------------------------------------------------

local NOTIFY_CURSORX = { NOTIFY_SELF, "onSetCursorX", NOTIFY_VALUE }
local NOTIFY_CURSORY = { NOTIFY_SELF, "onSetCursorY", NOTIFY_VALUE }
local NOTIFY_FILENAME = { NOTIFY_SELF, "onSetFileName", NOTIFY_VALUE }
local NOTIFY_CHANGED = { NOTIFY_SELF, "onSetChanged", NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	Class style properties:
-------------------------------------------------------------------------------

Properties = {
	["border-top-width"] = 0,
	["border-right-width"] = 0,
	["border-bottom-width"] = 0,
	["border-left-width"] = 0,
}

-------------------------------------------------------------------------------
--	init: overrides
-------------------------------------------------------------------------------

function Input.init(self)
	self.AutoPosition = false
	self.BlinkState = false
	self.BlinkTick = false
	self.BlinkTickInit = false
	self.Changed = false
	self.Cursor = false
	self.CursorX = self.CursorX or 1
	self.CursorY = self.CursorY or 1
	self.Data = self.Data or { "" }
	self.DynWrap = true
	self.Editing = false
	self.FileName = self.FileName or ""
	self.FixedFont = self.FixedFont or false
	self.FollowCursor = false
	self.FontHandle = false
	self.FWidth = false
	self.LineHeight = false
	self.LineOffset = 0
	self.LineSpacing = self.LineSpacing or 0
	self.LockCursorX = false
	self.Mode = "touch"
	self.SmoothScroll = self.SmoothScroll or false
	self.TabSize = self.TabSize or 4
	self.TextWidth = false
	self.VisualCursorX = 1
	-- indicates that variable line heights are possible:
	self.Wrap = false
	-- indicates that Y positions and heights are cached and valid:
	self.YValid = true 
	return Sizeable.init(self)
end

-------------------------------------------------------------------------------
--	changed_width = initText()
-------------------------------------------------------------------------------

function Input:initText()
	local d = self.Data
	local maxw = 0
	for i = 1, self:getNumLines() do
		local line = d[i]
		if type(line) == "string" then
			line = self:createLine(line)
			d[i] = line
		end
		maxw = max(maxw, line[2])
	end
	if self.TextWidth ~= maxw then
		self.TextWidth = maxw
		-- self:layoutText()
		return true
	end
end

-------------------------------------------------------------------------------
--	updateCanvasSize(recalc)
-------------------------------------------------------------------------------

function Input:updateCanvasSize(recalc)
	if recalc then
		self:initText()
	end
	local c = self.Parent
	if c then
		local maxw = self.TextWidth
		local nlines = self:getNumLines()
		local m1, m2, m3, m4 = self:getMargin()
		local w = maxw + m1 + m3 + self.FWidth
		local h = self.LineHeight * nlines + m2 + m4
		c:setValue("CanvasWidth", w)
		c:setValue("CanvasHeight", h)
		c:rethinkLayout()
	end
end

-------------------------------------------------------------------------------
--	newtext(text) - Initialize text from a string or a table of strings.
-------------------------------------------------------------------------------

function Input:newText(text)
	local data
	if not text then
		data = { "" }
	elseif type(text) == "string" then
		data = { }
		for l in text:gmatch("([^\n]*)\n?") do
			insert(data, l)
		end
	else -- assuming it's a table
		data = text
	end
	self.Data = data
	self:updateCanvasSize(true)
	self.LockCursorX = false
	self:setValue("FileName", "")
	self:setValue("Changed", false)
	self:setCursor(-1, 1, 1, 0)
	local c = self.Parent
	c:damageChild(0, 0, c.CanvasWidth - 1, c.CanvasHeight - 1)
end

-------------------------------------------------------------------------------
--	layoutText:
-------------------------------------------------------------------------------

-- function Input:getHeadLineNumber(lnr)
-- 	lnr = lnr or self.CursorY
-- 	local line = self.Data[lnr]
-- 	if line then
-- 		local extl = tonumber(line[1])
-- 		if extl then
-- 			lnr = lnr + extl
-- 		end
-- 		return lnr
-- 	end
-- end
-- 
-- function Input:getLineHead(lnr)
-- 	return self.Data[self:getHeadLineNumber(lnr)]
-- end
-- 
-- function Input:getLinePart(lnr)
-- 	lnr = lnr or self.CursorY
-- 	local line = self:getLine(lnr)
-- 	if line then
-- 		local extl = tonumber(line[1])
-- 		if extl then
-- 			return self:getLine(lnr + extl)[1], line[3], line[4]
-- 		end
-- 		return line[1], line[3] or 1, line[4] or line[1]:len()
-- 	end
-- end
-- 
-- function Input:mergeLine(lnr)
-- 	lnr = self:getHeadLineNumber(lnr)
-- 	local data = self.Data
-- 	lnr = lnr + 1
-- 	while data[lnr] and type(data[lnr]) == "number" do
-- 		remove(lnr)
-- 	end
-- 	return lnr - 1
-- end
-- 
-- function Input:mergeText()
-- 	local data = self.Data
-- 	local lnr = 1
-- 	while lnr <= #data do
-- 		self:mergeLine(lnr)
-- 		lnr = lnr + 1
-- 	end
-- end
-- 
-- function Input:layoutText()
-- 	local r1, _, r3 = self.Parent:getRect()
-- 	if r1 and self.DynWrap then
-- 		local width = r3 - r1 + 1
-- 		db.warn("layout to width: %s", width)
-- 		
-- 		local data = self.Data
-- 		local onl = #data
-- 		
-- 		self:mergeText()
-- 		db.warn("text merged: %s -> %s lines", onl, #data)
-- 
-- 		for lnr = #data, 1, -1 do
-- 			local line = data[lnr]
-- 			local lw = line[2]
-- 			if lw > width then
-- 				db.warn("split line %s", lnr)
-- 				local text = line[1]
-- 				local nlnr = 0
-- 				data[lnr][3] = 1
-- 				
-- 				local x0 = 1
-- 				while lw > 0 do
-- 					local x = self:findTextPos(text, width)
-- 					assert(x > 1)
-- 					data[lnr + nlnr][4] = x0 + x - 2
-- 					-- db.warn("%d-%d:\t%s", data[lnr + nlnr][3], data[lnr + nlnr][4], text:sub(1, x - 1))
-- 					local nlw = self:getTextSize(text, 0, x - 1)
-- 					text = text:sub(x)
-- 					text = UTF8String:new(text)
-- 					nlnr = nlnr + 1
-- 					x0 = x0 + x - 1
-- 					insert(data, lnr + nlnr, { -nlnr, nlw, x0 })
-- 					lw = lw - nlw
-- 				end
-- 			end
-- 		end
-- 	end
-- end

-------------------------------------------------------------------------------
--	changeLine:
-------------------------------------------------------------------------------

function Input:changeLine(lnr)
	local line = self.Data[lnr or self.CursorY]
	local olen = line[2]
	line[2] = self:getTextSize(line[1])
	local tw = self.TextWidth
	if line[2] > tw then
		self.TextWidth = line[2]
	elseif olen == tw then
		self:initText()
	end
	if self.TextWidth ~= tw then
		local insx = min(tw, self.TextWidth)
		self:resize(self.TextWidth - tw, 0, insx, 0)
		self.Window:update()
	end
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function Input:setup(app, window)
	Sizeable.setup(self, app, window)
	local f = self.Application.Display:openFont(self.Font)
	self.FontHandle = f
	local fw, lh = f:getTextSize(" ")
	self.FWidth = fw
	self.LineOffset = floor(self.LineSpacing / 2)
	self.LineHeight = lh + self.LineSpacing
	self:updateCanvasSize(true)
	self:addNotify("CursorX", ui.NOTIFY_ALWAYS, NOTIFY_CURSORX)
	self:addNotify("CursorY", ui.NOTIFY_ALWAYS, NOTIFY_CURSORY)
	self:addNotify("FileName", ui.NOTIFY_ALWAYS, NOTIFY_FILENAME)
	self:addNotify("Changed", ui.NOTIFY_ALWAYS, NOTIFY_CHANGED)
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function Input:cleanup()
	self:remNotify("Changed", ui.NOTIFY_ALWAYS, NOTIFY_CHANGED)
	self:remNotify("FileName", ui.NOTIFY_ALWAYS, NOTIFY_FILENAME)
	self:remNotify("CursorY", ui.NOTIFY_ALWAYS, NOTIFY_CURSORY)
	self:remNotify("CursorX", ui.NOTIFY_ALWAYS, NOTIFY_CURSORX)
	self:setEditing(false)
	self.FontHandle = self.Application.Display:closeFont(self.FontHandle)
	Sizeable.cleanup(self)
end

-------------------------------------------------------------------------------
--	show: overrides
-------------------------------------------------------------------------------

function Input:show()
	Sizeable.show(self)
	self.BlinkTick = 0
	self.BlinkTickInit = 18
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function Input:layout(x0, y0, x1, y1, markdamage)
	local c = self.Cursor
	if c and c[6] == 1 then
		local insx = self.InsertX
		local insy = self.InsertY
		if insx or insy then
			local m1, m2, m3, m4 = self:getMargin()
			local n1 = x0 + m1
			local n2 = y0 + m2
			local n3 = x1 - m3
			local n4 = y1 - m4
			local r1, r2, r3, r4 = self:getRect()
			markdamage = markdamage ~= false
			if n1 == r1 and n2 == r2 and markdamage and self.TrackDamage then
				local dw = n3 - r3
				local dh = n4 - r4
				if dw ~= 0 and insx and c[1] > insx then
					c[1] = c[1] + dw
					c[3] = c[3] + dw
				end
				if dh ~= 0 and insy and c[2] > insy then
					c[2] = c[2] + dh
					c[4] = c[4] + dh
				end
			end		
		end
	end
	return Sizeable.layout(self, x0, y0, x1, y1, markdamage)
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function Input:draw()
	local dr = self.DamageRegion
	if dr then
		-- repaint intra-area damagerects:
		local d = self.Window.Drawable
		local bgpen = self:getBG()
		d:setFont(self.FontHandle)
		dr:forEach(self.drawPatch, self, d,
			self.Properties["color"] or "detail", bgpen)
		self.DamageRegion = false
	end
end

-------------------------------------------------------------------------------
--	drawPatch:
-------------------------------------------------------------------------------

function Input:drawPatch(r1, r2, r3, r4, d, fgpen, bgpen)

	local data = self.Data
	local cw = self.Parent.CanvasWidth
	local x, y = self:getRect()
	local lh = self.LineHeight
	local lo = self.LineOffset
	local l0, l1 
	
	if self.Wrap then
	
	else
		-- line height is constant:
		l0 = floor((r2 - y) / lh) + 1
		l1 = floor((r4 - y) / lh) + 1
	end
	
	d:pushClipRect(r1, r2, r3, r4)
	
	for l = l0, l1 do
		local x0, y0, x1, y1 = self:getLineRect(l)
		if x0 then
			d:fillRect(x0, y0, x1, y1, bgpen)
			local line = self:getLineText(l)
			self:drawText(x0, y0 + lo, x1, y1 + lo, line, fgpen)
		end
	end
	
	local c = self.Cursor
	if c and intersect(r1, r2, r3, r4, c[1], c[2], c[3], c[4]) then
		if c[6] == 1 then
			d:fillRect(c[1], c[2], c[3], c[4], "cursor")
			d:drawText(c[1], c[2] + lo, c[3], c[4] + lo, c[5],
				"cursor-detail")
		end
	end

	d:popClipRect()
end

-------------------------------------------------------------------------------
--	onFocus: overrides
-------------------------------------------------------------------------------

function Input:onFocus()
	Sizeable.onFocus(self)
	self:setEditing(self.Focus)
end

-------------------------------------------------------------------------------
--	onSelect: overrides
-------------------------------------------------------------------------------

function Input:onSelect()
	Sizeable.onSelect(self)
	self:setEditing(self.Selected)
end

-------------------------------------------------------------------------------
--	setEditing()
-------------------------------------------------------------------------------

function Input:setEditing(onoff)
	local w = self.Window
	local c = self.Parent
	if onoff and not self.Editing then
		self.Editing = true
		w:addInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
		w:addInputHandler(ui.MSG_KEYUP + ui.MSG_KEYDOWN, self,
			self.handleKeyboard)
	elseif not onoff and self.Editing then
		self.Editing = false
		self:setValue("Selected", false)
		w:remInputHandler(ui.MSG_KEYUP + ui.MSG_KEYDOWN, self,
			self.handleKeyboard)
		w:remInputHandler(ui.MSG_INTERVAL, self, self.updateInterval)
	end
end

-------------------------------------------------------------------------------
--	
-------------------------------------------------------------------------------

function Input:damageLine(l)
	local x0, y0, x1, y1 = self:getLineRect(l, 1)
	self.Parent:damageChild(x0, y0, x1, y1)
end

function Input:addChar(utf8)
	local cx, cy = self:getCursor()
	local line = self:getLine()
	local text = line[1]
	text:insert(utf8, cx)
	self:setValue("Changed", true)
	self:changeLine(cy)
	local x0, y0, x1, y1 = self:getLineRect(cy, cx, -1)
	self.Parent:damageChild(x0, y0, x1, y1)
end

function Input:remChar()
	local cx, cy = self:getCursor()
	local line = self:getLine()
	local text = line[1]
	-- add width of the deleted char to refresh area:
	local w = self:getTextSize(text, cx, cx)
	text:erase(cx, cx)
	self:setValue("Changed", true)
	self:changeLine()
	local x0, y0, x1, y1 = self:getLineRect(cy, cx, -1)
	self.Parent:damageChild(x0, y0, x1 + w, y1)
end

function Input:createLine(text)
	local line = { UTF8String:new(text) }
	line[2] = self:getTextSize(line[1])
	return line
end

function Input:followCursor()
	local follow = self.FollowCursor
	if follow then
		local x0, y0, x1, y1 = unpack(self.Cursor, 1, 4)
		local m1, m2, m3, m4 = self:getMargin()
		x0 = x0 - m1 - self.FWidth * 3
		y0 = y0 - m2 - self.LineHeight
		x1 = x1 + m3 + self.FWidth * 3
		y1 = y1 + m4 + self.LineHeight
		local smooth = follow * (self.SmoothScroll or 0)
		if not self.Parent:focusRect(x0, y0, x1, y1, smooth) then
			self.FollowCursor = false
		end
	end
end

-------------------------------------------------------------------------------
--	insertLine(lnr, text)
-------------------------------------------------------------------------------

function Input:insertLine(lnr, text)
	local line = self:createLine(text)
	insert(self.Data, lnr or #self.Data, line)
	self:setValue("Changed", true)
end

-------------------------------------------------------------------------------
--	removeLine(lnr)
-------------------------------------------------------------------------------

function Input:removeLine(lnr)
	local line = remove(self.Data, lnr)
	self:setValue("Changed", true)
	if line[2] == self.TextWidth then
		self:initText()
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------

function Input:getNumLines()
	return #self.Data
end

function Input:getCursor(visual)
	if visual then
		return self.VisualCursorX, self.CursorY
	end
	return self.CursorX, self.CursorY
end

function Input:getLine(lnr)
	return self.Data[lnr or self.CursorY] 
end

function Input:getLineLength(lnr)
	local line = self:getLine(lnr)
-- 	local line = self:getLineHead(lnr)
	return line and line[1]:len()
end

function Input:getLineText(lnr)
	local line = self:getLine(lnr)
-- 	local line = self:getLineHead(lnr)
	return line and line[1]
end

-- function Input:getLineWidth(lnr, x)
-- 	local line = self:getLine(lnr)
-- 	if line then
-- 		if not x then
-- 			return line[2]
-- 		end
-- 		return self:getTextSize(line[1], 0, x)
-- 	end
-- end

function Input:getScreenSize(in_chars)
	local r1, r2, r3, r4 = self.Parent:getRect()
	local w = r3 - r1 + 1
	local h = r4 - r2 + 1
	if in_chars then
		w = floor(w / self.FWidth)
		h = floor(h / self.LineHeight)
	end
	return w, h
end

local function textwidth(text, a, b, font, fw)
	if fw then
		return fw * (b - a + 1)
	end
	return font:getTextSize(text:sub(a, b))
end

function Input:getVisualCursorX(cx, cy)
	local vx = 0
	local text = self:getLineText(cy or self.CursorY)
	if text then
		cx = cx or self.CursorX
		local oa = 1
		local tabsize = self.TabSize
		for a, c in text:chars() do
			if a == cx then
				break
			end
			if c == 9 then
				local inslen = tabsize - ((a - oa) % tabsize)
				vx = vx + inslen - 1
				oa = a + 1
			end
			vx = vx + 1
		end
	end
	return vx + 1
end


function Input:getRealCursorX(cx, cy)
	local text = self:getLineText(cy or self.CursorY)
	if text then
		cx = cx or self.CursorX
		local oa = 1
		local tabsize = self.TabSize
		local rx = 0
		for a, c in text:chars() do
			if c == 9 then
				local inslen = tabsize - ((a - oa) % tabsize)
				rx = rx + inslen - 1
				oa = a + 1
			end
			rx = rx + 1
			if rx >= cx then
				return a
			end
		end
		return text:len() + 1
	end
	return 1
end


function Input:getTextSize(text, p0, p1)

	local len = text:len()
	p0 = p0 or 0
	p1 = p1 or -1
	
	if p1 < 0 then
		p1 = len + 1 + p1
	end
	
	local w = 0
	if p1 >= p0 and len > 0 then
		local fw = self.FixedFont and self.FWidth
		local f = self.FontHandle
		local oa = 0
		local lasttext
		local tabsize = self.TabSize
		local x = 0
		local w0 = 0
		p0 = max(p0, 1)
		for a, c in text:chars() do
			if a == p0 then
				x = x + textwidth(text, oa, a - 1, f, fw)
				w0 = x
				oa = a
			end
			if c == 9 then
				x = x + textwidth(text, oa, a - 1, f, fw)
				local inslen = tabsize - ((a - oa) % tabsize)
				x = x + inslen * self.FWidth
				oa = a + 1
			end
			if a == p1 then
				x = x + textwidth(text, oa, a, f, fw)
				oa = -1
				break
			end
		end
		if oa > 0 then
			x = x + textwidth(text, oa, len, f, fw)
		end
		w = x - w0
	end
	
	return w
end

function Input:drawText(x0, y0, x1, y1, text, fgpen, p0, p1)
-- 	local p0 = 1
	local w = 0
	if text:len() > 0 then
		local fw = self.FixedFont and self.FWidth
		local f = self.FontHandle
		local d = self.Window.Drawable
		local oa = 0
		local lasttext
		local tabsize = self.TabSize
		local x = 0
		local w0 = 0
		p0 = max(p0 or 1, 1)
		for a, c in text:chars() do
			if a == p0 then
				x = x + textwidth(text, oa, a - 1, f, w)
				w0 = x
				oa = a
			end
			if c == 9 then
				lasttext = text:sub(oa, a - 1)
				d:drawText(x0 + x, y0, x1, y1, lasttext, fgpen)
				local inslen = tabsize - ((a - oa) % tabsize)
				x = x + f:getTextSize(lasttext) + inslen * self.FWidth
				oa = a + 1
			end
		end
		if oa > 0 then
			lasttext = text:sub(oa, p1 or text:len())
			d:drawText(x0 + x, y0, x1, y1, lasttext, fgpen)
		end
	end
end

function Input:findTextPos(text, x)
	if x < 0 then
		return 1
	end
	local p0 = 0
	local p1 = text:len()
	local pn
	local x0 = 0
	local x1 = self:getTextSize(text, 1, p1)
	local xn
	while true do
		if x >= x1 then
			return p1 + 1
		end
		if p0 + 1 == p1 then
			return p1
		end
		pn = p0 + floor((p1 - p0) / 2)
		xn = self:getTextSize(text, 1, pn)
		if xn > x then
			p1 = pn
			x1 = xn
		else
			p0 = pn
			x0 = xn
		end
	end
end

-------------------------------------------------------------------------------
--	x0, y0, x1, y1 = getLineRect(line[, xstart[, xend]]) - Gets a line's
--	rectangle on the screen. If {{xend}} is less than {{0}}, it is added to
--	the character position past the end the string. If {{xend}} is omitted,
--	returns the right edge of the canvas.
-------------------------------------------------------------------------------

function Input:getLineRect(lnr, xstart, xend)
	local line = self:getLine(lnr)
	if line then
		local r1, r2, r3, r4 = self:getRect()
		local lh = self.LineHeight
		local x0 = r1
		local y0 = r2 + (lnr - 1) * lh
		local x1
		local y1 = y0 + lh - 1
		
		if xstart and xstart <= 1 and xend and xend == -1 then
			return x0, y0, x0 + line[2], y1
		end
		
		line = line[1]
		local f = self.FontHandle
		if xstart then
			x0 = r1 + self:getTextSize(line, 1, xstart - 1)
		end
		if not xend then
			x1 = r3
		else
			if xend < 0 then
				xend = line:len() + 1 + xend
			end
			local w = self:getTextSize(line, xstart, xend) - 1			
			x1 = x0 + w - 1 + self.FWidth
		end
		return x0, y0, x1, y1
	end
end

-------------------------------------------------------------------------------
--	setCursor(blink, cx, cy, follow) - blink=1 cursor on, blink=0 cursor off,
--	blink=-1 cursor on in next frame, blink=false no change. follow: 
--	false=do not follow cursor, 1=visible area jumps to the cursor
--	immediately, 1=visible area moves gradually (if enabled)
-------------------------------------------------------------------------------

function Input:setCursor(bs, cx, cy, follow)
	
	local c = self.Cursor
	local changed = not c
	local obs = self.BlinkState
	local ocx, ocy = self:getCursor()
	
	if bs < 0 then
		self.BlinkTick = 0
		bs = 0
		changed = true
	end
	
	if bs then
		changed = bs ~= obs
		self.BlinkState = bs
	else
		bs = obs
	end
	
	if cx or cy then
		if cx and cx < 0 then
			cx = self:getLineLength() + 2 + cx
		end
		if cy and cy ~= ocy then
			self:setValue("CursorY", cy)
			changed = true
		else
			cy = ocy
		end
		if cx and cx ~= ocx then
			self:setValue("CursorX", cx)
			changed = true
		else
			cx = ocx
		end
	else
		changed = true
		cx = ocx
		cy = ocy
	end
	
	if not changed then
		return
	end	

	local d = self.Window.Drawable
	if d then
		local r1, r2, r3, r4 = self:getRect()
		local text = self:getLineText()
		local textc = text:sub(cx, cx)
		if textc == "" or textc == "\t" then
			textc = " "
		end
		local cw = self.FontHandle:getTextSize(textc)
		local h = self.LineHeight
		local x0 = r1 + self:getTextSize(text, 1, cx - 1)
		local x1 = x0 + cw - 1
		local y0 = r2 + h * (cy - 1)
		local y1 = y0 + h - 1
	
		if c then
			-- old cursor, and visible?
			if c[6] and (c[1] ~= x0 or c[2] ~= y0 or c[3] ~= x1 or c[4] ~= y1) then
				self.Parent:damageChild(c[1], c[2], c[3], c[4])
			end
		else
			c = { }
			self.Cursor = c
		end
		
		c[1] = x0
		c[2] = y0
		c[3] = x1
		c[4] = y1
		c[5] = textc
		c[6] = bs
		
		if follow then
			self.FollowCursor = follow
		end
		
		self.Parent:damageChild(x0, y0, x1, y1)
	end
end

-------------------------------------------------------------------------------
--	moveCursor()
-------------------------------------------------------------------------------

function Input:moveCursor(dx, dy)
	local cx, cy = self:getCursor()
	local nlines = self:getNumLines()
	local len = self:getLineLength()
	cx = cx + dx
	if dx > 0 and cx > len + 1 then
		if cy < nlines then
			cy = cy + 1
			cx = 1
		else
			cx = len + 1
		end
	elseif dx < 0 and cx == 0 then
		self.LockCursorX = false
		if cy > 1 then
			cy = cy - 1
			cx = self:getLineLength(cy) + 1
		else
			cx = 1
		end
	end
	if dx ~= 0 then
		self.LockCursorX = self:getVisualCursorX(cx)
	end
	if dy > 0 and cy < nlines then
		cy = min(cy + dy, nlines)
		local vx = self.LockCursorX
		if vx then
			cx = self:getRealCursorX(vx, cy)
		end
		cx = min(cx, self:getLineLength(cy) + 1)
	elseif dy < 0 and cy > 1 then
		cy = max(cy + dy, 1)
		local vx = self.LockCursorX
		if vx then
			cx = self:getRealCursorX(vx, cy)
		end
		cx = min(cx, self:getLineLength(cy) + 1)
	end
	self:setCursor(-1, cx, cy, 1)
end

function Input:cursorLeft()
	self:moveCursor(-1, 0)
end

function Input:cursorRight()
	self:moveCursor(1, 0)
end

function Input:cursorUp()
	self:moveCursor(0, -1)
end

function Input:cursorDown()
	self:moveCursor(0, 1)
end

function Input:backSpace()
	local cx, cy = self:getCursor()
	if cx > 1 then
		self:cursorLeft()
		self:remChar()
		return false
	elseif cy > 1 then
		local lh = self.LineHeight
		-- local noscroll = c.CanvasTop == (cy - 1) * lh + m[2]
		local curline = self:getLineText(cy)
		local newline = self:getLineText(cy - 1)
		local cx = newline:len() + 1
		newline:insert(curline:get())
		self:changeLine(cy - 1)
		self:removeLine(cy)
		cy = cy - 1
		self:resize(0, -lh, 0, lh * cy)
		self:damageLine(cy)
		self:setCursor(-1, cx, cy, 1)
		self.Window:update()
	end
end

function Input:delChar()
	local cx, cy = self:getCursor()
	local lh = self.LineHeight
	local curline = self:getLineText(cy)
	local curlen = self:getLineLength(cy)
	if cx < curlen + 1 then
		self:remChar()
	elseif cy < self:getNumLines() then
		local nextline = self:getLineText(cy + 1)
		curline:insert(nextline:get())
		self:changeLine(cy)
		self:removeLine(cy + 1)
		self:damageLine(cy)
		self:resize(0, -lh, 0, lh * cy)
		self.Window:update()
	end
end

function Input:enter()
	local cx, cy = self:getCursor()
	local lh = self.LineHeight
	-- local _, c2, _, c4 = c:getRect()
	-- local ch = c4 - c2 + 1
	-- local noscroll = c.CanvasTop + ch == cy * lh + m[2]
	local oldline = self:getLineText(cy)
	self:resize(0, lh, 0, lh * cy)
	self:damageLine(cy)
	cy = cy + 1
	self:insertLine(cy, oldline:sub(cx))
	oldline:erase(cx, -1)
	self:changeLine(cy - 1)
	self:changeLine(cy)
	self:setCursor(-1, 1, cy, 1)
	self.Window:update()
end

function Input:cursorEOL()
	self.LockCursorX = self:getVisualCursorX(self:getLineLength()) + 1
	self:setCursor(-1, -1, false, 1)
end

function Input:cursorSOL()
	self.LockCursorX = 1
	self:setCursor(-1, 1, false, 1)
end

function Input:pageUp()
	local _, sh = self:getScreenSize(true)
	self:moveCursor(0, -sh)
end

function Input:pageDown()
	local _, sh = self:getScreenSize(true)
	self:moveCursor(0, sh)
end

function Input:getCursorByXY(x, y)
	local cy = floor(y / self.LineHeight) + 1
	if cy < 1 then
		return 1, 1
	end
	local nl = self:getNumLines()
	if cy > nl then
		return 1, nl
	end
	local cx = self:findTextPos(self:getLineText(cy), x)
	return cx, cy
end

function Input:setCursorByXY(x, y)
	self:setEditing(true)
	local m1, m2 = self:getMargin()
	x, y = self:getCursorByXY(x - m1, y - m2)
	self:setCursor(-1, x, y, 0)
	self.LockCursorX = self:getVisualCursorX()
end

function Input:deleteLine()
	local nl = self:getNumLines()
	if nl > 0 then
		local cx, cy = self:getCursor()
		if nl > 1 then
			self:removeLine(cy)
			if cy == nl then
				cy = cy - 1
			end
			local lh = self.LineHeight
			self:resize(0, -lh, 0, lh * cy)
			self:damageLine(cy)
			self.Window:update()
			self:updateCanvasSize()
		else
			self:getLineText(cy):set("")
			self:changeLine(cy)
		end
		self:setCursor(-1, cx, cy, 1)
	end
end

-------------------------------------------------------------------------------
--	loadText(filename)
-------------------------------------------------------------------------------

function Input:loadText(fname)
	local f = open(fname)
	if f then
		local data = { }
		local buf = ""
		while true do
			local nbuf = f:read(4096)
			if not nbuf then
				break
			end
			buf = buf .. nbuf
			while true do
				local p = buf:find("\n")
				if not p then
					break
				end
				insert(data, buf:sub(1, p - 1))
				buf = buf:sub(p + 1)
			end
		end
		insert(data, buf)
		self:newText(data)
		self:setValue("FileName", fname)
		return true
	end
end

-------------------------------------------------------------------------------
--	saveText(filename)
-------------------------------------------------------------------------------

function Input:saveText(fname)
	local f, msg = open(fname, "wb")
	if f then
		local numl = self:getNumLines()
		local n = 0
		for lnr = 1, numl do
			f:write(self:getLineText(lnr):get())
			n = n + 1
			if lnr < numl then
				f:write("\n")
			end
		end
		f:close()
		db.info("lines saved: %s", n)
		self:setValue("Changed", false)
		return true
	end
	return false, msg
end

-------------------------------------------------------------------------------
--	handleKeyboard()
-------------------------------------------------------------------------------

function Input:handleKeyboard(msg)
	
	if self.Window.ActivePopup then
		return msg
	end
	
	if msg[2] == ui.MSG_KEYDOWN then
		local code = msg[3]
		local qual = msg[6]
		local utf8code = msg[7]
		while true do
			if qual > 3 or code == 27 then -- ctrl, alt, esc, ...
				-- db.warn("code: %s - qual: %s", code, qual)
				break -- do now aborb
			elseif code == 13 then
				self:enter()
			elseif code == 8 then
				self:backSpace()
			elseif code == 127 then
				self:delChar()
			elseif code == 0xf010 then
				self:cursorLeft()
			elseif code == 0xf011 then
				self:cursorRight()
			elseif code == 0xf012 then
				self:cursorUp()
			elseif code == 0xf013 then
				self:cursorDown()
			elseif code == 0xf023 then
				self:pageUp()
			elseif code == 0xf024 then
				self:pageDown()
			elseif code == 0xf025 then
				self:cursorSOL()
			elseif code == 0xf026 then
				self:cursorEOL()
			elseif code == 9 or code > 31 and code < 256 then
				self:addChar(utf8code)
				self:cursorRight()
			end
			return false -- absorb
		end
	end
	return msg
end

-------------------------------------------------------------------------------
--	updateInterval:
-------------------------------------------------------------------------------

function Input:updateInterval(msg)
	if self.Window.ActivePopup then
		return msg
	end
	self:followCursor()
	local bt = self.BlinkTick
	bt = bt - 1
	if bt < 0 then
		bt = self.BlinkTickInit
		self:setCursor(((self.BlinkState == 1) and 0) or 1)
	end
	self.BlinkTick = bt
	return msg
end

-------------------------------------------------------------------------------
--	setState: overrides
-------------------------------------------------------------------------------

function Input:setState(bg, fg)
	Sizeable.setState(self, bg or self.BGPen, fg or self.FGPen)
end

-------------------------------------------------------------------------------
--	onSetCursorX(cx)
-------------------------------------------------------------------------------

function Input:onSetCursorX(cx)
	local vx = self:getVisualCursorX(cx)
	self.VisualCursorX = vx
end

-------------------------------------------------------------------------------
--	onSetCursorY(cy)
-------------------------------------------------------------------------------

function Input:onSetCursorY(cy)
end

-------------------------------------------------------------------------------
--	onSetFileName(fname)
-------------------------------------------------------------------------------

function Input:onSetFileName(fname)
end

-------------------------------------------------------------------------------
--	onSetChanged(changed)
-------------------------------------------------------------------------------

function Input:onSetChanged(changed)
end

-------------------------------------------------------------------------------
--	getText()
-------------------------------------------------------------------------------

function Input:getText()
	local t = { }
	local d = self.Data
	for lnr = 1, #d do
		insert(t, d[lnr][1]:get())
	end
	return t
end
