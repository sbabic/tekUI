#!/usr/bin/env lua

local ui = require "tek.ui"
local List = require "tek.class.list"
local Window = ui.Window

local L = ui.getLocale("tekui-demo", "schulze-mueller.de")

-------------------------------------------------------------------------------
--	Create demo window:
-------------------------------------------------------------------------------

local window = Window:new
{
	Orientation = "vertical",
	Id = "list-window",
	Title = L.LIST_TITLE,
	Status = "hide",
	HideOnEscape = true,
	Children =
	{
		ui.ScrollGroup:new
		{
			VSliderMode = "auto",
			HSliderMode = "auto",
			Child = ui.Canvas:new
			{
				Child = ui.Lister:new
				{
					Id = "the-list",
					SelectMode = "single",
					ListObject = List:new
					{
						Items =
						{
							{ { "Adramelech", "The Fall", "Finland", "1995", "Death Metal" } },
							{ { "Blood", "O Agios Pethane", "Germany", "1993", "Grindcore" } },
							{ { "Brian Eno/Robert Fripp", "Evening Star", "United Kingdom", "1975", "Ambient/Drone" } },
							{ { "Cathedral", "Forest of Equilibrium", "United Kingdom", "1991", "Doom Metal" } },
							{ { "Deeds of Flesh", "Mark of the Legion", "United States", "2001", "Death Metal" } },
							{ { "East of Eden", "Mercator Projected", "United Kingdom", "1968", "Blues/Rock" } },
							{ { "Entombed", "Clandestine", "Sweden", "1991", "Death Metal" } },
							{ { "Gorguts", "Considered Dead", "Canada", "1991", "Death Metal" } },
							{ { "Hellhammer", "Apocalyptic Raids", "Switzerland", "1985", "Black Metal" } },
							{ { "Immortal", "Battles in the North", "Norway", "1995", "Black Metal" } },
							{ { "Kampfar", "Mellom Skogkledde Aaser", "Norway", "1997", "Viking Metal" } },
							{ { "Killing Joke", "Extremities, Dirt, and various repressed Emotions", "United Kingdom", "1991", "Wave" } },
							{ { "King Crimson", "Discipline", "United Kingdom", "1981", "Rock" } },
							{ { "Limbonic Art", "Moon in the Scorpio", "Norway", "1996", "Black Metal" } },
							{ { "Massacra", "Enjoy the Violence", "France", "1991", "Death Metal" } },
							{ { "Negură Bunget", "'n Crugu Bradului", "Romania", "2002", "Black Metal" } },
							{ { "Neurosis", "Times of Grace", "United States", "1999", "Hardcore/Rock/Sludge Metal" } },
							{ { "Oppressor", "Elements of Corrosion", "United States", "1998", "Death Metal" } },
							{ { "Pink Floyd", "Meddle", "United Kingdom", "1971", "Rock" } },
							{ { "Robert Rich", "Trances/Drones", "United States", "1981", "Ambient/Drone" } },
							{ { "Rotting Christ", "Thy Mighty Contract", "Greece", "1993", "Black Metal" } },
							{ { "Rudimentary Peni", "Death Church", "United Kingdom", "1983", "Punkrock" } },
							{ { "Sepultura", "Beneath the Remains", "Brazil", "1989", "Death Metal" } },
							{ { "Soft Machine", "Live in France", "United Kingdom", "1969", "Jazz/Blues/Rock" } },
							{ { "Sparks", "Indiscreet", "United Kingdom", "1975", "Rock" } },
							{ { "Unleashed", "Where no Life Dwells", "Sweden", "1991", "Death Metal" } },
							{ { "Vader", "De Profundis", "Poland", "1995", "Death Metal" } },
							{ { "Watain", "Rabid Death's Curse", "Sweden", "2001", "Black Metal" } },
							{ { "Xibalba", "Ah Dzam Poop Ek", "Mexico", "1994", "Black Metal" } },
						}
					}
				}
			}
		}
	}
}

-------------------------------------------------------------------------------
--	Started stand-alone or as part of the demo?
-------------------------------------------------------------------------------

if ui.ProgName:match("^demo_") then
	local app = ui.Application:new()
	ui.Application.connect(window)
	app:addMember(window)
	window:setValue("Status", "show")
	app:run()
else
	return
	{
		Window = window,
		Name = L.LIST_TITLE,
		Description = L.LIST_DESCRIPTION
	}
end
