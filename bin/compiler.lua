#!/usr/bin/env lua

--
--	compiler.lua - Lua compiler and module linker
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	Compiler based on luac.lua by
--	Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>
--

local Args = require "tek.lib.args"
local lfs = require "lfs"
local unpack = unpack or table.unpack
local loadstring = loadstring or load

-------------------------------------------------------------------------------

local PS = package and package.config:sub(1, 1) or "/"
local PM = "^(" .. PS .. "?.-)" .. PS .. "*([^" .. PS .. "]*)" .. PS .. "+$"

function shellquote(s)
	return s:gsub('["$\\`!]', "\\%1")
end

function splitpath(path)
	local part
	path, part = (path .. PS):match(PM)
	path = path:gsub(PS .. PS .. "*", PS)
	return path, part
end

function addpath(path, part)
	return path .. PS .. part
end

function stat(name, attr)
	return lfs.attributes(name, attr)
end

-------------------------------------------------------------------------------

local function compile(fname, arg, m64)

	local MARK = "////////"
	local NAME = "luac"
	NAME = "=(" .. NAME .. ")"

	local n = #arg
	local m = n
	local b

	for i = 1, n do
		if arg[i] == "-L" then
			m = i - 1
			break
		end
	end

	if m + 2 <= n then
		b = { "local t=package.preload;" }
	else
		b = { "local t;" }
	end

	for i = m + 2, n do
		local mod, fname = arg[i]:match("^%s*([^%s:]+)%s*:%s*(.+)%s*$")
		mod = mod:gsub("^.-([^" .. PS .. "]+)$", "t['%1']=function()end")
		table.insert(b, mod)
		arg[i] = string.sub(string.dump(assert(loadfile(fname))), 13)
	end

	table.insert(b, "t='" .. MARK .. "'")

	for i = 1, m do
		table.insert(b, "(function()end)()")
		arg[i] = string.sub(string.dump(assert(loadfile(arg[i]))), 13)
	end

	b = string.dump(assert(loadstring(table.concat(b, "\n"), NAME)))
	local x, y = string.find(b, MARK)
	b = string.sub(b, 1, x - 6 - (m64 and 4 or 0)) .. "\0" .. string.sub(b, y + 2, y + 5)

	f = assert(io.open(fname, "wb"))
	assert(f:write(b))
	for i = m + 2, n do
		assert(f:write(arg[i]))
	end
	for i = 1, m do
		assert(f:write(arg[i]))
	end
	assert(f:write(string.rep("\0", 12)))
	assert(f:close())
end

-------------------------------------------------------------------------------

function tocsource(outname)
	local tmpname = outname .. ".tmp"
	local b = io.open(outname):read("*a")
	local f = io.open(tmpname, "wb")
	if f then
		local size = b:len()
		local out = function(...) f:write(...) end
		out(("const unsigned char bytecode[%d] = {\n\t"):format(size))
		for i = 1, size do
			local c = string.byte(b:sub(i, i))
			out(("%d,"):format(c))
			if i % 32 == 0 then
				out("\n\t")
			end
		end
		out("\n};\n")
		f:close()
		os.rename(tmpname, outname)
		return true
	end
end

-------------------------------------------------------------------------------

function strip(outname)
	local tmpname = outname .. ".tmp"
	local cmd = ('luac -s -o "%s" "%s"'):format(tmpname:gsub("\\", "\\\\"),
		outname:gsub("\\", "\\\\"))
	if os.execute(cmd) == 0 and stat(tmpname, "mode") == "file" then
		os.remove(outname)
		os.rename(tmpname, outname)
		return true
	end
end


-------------------------------------------------------------------------------
--	main
-------------------------------------------------------------------------------

