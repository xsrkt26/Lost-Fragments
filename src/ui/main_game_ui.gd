extends Control

## 主游戏 UI 控制器：负责将布局中的各个部分与逻辑层连接

@onready var backpack_ui = $ContentLayer/GridPanel/BackpackUI
@onready var sanity_label = $ContentLayer/StatsPanel/VBox/SanityLabel
@onready var score_label = $ContentLayer/StatsPanel/VBox/ScoreLabel
@onready var draw_button = $ContentLayer/DreamcatcherPanel/DrawButton
@onready var dreamcatcher_panel = $ContentLayer/DreamcatcherPanel
@onready var draw_spawn_point = get_node_or_null(draw_spawn_point_path)
@onready var trash_bin = $ContentLayer/GridPanel/TrashBin
@onready var ornaments_area = $ContentLayer/OrnamentsPanel/Slots

@export var draw_spawn_point_path: NodePath = "ContentLayer/DreamcatcherPanel/DrawSpawnPoint"

var battle_manager: BattleManager
var _is_battle_ended: bool = false
var _draw_locked: bool = false
var _dreamcatcher_base_scale := Vector2.ONE

func _ready():
	print("[MainGameUI Debug] UI初始化开始...")
	if dreamcatcher_panel:
		_dreamcatcher_base_scale = dreamcatcher_panel.scale
	
	# 设置手动结束按钮文本 (对齐设计需求)
	var menu_btn = $ContentLayer/MenuButton
	if menu_btn:
		menu_btn.text = "结束本局"
	
	# 检查关键节点是否成功获取
	if draw_button:
		# 强制确保按钮是可见的且接收鼠标
		draw_button.visible = true
		draw_button.tooltip_text = "捕梦"
	if trash_bin:
		trash_bin.tooltip_text = "丢弃"
	
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
	
	# 核心修复：确保进入战斗时状态是干净的
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.reset_game()
	
	if backpack_ui == null:
		print("[MainGameUI] 错误: backpack_ui 引用为空！")
	
	battle_manager.backpack_ui = backpack_ui
	if not battle_manager.battle_finish_requested.is_connected(_on_battle_finish_requested):
		battle_manager.battle_finish_requested.connect(_on_battle_finish_requested)
	
	# 连接逻辑信号
	battle_manager.item_drawn.connect(_on_item_drawn)
	backpack_ui.item_dropped_on_grid.connect(battle_manager.request_place_item)
	_render_existing_backpack_items()
	_render_ornaments()
	
	# 连接状态更新信号
	gs = get_node_or_null("/root/GameState")
	if gs:
		# 断开旧连接避免重复 (容错)
		if gs.sanity_changed.is_connected(_on_sanity_changed): gs.sanity_changed.disconnect(_on_sanity_changed)
		if gs.score_changed.is_connected(_on_score_changed): gs.score_changed.disconnect(_on_score_changed)
		if gs.game_over.is_connected(_on_game_over): gs.game_over.disconnect(_on_game_over)
		
		gs.sanity_changed.connect(_on_sanity_changed)
		gs.score_changed.connect(_on_score_changed)
		gs.game_over.connect(_on_game_over)
		_update_stats_display(gs.current_sanity, gs.current_score)
	_sync_draw_button_state()

func _on_game_over():
	if _is_battle_ended: return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_sanity > 0:
		return
	print("[MainGameUI] 收到梦值归零信号，正在按当前战斗规则结算...")
	if battle_manager and battle_manager.has_method("request_finish_battle"):
		battle_manager.request_finish_battle("sanity_depleted")
	else:
		_finish_battle_from_current_state()

func _on_defeat():
	if _is_battle_ended: return
	_is_battle_ended = true
	if battle_manager and battle_manager.has_method("mark_battle_finished"):
		battle_manager.mark_battle_finished()
	print("[MainGameUI] 未满足当前战斗目标，正在显示失败浮窗...")
	_show_result_popup(false)

