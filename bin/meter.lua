#!/usr/bin/env lua

ui = require "tek.ui"

print "This example visualizes sets of 256 16bit numbers, coming in via stdin."
print "The X11 driver supports the conversion of stdin into input messages of"
print "the required MSG_USER type. Invoke this example as follows:"
print "# bin/gendata.lua | bin/meter.lua"

ui.Application:new
{
	Theme = "industrial",
	Children =
	{
		ui.Window:new
		{
			Title = "stdin Meter",
			Orientation = "vertical",
			HideOnEscape = true,
			Children =
			{
				ui.Text:new { Text = "stdin Meter" },
				ui.Meter:new { }
			}
		}
	}

}:run()
