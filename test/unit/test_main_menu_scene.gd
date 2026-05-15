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
	var title_logo: Control = menu.get_node_or_null("MenuHotspots/TitleLogo") as Control
	assert_not_null(title_logo)
	assert_eq(_texture_path(menu, "MenuHotspots/TitleLogo/TitleShi"), "res://assets/ui/main_menu/title_shi.png")
	assert_eq(_texture_path(menu, "MenuHotspots/TitleLogo/TitleYi"), "res://assets/ui/main_menu/title_yi.png")
	assert_eq(_texture_path(menu, "MenuHotspots/TitleLogo/TitleMeng"), "res://assets/ui/main_menu/title_meng.png")

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
		var scroll := button.get_node_or_null("Scroll") as TextureRect
		assert_not_null(scroll, "Main menu button should render scroll texture: %s" % button_name)
		assert_not_null(scroll.texture)
		assert_eq(scroll.texture.resource_path, "res://assets/ui/main_menu/menu_scroll_blank.png")
		var label := button.get_node_or_null("Label") as Label
		assert_not_null(label, "Main menu button should render Godot text: %s" % button_name)
		assert_true(label.text.length() > 0)

	assert_not_null(menu.get_node_or_null("CanvasLayer/SettingsContainer"))

func _texture_path(root: Node, node_path: String) -> String:
	var texture_rect := root.get_node_or_null(node_path) as TextureRect
	if texture_rect == null or texture_rect.texture == null:
		return ""
	return texture_rect.texture.resource_path
