
local ui = require "tek.ui"
local VectorImage = ui.VectorImage
module("tek.ui.image.arrowright", tek.ui.class.vectorimage)

local coords = { 0x4000,0x1000, 0x4000,0xf000, 0xc000,0x8000 }
local prims = { { 0x1000, 3, { 1, 2, 3 }, ui.PEN_DETAIL } }

function new(class, num)
	return VectorImage.new(class, { coords, prims, true })
end