local template = "-f=FROM,-o=TO,-c=SOURCE/S,-s=STRIP/S,-l=LINK/M,-m64/S,-m32/S,-h=HELP/S"
local args = Args.read(template, arg)
if not args or args["-h"] then
	print "Lua linker and compiler, with optional GUI"
	print "Available options:"
	print "  -f=FROM      Lua source file name"
	print "  -o=TO        Lua bytecode output file name"
	print "  -c=SOURCE/S  Output as C source"
	print "  -s=STRIP/S   Strip debug information"
	print "  -l=LINK/M    List of modules to link, each as modname:filename"
	print "  -m32/S       32 bit architecture (default)"
	print "  -m64/S       64 bit architecture"
	print "  -h=HELP/S    This help"
	return
end

local from, to, mods = args["-f"], args["-o"], args["-l"]

if from or (to and mods) then
	local ext = args["-c"] and ".c" or ".luac"
	to = to or (from:match("^(.*)%.lua$") or from) .. ext

	local t = { }
	if from then
		table.insert(t, from)
	end

	if mods then
		table.insert(t, "-L")
		for _, m in ipairs(mods) do
			table.insert(t, m)
		end
	end

	compile(to, t, args["-m64"])

	if args["-s"] then
		strip(to)
	end

	if args["-c"] then
		tocsource(to)
	end

	return
end

-------------------------------------------------------------------------------
--	Run application to sample modules:
-------------------------------------------------------------------------------

local function sample(fname)
	local f = io.open(".luac_sample.lua", "wb")
	local mods = { }
	if f then

		fname = fname:gsub("\\", "\\\\")

		f:write([[
arg[0] = "]] .. fname .. [["
local p = loadfile("]] .. fname .. [[")
if p then
	local success, res = pcall(p)
	if not success then
		io.stderr:write(res .. "\n")
	end
end
local pd = package.config:sub(1, 1) or "/"
local path = tek and tek.ui and tek.ui.LocalPath or package.path
local f = io.open(".luac_sample.txt", "wb")
for pkg in pairs(package.loaded) do
	local mod = pkg:gsub("%.", pd)
	for mname in path:gmatch("([^;]+);?") do
		local fname = mname:gsub("?", mod)
		if io.open(fname) then
			f:write(pkg, " = ", fname, "\n")
			break
		end
	end
end
]])
		f:close()

		os.execute("lua .luac_sample.lua")

		f = io.open(".luac_sample.txt")
		if f then
			for line in f:lines() do
				table.insert(mods, line)
			end
			f:close()
			table.sort(mods)
		end

		os.remove(".luac_sample.lua")
		os.remove(".luac_sample.txt")
	end
	return mods
end

-------------------------------------------------------------------------------
--	GUI main
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local List = require "tek.class.list"
local Input = ui.Input
local APP_ID = "lua-compiler"
local DOMAIN = "schulze-mueller.de"
local PROGNAME = "Lua Compiler"
local VERSION = "1.3"
local AUTHOR = "Timm S. Müller"
local COPYRIGHT = "© 2009-2015, Schulze & Müller GbR"

-------------------------------------------------------------------------------
--	FileButton class:
-------------------------------------------------------------------------------

local FileButton = ui.ImageWidget:newClass()

function FileButton.init(self)
	self.Image = ui.getStockImage("file")
	self.Mode = "button"
	self.Class = "button"
	self.Height = "fill"
	self.Width = "fill"
	self.MinWidth = 15
	self.MinHeight = 17
	self.ImageAspectX = 5
	self.ImageAspectY = 7
	self.Style = "padding: 2"
	return ui.ImageWidget.init(self)
end

function FileButton:onClick()
	self.Application:addCoroutine(function()
		self:doRequest()
	end)
end

function FileButton:doRequest()
end

-------------------------------------------------------------------------------
--	CompilerApp class:
-------------------------------------------------------------------------------

local CompilerApp = ui.Application:newClass()

function CompilerApp.new(class, self)
	self = self or { }
	self.Settings = self.Settings or { }
	self.Settings.ModulePath = self.Settings.ModulePath or ""
	self.Settings.OutFileName = self.Settings.OutFileName or ""
	return ui.Application.new(class, self)
end

