class_name ShopGenerator
extends RefCounted

const TYPE_ITEM := "item"
const TYPE_ORNAMENT := "ornament"

static func generate_offers(run_manager: Node, item_db: Node, ornament_db: Node, count: int = 4) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var act = max(1, int(run_manager.get("current_act"))) if run_manager != null else 1

	var items = _get_item_offers(item_db, count)
	var ornaments = _get_ornament_offers(run_manager, ornament_db, act, count)

	var item_index = 0
	var ornament_index = 0
	while offers.size() < count and (item_index < items.size() or ornament_index < ornaments.size()):
		if item_index < items.size():
			offers.append(items[item_index])
			item_index += 1
			if offers.size() >= count:
				break
		if ornament_index < ornaments.size():
			offers.append(ornaments[ornament_index])
			ornament_index += 1

	return offers

static func _get_item_offers(item_db: Node, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if item_db == null or not item_db.has_method("get_all_items"):
		return result
	var items = item_db.get_all_items()
	items = items.filter(func(item): return item != null and item.can_draw)
	items.sort_custom(func(a, b):
		if int(a.price) == int(b.price):
			return a.id < b.id
		return int(a.price) < int(b.price)
	)
	for item in items:
		result.append({
			"type": TYPE_ITEM,
			"id": item.id,
			"title": item.item_name,
			"description": item.description,
			"price": max(1, abs(int(item.price))),
		})
		if result.size() >= count:
			break
	return result

static func _get_ornament_offers(run_manager: Node, ornament_db: Node, act: int, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if ornament_db == null or not ornament_db.has_method("get_available_ornaments"):
		return result
	var owned: Array[String] = []
	if run_manager != null:
		for ornament_id in Array(run_manager.get("current_ornaments")):
			owned.append(str(ornament_id))
	var ornaments = ornament_db.get_available_ornaments(act, owned)
	ornaments.sort_custom(func(a, b):
		if int(a.price) == int(b.price):
			return a.id < b.id
		return int(a.price) < int(b.price)
	)
	for ornament in ornaments:
		result.append({
			"type": TYPE_ORNAMENT,
			"id": ornament.id,
			"title": ornament.ornament_name,
			"description": ornament.effect_text,
			"rarity": ornament.rarity,
			"price": max(1, int(ornament.price)),
		})
		if result.size() >= count:
			break
	return result
