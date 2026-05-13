extends GutTest

func before_each():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.reset_route_progress()
		rm.is_run_active = true

func after_each():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.reset_route_progress()

func test_score_target_text_supports_none():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	assert_eq(ui._format_target_text(false, -1), "无")
	assert_eq(ui._format_target_text(true, 50), "50")

func test_reaching_boss_target_does_not_auto_end_battle():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	ui.sanity_label = autofree(Label.new())
	ui.score_label = autofree(Label.new())

	ui._apply_stats_display(100, 50, 100, {"has_target": true, "target": 50})

	assert_eq(ui.score_label.text, "得分: 50 / 50")
	assert_false(ui._is_battle_ended)
