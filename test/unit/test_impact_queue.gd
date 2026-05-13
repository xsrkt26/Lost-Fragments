extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

var manager: BattleManager
var item_db

func before_each():
	manager = add_child_autofree(BattleManagerScript.new())
	item_db = get_node_or_null("/root/ItemDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	await get_tree().process_frame
	manager.backpack_manager.grid.clear()
	manager.battle_state = BattleManager.BattleState.RESOLVING

func _place_paper(pos: Vector2i) -> BackpackManager.ItemInstance:
	var item = item_db.get_item_by_id("paper_ball")
	assert_true(manager.backpack_manager.place_item(item, pos))
	return manager.backpack_manager.grid[pos]

func _queued_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for queue_item in manager._impact_queue:
		positions.append(queue_item["pos"])
	return positions

func test_queue_orders_impacts_by_top_left_priority():
	var lower = _place_paper(Vector2i(3, 3))
	var first = _place_paper(Vector2i(1, 2))
	var second = _place_paper(Vector2i(2, 2))

	assert_true(manager.queue_impact_at(lower.root_pos, -1, lower, "test"))
	assert_true(manager.queue_impact_at(first.root_pos, -1, first, "test"))
	assert_true(manager.queue_impact_at(second.root_pos, -1, second, "test"))

	assert_eq(_queued_positions(), [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 3)])

func test_new_impacts_added_during_same_window_are_resorted_before_remaining_items():
	var first = _place_paper(Vector2i(2, 2))
	var last = _place_paper(Vector2i(5, 5))
	var inserted = _place_paper(Vector2i(1, 2))

	manager.queue_impact_at(first.root_pos, -1, first, "initial")
	manager.queue_impact_at(last.root_pos, -1, last, "initial")

	var dequeued = manager._dequeue_next_impact()
	assert_eq(dequeued["pos"], Vector2i(2, 2))

	manager.queue_impact_at(inserted.root_pos, -1, inserted, "during_resolution")

	assert_eq(manager._dequeue_next_impact()["pos"], Vector2i(1, 2))
	assert_eq(manager._dequeue_next_impact()["pos"], Vector2i(5, 5))

func test_queue_rejects_empty_or_stale_sources():
	assert_false(manager.queue_impact_at(Vector2i(1, 1), -1, null, "empty"))
	assert_true(manager._impact_queue.is_empty())

	var source = _place_paper(Vector2i(1, 1))
	manager.backpack_manager.remove_instance(source)

	assert_false(manager.queue_impact_at(source.root_pos, -1, source, "stale"))
	assert_true(manager._impact_queue.is_empty())

func test_trigger_impact_at_keeps_legacy_entry_but_queues_work():
	var source = _place_paper(Vector2i(1, 1))

	manager.trigger_impact_at(source.root_pos)

	assert_eq(manager._impact_queue.size(), 1)
	assert_eq(manager._impact_queue[0]["pos"], source.root_pos)
	assert_eq(manager._impact_queue[0]["reason"], "direct")