function CompilerApp:addModule(classname, filename, enable)
	enable = enable == nil or enable
	local group = self:getById("group-modules")
	for i = 1, #group.Children, 3 do
		local c = group.Children[i]
		if c.Text == classname then
			return 0 -- already present
		end
	end
	local filefield = Input:new
	{
		Disabled = not enable,
		Text = filename,
		Width = "free",
		VAlign = "center",
	}
	local selectbutton = FileButton:new
	{
		Disabled = not enable,
		doRequest = function(self)
			local app = self.Application
			local path, part = splitpath(filefield:getText())
			local status, path, select = app:requestFile
			{
				Title = "Select Lua module...",
				Path = path,
				Location = part
			}
			if status == "selected" and select[1] then
				app.Settings.ModulePath = path
				filefield:setValue("Enter", addpath(path, select[1]))
				app:setStatus("Module selected.")
			end
		end,
	}
	local checkmark = ui.CheckMark:new
	{
		Width = "fill",
		Selected = enable,
		Text = classname,
		onSelect = function(self)
			local app = self.Application
			ui.CheckMark.onSelect(self)
			local selected = self.Selected
			filefield:setValue("Disabled", not selected)
			selectbutton:setValue("Disabled", not selected)
			local n = app:selectModules()
			app:setStatus("%d modules selected", n)
		end,
	}
	group:addMember(checkmark)
	group:addMember(filefield)
	group:addMember(selectbutton)
	if #group.Children == 3 then
		self:getById("button-all"):setValue("Disabled", false)
		self:getById("button-none"):setValue("Disabled", false)
		self:getById("button-invert"):setValue("Disabled", false)
	end
	self:selectModules()
	return 1
end

function CompilerApp:getExcludeList()
	local exclude = { }	
	local excludefname = self:getById("text-exclude-filename"):getText()
	if excludefname then
		local f = io.open(excludefname)
		if f then
			for line in f:lines() do
				line = line:match("^(.*)%:.*$")
				if line then
					table.insert(exclude, line)
					exclude[line] = #exclude
				end
			end
			f:close()
		end
	end
	return exclude
end

function CompilerApp:sample()
	local filefield = self:getById("text-filename")
	local fname = filefield:getText()
	local exclude = self:getById("check-exclude-modules").Selected and self:getExcludeList()
	self:addCoroutine(function()
		local mods = sample(fname)
		local n = 0
		for _, mod in ipairs(mods) do
			local classname, filename = mod:match("^(.-)%s*=%s*(.*)$")
			local disable = exclude and exclude[classname]
			n = n + self:addModule(classname, filename, not disable)
		end
		self:setStatus("%d modules added.", n)
	end)
end

function CompilerApp:compile()

	self:addCoroutine(function()

		local m64 = self:getById("popitem-architecture").SelectedLine == 2
	
		local savemode = -- 1 = binary, 2 == source
			self:getById("popitem-savemode").SelectedLine
		local ext = savemode == 1 and ".luac" or ".c"

		local srcname = self:getById("text-filename"):getText()
		local outname = self.Settings.OutFileName
		if outname == "" then
			outname = (srcname:match("^(.*)%.lua$") or srcname) .. ext
		else
			local _, srcfile = splitpath(srcname)
			local outpath = splitpath(outname)
			srcfile = (srcfile:match("^(.*)%.lua$") or srcfile) .. ext
			outname = addpath(outpath, srcfile)
		end

		local path, part = splitpath(outname)

		local status, path, select = self:requestFile
		{
			Title = "Select File to Save...",
			Path = path,
			Location = part,
			SelectText = "_Save",
		}

		if status == "selected" and select[1] then

			outname = addpath(path, select[1])

			local success, msg = true

			if io.open(outname) then
				success = self:easyRequest("Overwrite File",
					("%s\nalready exists. Overwrite it?"):format(outname),
					"_Overwrite", "_Cancel") == 1
			end

			if success then

				local group = self:getById("group-modules")
				local mods = { }
				local modgroup = group.Children
				success = true
				for i = 1, #modgroup, 3 do
					local checkbutton = modgroup[i]
					if checkbutton.Selected then
						local classname = checkbutton.Text
						local filename = modgroup[i + 1]:getText()
						if io.open(filename) then
							table.insert(mods, ("%s:%s"):format(classname, filename))
						else
							local text =
								filename == "" and "No filename specified" or
									"Cannot open file:\n" .. filename
							success = self:easyRequest("Error",
								"Error loading module " .. classname .. ":\n" ..
								text,
								"_Abort", "_Continue Anyway") == 1
						end
					end
					if not success then
						break
					end
				end

				if success then
					success, msg = pcall(compile, outname,
						{ srcname, "-L", unpack(mods) }, m64)
					if not success then
						self:easyRequest("Error",
							"Compilation failed:\n" .. msg, "_Okay")
					else
						local tmpname = outname .. ".tmp"
						if self:getById("check-strip").Selected then
							if not strip(outname) then
								self:easyRequest("Error",
									"Error stripping file:\n" .. outname, "_Okay")
								success = false
							end
						end
						if success then
							local size = stat(outname, "size")
							if savemode == 2 then
								if tocsource(outname) then
									self:setStatus("C source saved, binary size: %d bytes", size)
								end
							else
								self:setStatus("Binary saved, size: %d bytes", size)
							end
						else
							self:setStatus("Error saving file.")
						end
					end
				end
			end
		end
		self.Settings.OutFileName = outname
	end)
