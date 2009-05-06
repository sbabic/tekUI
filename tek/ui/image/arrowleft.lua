-------------------------------------------------------------------------------
--
--	tek.ui.image.arrowleft
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	Version 1.3
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Image = ui.Image
module("tek.ui.image.arrowleft", tek.ui.class.image)

local coords = { 0xc000,0x1000, 0xc000,0xf000, 0x5000,0x8000 }
local prims = { { 0x1000, 3, { 1, 2, 3 }, ui.PEN_DETAIL } }

function new(class, num)
	return Image.new(class, { coords, false, false, true, prims })
end
