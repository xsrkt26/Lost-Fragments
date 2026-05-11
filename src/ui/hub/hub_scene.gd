extends Node2D

## 枢纽场景控制器：负责场景间的交互流转
## 交互模式：进入区域后按 E 键触发

@onready var overlay_root = $CanvasLayer/OverlayRoot

var current_zone: String = "" # 记录当前所在的交互区: "battle", "shop", "gallery"

func _ready():
	print("[Hub] 已进入梦境整备室。按 A/D 移动，站在区域内按 E 交互。")
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	GlobalAudio.play_bgm("hub")

func _input(event):
	# 输入权限检查
	if not GlobalInput.can_cancel(): return

	# ESC 键处理：如果有浮窗则关闭浮窗，否则退回主菜单
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if overlay_root.get_child_count() > 0:
			_close_backpack_overlay()
		else:
			GlobalScene.go_back()
		return

	# 仅在探索模式下允许 E 键交互
	if GlobalInput.is_context(GlobalInput.Context.WORLD):
		if event.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
			if current_zone == "": return
			
			match current_zone:
				"battle":
					_enter_battle()
				"shop":
					_enter_shop()
				"gallery":
					_enter_gallery()

# --- 区域进入/退出判定 ---

func _on_battle_trigger_body_entered(_body):
	current_zone = "battle"
	print("[Hub] 站在 [进入战斗] 区域。按 E 进入。")

func _on_shop_trigger_body_entered(_body):
	current_zone = "shop"
	print("[Hub] 站在 [梦境商店] 区域。按 E 进入。")

func _on_gallery_trigger_body_entered(_body):
	current_zone = "gallery"
	print("[Hub] 站在 [物品图鉴] 区域。按 E 进入。")

func _on_zone_body_exited(_body):
	current_zone = ""
	print("[Hub] 离开区域")

# --- 场景切换逻辑 ---

func _enter_battle():
	GlobalScene.transition_to(GlobalScene.SceneType.BATTLE)

func _enter_shop():
	GlobalScene.transition_to(GlobalScene.SceneType.SHOP)

func _enter_gallery():
	GlobalScene.transition_to(GlobalScene.SceneType.GALLERY)

# --- 浮动背包逻辑 ---

func _on_backpack_button_pressed():
	if overlay_root.get_child_count() > 0:
		_close_backpack_overlay()
	else:
		_open_backpack_overlay()

func _open_backpack_overlay():
	print("[Hub] 正在打开背包浮层...")
	GlobalInput.set_context(GlobalInput.Context.UI)
	var ui_scene = load("res://src/ui/main_game_ui.tscn")
	var overlay = ui_scene.instantiate()
	overlay_root.add_child(overlay)
	
	# 关键定制：隐藏战斗专属元素
	if overlay.has_node("ContentLayer/DreamcatcherPanel"):
		overlay.get_node("ContentLayer/DreamcatcherPanel").hide()
	if overlay.has_node("ContentLayer/MenuButton"):
		overlay.get_node("ContentLayer/MenuButton").hide()
	
	# 视觉提示
	var bg = overlay.get_node("Background")
	if bg:
		bg.color = Color(0, 0, 0, 0.6) # 变为半透明背景

func _close_backpack_overlay():
	print("[Hub] 正在关闭背包浮层")
	for child in overlay_root.get_children():
		child.queue_free()
	GlobalInput.set_context(GlobalInput.Context.WORLD)
