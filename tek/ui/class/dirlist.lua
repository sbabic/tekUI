-------------------------------------------------------------------------------
--
--	tek.ui.class.dirlist
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		[[#tek.ui.class.frame : Frame]] /
--		[[#tek.ui.class.widget : Widget]] /
--		[[#tek.ui.class.group : Group]] /
--		DirList ${subclasses(DirList)}
--
--		This class implements a directory lister.
--
--	ATTRIBUTES::
--		- {{AutoWidth [IG]}} (boolean)
--			Tells the directory lister to adapt its contents dynamically to
--			the width of the element. By default, the column widths remain
--			adjusted to the initial width.
--		- {{FocusElement [I]}} (string)
--			What element to focus initially: {{"path"}}, {{"location"}},
--			{{"list"}}. Default: {{"list"}}
--		- {{Kind [IG]}} (string)
--			The visual appearance (or purpose) of the lister, which will
--			determine the presence and arrangement of some interface elements:
--				* {{"requester"}} - for a standalone file requester
--				* {{"lister"}} - for a directory lister component
--				* {{"simple"}} - for the use without accompanying elements
--			The default kind is {{"lister"}}.
--		- {{Location [IG]}} (string)
--			The currently selected entry (may be a file or directory)
--		- {{Path [IG]}} (string)
--			Directory in the file system
--		- {{Selection [G]}} (table)
--			An array of selected entries
--		- {{SelectMode [IG]}} (String)
--			Selection mode:
--				- {{"single"}} - allows selections of one entry at a time
--				- {{"multi"}} - allows selections of multiple entries
--		- {{SelectText [IG]}} (String)
--			The text to display on the selection button. Default: {{"Open"}}
--			(or its equivalent in the current locale)
--		- {{Status [G]}} (string)
--			Status of the directory lister:
--				- {{"running"}} - the lister is currently being shown
--				- {{"selected"}} - the user has selected one or more entries
--				- {{"cancelled"}} - the lister has been cancelled by the user
--
--	IMPLEMENTS::
--		- DirList:abortScan() - Aborts scanning
--		- DirList:getCurrentDir() - Gets the current directory
--		- DirList:getDirIterator() - Gets an iterator over a directory
--		- DirList:getFileStat() - Examines a file entry
--		- DirList:goParent() - Goes to the parent of the current directory
--		- DirList:onSelectEntry() - Handler invoked on selection of an entry
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
local List = require "tek.class.list"
local ui = require "tek.ui"

local Group = ui.require("group", 31)
local Lister = ui.require("lister", 30)
local Text = ui.require("text", 28)
local TextInput = ui.require("textinput", 18)

local insert = table.insert
local pairs = pairs
local pcall = pcall
local sort = table.sort

module("tek.ui.class.dirlist", tek.ui.class.group)
_VERSION = "DirList 16.1"

local DirList = _M

-------------------------------------------------------------------------------
--	cdir = getCurrentDir(): Returns the current directory. You can override
--	this function to implement your own filesystem semantics.
-------------------------------------------------------------------------------

function DirList:getCurrentDir()
	local success, path = pcall(lfs.currentdir)
	return success and path
end

-------------------------------------------------------------------------------
--	iterator = getDirIterator(directory): Returns an iterator function for
--	traversal of the entries in the given {{directory}}. You can override this
--	function to get an iterator over arbitrary kinds of listings.
-------------------------------------------------------------------------------

function DirList:getDirIterator(path)
	local success, dir, iter = pcall(lfs.dir, path)
	if success then
		return function()
			local e
			repeat
				e = dir(iter)
			until e ~= "." and e ~= ".."
			return e
		end
	end
end

-------------------------------------------------------------------------------
--	attr = getFileStat(path, name, attr[, idx]): Returns an attribute for the
--	entry of the given {{path}} and {{name}}; see the documentation of the
--	LuaFileSystem module for the attribute names and their meanings.
--	Currently, only the {{"mode"}} and {{"size"}} attributes are requested,
--	but if you override this function, it would be smart to implement as many
--	attributes as possible. {{idx}} is optional and specifies the entry number
--	inside the list, which is an information that may or may not be supplied
--	by the calling function.
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

	self.AutoWidth = self.AutoWidth or false
	self.Path = self.Path or ""
	self.Location = self.Location or ""
	self.FocusElement = self.FocusElement or "list"

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
		InitialFocus = self.FocusElement == "path",
		onEnter = function(pathfield)
			TextInput.onEnter(pathfield)
			self:scanDir(pathfield.Text)
		end
	}

	self.ParentButton = newButton
	{
		Text = L.PARENT,
		MaxWidth = 0,
		Height = "fill",
		onClick = function(parentbutton)
			self:goParent()
		end
	}

	self.LocationField = TextInput:new
	{
		Text = self.Location,
		KeyCode = "f",
		Height = "fill",
		InitialFocus = self.FocusElement == "location",
		EnterNext = true,
		onEnter = function(locationfield)
			TextInput.onEnter(locationfield)
			self:setFileEntry(pathfield.Text)
		end
	}

	self.ReloadButton = newButton
	{
		Text = L.RELOAD,
		MaxWidth = 0,
		Height = "fill",
		onClick = function(reloadbutton)
			self:reload()
		end
	}

	self.StatusText = Text:new
	{
		Height = "fill",
		Width = "fill",
	}

	self.Lister = self.Lister or Lister:new
	{
		AlignColumn = 1,
		SelectMode = self.SelectMode or "single",
		ListObject = self.DirList,
		onClick = function(lister)
			self:clickList()
		end,
		onSelectLine = function(lister)
			Lister.onSelectLine(lister)
			self:showStats()
		end,
	}

	self.Lister:addNotify("DblClick", true,
		{ self, "dblClickList" })

	self.ListView = ui.ScrollGroup:new
	{
		HSliderMode = self.HSliderMode or "off",
		VSliderMode = "on",
		Child = ui.Canvas:new
		{
			AutoWidth = self.AutoWidth,
			Child = self.Lister
		}
	}

	self.OpenWidget = newButton
	{
		Text = self.SelectText,
		Width = "fill",
		Height = "fill",
		onClick = function(openwidget)
			local list = self.Lister
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
		end
	}

	self.CancelWidget = newButton
	{
		Text = L.CANCEL,
		Width = "fill",
		onClick = function(cancelwidget)
			self:setValue("Status", "cancelled")
		end
	}

	self.DirectoryCaption = Text:new
	{
		Text = L.DIRECTORY,
		Width = "fill",
		MaxWidth = 0,
		Class = "caption",
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
								Width = "fill",
								MaxWidth = 0,
								Class = "caption",
							},
							self.LocationField,
						}
					},
					self.OpenWidget,
					Group:new
					{
						Width = "fill",
						Children =
						{
							self.ReloadButton,
							self.StatusText,
						}
					},
					self.CancelWidget
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

	self:addNotify("Path", NOTIFY_ALWAYS,
		{ self.PathField, "setValue", "Enter", NOTIFY_VALUE })

	return self
end

-------------------------------------------------------------------------------
--	showStats:
-------------------------------------------------------------------------------

function DirList:showStats(selected, total)
	local list = self.Lister
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
	local diri = self:getDirIterator(path)

	app:addCoroutine(function()

		self:abortScan()

		self.ScanMode = "scanning"

		local obj = self.Lister
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
			if self.FocusElement == "list" then
				obj:setValue("Focus", true)
			end
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
	if not path or path == "" then
		path = self:getCurrentDir()
	end
	self.Path = path
	self.PathField:setValue("Enter", path)
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
	local list = self.Lister
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
	local list = self.Lister
	local locationfield = self.LocationField
	local entry = list:getItem(list.CursorLine)
	entry = entry and entry[1][1]
	if entry then
		local type = self:getFileStat(self.Path, entry, "mode")
		if type == "file" then
			locationfield:setValue("Text", entry)
		end
		self:onSelectEntry(list.CursorLine, entry, type)
	end
end

-------------------------------------------------------------------------------
--	onSelectEntry(lnr, name, type): This handler is called when an item in the
--	list was selected by the user. It is passed the line number, {{name}} and
--	{{type}} of the entry (which can be {{"file"}} or {{"directory"}}).
-------------------------------------------------------------------------------

function DirList:onSelectEntry(lnr, name, type)
end

-------------------------------------------------------------------------------
--	dblClickList:
-------------------------------------------------------------------------------

function DirList:dblClickList()
	local list = self.Lister
	local entry = list:getItem(list.CursorLine)
	if entry then
		if not self:setFileEntry(entry[1][1]) then
			if self.Window then
				-- click on "Open":
				self.Window:clickElement(self.OpenWidget)
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
