#!/usr/bin/env lua
local ui = require "tek.ui"
ui.Application:new
{
	ApplicationId = "tekui-demo",
	ProgramName = "Dynamic",
	Domain = "schulze-mueller.de",
	Author = "Timm S. Müller";
	Children =
	{
		ui.Window:new
		{
			HideOnEscape = true,
			Orientation = "vertical",
			Children =
			{
				ui.Group:new
				{
					Legend = "Self Modification",
					Width = "fill",
					Children =
					{
						ui.Button:new
						{
							Id = "add-button",
							NumButtons = 0,
							MaxWidth = 0,
							Text = "Add",
							onPress = function(self, pressed)
								ui.Button.onPress(self, pressed)
								if pressed == false and self.NumButtons < 10 then
									self:getParent():addMember(ui.Button:new {
										MaxWidth = 0,
										Text = "Remove",
										onPress = function(self, pressed)
											ui.Button.onPress(self, pressed)
											if pressed == false then
												local add = self:getById("add-button")
												add.NumButtons = add.NumButtons - 1
												self:getParent():remMember(self)
											end
										end			
									})
									self.NumButtons = self.NumButtons + 1
								end
							end
						}
					}
				},
				ui.Group:new
				{
					Legend = "Dynamic Weight",
					Orientation = "vertical",
					Children =
					{
						ui.Group:new
						{
							Children =
							{
								ui.Slider:new
								{
									Child = ui.Text:new
									{
										Id = "dynweight-knob",
										Class = "knob button",
									},
									Id = "slider-2",
									Min = 0,
									Max = 0x10000,
									Width = "free",
									Default = 0x8000,
									Step = 0x400,
									show = function(self, drawable)
										ui.Slider.show(self, drawable)
										self:setValue("Value", self.Value, true)
									end,
									onSetValue = function(self, val)
										ui.Slider.onSetValue(self, val)
										val = self.Value
										local e = self:getById("slider-weight-1")
										e:setValue("Weight", val)
										e:getParent():rethinkLayout()
										e:setValue("Text", ("$%05x"):format(val))
										val = math.floor(val)
										e:getById("dynweight-knob"):setValue("Text", val)
									end
								},
								ui.Button:new
								{
									Text = "Reset",
									VAlign = "center",
									MaxWidth = 0,
									onPress = function(self, press)
										ui.Button.onPress(self, press)
										if press == false then
											self:getById("slider-2"):reset()
										end
									end
								}
							}
						},
						ui.Group:new
						{
							Children =
							{
								ui.Text:new 
								{
									Id="slider-weight-1", 
									Style = "font: ui-huge",
									Height = "fill",
								},
								ui.Frame:new { Height = "fill" }
							}
						}
					}
				},
				ui.Group:new
				{
					Width = "free",
					Legend = "Dynamic Layout",
					Children =
					{
						ui.Slider:new
						{
							Child = ui.Text:new
							{
								Id = "dynlayout-knob",
								Class = "button knob",
							},
							Height = "fill",
							Min = 0,
							Max = 100000,
							Step = 100,
							show = function(self, drawable)
								ui.Slider.show(self, drawable)
								self:setValue("Value", self.Value, true)
							end,
							onSetValue = function(self, val)
								ui.Slider.onSetValue(self, val)
								val = self.Value
								local text = ("%d"):format(val)
								if val == 100000 then
									text = text .. "\nMaximum"
								end
								self:getById("text-field-1"):setValue("Text", text)
								self:getById("dynlayout-knob"):setValue("Text", math.floor(val))
							end
						},
						ui.Text:new
						{
							Style = "font: ui-huge",
							Id = "text-field-1",
							MaxWidth = 0,
						}
					}
				}
			}
		}
	}
}:run()
