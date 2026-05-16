extends Control

const RouteConfig = preload("res://src/core/route/route_config.gd")

@onready var route_title_label: Label = $MainPanel/MarginContainer/VBoxContainer/RouteHeader/RouteTitleLabel
@onready var route_summary_label: Label = $MainPanel/MarginContainer/VBoxContainer/RouteHeader/RouteSummaryLabel
@onready var route_list: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/RouteScroll/RouteList
@onready var save_warning_label: Label = $MainPanel/MarginContainer/VBoxContainer/SaveWarningLabel
@onready var start_button: Button = $MainPanel/MarginContainer/VBoxContainer/Footer/StartButton
@onready var back_button: Button = $MainPanel/MarginContainer/VBoxContainer/Footer/BackButton

func _ready() -> void:
	print("[NewGame] 进入开始游戏界面")
	GlobalInput.set_context(GlobalInput.Context.MENU)
	GlobalAudio.play_bgm("menu")
	_populate_route_preview()
	_refresh_save_warning()
	start_button.pressed.connect(_on_start_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

func _input(event: InputEvent) -> void:
	if not GlobalInput.can_cancel():
		return
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

func _populate_route_preview() -> void:
	for child in route_list.get_children():
		child.queue_free()

	var route_id := RouteConfig.normalize_route_id(RouteConfig.DEFAULT_ROUTE_ID)
	var nodes := RouteConfig.get_route_nodes(route_id)
	var max_act := RouteConfig.get_max_act()
	route_title_label.text = "默认路线"
	route_summary_label.text = "%d 层 / 每层 %d 个节点" % [max_act, nodes.size()]

	for index in range(nodes.size()):
		route_list.add_child(_create_route_row(index, nodes[index]))

func _create_route_row(index: int, node: Dictionary) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 42)
	row_panel.add_theme_stylebox_override("panel", _row_style(index))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_panel.add_child(row)

	var index_label := Label.new()
	index_label.custom_minimum_size = Vector2(44, 0)
	index_label.text = "%02d" % (index + 1)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	index_label.add_theme_color_override("font_color", Color(0.42, 0.26, 0.12, 1.0))
	row.add_child(index_label)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = str(node.get("label", "路线节点"))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04, 1.0))
	row.add_child(name_label)

	var type_label := Label.new()
	type_label.custom_minimum_size = Vector2(88, 0)
	type_label.text = _node_type_name(str(node.get("type", "")))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.08, 1.0))
	row.add_child(type_label)

	var score_rule := RouteConfig.get_score_target_rule(node, 1)
	var target_label := Label.new()
	target_label.custom_minimum_size = Vector2(88, 0)
	target_label.text = "%d 分" % int(score_rule.get("target", -1)) if bool(score_rule.get("enabled", false)) else "无目标"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.08, 1.0))
	row.add_child(target_label)

	return row_panel

func _row_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.79, 0.47, 0.18 if index % 2 == 0 else 0.1)
	style.border_color = Color(0.28, 0.17, 0.08, 0.16)
	style.border_width_bottom = 1
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _node_type_name(node_type: String) -> String:
	match node_type:
		RouteConfig.NODE_BATTLE:
			return "局内"
		RouteConfig.NODE_BOSS_BATTLE:
			return "Boss"
		RouteConfig.NODE_ELITE_BATTLE:
			return "精英"
		RouteConfig.NODE_SHOP:
			return "商店"
		RouteConfig.NODE_EVENT:
			return "事件"
		RouteConfig.NODE_REWARD:
			return "奖励"
		RouteConfig.NODE_CUTSCENE:
			return "演出"
	return "节点"

func _refresh_save_warning() -> void:
	var rm = get_node_or_null("/root/RunManager")
	var has_continue_save: bool = rm != null and rm.saver != null and rm.saver.has_save() and not rm.is_run_complete
	save_warning_label.visible = has_continue_save
	save_warning_label.text = "当前存在未完成进度，开始新梦会覆盖该进度。" if has_continue_save else ""

func _on_start_button_pressed() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.start_new_run()
	GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_back_button_pressed() -> void:
	GlobalScene.go_back()