end

function CompilerApp:setStatus(text, ...)
	self:getById("text-status"):setValue("Text", text:format(...))
end

function CompilerApp:deleteModules(mode)
	local g = self:getById("group-modules")
	local n, nd = 0, 0
	if mode == "all" then
		while #g.Children > 0 do
			g:remMember(g.Children[1])
			nd = nd + 1
		end
	elseif mode == "selected" then
		for i = #g.Children - 2, 1, -3 do
			local c = g.Children[i]
			if c.Selected then
				g:remMember(g.Children[i])
				g:remMember(g.Children[i])
				g:remMember(g.Children[i])
				nd = nd + 1
			else
				n = n + 1
			end
		end
	end
	if n == 0 then
		self:getById("button-all"):setValue("Disabled", true)
		self:getById("button-none"):setValue("Disabled", true)
		self:getById("button-invert"):setValue("Disabled", true)
	end
	self.Application:selectModules()
	return nd
end

function CompilerApp:selectModules(mode)
	local exclude = self:getExcludeList()
	local g = self:getById("group-modules")
	local n = 0
	for i = 1, #g.Children, 3 do
		local c = g.Children[i]
		if mode == "toggle" then
			c:setValue("Selected", not c.Selected)
		elseif mode == "all" then
			c:setValue("Selected", true)
		elseif mode == "none" then
			c:setValue("Selected", false)
		elseif mode == "exclude" then
			local classname = c.Text
			local disable = exclude and exclude[classname]
			c:setValue("Selected", not disable)
		end
		if c.Selected then
			n = n + 1
		end
	end
	self:getById("button-delete"):setValue("Disabled", n == 0)
	return n
end

-------------------------------------------------------------------------------
--	Application:
-------------------------------------------------------------------------------

