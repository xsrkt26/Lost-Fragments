extends Node2D

## 枢纽场景控制器：负责场景间的交互流转
## 交互模式：进入区域后按 E 键触发

var current_zone: String = "" # 记录当前所在的交互区: "battle", "shop", "backpack"

func _ready():
	print("[Hub] 已进入梦境整备室。按 A/D 移动，站在区域内按 E 交互。")

func _input(event):
	# ESC 键退回主菜单
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		print("[Hub] 玩家选择返回主菜单")
		get_tree().change_scene_to_file("res://src/ui/main_menu/main_menu.tscn")
		return

	if event.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
		if current_zone == "": return
		
		match current_zone:
			"battle":
				_enter_battle()
			"shop":
				_enter_shop()
			"backpack":
				_enter_backpack()

# --- 区域进入/退出判定 ---

func _on_battle_trigger_body_entered(_body):
	current_zone = "battle"
	print("[Hub] 站在 [进入战斗] 区域。按 E 进入。")

func _on_shop_trigger_body_entered(_body):
	current_zone = "shop"
	print("[Hub] 站在 [梦境商店] 区域。按 E 进入。")

func _on_backpack_trigger_body_entered(_body):
	current_zone = "backpack"
	print("[Hub] 站在 [整理背包] 区域。按 E 进入。")

func _on_zone_body_exited(_body):
	current_zone = ""
	print("[Hub] 离开区域")

# --- 场景切换逻辑 ---

func _enter_battle():
	print("[Hub] 准备进入战斗...")
	get_tree().change_scene_to_file("res://src/ui/main_game_ui.tscn")

func _enter_shop():
	print("[Hub] 商店界面开发中...")
	# get_tree().change_scene_to_file("res://src/ui/shop/shop_ui.tscn")

func _enter_backpack():
	print("[Hub] 背包整理界面开发中...")
