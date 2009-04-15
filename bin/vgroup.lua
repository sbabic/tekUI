#!/usr/bin/env lua

local ui = require "tek.ui"

ui.Application:new
{
	Children =
	{
		ui.Window:new
		{
			Title = "Groups Demo",
			HideOnEscape = true,
			Children =
			{
				ui.ScrollGroup:new
				{
					Legend = "Virtual Group",
					Width = 500,
					Height = 500,
					HSliderMode = "on",
					VSliderMode = "on",
					Child = ui.Canvas:new
					{
						MaxWidth = 500,
						MaxHeight = 500,
						CanvasWidth = 500,
						CanvasHeight = 500,
						Child = ui.Group:new
						{
							Columns = 2,
							Children =
							{
								ui.Button:new { Width = "free", Height = "free", Text = "foo" },
								ui.Button:new { Width = "free", Height = "free", Text = "foo" },
								ui.Button:new { Width = "free", Height = "free", Text = "foo" },
								ui.ScrollGroup:new
								{
									Legend = "Virtual Group",
									Width = 500,
									Height = 500,
									HSliderMode = "on",
									VSliderMode = "on",
									Child = ui.Canvas:new
									{
										CanvasWidth = 500,
										CanvasHeight = 500,
										Child = ui.Group:new
										{
											Columns = 2,
											Children =
											{
												ui.Button:new { Width = "free", Height = "free", Text = "foo" },
												ui.Button:new { Width = "free", Height = "free", Text = "foo" },
												ui.Button:new { Width = "free", Height = "free", Text = "foo" },
												ui.ScrollGroup:new
												{
													Legend = "Virtual Group",
													Width = 500,
													Height = 500,
													HSliderMode = "on",
													VSliderMode = "on",
													Child = ui.Canvas:new
													{
														CanvasWidth = 500,
														CanvasHeight = 500,
														Child = ui.Group:new
														{
															Columns = 2,
															Children =
															{
																ui.Button:new { Width = "free", Height = "free", Text = "foo" },
																ui.Button:new { Width = "free", Height = "free", Text = "foo" },
																ui.Button:new { Width = "free", Height = "free", Text = "foo" },
																ui.Button:new { Width = "free", Height = "free", Text = "foo" },
															}
														}
													}
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}:run()
