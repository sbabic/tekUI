#!/usr/bin/env lua

--
--	compiler.lua - Lua compiler and module linker
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	Compiler based on luac.lua by
--	Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>
--

local lfs = require "lfs"
local ui = require "tek.ui"
local List = require "tek.class.list"

local APP_ID = "lua-compiler"
local VENDOR = "schulze-mueller.de"
local PROGNAME = "Lua Compiler"
local VERSION = "1.0"
local AUTHOR = "Timm S. Müller"
local COPYRIGHT = "© 2008, 2009, Schulze-Müller GbR"

-------------------------------------------------------------------------------

local PS = ui.PathSeparator
local PM = "^(" .. PS .. "?.-)" .. PS .. "*([^" .. PS .. "]*)" .. PS .. "+$"

function shellquote(s)
	return s:gsub('["$\`!]', "\\%1")
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

local function compile(fname, arg)

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
		local mod, fname = arg[i]:match("^%s*([^%s=]+)%s*=%s*(.+)%s*$")
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
	b = string.sub(b, 1, x - 6) .. "\0" .. string.sub(b, y + 2, y + 5)

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
--	FileButton class:
-------------------------------------------------------------------------------

local fileimage = ui.createImage("file")

local FileButton = ui.ImageGadget:newClass()

function FileButton.init(self)
	self.Image = fileimage
	self.Mode = "button"
	self.Class = "button"
	self.Height = "fill"
	self.Width = "fill"
	self.MinWidth = 15
	self.MinHeight = 18
	self.Style = "padding: 2"
	return ui.ImageGadget.init(self)
end

-------------------------------------------------------------------------------

local function addmodule(app, classname, filename)
	local group = app:getElementById("group-modules")
	for i = 1, #group.Children, 3 do
		local c = group.Children[i]
		if c.Text == classname then
			return 0 -- already present
		end
	end
	local filefield = ui.TextInput:new
	{
		Text = filename,
		TextHAlign = "left",
		Width = "free",
		VAlign = "center",
	}
	local selectbutton = FileButton:new
	{
		onPress = function(self, press)
			ui.Button.onPress(self, press)
			if press == false then
				local app = self.Application
				app:addCoroutine(function()
					local path, part = splitpath(filefield.Text)
					local status, path, select = app:requestFile
					{
						Title = "Select Lua module...",
						Path = path,
						Location = part
					}
					if status == "selected" and select[1] then
						app.ModulePath = path
						filefield:setValue("Enter", addpath(path, select[1]))
					end
				end)
			end
		end
	}			
	local checkmark = ui.CheckMark:new
	{
		Width = "fill",
		Selected = true,
		Text = classname,
		TextHAlign = "left",
		onSelect = function(self, selected)
			ui.CheckMark.onSelect(self, selected)
			filefield:setValue("Disabled", not selected)
			selectbutton:setValue("Disabled", not selected)
			local n = self.Application:selectModules()
			self.Application:setStatus("%d modules selected", n)
		end,
	}
	group:addMember(checkmark)
	group:addMember(filefield)
	group:addMember(selectbutton)
	if #group.Children == 3 then
		app:getElementById("button-all"):setValue("Disabled", false)
		app:getElementById("button-none"):setValue("Disabled", false)
		app:getElementById("button-invert"):setValue("Disabled", false)
	end
	app:selectModules()
	return 1
end

local function gui_sample(self)
	local app = self.Application
	local filefield = app:getElementById("text-filename")
	local fname = filefield.Text
	app:addCoroutine(function()
		local mods = sample(fname)
		local n = 0
		for _, mod in ipairs(mods) do
			local classname, filename = mod:match("^(.*)%s*=%s*(.*)$")
			n = n + addmodule(app, classname, filename)
		end
		self.Application:setStatus("%d modules added.", n)
	end)
end

-------------------------------------------------------------------------------

