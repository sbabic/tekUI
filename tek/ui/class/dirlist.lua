-------------------------------------------------------------------------------
--
--	tek.ui.class.dirlist
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
--		[[#tek.ui.class.group : Group]] /
--		DirList
--
--	OVERVIEW::
--		This class implements a directory lister.
--
--	ATTRIBUTES::
--		- {{Kind [IG]}} (string)
--			The visual appearance (or purpose) of the lister, which will
--			determine the arrangement of some interface elements:
--				- {{"requester"}} - for a standalone file requester
--				- {{"lister"}} - for a directory lister component
--				- {{"simple"}} - without accompanying user interface elements
--			The default kind is {{"lister"}}.
--		- {{Location [IG]}} (string)
--			The currently selected entry, may be a file or directory
--		- {{Path [IG]}} (string)
--			Directory in the file system
--		- {{Selection [G]}} (table)
--			An array of selected entries
--		- {{SelectMode [IG]}} (String)
--			- {{"single"}} - allows selections of one entry at a time
--			- {{"multi"}} - allows selections of multiple entries
--		- {{SelectText [IG]}} (String)
--			Text to display on the selection button. Default: {{"Open"}}.
--		- {{Status [G]}} (string)
--			- {{"running"}} - the lister is currently being shown
--			- {{"selected"}} - the user has selected one or more entries
--			- {{"cancelled"}} - the lister has been cancelled by the user
--
--	IMPLEMENTS::
--		- DirList:abortScan() - Aborts scanning
--		- DirList:getCurrentDir() - Gets the current directory
--		- DirList:getDirIterator() - Gets an iterator over a directory
--		- DirList:getFileStat() - Examines a file entry
--		- DirList:goParent() - Goes to the parent of the current directory
--		- DirList:showDirectory() - Reads and shows a directory
--		- DirList:scanEntry() - Scans a single entry in a directory
--		- DirList:showDirectory() - Starts scanning and displays a directory
--		- DirList:splitPath() - Splits a filename
--
--	OVERRIDES::
--		- Class.new()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local _, lfs = pcall(require, "lfs")
local ui = require "tek.ui"
local List = require "tek.class.list"

local Group = ui.Group
local ListGadget = ui.ListGadget
local Text = ui.Text
local TextInput = ui.TextInput

local insert = table.insert
local pairs = pairs
local pcall = pcall
local sort = table.sort

module("tek.ui.class.dirlist", tek.ui.class.group)
_VERSION = "DirList 11.0"

local DirList = _M

-------------------------------------------------------------------------------
--	cdir = getCurrentDir(): Get current directory
-------------------------------------------------------------------------------

function DirList:getCurrentDir()
	local success, path = pcall(lfs.currentdir)
	return success and path
end

-------------------------------------------------------------------------------
--	iterator = getDirIterator(path): Returns an iterator function for
--	traversal of the entries in the given directory. You can override this
--	function to get an iterator over arbitrary kinds of listings.
-------------------------------------------------------------------------------

function DirList:getDirIterator(path)
	local success, dir = pcall(lfs.dir, path)
	if success then
		return function()
			local e
			repeat
				e = dir()
			until e ~= "." and e ~= ".."
			return e
		end
	end
end

-------------------------------------------------------------------------------
--	attr = getFileStat(path, name, attr[, idx]): Returns an attribute for the
--	entry of the given path and name; for the attribute names and their
--	meanings, see the documentation of the LuaFileSystem module.
--	Currently, only the "mode" and "size" attributes are actually requested,
--	but if you override this function, it would be smart to implement as many
--	attributes as possible. {{idx}} is optional and determines the entry
--	number inside the list, which is an information that may or may not be
--	supplied by the calling function.
-------------------------------------------------------------------------------

function DirList:getFileStat(path, name, attr, idx)
	return lfs.attributes(path .. ui.PathSeparator .. name, attr)
end

-------------------------------------------------------------------------------
--	path, part = splitPath(path): Splits a path, returning a path and the
--	rearmost path or file part. You can override this function to implement
--	your own file system naming conventions.
-------------------------------------------------------------------------------

function DirList:splitPath(path)
	local p = ui.PathSeparator
	local part
	path, part = (path..p):match("^("..p.."?.-)"..p.."*([^"..p.."]*)"..p.."+$")
	path = path:gsub(p..p.."*", p)
	return path, part
end

-------------------------------------------------------------------------------
--	newButton:
-------------------------------------------------------------------------------

local function newButton(obj)
	obj.Mode = "button"
	obj.Class = "button"
	obj.KeyCode = true
	return Text:new(obj)
end

-------------------------------------------------------------------------------
--	DirList:
-------------------------------------------------------------------------------

function DirList.new(class, self)

	self = self or { }

	self.Path = self.Path or ""
	self.Location = self.Location or ""

	self.Locale = self.Locale or
		ui.getLocale("dirlist-class", "schulze-mueller.de")
	local L = self.Locale

	-- Kind: "requester", "lister", "simple"
	self.Kind = self.Kind or "lister"

	self.Selection = { }
	-- Status: "running", "cancelled", "selected"
	self.Status = "running"

	self.ScanMode = false
	self.DirList = false
	
	self.SelectMode = self.SelectMode or false
	self.SelectText = self.SelectText or L.OPEN
	
	self.Preselect = self.Preselect or self.Location or false

	self.PathField = TextInput:new
	{
		Text = self.Path,
		KeyCode = "d",
		Height = "fill",
	}

	self.PathField:addNotify("Enter", ui.NOTIFY_ALWAYS,
		{ self, "scanDir", ui.NOTIFY_VALUE })

	self.ParentButton = newButton
	{
		Text = L.PARENT,
		Width = "auto",
		Height = "fill",
	}

	self.ParentButton:addNotify("Pressed", false,
		{ self, "goParent" })

	self.LocationField = TextInput:new
	{
		Text = self.Location,
		KeyCode = "f",
		Height = "fill",
	}

	self.LocationField:addNotify("Enter", ui.NOTIFY_ALWAYS,
		{ self, "setFileEntry", ui.NOTIFY_VALUE })

	self.ReloadButton = newButton
	{
		Text = L.RELOAD,
		Width = "auto",
		Height = "fill",
	}

	self.ReloadButton:addNotify("Pressed", false,
		{ self, "reload" })

	self.StatusText = Text:new
	{
		Height = "fill",
		Width = "fill",
	}

	self.ListGadget = self.ListGadget or ListGadget:new
	{
		AlignColumn = 1,
		SelectMode = self.SelectMode or "single",
		ListObject = self.DirList,
	}

	self.ListGadget:addNotify("Pressed", true,
		{ self, "clickList" })
	self.ListGadget:addNotify("DblClick", true,
		{ self, "dblClickList" })
	self.ListGadget:addNotify("SelectedLine", ui.NOTIFY_ALWAYS,
		{ self, "showStats" })

	self.ListView = ui.ScrollGroup:new
	{
		HSliderMode = self.HSliderMode or "off",
		VSliderMode = "on",
		Child = ui.Canvas:new
		{
			AutoWidth = false,
			Child = self.ListGadget
		}
	}

	self.OpenGadget = newButton
	{
		Text = self.SelectText,
		Width = "fill",
		Height = "fill",
	}

	self.OpenGadget:addNotify("Pressed", false,
		{ self, ui.NOTIFY_FUNCTION, function(self)
			local list = self.ListGadget
			local sel = self.Selection
			for line in pairs(list.SelectedLines) do
				local entry = list:getItem(line)
				insert(sel, entry[1][1])
			end
			-- if nothing selected, use the text in the location field:
			if #sel == 0 and self.LocationField.Text ~= "" then
				insert(sel, self.LocationField.Text)
			end
			self:setValue("Status", "selected")
		end })

	self.CancelGadget = newButton
	{
		Text = L.CANCEL,
		Width = "fill",
	}

	self.CancelGadget:addNotify("Pressed", false,
		{ self, ui.NOTIFY_FUNCTION, function(self)
			self:setValue("Status", "cancelled")
		end })

	self.DirectoryCaption = Text:new
	{
		Text = L.DIRECTORY,
		Width = "auto",
		Class = "caption",
		TextHAlign = "right",
		KeepMinWidth = true,
	}

	self.Orientation = "vertical"

	if self.Kind == "requester" then

		self.Children =
		{
			Group:new
			{
				Orientation = "horizontal",
				Children =
				{
					self.DirectoryCaption,
					self.PathField,
					self.ParentButton,
				}
			},
			self.ListView,
			Group:new
			{
				Width = "fill",
				Columns = 2,
				Children =
				{
					Group:new
					{
						Width = "fill",
						Height = "fill",
						Children =
						{
							Text:new
							{
								Text = L.LOCATION,
								Width = "auto",
								Class = "caption",
								Height = "fill",
							},
							self.LocationField,
						}
					},
					self.OpenGadget,
					Group:new
					{
						Width = "fill",
						Children =
						{
							self.ReloadButton,
							self.StatusText,
						}
					},
					self.CancelGadget
				}
			}
		}

	elseif self.Kind == "lister" then

		self.Children =
		{
			Group:new
			{
				Orientation = "horizontal",
				Children =
				{
					self.DirectoryCaption,
					self.PathField,
					self.ParentButton,
				}
			},
			self.ListView
		}

	else

		self.Children =
		{
			self.ListView
		}

	end

	self = Group.new(class, self)

	self:addNotify("Path", ui.NOTIFY_ALWAYS,
		{ self.PathField, "setValue", "Enter", ui.NOTIFY_VALUE })
	
	return self
end

-------------------------------------------------------------------------------
--	showStats:
-------------------------------------------------------------------------------

function DirList:showStats(selected, total)
	local list = self.ListGadget
	selected = selected or list.NumSelectedLines
	total = total or list:getN()
	self.StatusText:setValue("Text",
		self.Locale.N_OF_M_SELECTED:format(selected, total))
end

-------------------------------------------------------------------------------
--	abortScan(): This function aborts the coroutine which is
--	currently scanning the directory. The caller of this function must
--	be running in its own coroutine.
-------------------------------------------------------------------------------

function DirList:abortScan()
	-- if another coroutine is already scanning, abort it:
	while self.ScanMode do
		self.ScanMode = "abort"
		self.Application:suspend()
	end
end

-------------------------------------------------------------------------------
--	table, type = scanEntry(path, name, idx): Scans a single entry
--	{{name}} in a directory named {{path}}. {{idx}} is the entry number
--	with which this scanned entry will appear in the directory listing.
--	{{table}} is an array of strings, containing entries like name, size,
--	date, permissions, modification date etc. The {{type}} return value
--	corresponds to the return values of DirList:getFileStat().
-------------------------------------------------------------------------------

function DirList:scanEntry(path, name, idx)
	local mode = self:getFileStat(path, name, "mode", idx)
	return
	{
		name,
		mode == "directory" and self.Locale.DIR or
			self:getFileStat(path, name, "size", idx) or
			"[?]"
	},
	mode
end

-------------------------------------------------------------------------------
--	sort()
-------------------------------------------------------------------------------

local function compareEntries(a, b)
	if a[2] == b[2] then
		return a[1][1]:lower() < b[1][1]:lower()
	end
	return a[2] == "directory"
end

function DirList:sort(list)
	sort(list, compareEntries)
end

-------------------------------------------------------------------------------
--	scanDir(path)
-------------------------------------------------------------------------------

function DirList:scanDir(path)
	
	local app = self.Application
	
	self.Path = path
	if path == "" then
		path = self:getCurrentDir()
		self.Path = path
		self.PathField:setValue("Enter", path)
	end
	
	local diri = self:getDirIterator(path)

	app:addCoroutine(function()

		self:abortScan()

		self.ScanMode = "scanning"

		local obj = self.ListGadget
		obj:setValue("CursorLine", 0)
		obj:setList(List:new())

		self.Selection = { }
		if diri then
			local list = { }
			local n = 0

			for name in diri do

				if n % 50 == 0 then
					self:showStats(0, n)
					app:suspend()
					if self.ScanMode ~= "scanning" then
						db.warn("scan aborted")
						self.ScanMode = false
						return
					end
				end
				
				n = n + 1
				
				insert(list, { self:scanEntry(path, name, n) })
			end

			self:sort(list)

			self:showStats(0, n)
			app:suspend()

			local selectline = 1
			local preselect = self.Preselect
			for lnr = 1, #list do
				local entry = list[lnr]
				if preselect and entry[1][1] == preselect then
					selectline = lnr
				end
				obj:addItem(entry, nil, true)
			end
			self.Preselect = false

			obj:repaint()
			obj:setValue("CursorLine", selectline)
			obj:setValue("Focus", true)
			self:showStats()
			self:finishScanDir(path)
		
		end

		self.ScanMode = false

	end)

end

-------------------------------------------------------------------------------
--	finishScanDir()
-------------------------------------------------------------------------------

function DirList:finishScanDir(path)
end

-------------------------------------------------------------------------------
--	showDirectory(path): Starts reading and displays the specified directory.
-------------------------------------------------------------------------------

function DirList:showDirectory(path)
	path = path or self.Path
	self.Path = path
	local pathfield = self.PathField
	pathfield:setValue("Enter", path)
end

-------------------------------------------------------------------------------
--	goParent(): Starts reading and displays the parent directory of the
--	current directory.
-------------------------------------------------------------------------------

function DirList:goParent()
	self:showDirectory(self:splitPath(self.PathField.Text))
end

-------------------------------------------------------------------------------
--	setFileEntry()
-------------------------------------------------------------------------------

function DirList:setFileEntry(entry)
	local list = self.ListGadget
	local pathfield = self.PathField
	local p = ui.PathSeparator
	local path = pathfield.Text:match("(.*[^"..p.."])"..p.."?$") or ""
	local fullpath = pathfield.Text .. p .. entry
	fullpath = fullpath:gsub(p..p.."*", p)
	if self:getFileStat(path, entry, "mode") == "directory" then
		self:showDirectory(fullpath)
		return true -- is directory
	end
end

-------------------------------------------------------------------------------
--	clickList:
-------------------------------------------------------------------------------

function DirList:clickList()
	local list = self.ListGadget
	local locationfield = self.LocationField
	local entry = list:getItem(list.CursorLine)
	entry = entry and entry[1][1]
	if entry and self:getFileStat(self.Path, entry, "mode") == "file" then
		locationfield:setValue("Text", entry)
	end
end

-------------------------------------------------------------------------------
--	dblClickList:
-------------------------------------------------------------------------------

function DirList:dblClickList()
	local list = self.ListGadget
	local entry = list:getItem(list.CursorLine)
	if entry then
		if not self:setFileEntry(entry[1][1]) then
			if self.Window then
				-- click on "Open":
				self.Window:clickElement(self.OpenGadget)
			end
		end
	end
end

-------------------------------------------------------------------------------
--	reload:
-------------------------------------------------------------------------------

function DirList:reload()
	self:scanDir(self.PathField.Text)
end
