extends Control

## 主菜单：游戏的门户
## 负责开启新游戏、继续进度以及访问图鉴。

@onready var continue_button = $MarginContainer/VBoxContainer/ContinueButton
@onready var new_game_button = $MarginContainer/VBoxContainer/NewGameButton
@onready var settings_container = $CanvasLayer/SettingsContainer # 需要在编辑器中添加此节点

func _ready():
	print("[MainMenu] 进入主菜单")
	GlobalInput.set_context(GlobalInput.Context.MENU)
	GlobalAudio.play_bgm("menu")
	
	# 检查是否有存档
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.saver.has_save():
		continue_button.disabled = false
		continue_button.text = "继续梦境 (深度: %d)" % rm.current_depth
	else:
		continue_button.disabled = true
		continue_button.text = "继续梦境 (无存档)"

func _input(event):
	# 调试快捷键：F1 直接进入沙盒
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			GlobalScene.transition_to(GlobalScene.SceneType.DEBUG)

func _on_new_game_button_pressed():
	print("[MainMenu] 点击新游戏")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.start_new_run()
		GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_continue_button_pressed():
	print("[MainMenu] 点击继续游戏")
	GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_gallery_button_pressed():
	print("[MainMenu] 进入图鉴")
	GlobalScene.transition_to(GlobalScene.SceneType.GALLERY)

func _on_settings_button_pressed():
	if settings_container.get_child_count() > 0:
		for child in settings_container.get_children():
			child.queue_free()
	else:
		var scene = load("res://src/ui/settings/audio_settings_ui.tscn")
		var ui = scene.instantiate()
		settings_container.add_child(ui)

func _on_quit_button_pressed():
	get_tree().quit()