local function gui_compile(self)
	
	local app = self.Application
	app:addCoroutine(function()
		
		local savemode = -- 1 = binary, 2 == source
			app:getElementById("popitem-savemode").SelectedLine
		local ext = savemode == 1 and ".luac" or ".c"
		
		local srcname = app:getElementById("text-filename").Text
		local outname = app.OutFileName
		if outname == "" then
			outname = (srcname:match("^(.*)%.lua$") or srcname) .. ext
		else
			local _, srcfile = splitpath(srcname)
			local outpath = splitpath(outname)
			srcfile = (srcfile:match("^(.*)%.lua$") or srcfile) .. ext
			outname = addpath(outpath, srcfile)
		end
		
		local path, part = splitpath(outname)
		
		local status, path, select = app:requestFile
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
				success = app:easyRequest("Overwrite File",
					("%s\nalready exists. Overwrite it?"):format(outname),
					"_Overwrite", "_Cancel") == 1
			end
			
			if success then
			
				local group = app:getElementById("group-modules")
				local mods = { }
				local modgroup = group.Children
				success = true
				for i = 1, #modgroup, 3 do
					local checkbutton = modgroup[i]
					if checkbutton.Selected then
						local classname = checkbutton.Text
						local filename = modgroup[i + 1].Text
						if io.open(filename) then
							table.insert(mods, ("%s = %s"):format(classname, filename))
						else
							local text =
								filename == "" and "No filename specified" or
									"Cannot open file:\n" .. filename
							success = app:easyRequest("Error",
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
						{ srcname, "-L", unpack(mods) })
					if not success then
						app:easyRequest("Error",
							"Compilation failed:\n" .. msg, "_Okay")
					else
						local tmpname = outname .. ".tmp"
						if app:getElementById("check-strip").Selected then
							local cmd = ('luac -s -o "%s" "%s"'):format(tmpname:gsub("\\", "\\\\"), 
								outname:gsub("\\", "\\\\"))
							if os.execute(cmd) == 0 and stat(tmpname, "mode") == "file" then
								os.remove(outname)
								os.rename(tmpname, outname)
							else
								app:easyRequest("Error",
									"Error stripping file:\n" .. outname, "_Okay")
								success = false
							end
						end
						if success then
							local size = stat(outname, "size")
							if savemode == 2 then
								local b = io.open(outname):read("*a")
								local f = io.open(tmpname, "wb")
								if f then
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
									app:setStatus("C source saved, binary size: %d bytes", size)
								end
							else
								app:setStatus("Binary saved, size: %d bytes", size)
							end
						else
							app:setStatus("Error saving file.")
						end
					end
				end
			end
		end
		
		app.OutFileName = outname
	
	end)
end

-------------------------------------------------------------------------------

