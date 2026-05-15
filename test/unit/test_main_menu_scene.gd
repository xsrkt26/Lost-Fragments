extends GutTest

const MainMenuScene = preload("res://src/ui/main_menu/main_menu.tscn")

func test_main_menu_uses_source_art_and_click_hotspots() -> void:
	var menu = add_child_autofree(MainMenuScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var background := menu.get_node_or_null("Background") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/main_menu/main_menu_background.png")
	assert_eq(background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)

	var expected_buttons := [
		"NewGameButton",
		"ContinueButton",
		"GalleryButton",
		"SettingsButton",
		"QuitButton",
	]
	for button_name in expected_buttons:
		var button := menu.get_node_or_null("MenuHotspots/%s" % button_name) as Button
		assert_not_null(button, "Main menu should expose hotspot: %s" % button_name)
		assert_eq(button.text, "")
		assert_true(button.tooltip_text.length() > 0)
		assert_true(button.size.x > 0.0)
		assert_true(button.size.y > 0.0)

	assert_not_null(menu.get_node_or_null("MenuHotspots/ContinueDisabledOverlay"))
	assert_not_null(menu.get_node_or_null("CanvasLayer/SettingsContainer"))