func _on_victory():
	if _is_battle_ended: return
	_is_battle_ended = true
	if battle_manager and battle_manager.has_method("mark_battle_finished"):
		battle_manager.mark_battle_finished()
	print("[MainGameUI] 达成目标分数，正在显示胜利浮窗...")
	_show_result_popup(true)

func _on_battle_finish_requested(_reason: String):
	_finish_battle_from_current_state()

func _show_result_popup(is_victory: bool):
	# 自动清理背包外物品 (核心需求)
	if battle_manager:
		battle_manager.discard_all_outside_items()
		if battle_manager.has_method("persist_backpack_to_run"):
			battle_manager.persist_backpack_to_run()
		
	# 禁用背景输入
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	
	var popup_scene = load("res://src/ui/battle/result_popup.tscn")
	var popup = popup_scene.instantiate()
	add_child(popup)
	
	# 获取组件
	var title = popup.get_node("%TitleLabel")
	var score_label = popup.get_node("%ScoreLabel")
	var btn = popup.get_node("%ConfirmButton")
	
	# 设置文本
	var gs = get_node("/root/GameState")
	var rm = get_node_or_null("/root/RunManager")
	var score_rule = _get_current_score_rule()
	var target_text = _format_target_text(score_rule.has_target, score_rule.target)
	
	if is_victory:
		title.text = "梦境圆满"
		title.add_theme_color_override("font_color", Color("#ec3073")) # 暖粉/金色
		score_label.text = "最终得分: %d / %s" % [gs.current_score, target_text]
		var reward_options = _get_reward_options(rm)
		if reward_options.is_empty():
			btn.text = "继续梦境"
			btn.pressed.connect(func(): _complete_victory_route(rm))
		else:
			btn.hide()
			_add_reward_choices(popup, reward_options, rm)
	else:
		title.text = "梦境惊醒"
		title.add_theme_color_override("font_color", Color("#555555")) # 灰色
		score_label.text = "遗憾离场 (得分: %d / %s)" % [gs.current_score, target_text]
		btn.text = "回到现实"
		btn.pressed.connect(func():
			if rm:
				rm.fail_run()
			GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU)
		)

func _get_reward_options(rm) -> Array[Dictionary]:
	if rm == null or not rm.has_method("generate_current_reward_options"):
		return []
	var item_db = get_node_or_null("/root/ItemDatabase")
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	var option_count = 4 if _has_empty_dream_trophy_bonus(rm) else 3
	return rm.generate_current_reward_options(item_db, ornament_db, option_count)

func _has_empty_dream_trophy_bonus(rm) -> bool:
	if rm == null or not Array(rm.current_ornaments).has("empty_dream_trophy"):
		return false
	var gs = get_node_or_null("/root/GameState")
	var score_rule = _get_current_score_rule()
	if gs == null or not bool(score_rule.get("has_target", false)):
		return false
	return gs.current_score > int(score_rule.get("target", -1)) + 50

func _add_reward_choices(popup: Control, reward_options: Array[Dictionary], rm) -> void:
	var panel = popup.get_node("Panel")
	panel.custom_minimum_size = Vector2(640, 360)
	panel.offset_left = -320.0
	panel.offset_top = -180.0
	panel.offset_right = 320.0
	panel.offset_bottom = 180.0

	var container = popup.get_node("Panel/VBoxContainer")
	var reward_row = HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 12)
	container.add_child(reward_row)
	container.move_child(reward_row, max(0, container.get_child_count() - 2))

	for reward in reward_options:
		var reward_button = Button.new()
		reward_button.custom_minimum_size = Vector2(180, 92)
		reward_button.text = _format_reward_button_text(reward)
		reward_button.tooltip_text = str(reward.get("description", ""))
		reward_button.pressed.connect(func():
			if rm and rm.has_method("apply_reward"):
				rm.apply_reward(reward)
			_complete_victory_route(rm)
		)
		reward_row.add_child(reward_button)

func _format_reward_button_text(reward: Dictionary) -> String:
	var title = str(reward.get("title", "奖励"))
	var reward_type = str(reward.get("type", ""))
	match reward_type:
		"item":
			return "%s\n物品" % title
		"ornament":
			return "%s\n%s饰品" % [title, str(reward.get("rarity", ""))]
		"shards":
			return title
	return title