ui.Application:new
{
	ApplicationId = APP_ID,
	VendorDomain = VENDOR,
	
	setStatus = function(self, text, ...)
		self.Application:getElementById("text-status"):setValue("Text", 
			text:format(...))
	end,
	
	deleteModules = function(self, mode)
		local g = self:getElementById("group-modules")
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
			self:getElementById("button-all"):setValue("Disabled", true)
			self:getElementById("button-none"):setValue("Disabled", true)
			self:getElementById("button-invert"):setValue("Disabled", true)
		end
		self.Application:selectModules()
		return nd
	end,
	
	selectModules = function(self, mode)
		local g = self:getElementById("group-modules")
		local n = 0
		for i = 1, #g.Children, 3 do
			local c = g.Children[i]
			if mode == "toggle" then
				c:setValue("Selected", not c.Selected)
			elseif mode == "all" then
				c:setValue("Selected", true)
			elseif mode == "none" then
				c:setValue("Selected", false)
			end
			if c.Selected then
				n = n + 1
			end
		end
		self.Application:getElementById("button-delete"):setValue("Disabled", n == 0)
		return n
	end,

	OutFileName = "",
	ModulePath = "",

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
									Child = ui.ListGadget:new
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
					onPress = function(self, pressed)
						if pressed == false then
							self.Window:setValue("Status", "hide")
						end
						ui.Button.onPress(self, pressed)
					end,
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
						"Are you sure that you quit?",
						"_Quit", "_Cancel") == 1 then
						self.Application:quit()
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
									onPress = function(self, pressed)
										ui.MenuItem.onPress(self, pressed)
										if pressed == false then
											self:getId("window-about"):setValue("Status", "show")
										end
									end
								},
								ui.Spacer:new { },
								ui.MenuItem:new
								{
									Text = "_Quit",
									Shortcut = "Ctrl+Q",
									onPress = function(self, pressed)
										if pressed == false then
											self:getId("window-main"):onHide()
										end
										ui.MenuItem.onPress(self, pressed)
									end,
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
									Width = "auto",
									KeyCode = true,
								},
								ui.TextInput:new
								{
									Id = "text-filename",
									Height = "fill",
									TextHAlign = "left",
									KeepMinWidth = true,
									onEnter = function(self, text)
										ui.TextInput.onEnter(self, text)
										local notexist = io.open(text) == nil
										local app = self.Application
										app:getElementById("button-run"):setValue("Disabled", notexist)
										app:getElementById("button-compile"):setValue("Disabled", notexist)
									end,
								},
								FileButton:new
								{
									KeyCode = "l",
									onPress = function(self, pressed)
										if pressed == false then
											local app = self.Application
											app:addCoroutine(function()
												local filefield = app:getElementById("text-filename")
												local path, part = splitpath(filefield.Text)
												local status, path, select = app:requestFile
												{
													Title = "Select Lua source...",
													Path = path,
													Location = part
												}
												if status == "selected" and select[1] then
													local newfname = addpath(path, select[1])
													filefield:setValue("Enter", newfname)
													app:setStatus("Lua source selected.")
												else
													app:setStatus("File selection cancelled.")
												end
											end)
										end
										self:getClass().onPress(self, pressed)
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
									Orientation = "vertical",
									Children =
									{
										ui.CheckMark:new
										{
											Id = "check-strip",
											Text = "Strip _Debug Information",
											Width = "auto",
										},
										ui.Group:new
										{
											Children =
											{
												ui.Text:new
												{
													Class = "caption",
													Text = "Save _Format",
													Width = "auto",
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
													},
													Width = "fill",
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
									onPress = function(self, pressed)
										if pressed == false then
											gui_compile(self)
										end
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
									Text = "_Run Sample",
									Disabled = true,
									onPress = function(self, pressed)
										ui.Button.onPress(self, pressed)
										if pressed == false then
											self.Application:setStatus("Running sample...")
											gui_sample(self)
										end
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
												ui.TextInput:new
												{
													MinWidth = 200,
													InitialFocus = true,
													onEnter = function(self, text)
														ui.TextInput.onEnter(self, text)
														if text ~= "" then
															addmodule(self.Application, text, "")
															self.Application:setStatus("Module %s added - please select a file name for it.", text)
														end
														self.Window:finishPopup()
													end,
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
									onPress = function(self, press)
										ui.Button.onPress(self, press)
										if press == false then
											self.Application:selectModules("all")
										end
									end
								},
								
								ui.Button:new
								{
									Id = "button-none",
									Text = "Select _None",
									Disabled = true,
									onPress = function(self, press)
										ui.Button.onPress(self, press)
										if press == false then
											self.Application:selectModules("none")
										end
									end
								},
								
								ui.Button:new
								{
									Id = "button-invert",
									Text = "_Invert Sel.",
									Disabled = true,
									onPress = function(self, press)
										ui.Button.onPress(self, press)
										if press == false then
											self.Application:selectModules("toggle")
										end
									end
								},
								
								ui.Button:new
								{
									Id = "button-delete",
									Text = "Delete Sel.",
									Disabled = true,
									onPress = function(self, press)
										ui.Button.onPress(self, press)
										if press == false then
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
									end
								}
								
							}
						},
						ui.ScrollGroup:new
						{
							VSliderMode = "on",
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
									Orientation = "vertical",
								}
							}
						}
					}
				},
				
				ui.Text:new
				{
					Id = "text-status",
					Text = "Please select a Lua source.",
					KeepMinWidth = true,
				}
				
			}
		}
	}
}:run()
