#!/usr/bin/env lua

local ui = require "tek.ui"
local rdargs = require "tek.lib.args".read

local template = "FILE,-f=FULLSCREEN/S,-w=WIDTH/N,-h=HEIGHT/N,-ns=NOSPLASH,--help=HELP/S"
local args = rdargs(template, arg)
if not args or args.help then
	print(template)
	return
end


local editwindow = ui.EditWindow:new
{
	FullScreen = args.fullscreen,
	FileName = args.file
}

local app = ui.Application:new()


app:addMember(editwindow)


while editwindow.Running do

	editwindow.Width = args.width or editwindow.FullScreen and 800
	editwindow.Height = args.height or editwindow.FullScreen and 600

	editwindow:setValue("Status", "show")
	
	app:show()
	app:run()
	app:hide()
end

app:cleanup()

