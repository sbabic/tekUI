
local ui = require "tek.ui"
local Element = ui.require("element", 16)

module("tek.ui.class.drawhook", tek.ui.class.element)
_VERSION = "DrawHook 3.1"
local DrawHook = _M
Element:newClass(DrawHook)

function DrawHook:layout(x0, y0, x1, y1)
end

function DrawHook:draw()
end
