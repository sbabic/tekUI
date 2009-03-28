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
--			The visual appearance or purpose of the lister, which will
--			determine the arrangement of some interface elements:
--				- "requester" - for being used as a standalone file requester
--				- "lister" - for being used as a lister component
--				- "simple" - without accompanying user interface elements
--			The default kind is "lister".
--		- {{Location [IG]}} (string)
--			The entry currently selected, may be a file or directory
--		- {{Path [IG]}} (string)
--			Directory in the file system
--		- {{Selection [G]}} (table)
--			An array of selected entries
--		- {{SelectMode [IG]}} (String)
--			Mode of selection:
--				- "single" - allows selections of one entry at a time
--				- "multi" - allows selections of multiple entries
--		- {{Status [G]}} (string)
--			Status of the lister:
--				- "running" - the lister is currently being shown
--				- "selected" - the user has selected one or more entries
--				- "cancelled" - the lister has been cancelled by the user
--
--	IMPLEMENTS::
--		- DirList:showDirectory() - Reads and shows a directory
--		- DirList:goParent() - Goes to the parent of the current directory
--		- DirList:abortScan() - Abort scanning
--
--	OVERRIDES::
--		- Class.new()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local _, lfs = pcall(require, "lfs")
local ui = require "tek.ui"
local List = require "tek.class.list"

local Button = ui.Button
local Group = ui.Group
local ListGadget = ui.ListGadget
local Text = ui.Text
local TextInput = ui.TextInput

local insert = table.insert
local pairs = pairs
local pcall = pcall
local sort = table.sort

module("tek.ui.class.dirlist", tek.ui.class.group)
_VERSION = "DirList 9.6"

local DirList = _M

-------------------------------------------------------------------------------
--	iterator = getDirectoryIterator(path): Returns an iterator function for
--	traversal of the entries in the given directory. You can override this
--	function to get an iterator over arbitrary kinds of listings.
-------------------------------------------------------------------------------

function DirList:getDirectoryIterator(path)
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
	return lfs.attributes(path .. "/" .. name, attr)
end

-------------------------------------------------------------------------------
--	path, part = splitPath(path): Splits a path, returning a path and the
--	rearmost path or file part. You can override this function to implement
--	your own file system naming conventions.
-------------------------------------------------------------------------------

function DirList:splitPath(path)
	local part
	path, part = (path .. "/"):match("^(/?.-)/*([^/]*)/+$")
	path = path:gsub("//*", "/")
	return path, part
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

	self.PathField = TextInput:new
	{
		KeyCode = "d",
		Text = self.Path,
		Height = "fill",
	}

	self.PathField:addNotify("Enter", ui.NOTIFY_ALWAYS,
		{ self, "scanDir", ui.NOTIFY_VALUE })

	self.ParentButton = Button:new
	{
		Text = L.PARENT,
		Width = "auto",
		Height = "fill",
	}

	self.ParentButton:addNotify("Pressed", false,
		{ self, "goParent" })

	self.LocationField = TextInput:new
	{
		KeyCode = "f",
		Text = self.Location,
		Height = "fill",
	}

	self.LocationField:addNotify("Enter", ui.NOTIFY_ALWAYS,
		{ self, "setFileEntry", ui.NOTIFY_VALUE })

	self.ReloadButton = Button:new
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
		},
	}

	self.OpenGadget = Button:new
	{
		Text = L.OPEN,
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
			self:setValue("Status", "selected")
		end })

	self.CancelGadget = Button:new
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

function DirList:showStats(selected, total)
	local list = self.ListGadget
	selected = selected or list.NumSelectedLines
	total = total or list:getN()
	self.StatusText:setValue("Text",
		self.Locale.N_OF_M_SELECTED:format(selected, total))
end

-------------------------------------------------------------------------------
--	DirList:abortScan(): This function aborts the coroutine which is
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
--	table, type = DirList:scanEntry(path, name, idx): Scans a single entry
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
--	DirList:sort()
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
--	DirList:scanDir(path)
-------------------------------------------------------------------------------

function DirList:scanDir(path)
	local app = self.Application
	local diri = self:getDirectoryIterator(path)

	app:addCoroutine(function()

		self:abortScan()

		self.ScanMode = "scanning"

		local obj = self.ListGadget
		path = path == "" and "." or path
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

			for i = 1, #list do
				obj:addItem(list[i], nil, true)
			end

			obj:prepare(true)
			obj:setValue("CursorLine", 1)
			obj:setValue("Focus", true)
			self:showStats()
			self:finishScanDir(path)
		end

		self.ScanMode = false

	end)

end

function DirList:finishScanDir(path)
end

-------------------------------------------------------------------------------
--	DirList:showDirectory(path): Starts reading and displays the specified
--	directory.
-------------------------------------------------------------------------------

function DirList:showDirectory(path)
	path = path or self.Path
	self.Path = path
	local pathfield = self.PathField
	local locationfield = self.LocationField
	locationfield:setValue("Text", "")
-- 	pathfield:setValue("Text", path)
	pathfield:setValue("Enter", path)
end

-------------------------------------------------------------------------------
--	DirList:goParent(): Starts reading and displays the parent directory
--	of the current directory.
-------------------------------------------------------------------------------

function DirList:goParent()
	self:showDirectory(self:splitPath(self.PathField.Text))
end

function DirList:setFileEntry(entry)
	local list = self.ListGadget
	local pathfield = self.PathField
	local path = pathfield.Text:match("(.*[^/])/?$") or ""
	local fullpath = pathfield.Text .. "/" .. entry
	fullpath = fullpath:gsub("//*", "/")
	if self:getFileStat(path, entry, "mode") == "directory" then
		self:showDirectory(fullpath)
		return true -- is directory
	end
end

function DirList:clickList()
	local list = self.ListGadget
	local locationfield = self.LocationField
	local entry = list:getItem(list.CursorLine)
	if entry then
		locationfield:setValue("Text", entry[1][1])
	end
end

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

function DirList:reload()
	self:scanDir(self.PathField.Text)
end