func _complete_victory_route(rm) -> void:
	if rm:
		rm.win_battle(0)
	var next_scene = GlobalScene.SceneType.MAIN_MENU if rm and rm.is_run_complete else GlobalScene.SceneType.HUB
	GlobalScene.transition_to(next_scene, false)

func _on_item_drawn(item_data: ItemData):
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	var card = item_ui_scene.instantiate()

	# 将卡牌放入 UI 层
	add_child(card)
	card.setup(item_data, battle_manager.context)
	
	# 注册到管理器以便自动清理
	if battle_manager:
		battle_manager.managed_item_uis.append(card)
	
	# --- 核心适配：同步背包缩放 ---
	card.scale = Vector2(0.7, 0.7)
	
	# 初始位置：抽卡区中心
	card.global_position = _get_draw_spawn_position(card)
	_play_item_spawn_animation(card)
	
	# 连接拖拽信号
	_connect_item_ui_signals(card)

func _render_existing_backpack_items():
	if not battle_manager or not backpack_ui:
		return
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	for instance in battle_manager.backpack_manager.get_all_instances():
		var card = item_ui_scene.instantiate()
		add_child(card)
		card.setup(instance.data, battle_manager.context)
		card.item_instance = instance
		battle_manager.managed_item_uis.append(card)
		_connect_item_ui_signals(card)
		backpack_ui.add_item_visual(card, instance.root_pos)

func _render_ornaments():
	if ornaments_area == null:
		return
	for child in ornaments_area.get_children():
		child.queue_free()
	var rm = get_node_or_null("/root/RunManager")
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if rm == null or ornament_db == null:
		return
	for ornament_id in rm.current_ornaments:
		var ornament = ornament_db.get_ornament_by_id(ornament_id)
		if ornament == null:
			continue
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.text = ornament.ornament_name.substr(0, min(2, ornament.ornament_name.length()))
		slot.tooltip_text = ornament.get_tooltip_text()
		slot.focus_mode = Control.FOCUS_NONE
		ornaments_area.add_child(slot)

func _connect_item_ui_signals(card: Control):
	card.dropped.connect(func(_mouse_pos, _pivot): _handle_item_dropped(card, _mouse_pos, _pivot))
	card.drag_moved.connect(func(_item_ui, _mouse_pos, _pivot): _handle_item_dragged(_item_ui, _mouse_pos, _pivot))
	card.rotation_requested.connect(_handle_item_rotation_requested)

func _handle_item_dragged(item_ui: Control, mouse_pos: Vector2, pivot_offset: Vector2i):
	var mouse_grid_pos = backpack_ui.get_grid_pos_at(mouse_pos)
	var root_grid_pos = mouse_grid_pos - pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	backpack_ui.highlight_placement(root_grid_pos, item_ui.item_data)

func _handle_item_rotation_requested(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i):
	if battle_manager and battle_manager.has_method("request_rotate_item"):
		battle_manager.request_rotate_item(item_ui, mouse_global_pos, pivot_offset)

func _handle_item_dropped(item_ui: Control, mouse_pos: Vector2, pivot_offset: Vector2i):
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
	
	# 3. 计算 root_pos 并交给管理器
	var mouse_grid_pos = backpack_ui.get_grid_pos_at(mouse_pos)
	var root_grid_pos = mouse_grid_pos - pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	
	battle_manager.request_place_item(item_ui, root_grid_pos)

func _on_draw_button_pressed():
	if not _is_draw_interaction_available():
		return
	_set_draw_locked(true)
	await _play_dreamcatcher_animation()
	if battle_manager and not _is_battle_ended:
		await battle_manager.request_draw()
	if not _is_battle_ended:
		_set_draw_locked(false)

func _input(event):
	# 输入权限检查
	if not GlobalInput.can_cancel() or _is_battle_ended: return

	# ESC 键撤退回整备室
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_return_to_hub()

