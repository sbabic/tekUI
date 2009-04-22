-------------------------------------------------------------------------------
--
--	tek.ui.class.handle
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
--		Handle
--
--	OVERVIEW::
--		Implements a handle to drag around in the group,
--		thus reassigning widths (or heights) to its neighbours elements.
--
--	OVERRIDES::
--		- Area:askMinMax()
--		- Area:checkFocus()
--		- Area:draw()
--		- Object.init()
--		- Gadget:onHover()
--		- Area:passMsg()
--		- Area:setState()
--		- Area:show()
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Gadget = ui.Gadget
local floor = math.floor
local insert = table.insert
local ipairs = ipairs
local max = math.max
local min = math.min

module("tek.ui.class.handle", tek.ui.class.gadget)
_VERSION = "Handle 3.3"

local Handle = _M

-------------------------------------------------------------------------------
-- Class implementation:
-------------------------------------------------------------------------------

function Handle.init(self)
	self.AutoPosition = self.AutoPosition ~= nil and self.AutoPosition or false
	self.Mode = self.Mode or "button"
	self.MoveMinMax = { }
	self.Move0 = false
	self.Orientation = self.Orientation or 1
	self.SizeList = false
	return Gadget.init(self)
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function Handle:askMinMax(m1, m2, m3, m4)
	local o = self.Parent:getStructure()
	self.Orientation = o
	m3 = o == 1 and 0 or m3
	m4 = o == 2 and 0 or m4
	return Gadget.askMinMax(self, m1, m2, m3, m4)
end

-------------------------------------------------------------------------------
--	startMove: internal
-------------------------------------------------------------------------------

function Handle:startMove(x, y)

	local g = self.Parent
	local i1, i3
	if self.Orientation == 1 then
		i1, i3 = 1, 3
		self.Move0 = x
	else
		i1, i3 = 2, 4
		self.Move0 = y
	end

	local free0, free1 = 0, 0 -- freedom
	-- local max0, max1 = 0, 0
	local nfuc = 0 -- free+unweighted children
	local tw, fw = 0, 0 -- totweight, weight per unweighted child

	for _, e in ipairs(g.Children) do
		local df = 0 -- delta free
		local mf = 0 -- max free
		if e.MinMax[i3] > e.MinMax[i1] then
			local er = e.Rect
			local emb = e.MarginAndBorder
			if e.Weight then
				tw = tw + e.Weight
			else
				local s = er[i3] - er[i1] + 1
				if s < e.MinMax[i3] then
					nfuc = nfuc + 1
					fw = fw + 0x10000
				end
			end
			df = er[i3] - er[i1] + 1 + emb[i1] +
				emb[i3] - e.MinMax[i1]
			mf = e.MinMax[i3] - (er[i3] - er[i1] + 1 + emb[i1] + emb[i3])
		end

		free1 = free1 + df
		-- max1 = max1 + mf
		if e == self then
			free0 = free1
			-- max0 = max1
		end
		prev = e
	end
	free1 = free1 - free0
	-- max1 = max1 - max0
	-- free0 = min(max1, free0)
	-- free1 = min(max0, free1)

	if tw < 0x10000 then
		if fw == 0 then
			fw, tw = 0, 0x10000
		else
			fw, tw = floor((0x10000 - tw) * 0x100 / (fw / 0x100)), 0x10000
		end
	else
		fw, tw = 0, tw
	end

	self.SizeList = { { }, { } } -- left, right
	local li = self.SizeList[1]

	local n = 0
	local w = 0x10000
	for _, e in ipairs(g.Children) do
		local nw
		if e.MinMax[i3] > e.MinMax[i1] then
			if not e.Weight then
				n = n + 1
				if n == nfuc then
					nw = w -- rest
				else
					nw = fw -- weight of an unweighted child
				end
			else
				nw = e.Weight
			end
			w = w - nw
			insert(li, { element = e, weight = nw })
		end
		if e == self then
			li = self.SizeList[2] -- second list
		end
	end

	self.MoveMinMax[1] = -free0
	self.MoveMinMax[2] = free1

	return self
end

-------------------------------------------------------------------------------
--	doMove: internal
-------------------------------------------------------------------------------

function Handle:doMove(x, y)

	local g = self.Parent
	local xy = (self.Orientation == 1 and x or y) - self.Move0

	if xy < self.MoveMinMax[1] then
		xy = self.MoveMinMax[1]
	elseif xy > self.MoveMinMax[2] then
		xy = self.MoveMinMax[2]
	end
	local tot = self.MoveMinMax[2] - self.MoveMinMax[1]
	local totw = xy * 0x10000 / tot

	local totw2 = totw

	if xy < 0 then
		-- left:
		for i = #self.SizeList[1], 1, -1 do
			local c = self.SizeList[1][i]
			local e = c.element
			local nw = max(c.weight + totw, 0)
			totw = totw + (c.weight - nw)
			e.Weight = nw
		end
		-- right:
		for i = 1, #self.SizeList[2] do
			local c = self.SizeList[2][i]
			local e = c.element
			local nw = min(c.weight - totw2, 0x10000)
			totw2 = totw2 - (c.weight - nw)
			e.Weight = nw
		end
	elseif xy > 0 then
		-- left:
		for i = #self.SizeList[1], 1, -1 do
			local c = self.SizeList[1][i]
			local e = c.element
			local nw = min(c.weight + totw, 0x10000)
			totw = totw - (nw - c.weight)
			e.Weight = nw
		end
		-- right:
		for i = 1, #self.SizeList[2] do
			local c = self.SizeList[2][i]
			local e = c.element
			local nw = max(c.weight - totw2, 0)
			totw2 = totw2 + (nw - c.weight)
			e.Weight = nw
		end
	end
	self.Window:addLayoutGroup(g, 1)
end

-------------------------------------------------------------------------------
--	passMsg: overrides
-------------------------------------------------------------------------------

function Handle:passMsg(msg)
	if msg[2] == ui.MSG_MOUSEBUTTON then
		if msg[3] == 1 then -- leftdown:
			if self.Window.HoverElement == self and not self.Disabled then
				if self:startMove(msg[4], msg[5]) then
					self.Window:setMovingElement(self)
				end
			end
		elseif msg[3] == 2 then -- leftup:
 			if self.Window.MovingElement == self then
 				self.SizeList = false
				self.Window:setMovingElement()
			end
			self.Move0 = false
		end
	elseif msg[2] == ui.MSG_MOUSEMOVE then
		if self.Window.MovingElement == self then
			self:doMove(msg[4], msg[5])
			-- do not pass message to other elements while dragging:
			return false
		end
	end
	return Gadget.passMsg(self, msg)
end

-------------------------------------------------------------------------------
--	onHover: overrides
-------------------------------------------------------------------------------

function Handle:onHover(hover)
	hover = hover or self.Window.MovingElement == self
	if not hover or not self.Window.MovingElement then
		self:setValue("Hilite", hover)
	end
	self:setState()
end

-------------------------------------------------------------------------------
--	checkFocus: overrides
-------------------------------------------------------------------------------

function Handle:checkFocus()
	return false
end
