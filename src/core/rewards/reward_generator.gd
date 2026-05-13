class_name RewardGenerator
extends RefCounted

const TYPE_SHARDS := "shards"
const TYPE_ITEM := "item"
const TYPE_ORNAMENT := "ornament"
const RouteConfig = preload("res://src/core/route/route_config.gd")
const RARITY_WEIGHT := {
	"普通": 1,
	"进阶": 2,
	"稀有": 3,
}

static func generate_options(run_manager: Node, item_db: Node, ornament_db: Node, count: int = 3) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if run_manager == null:
		return options
	var is_boss = run_manager.get_current_route_node_type() == RouteConfig.NODE_BOSS_BATTLE if run_manager.has_method("get_current_route_node_type") else false
	var act = max(1, int(run_manager.get("current_act")))

	var ornament = _pick_ornament(run_manager, ornament_db, act, is_boss)
	if not ornament.is_empty():
		options.append(ornament)

	var item = _pick_item(item_db, is_boss)
	if not item.is_empty() and options.size() < count:
		options.append(item)

	if options.size() < count:
		options.append(_make_shards_reward(act, is_boss))

	var backup_ornaments = _pick_additional_ornaments(run_manager, ornament_db, act, is_boss, count - options.size(), options)
	for reward in backup_ornaments:
		options.append(reward)

	while options.size() < count:
		var shards = _make_shards_reward(act, is_boss)
		shards["amount"] = int(shards["amount"]) + options.size() * 2
		shards["title"] = "%d 碎片" % int(shards["amount"])
		options.append(shards)

	return options.slice(0, count)

static func _pick_item(item_db: Node, prefer_high_value: bool) -> Dictionary:
	if item_db == null or not item_db.has_method("get_all_items"):
		return {}
	var items = item_db.get_all_items()
	items = items.filter(func(item): return item != null and item.can_draw)
	items.sort_custom(func(a, b): return int(a.price) > int(b.price) if prefer_high_value else int(a.price) < int(b.price))
	if items.is_empty():
		return {}
	var item = items[0]
	return {
		"type": TYPE_ITEM,
		"id": item.id,
		"title": item.item_name,
		"description": "加入卡组",
		"rarity": "",
		"amount": 1,
	}

static func _pick_ornament(run_manager: Node, ornament_db: Node, act: int, prefer_high_value: bool) -> Dictionary:
	var rewards = _pick_additional_ornaments(run_manager, ornament_db, act, prefer_high_value, 1, [])
	return rewards[0] if not rewards.is_empty() else {}

static func _pick_additional_ornaments(run_manager: Node, ornament_db: Node, act: int, prefer_high_value: bool, count: int, existing: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if count <= 0 or ornament_db == null or not ornament_db.has_method("get_available_ornaments"):
		return result
	var owned: Array[String] = []
	if run_manager != null:
		for ornament_id in Array(run_manager.get("current_ornaments")):
			owned.append(str(ornament_id))
	var available = ornament_db.get_available_ornaments(act, owned)
	var existing_ids: Array[String] = []
	for reward in existing:
		if reward.get("type", "") == TYPE_ORNAMENT:
			existing_ids.append(str(reward.get("id", "")))
	available = available.filter(func(ornament): return not existing_ids.has(ornament.id))
	available.sort_custom(func(a, b): return _compare_ornaments(a, b, prefer_high_value))
	for ornament in available:
		result.append(_make_ornament_reward(ornament))
		if result.size() >= count:
			break
	return result

static func _compare_ornaments(a, b, prefer_high_value: bool) -> bool:
	var rarity_a = int(RARITY_WEIGHT.get(a.rarity, 0))
	var rarity_b = int(RARITY_WEIGHT.get(b.rarity, 0))
	if rarity_a != rarity_b:
		return rarity_a > rarity_b if prefer_high_value else rarity_a < rarity_b
	if int(a.price) != int(b.price):
		return int(a.price) > int(b.price) if prefer_high_value else int(a.price) < int(b.price)
	return a.id < b.id

static func _make_ornament_reward(ornament) -> Dictionary:
	return {
		"type": TYPE_ORNAMENT,
		"id": ornament.id,
		"title": ornament.ornament_name,
		"description": ornament.effect_text,
		"rarity": ornament.rarity,
		"amount": 1,
	}

static func _make_shards_reward(act: int, is_boss: bool) -> Dictionary:
	var amount = 12 + act * 4 if is_boss else 6 + act * 2
	return {
		"type": TYPE_SHARDS,
		"id": "shards",
		"title": "%d 碎片" % amount,
		"description": "立即获得长期货币",
		"rarity": "",
		"amount": amount,
	}