func _on_menu_button_pressed():
	if battle_manager and battle_manager.has_method("request_finish_battle"):
		battle_manager.request_finish_battle("manual")
	else:
		_finish_battle_from_current_state()

func _is_draw_interaction_available() -> bool:
	return not _is_battle_ended and not _draw_locked and battle_manager != null and battle_manager.battle_state == BattleManager.BattleState.INTERACTIVE

func _set_draw_locked(locked: bool) -> void:
	_draw_locked = locked
	_sync_draw_button_state()

func _sync_draw_button_state() -> void:
	if draw_button:
		draw_button.disabled = _draw_locked or _is_battle_ended or battle_manager == null or battle_manager.battle_state != BattleManager.BattleState.INTERACTIVE

func _play_dreamcatcher_animation() -> void:
	if dreamcatcher_panel == null or not is_inside_tree():
		return
	var tween = create_tween()
	tween.tween_property(dreamcatcher_panel, "scale", _dreamcatcher_base_scale * 1.04, 0.08)
	tween.tween_property(dreamcatcher_panel, "scale", _dreamcatcher_base_scale, 0.12)
	await tween.finished

func _get_draw_spawn_position(card: Control) -> Vector2:
	var spawn_center: Vector2
	if draw_spawn_point:
		spawn_center = draw_spawn_point.global_position + draw_spawn_point.size / 2.0
	else:
		spawn_center = dreamcatcher_panel.global_position + (dreamcatcher_panel.size * dreamcatcher_panel.scale) / 2.0
	return spawn_center - (card.size * card.scale) / 2.0

func _play_item_spawn_animation(card: Control) -> void:
	card.modulate.a = 0.0
	var target_scale = card.scale
	card.scale = target_scale * 0.65
	var tween = create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(card, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 根据当前得分评估并结束战斗 (满足手动结束按钮需求)
func _evaluate_and_end_battle():
	if battle_manager and battle_manager.has_method("request_finish_battle"):
		battle_manager.request_finish_battle("manual")
	else:
		_finish_battle_from_current_state()

func _finish_battle_from_current_state():
	if _is_battle_ended: return
	
	var gs = get_node("/root/GameState")
	var rm = get_node_or_null("/root/RunManager")
	var score_rule = _get_current_score_rule()
	
	print("[MainGameUI] 正在结束战斗. 当前得分: ", gs.current_score, " 目标: ", _format_target_text(score_rule.has_target, score_rule.target))
	
	if rm and rm.has_method("is_current_battle_score_success"):
		if rm.is_current_battle_score_success(gs.current_score):
			_on_victory()
		else:
			_on_defeat()
	elif not score_rule.has_target or gs.current_score >= score_rule.target:
		_on_victory()
	else:
		_on_defeat()

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

func _update_stats_display(san, score):
	var gs = get_node_or_null("/root/GameState")
	var score_rule = _get_current_score_rule()
	var max_san = gs.max_sanity if gs else 100
	_apply_stats_display(san, score, max_san, score_rule)

func _apply_stats_display(san: int, score: int, max_san: int, score_rule: Dictionary):
	if sanity_label:
		sanity_label.text = "梦值: %d / %d" % [san, max_san]
		# 梦值低时变红
		if san <= max_san * 0.2:
			sanity_label.add_theme_color_override("font_color", Color(1, 0, 0))
		else:
			sanity_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	
	if score_label:
		score_label.text = "得分: %d / %s" % [score, _format_target_text(score_rule.has_target, score_rule.target)]
		# 有目标且达成时变绿；无目标时保持默认深色。
		if score_rule.has_target and score >= score_rule.target:
			score_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		else:
			score_label.add_theme_color_override("font_color", Color(0.2, 0.16, 0.13))

func _get_current_score_rule() -> Dictionary:
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.has_method("get_current_battle_config"):
		var config = rm.get_current_battle_config()
		return {
			"has_target": bool(config.get("has_score_target", false)),
			"target": int(config.get("target_score", -1))
		}
	return {
		"has_target": true,
		"target": 50
	}

func _format_target_text(has_target: bool, target: int) -> String:
	if not has_target or target < 0:
		return "无"
	return str(target)
