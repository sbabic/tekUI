
local ui = require "tek.ui"
local VectorImage = ui.VectorImage
module("tek.ui.image.arrowup", tek.ui.class.vectorimage)

local coords = { 0x1111,0x4444, 0xffff,0x4444, 0x8888,0xcccc }
local prims = { { 0x1000, 3, Points = { 1, 2, 3 }, Pen = ui.PEN_DETAIL } }

function new(class, num)
	return VectorImage.new(class, {
		Coords = coords,
		Primitives = prims,
		Transparent = true
	})
end
