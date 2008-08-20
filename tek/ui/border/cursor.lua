
--
--	tek.ui.class.border.cursor
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--

local ui = require "tek.ui"
local Border = require "tek.ui.class.border"
local Region = require "tek.lib.region"

module("tek.ui.border.cursor", tek.ui.class.border)
_VERSION = "CursorBorder 3.0"

local CursorBorder = _M

function CursorBorder:draw()
	local d = self.Parent.Drawable
	local r = self.Rect
	local b1, b2, b3, b4 = self:getBorder()
	local p1 = d.Pens[ui.PEN_CURSORDETAIL]
	d:fillRect(r[1] - b1, r[2] - b2, r[3] + b3, r[2] - 1, p1)
	d:fillRect(r[3] + 1, r[2], r[3] + b3, r[4] + b4, p1)
	d:fillRect(r[1] - b1, r[4] + 1, r[3] + b3, r[4] + b4, p1)
	d:fillRect(r[1] - b1, r[2], r[1] - 1, r[4], p1)
end
