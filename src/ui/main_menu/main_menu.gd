extends Control

## 主菜单：游戏的门户
## 负责开启新游戏、继续进度以及访问图鉴。

@onready var continue_button = $MarginContainer/VBoxContainer/ContinueButton
@onready var new_game_button = $MarginContainer/VBoxContainer/NewGameButton

func _ready():
	print("[MainMenu] 进入主菜单")
	
	# 检查是否有存档
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.saver.has_save():
		continue_button.disabled = false
		continue_button.text = "继续梦境 (深度: %d)" % rm.current_depth
	else:
		continue_button.disabled = true
		continue_button.text = "继续梦境 (无存档)"

func _on_new_game_button_pressed():
	print("[MainMenu] 点击新游戏")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.start_new_run()
		# 跳转到梦境整备室 (Hub)
		get_tree().change_scene_to_file("res://src/ui/hub/hub_scene.tscn")

func _on_continue_button_pressed():
	print("[MainMenu] 点击继续游戏")
	# 直接跳转到梦境整备室 (Hub)
	get_tree().change_scene_to_file("res://src/ui/hub/hub_scene.tscn")

func _on_gallery_button_pressed():
	print("[MainMenu] 点击图鉴 (功能待开发)")

func _on_quit_button_pressed():
	get_tree().quit()
