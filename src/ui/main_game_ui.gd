extends Control

## 主游戏 UI 控制器：负责将布局中的各个部分与逻辑层连接

@onready var backpack_ui = $ContentLayer/GridPanel/BackpackUI
@onready var sanity_label = $ContentLayer/StatsPanel/Label
@onready var draw_button = $ContentLayer/DreamcatcherPanel/DrawButton
@onready var trash_bin = $ContentLayer/GridPanel/TrashBin
@onready var ornaments_area = $ContentLayer/OrnamentsPanel/Slots

var battle_manager: BattleManager

func _ready():
	print("[MainGameUI Debug] UI初始化开始...")
	# 检查关键节点是否成功获取
	if draw_button:
		# 强制确保按钮是可见的且接收鼠标
		draw_button.visible = true
	
	# 容错：自动初始化逻辑
	await get_tree().create_timer(0.1).timeout
	if battle_manager == null:
		var mock_manager = BattleManager.new()
		add_child(mock_manager)
		setup(mock_manager)

func setup(p_battle_manager: BattleManager):
	print("[MainGameUI] 正在执行 setup...")
	GlobalInput.set_context(GlobalInput.Context.BATTLE)
	GlobalAudio.play_bgm("battle")
	battle_manager = p_battle_manager
	
	if backpack_ui == null:
		print("[MainGameUI] 错误: backpack_ui 引用为空！")
	
	battle_manager.backpack_ui = backpack_ui
	
	# 连接逻辑信号
	battle_manager.item_drawn.connect(_on_item_drawn)
	backpack_ui.item_dropped_on_grid.connect(battle_manager.request_place_item)
	
	# 连接状态更新信号
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.sanity_changed.connect(_on_sanity_changed)
		gs.score_changed.connect(_on_score_changed)
		gs.game_over.connect(_on_game_over)
		_update_stats_display(gs.current_sanity, gs.current_score)

func _on_game_over():
	print("[MainGameUI] 收到游戏结束信号，正在执行失败逻辑...")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.fail_run()
	
	GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU)

func _on_item_drawn(item_data: ItemData):
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	var card = item_ui_scene.instantiate()

	# 将卡牌放入 UI 层
	add_child(card)
	card.setup(item_data, battle_manager.context)
	
	# --- 核心适配：同步背包缩放 ---
	card.scale = Vector2(0.7, 0.7)
	
	# 初始位置：抽卡区中心
	var dc_panel = $ContentLayer/DreamcatcherPanel
	var draw_center = dc_panel.global_position + (dc_panel.size * dc_panel.scale) / 2.0
	card.global_position = draw_center - (card.size * card.scale) / 2.0
	
	# 连接拖拽信号
	card.dropped.connect(func(_snap_pos, _mouse_pos): _handle_item_dropped(card, _snap_pos, _mouse_pos))
	card.drag_moved.connect(func(_item_ui, _center_pos): _handle_item_dragged(_item_ui, _center_pos))
	card.rotation_requested.connect(_handle_item_rotation_requested)

func _handle_item_dragged(item_ui: Control, center_pos: Vector2):
	var grid_pos = backpack_ui.get_grid_pos_at(center_pos)
	backpack_ui.highlight_placement(grid_pos, item_ui.item_data)

func _handle_item_rotation_requested(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i):
	if battle_manager and battle_manager.has_method("request_rotate_item"):
		battle_manager.request_rotate_item(item_ui, mouse_global_pos, pivot_offset)

func _handle_item_dropped(item_ui: Control, snap_pos: Vector2, mouse_pos: Vector2):
	backpack_ui.update_slot_visuals() # 清除高亮
	
	# 1. 检查是否掉落在垃圾桶
	if trash_bin.get_global_rect().has_point(mouse_pos):
		if battle_manager:
			battle_manager.request_discard_item(item_ui)
		return
		
	# 2. 检查是否掉落在饰品区
	if ornaments_area.get_global_rect().has_point(mouse_pos):
		if battle_manager and battle_manager.has_method("request_equip_ornament"):
			battle_manager.request_equip_ornament(item_ui)
		return
	
	# 3. 否则按原逻辑交给背包
	backpack_ui.handle_item_dropped(item_ui, snap_pos)

func _on_draw_button_pressed():
	if battle_manager:
		battle_manager.request_draw()

func _input(event):
	# 输入权限检查
	if not GlobalInput.can_cancel(): return

	# ESC 键撤退回整备室
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_return_to_hub()

func _on_menu_button_pressed():
	_return_to_hub()

func _return_to_hub():
	GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_sanity_changed(new_val):
	var gs = get_node("/root/GameState")
	if gs:
		_update_stats_display(new_val, gs.current_score)

func _on_score_changed(new_val):
	var gs = get_node("/root/GameState")
	if gs:
		_update_stats_display(gs.current_sanity, new_val)

func _update_stats_display(_san, score):
	var rm = get_node_or_null("/root/RunManager")
	var target = 100
	if rm:
		target = rm.get_target_score()
		
	if sanity_label:
		sanity_label.text = str(score) + " / " + str(target)
		
	# 胜利判定
	if score >= target:
		_on_victory()

func _on_victory():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.win_battle(5 + rm.current_depth * 2)
		
	GlobalScene.transition_to(GlobalScene.SceneType.HUB)
