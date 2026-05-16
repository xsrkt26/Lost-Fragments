extends GutTest

const NewGameScene = preload("res://src/ui/new_game/new_game_scene.tscn")
const RouteConfig = preload("res://src/core/route/route_config.gd")

func test_new_game_scene_shows_route_preview_and_controls() -> void:
	var scene = add_child_autofree(NewGameScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var background := scene.get_node_or_null("Background") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/main_menu/main_menu_background.png")
	assert_eq(background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)

	var route_list := scene.get_node_or_null("MainPanel/MarginContainer/VBoxContainer/RouteScroll/RouteList") as VBoxContainer
	assert_not_null(route_list)
	assert_eq(route_list.get_child_count(), RouteConfig.get_route_size())

	var start_button := scene.get_node_or_null("MainPanel/MarginContainer/VBoxContainer/Footer/StartButton") as Button
	var back_button := scene.get_node_or_null("MainPanel/MarginContainer/VBoxContainer/Footer/BackButton") as Button
	assert_not_null(start_button)
	assert_not_null(back_button)
	assert_eq(start_button.text, "开始新梦")
	assert_eq(back_button.text, "返回主界面")

func test_scene_manager_registers_new_game_scene() -> void:
	assert_true(GlobalScene.SCENE_PATHS.has(GlobalScene.SceneType.NEW_GAME))
	assert_eq(GlobalScene.SCENE_PATHS[GlobalScene.SceneType.NEW_GAME], "res://src/ui/new_game/new_game_scene.tscn")
