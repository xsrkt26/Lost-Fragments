extends GutTest

const RouteConfig = preload("res://src/core/route/route_config.gd")

var run_manager

func before_each():
	run_manager = autofree(load("res://src/autoload/run_manager.gd").new())
	run_manager.reset_route_progress()
	run_manager.is_run_active = true

func test_default_route_is_configured():
	var nodes = run_manager.get_route_nodes()
	assert_eq(nodes.size(), 9)
	assert_eq(nodes[0].get("type"), RouteConfig.NODE_BATTLE)
	assert_eq(nodes[1].get("type"), RouteConfig.NODE_SHOP)
	assert_eq(nodes[2].get("type"), RouteConfig.NODE_EVENT)
	assert_eq(nodes[6].get("type"), RouteConfig.NODE_BOSS_BATTLE)

func test_new_route_progress_starts_at_first_node():
	var node = run_manager.get_current_route_node()
	assert_eq(run_manager.current_act, 1)
	assert_eq(run_manager.current_route_index, 0)
	assert_eq(node.get("id"), "battle_1")
	assert_true(run_manager.can_enter_route_node(0))
	assert_false(run_manager.can_enter_route_node(1))

func test_advance_route_node_unlocks_next_node():
	var completed = run_manager.advance_route_node()
	assert_eq(completed.get("id"), "battle_1")
	assert_eq(run_manager.current_route_index, 1)
	assert_true(run_manager.completed_route_nodes.has(0))
	assert_false(run_manager.can_enter_route_node(0))
	assert_true(run_manager.can_enter_route_node(1))

func test_advance_rejects_unexpected_node_id():
	var completed = run_manager.advance_route_node("wrong_node")
	assert_true(completed.is_empty())
	assert_eq(run_manager.current_route_index, 0)
	assert_true(run_manager.completed_route_nodes.is_empty())

func test_route_wraps_to_next_act_after_last_node():
	for _i in range(RouteConfig.get_route_size()):
		run_manager.advance_route_node()
	assert_eq(run_manager.current_act, 2)
	assert_eq(run_manager.current_route_index, 0)
	assert_true(run_manager.completed_route_nodes.is_empty())

func test_deserialize_old_save_defaults_route_fields():
	run_manager.deserialize_run({
		"shards": 12,
		"deck": ["paper_ball"],
		"ornaments": [],
		"depth": 3,
		"is_active": true
	})
	assert_eq(run_manager.current_route_id, RouteConfig.DEFAULT_ROUTE_ID)
	assert_eq(run_manager.current_act, 1)
	assert_eq(run_manager.current_route_index, 0)
	assert_eq(run_manager.get_current_route_node().get("id"), "battle_1")

func test_scene_mapping_supports_current_route_node_types():
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_BATTLE}), GlobalScene.SceneType.BATTLE)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_BOSS_BATTLE}), GlobalScene.SceneType.BATTLE)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_SHOP}), GlobalScene.SceneType.SHOP)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_EVENT}), GlobalScene.SceneType.EVENT)

func test_normal_battle_has_no_score_target():
	run_manager.current_route_index = 0
	var config = run_manager.get_current_battle_config()
	assert_false(config.has_score_target)
	assert_eq(config.target_score, run_manager.NO_SCORE_TARGET)
	assert_true(run_manager.is_current_battle_score_success(0))

func test_boss_battle_requires_score_target():
	run_manager.current_route_index = 6
	var config = run_manager.get_current_battle_config()
	assert_true(config.is_boss)
	assert_true(config.has_score_target)
	assert_eq(config.target_score, 50)
	assert_false(run_manager.is_current_battle_score_success(49))
	assert_true(run_manager.is_current_battle_score_success(50))

func test_boss_target_scales_by_act():
	run_manager.current_route_index = 6
	run_manager.current_act = 3
	assert_eq(run_manager.get_current_battle_target_score(), 90)