CompilerApp:new
{
	ApplicationId = APP_ID,
	Domain = DOMAIN,
	Children =
	{
		ui.Window:new
		{
			Style = "width: 400; height: 300",
			HideOnEscape = true,
			Center = true,
			Orientation = "vertical",
			Id = "window-about",
			Status = "hide",
			Title = "About Compiler",
			Children =
			{
				ui.Text:new
				{
					Text = "About Lua Compiler",
					Style = "font: ui-large"
				},
				ui.Group:new
				{
					Orientation = "vertical",
					Children =
					{
						ui.Group:new
						{
							Legend = "Application Information",
							Children =
							{
								ui.ListView:new
								{
									HSliderMode = "auto",
									VSliderMode = "auto",
									Child = ui.Lister:new
									{
										SelectMode = "none",
										ListObject = List:new
										{
											Items =
											{
												{ { "ProgramName", PROGNAME } },
												{ { "Version", VERSION } },
												{ { "Author", AUTHOR } },
												{ { "Copyright", COPYRIGHT } },
											}
										}
									}
								}
							}
						}
					}
				},
				ui.Button:new
				{
					InitialFocus = true,
					Text = "_Okay",
					Style = "width: fill",
					onClick = function(self)
						self.Window:setValue("Status", "hide")
					end
				}
			}
		},
		ui.Window:new
		{
			Id = "window-main",
			Title = "Lua compiler and module linker",
			Orientation = "vertical",
			HideOnEscape = true,
			onHide = function(self)
				local app = self.Application
				app:addCoroutine(function()
					if app:easyRequest("Exit Application",
						"Do you really want to\n" ..
						"quit the application?",
						"_Quit", "_Cancel") == 1 then
						app:quit()
					end
				end)
			end,
			Children =
			{
				ui.Group:new
				{
					Class = "menubar",
					Children =
					{
						ui.MenuItem:new
						{
							Text = "File",
							Children =
							{
								ui.MenuItem:new
								{
									Text = "About",
									Shortcut = "Ctrl+?",
									onClick = function(self)
										self:getById("window-about"):setValue("Status", "show")
									end
								},
								ui.Spacer:new { },
								ui.MenuItem:new
								{
									Text = "_Quit",
									Shortcut = "Ctrl+Q",
									onClick = function(self)
										self:getById("window-main"):onHide()
									end
								}
							}
						}
					}
				},
				ui.Group:new
				{
					Legend = "Compile and save to bytecode",
					Width = "fill",
					Orientation = "vertical",
					Children =
					{
						ui.Group:new
						{
							Children =
							{
								ui.Text:new
								{
									Text = "_Lua Source:",
									Class = "caption",
									Width = "fill",
									KeyCode = true,
								},
								Input:new
								{
									Id = "text-filename",
									Style = "text-align: right",
									onEnter = function(self)
										Input.onEnter(self)
										local text = self:getText()
										local notexist = io.open(text) == nil
										local app = self.Application
										app:getById("button-run"):setValue("Disabled", notexist)
										app:getById("button-compile"):setValue("Disabled", notexist)
									end,
								},
								FileButton:new
								{
									KeyCode = "l",
									doRequest = function(self)
										local app = self.Application
										local filefield = app:getById("text-filename")
										local path, part = splitpath(filefield:getText())
										local status, path, select = app:requestFile
										{
											Title = "Select Lua source...",
											Path = path,
											Location = part
										}
										if status == "selected" and select[1] then
											local newfname = addpath(path, select[1])
											filefield:setValue("Enter", newfname)
											app:setStatus("Run the script to collect module dependencies.")
										else
											app:setStatus("File selection cancelled.")
										end
									end,
								}
							}
						},
						ui.Group:new
						{
							Children =
							{
								ui.CheckMark:new 
								{ 
									Id = "check-exclude-modules",
									Text = "Exclude modules from list:", 
									Selected = true, 
									Width = "auto" 
								},
								Input:new
								{
									Id = "text-exclude-filename",
									Text = "tek/lib/MODLIST",
									Style = "text-align: right",
								},
								FileButton:new
								{
									doRequest = function(self)
										local app = self.Application
										local filefield = app:getById("text-exclude-filename")
										local path, part = splitpath(filefield:getText())
										local status, path, select = app:requestFile
										{
											Title = "Select Module list file...",
											Path = path,
											Location = part
										}
										if status == "selected" and select[1] then
											local newfname = addpath(path, select[1])
											filefield:setValue("Enter", newfname)
										end
									end,
								},
								ui.Button:new 
								{ 
									Text = "Exclude now", 
									Width = "auto",
									onClick = function(self)
										self.Application:selectModules("exclude")
									end
								}
							}
						},
						ui.Group:new
						{
							Width = "fill",
							Children =
							{
								ui.Group:new
								{
									Width = "auto",
									Orientation = "vertical",
									Children =
									{
										ui.CheckMark:new
										{
											Id = "check-strip",
											Text = "Strip _Debug Information",
										},
										ui.Group:new
										{
											Columns = 2,
											Children =
											{
												ui.Text:new
												{
													Class = "caption",
													Text = "_Architecture",
													KeyCode = true,
												},
												ui.PopList:new
												{
													SelectedLine = 1,
													Id = "popitem-architecture",
													KeyCode = "a",
													ListObject = List:new
													{
														Items =
														{
															{ { "32 bit" } },
															{ { "64 bit" } },
														}
													}
												},
												ui.Text:new
												{
													Class = "caption",
													Text = "Save _Format",
													KeyCode = true,
												},
												ui.PopList:new
												{
													SelectedLine = 1,
													Id = "popitem-savemode",
													KeyCode = "f",
													ListObject = List:new
													{
														Items =
														{
															{ { "Binary" } },
															{ { "C Source" } },
														}
													}
												}
											}
										}
									}
								},
								ui.Button:new
								{
									Id = "button-compile",
									Width = "fill",
									Height = "fill",
									Text = "Compile, Link, and _Save",
									Disabled = true,
									onClick = function(self)
										self.Application:compile()
									end
								}
							}
						}
					}
				},
				ui.Group:new
				{
					Legend = "Modules to link",
					Children =
					{
						ui.Group:new
						{
							Orientation = "vertical",
							Width = "fill",
							Children =
							{
								ui.Button:new
								{
									Id = "button-run",
									Text = "_Run",
									Disabled = true,
									onClick = function(self)
										self.Application:setStatus("Running sample...")
										self.Application:sample()
									end
								},
								ui.PopItem:new
								{
									Id = "button-add",
									Text = "Add _Module",
									Children =
									{
										ui.Group:new
										{
											Legend = "Add new Module",
											Children =
											{
												ui.Text:new
												{
													Class = "caption",
													Text = "Module Name:",
												},
												Input:new
												{
													MinWidth = 200,
													InitialFocus = true,
													onEnter = function(self)
														Input.onEnter(self)
														local text = self:getText()
														if text ~= "" then
															self.Application:addModule(text, "")
															self.Application:setStatus("Module %s added - please select a file name for it.", text)
														end
														self.Window:finishPopup()
													end
												}
											}
										}
									}
								},
								ui.Spacer:new { },
								ui.Button:new
								{
									Id = "button-all",
									Text = "Select _All",
									Disabled = true,
									onClick = function(self)
										self.Application:selectModules("all")
									end
								},
								ui.Button:new
								{
									Id = "button-none",
									Text = "Select _None",
									Disabled = true,
									onClick = function(self)
										self.Application:selectModules("none")
									end
								},
								ui.Button:new
								{
									Id = "button-invert",
									Text = "_Invert Sel.",
									Disabled = true,
									onClick = function(self)
										self.Application:selectModules("toggle")
									end
								},
								ui.Button:new
								{
									Id = "button-delete",
									Text = "Delete Sel.",
									Disabled = true,
									onClick = function(self)
										local app = self.Application
										local n = app:selectModules()
										local text = n == 1 and "one module" or
											("%d modules"):format(n)
										app:addCoroutine(function()
											if app:easyRequest("Delete Modules",
												"Are you sure that you want to\n" ..
													"delete " .. text .. " from the list?",
												"_Delete", "_Cancel") == 1 then
												local n = self.Application:deleteModules("selected")
												self.Application:setStatus("%d modules deleted from the list", n)
											end
										end)
									end
								}
							}
						},
						ui.ScrollGroup:new
						{
							VSliderMode = "auto",
							HSliderMode = "auto",
							Child = ui.Canvas:new
							{
								Id = "group-canvas",
								AutoPosition = true,
								AutoWidth = true,
								AutoHeight = true,
								Child = ui.Group:new
								{
									Columns = 3,
									Id = "group-modules",
									Orientation = "vertical"
								}
							}
						}
					}
				},
				ui.Text:new
				{
					Id = "text-status",
					Text = "Please select a Lua source.",
					KeepMinWidth = true
				}
			}
		}
	}
}:run()
