extends Node

## 运行管理器：单局游戏的数据源 (Source of Truth)
## 负责跨场景保存金钱、卡组、深度等核心数据。

const RouteConfig = preload("res://src/core/route/route_config.gd")
const RewardGenerator = preload("res://src/core/rewards/reward_generator.gd")
const ShopGenerator = preload("res://src/core/rewards/shop_generator.gd")

# --- 核心信号 ---
signal run_started
signal run_finished(victory: bool)
signal shards_changed(new_amount: int)
signal deck_changed(new_deck: Array)
signal route_changed(current_act: int, route_index: int, current_node: Dictionary)
signal ornaments_changed(current_ornaments: Array[String])
signal pending_items_changed(pending_items: Array[Dictionary])

# --- 配置项 ---
const INITIAL_SHARDS = 10
const INITIAL_DECK: Array[String] = [
	"paper_ball", "paper_ball", "paper_ball", "paper_ball", "paper_ball",
	"alarm_clock", "alarm_clock", "alarm_clock", "alarm_clock", "alarm_clock",
	"tin_can", "tin_can", "tin_can", "tin_can", "tin_can"
]
const NO_SCORE_TARGET := -1
const BACKPACK_GRID_WIDTH := 7
const BACKPACK_GRID_HEIGHT := 7
const INITIAL_BACKPACK_USABLE_WIDTH := 5
const INITIAL_BACKPACK_USABLE_HEIGHT := 5
const ROOT_DREAM_ID := "root_dream"
const ITEM_DEST_DECK := "deck"
const ITEM_DEST_BACKPACK := "backpack"
const ITEM_DEST_STAGING := "staging"
const INITIAL_BACKPACK_ITEMS: Array[Dictionary] = [
	{
		"id": ROOT_DREAM_ID,
		"x": 1,
		"y": 3,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": -1,
	},
]

# --- 状态数据 ---
var current_shards: int = INITIAL_SHARDS
var current_deck: Array[String] = INITIAL_DECK.duplicate()
var current_backpack_items: Array[Dictionary] = []
var pending_item_rewards: Array[Dictionary] = []
var next_pending_item_uid: int = 1
var current_ornaments: Array[String] = []
var backpack_usable_width: int = INITIAL_BACKPACK_USABLE_WIDTH
var backpack_usable_height: int = INITIAL_BACKPACK_USABLE_HEIGHT
var shop_purchase_state: Dictionary = {}
var event_node_state: Dictionary = {}
var seen_event_ids: Array[String] = []
var rng_seed: int = 0
var rng_state: int = 0
var current_depth: int = 1
var current_route_id: String = RouteConfig.DEFAULT_ROUTE_ID
var current_act: int = 1
var current_route_index: int = 0
var completed_route_nodes: Array[int] = []
var is_run_active: bool = false
var is_run_complete: bool = false

var saver: SaveManager = null
var _run_rng := RandomNumberGenerator.new()

func _ready():
	if saver == null:
		saver = SaveManager.new()
	add_child(saver)
	# 自动尝试恢复存档
	if saver.has_save():
		deserialize_run(saver.load_run())

## 开启新的一局
func start_new_run():
	print("[RunManager] 开启新的一局...")
	
	# 核心修复：重置全局战斗状态 (San值、分数等)
	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if gs:
		gs.reset_game()
	
	current_shards = INITIAL_SHARDS
	current_deck = INITIAL_DECK.duplicate()
	current_backpack_items = _get_initial_backpack_items()
	pending_item_rewards = []
	next_pending_item_uid = 1
	current_ornaments = []
	backpack_usable_width = INITIAL_BACKPACK_USABLE_WIDTH
	backpack_usable_height = INITIAL_BACKPACK_USABLE_HEIGHT
	shop_purchase_state.clear()
	event_node_state.clear()
	seen_event_ids = []
	_initialize_random_source()
	current_depth = 1
	reset_route_progress()
	is_run_active = true
	is_run_complete = false
	
	save_current_state()
	run_started.emit()
	_emit_route_changed()

## 胜利结算
func win_battle(reward_shards: int):
	current_shards += reward_shards
	current_depth += 1
	print("[RunManager] 战斗胜利! 获得碎片: ", reward_shards, " | 当前深度: ", current_depth)
	if RouteConfig.is_battle_node_type(get_current_route_node_type()):
		advance_route_node()
	shards_changed.emit(current_shards)
	save_current_state()

## 失败结算 (彻底重来)
func fail_run():
	print("[RunManager] 梦境惊醒... 运行结束。")
	is_run_active = false
	is_run_complete = false
	current_backpack_items.clear()
	if saver:
		saver.delete_save()
	run_finished.emit(false)

## 购买卡牌
func add_to_deck(item_id: String, cost: int):
	if current_shards >= cost:
		current_shards -= cost
		current_deck.append(item_id)
		print("[RunManager] 购买成功: ", item_id, " | 剩余碎片: ", current_shards)
		shards_changed.emit(current_shards)
		deck_changed.emit(current_deck)
		save_current_state()
		return true
	return false

func add_ornament(ornament_id: String) -> bool:
	if ornament_id == "" or current_ornaments.has(ornament_id):
		return false
	current_ornaments.append(ornament_id)
	ornaments_changed.emit(current_ornaments)
	save_current_state()
	return true

func has_ornament(ornament_id: String) -> bool:
	return current_ornaments.has(ornament_id)

func remove_ornament(ornament_id: String) -> bool:
	if not current_ornaments.has(ornament_id):
		return false
	current_ornaments.erase(ornament_id)
	ornaments_changed.emit(current_ornaments)
	save_current_state()
	return true

func generate_current_reward_options(item_db: Node, ornament_db: Node, count: int = 3) -> Array[Dictionary]:
	var options = RewardGenerator.generate_options(self, item_db, ornament_db, count, _get_random_source())
	_sync_random_state()
	save_current_state()
	return options

func apply_reward(reward: Dictionary, item_db: Node = null) -> bool:
	var reward_type = str(reward.get("type", ""))
	match reward_type:
		RewardGenerator.TYPE_SHARDS:
			var amount = max(0, int(reward.get("amount", 0)))
			current_shards += amount
			shards_changed.emit(current_shards)
		RewardGenerator.TYPE_ITEM:
			var item_id = str(reward.get("id", ""))
			var destination = _get_item_destination(reward, ITEM_DEST_DECK)
			if not grant_item(item_id, destination, item_db, "reward", false):
				return false
		RewardGenerator.TYPE_ORNAMENT:
			var ornament_id = str(reward.get("id", ""))
			if not add_ornament(ornament_id):
				return false
			return true
		_:
			return false
	save_current_state()
	return true

func generate_current_shop_offers(item_db: Node, ornament_db: Node, count: int = 4) -> Array[Dictionary]:
	var state = _get_current_shop_state()
	var cached = _to_dictionary_array(state.get("offers", []))
	if not cached.is_empty():
		return cached
	return _generate_and_cache_current_shop_offers(item_db, ornament_db, count, state)

func refresh_current_shop_offers(item_db: Node, ornament_db: Node, count: int = 4) -> Array[Dictionary]:
	var state = _get_current_shop_state()
	var cost = get_current_shop_refresh_cost()
	if current_shards < cost:
		return _to_dictionary_array(state.get("offers", []))
	current_shards -= cost
	shards_changed.emit(current_shards)
	state["refresh_count"] = int(state.get("refresh_count", 0)) + 1
	state.erase("offers")
	return _generate_and_cache_current_shop_offers(item_db, ornament_db, count, state)

func get_current_shop_refresh_cost() -> int:
	var state = _get_current_shop_state()
	return ShopGenerator.calculate_refresh_cost(current_act, int(state.get("refresh_count", 0)))

func buy_shop_offer(offer: Dictionary, item_db: Node = null) -> bool:
	var price = get_current_shop_offer_price(offer)
	if current_shards < price:
		return false

	var offer_type = str(offer.get("type", ""))
	match offer_type:
		ShopGenerator.TYPE_ITEM:
			var item_id = str(offer.get("id", ""))
			if item_id == "":
				return false
			current_shards -= price
			if not grant_item(item_id, _get_item_destination(offer, ITEM_DEST_DECK), item_db, "shop", false):
				current_shards += price
				return false
		ShopGenerator.TYPE_ORNAMENT:
			var ornament_id = str(offer.get("id", ""))
			if ornament_id == "" or current_ornaments.has(ornament_id):
				return false
			current_shards -= price
			current_ornaments.append(ornament_id)
			ornaments_changed.emit(current_ornaments)
		_:
			return false

	shards_changed.emit(current_shards)
	_record_shop_purchase(offer)
	save_current_state()
	return true

func grant_item(item_id: String, destination: String = ITEM_DEST_DECK, item_db: Node = null, source: String = "", save_after: bool = true) -> bool:
	if item_id == "":
		return false
	var normalized_destination = _normalize_item_destination(destination)
	match normalized_destination:
		ITEM_DEST_DECK:
			current_deck.append(item_id)
			deck_changed.emit(current_deck)
		ITEM_DEST_BACKPACK:
			if not _try_add_item_to_backpack_state(item_id, item_db):
				_add_pending_item_reward(item_id, source, ITEM_DEST_BACKPACK, false)
		ITEM_DEST_STAGING:
			_add_pending_item_reward(item_id, source, ITEM_DEST_STAGING, false)
		_:
			return false
	if save_after:
		save_current_state()
	return true

func get_pending_item_rewards() -> Array[Dictionary]:
	return pending_item_rewards.duplicate(true)

func consume_pending_item(uid: int, save_after: bool = true) -> bool:
	for index in pending_item_rewards.size():
		if int(pending_item_rewards[index].get("uid", -1)) == uid:
			pending_item_rewards.remove_at(index)
			pending_items_changed.emit(get_pending_item_rewards())
			if save_after:
				save_current_state()
			return true
	return false

func move_pending_item_to_deck(uid: int) -> bool:
	var entry = _get_pending_item(uid)
	if entry.is_empty():
		return false
	if not consume_pending_item(uid, false):
		return false
	current_deck.append(str(entry.get("id", "")))
	deck_changed.emit(current_deck)
	save_current_state()
	return true

func place_pending_item_in_backpack(uid: int, item_db: Node) -> bool:
	var entry = _get_pending_item(uid)
	if entry.is_empty():
		return false
	if not _try_add_item_to_backpack_state(str(entry.get("id", "")), item_db):
		return false
	return consume_pending_item(uid)

func _get_pending_item(uid: int) -> Dictionary:
	for entry in pending_item_rewards:
		if int(entry.get("uid", -1)) == uid:
			return entry.duplicate(true)
	return {}

func _add_pending_item_reward(item_id: String, source: String, preferred_destination: String, save_after: bool = true) -> Dictionary:
	var entry = {
		"uid": next_pending_item_uid,
		"id": item_id,
		"source": source,
		"preferred_destination": preferred_destination,
	}
	next_pending_item_uid += 1
	pending_item_rewards.append(entry)
	pending_items_changed.emit(get_pending_item_rewards())
	if save_after:
		save_current_state()
	return entry

func _try_add_item_to_backpack_state(item_id: String, item_db: Node) -> bool:
	if item_db == null or not item_db.has_method("get_item_by_id"):
		return false
	var item_data = item_db.get_item_by_id(item_id)
	if item_data == null:
		return false

	var backpack = BackpackManager.new()
	backpack.setup_grid(BACKPACK_GRID_WIDTH, BACKPACK_GRID_HEIGHT, backpack_usable_width, backpack_usable_height)
	restore_backpack_state(backpack, item_db)
	var target_pos = backpack.find_available_pos(item_data)
	if target_pos == Vector2i(-1, -1):
		backpack.free()
		return false
	if not backpack.place_item(item_data, target_pos):
		backpack.free()
		return false
	save_backpack_state(backpack)
	backpack.free()
	return true

func _get_item_destination(source_data: Dictionary, fallback: String) -> String:
	return _normalize_item_destination(str(source_data.get("item_destination", source_data.get("destination", fallback))))

func _normalize_item_destination(destination: String) -> String:
	match destination:
		ITEM_DEST_DECK, ITEM_DEST_BACKPACK, ITEM_DEST_STAGING:
			return destination
	return ITEM_DEST_DECK

func get_current_shop_offer_price(offer: Dictionary) -> int:
	var price = max(1, int(offer.get("price", 0)))
	if str(offer.get("type", "")) != ShopGenerator.TYPE_ITEM:
		return price
	if not current_ornaments.has("recycling_coupon"):
		return price
	var state = _get_current_shop_state()
	if bool(state.get("discount_next_item", false)):
		return max(1, floori(float(price) * 0.8))
	return price

func _record_shop_purchase(offer: Dictionary) -> void:
	var key = _get_current_shop_state_key()
	var state = _get_current_shop_state()
	var purchased_keys = _to_string_array(state.get("purchased_offer_keys", []))
	var offer_key = ShopGenerator.make_offer_key(offer)
	if offer_key != ":" and not purchased_keys.has(offer_key):
		purchased_keys.append(offer_key)
	state["purchased_offer_keys"] = purchased_keys
	if current_ornaments.has("recycling_coupon") and str(offer.get("type", "")) == ShopGenerator.TYPE_ITEM:
		if bool(state.get("discount_next_item", false)):
			state["discount_next_item"] = false
		elif not bool(state.get("first_item_purchase_done", false)):
			state["first_item_purchase_done"] = true
			state["discount_next_item"] = true
	shop_purchase_state[key] = state

func _get_current_shop_state() -> Dictionary:
	return Dictionary(shop_purchase_state.get(_get_current_shop_state_key(), {}))

func _get_current_shop_state_key() -> String:
	return "%d:%d" % [current_act, current_route_index]

func _generate_and_cache_current_shop_offers(item_db: Node, ornament_db: Node, count: int, state: Dictionary) -> Array[Dictionary]:
	var excluded_keys = _to_string_array(state.get("purchased_offer_keys", []))
	var offers = ShopGenerator.generate_offers(self, item_db, ornament_db, count, _get_random_source(), excluded_keys)
	_sync_random_state()
	state["offers"] = offers
	shop_purchase_state[_get_current_shop_state_key()] = state
	save_current_state()
	return offers

func pick_current_event(event_db: Node):
	if event_db == null or not event_db.has_method("pick_event_for_run"):
		return null
	var key = _get_current_node_state_key()
	var state = Dictionary(event_node_state.get(key, {}))
	var event_id = str(state.get("event_id", ""))
	if event_id != "" and event_db.has_method("get_event_by_id"):
		var cached_event = event_db.get_event_by_id(event_id)
		if cached_event != null:
			return cached_event
	var event_data = event_db.pick_event_for_run(self, _get_random_source())
	_sync_random_state()
	if event_data != null:
		state["event_id"] = event_data.id
		event_node_state[key] = state
	save_current_state()
	return event_data

func _get_current_node_state_key() -> String:
	return "%d:%d" % [current_act, current_route_index]

func apply_event_choice(choice: Dictionary) -> bool:
	var cost_shards = max(0, int(choice.get("cost_shards", 0)))
	if current_shards < cost_shards:
		return false

	var effects = _to_dictionary_array(choice.get("effects", []))
	if effects.is_empty():
		return false

	var snapshot = {
		"shards": current_shards,
		"deck": current_deck.duplicate(),
		"backpack_items": current_backpack_items.duplicate(true),
		"pending_item_rewards": pending_item_rewards.duplicate(true),
		"next_pending_item_uid": next_pending_item_uid,
		"ornaments": current_ornaments.duplicate(),
		"backpack_width": backpack_usable_width,
		"backpack_height": backpack_usable_height,
	}

	current_shards -= cost_shards
	if cost_shards > 0:
		shards_changed.emit(current_shards)

	for effect in effects:
		if not _apply_event_effect(effect):
			_restore_event_snapshot(snapshot)
			return false

	var event_id = str(choice.get("event_id", choice.get("_event_id", "")))
	if event_id != "" and not seen_event_ids.has(event_id):
		seen_event_ids.append(event_id)
	save_current_state()
	return true

func get_backpack_grid_config() -> Dictionary:
	return {
		"grid_width": BACKPACK_GRID_WIDTH,
		"grid_height": BACKPACK_GRID_HEIGHT,
		"usable_width": clampi(backpack_usable_width, 1, BACKPACK_GRID_WIDTH),
		"usable_height": clampi(backpack_usable_height, 1, BACKPACK_GRID_HEIGHT),
	}

func _apply_event_effect(effect: Dictionary) -> bool:
	var effect_type = str(effect.get("type", ""))
	match effect_type:
		RewardGenerator.TYPE_SHARDS, RewardGenerator.TYPE_ITEM, RewardGenerator.TYPE_ORNAMENT:
			var item_db = get_node_or_null("/root/ItemDatabase") if is_inside_tree() else null
			return apply_reward(effect, item_db)
		"sanity":
			var amount = int(effect.get("amount", 0))
			if amount == 0:
				return false
			var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
			if gs == null or not gs.has_method("heal_sanity"):
				return false
			gs.heal_sanity(amount)
			return true
		"backpack_space":
			var width_delta = int(effect.get("width_delta", 0))
			var height_delta = int(effect.get("height_delta", 0))
			var next_width = clampi(backpack_usable_width + width_delta, INITIAL_BACKPACK_USABLE_WIDTH, BACKPACK_GRID_WIDTH)
			var next_height = clampi(backpack_usable_height + height_delta, INITIAL_BACKPACK_USABLE_HEIGHT, BACKPACK_GRID_HEIGHT)
			if next_width == backpack_usable_width and next_height == backpack_usable_height:
				return false
			backpack_usable_width = next_width
			backpack_usable_height = next_height
			return true
	return false

func _restore_event_snapshot(snapshot: Dictionary) -> void:
	current_shards = int(snapshot.get("shards", current_shards))
	current_deck = _to_string_array(snapshot.get("deck", current_deck))
	current_backpack_items = _to_dictionary_array(snapshot.get("backpack_items", current_backpack_items))
	pending_item_rewards = _to_dictionary_array(snapshot.get("pending_item_rewards", pending_item_rewards))
	next_pending_item_uid = int(snapshot.get("next_pending_item_uid", next_pending_item_uid))
	current_ornaments = _to_string_array(snapshot.get("ornaments", current_ornaments))
	backpack_usable_width = int(snapshot.get("backpack_width", backpack_usable_width))
	backpack_usable_height = int(snapshot.get("backpack_height", backpack_usable_height))
	shards_changed.emit(current_shards)
	deck_changed.emit(current_deck)
	ornaments_changed.emit(current_ornaments)
	pending_items_changed.emit(get_pending_item_rewards())
	save_current_state()

func save_backpack_state(backpack: BackpackManager) -> void:
	current_backpack_items.clear()
	if backpack == null:
		return
	for instance in backpack.get_all_instances():
		if _is_derived_item(instance):
			continue
		current_backpack_items.append(_serialize_backpack_instance(instance))
	save_current_state()

func restore_backpack_state(backpack: BackpackManager, item_db: Node) -> void:
	if backpack == null:
		return
	backpack.grid.clear()
	if item_db == null:
		return
	for entry in current_backpack_items:
		var item_id = str(entry.get("id", ""))
		var item_data = item_db.get_item_by_id(item_id) if item_db.has_method("get_item_by_id") else null
		if item_data == null:
			continue
		var runtime_data: ItemData = item_data.duplicate(true)
		runtime_data.runtime_id = int(entry.get("runtime_id", randi()))
		runtime_data.direction = int(entry.get("direction", runtime_data.direction))
		runtime_data.shape = _deserialize_shape(Array(entry.get("shape", [])), runtime_data.shape)
		var root_pos = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		backpack.place_item(runtime_data, root_pos)
	_ensure_required_backpack_items(backpack, item_db)

func _serialize_backpack_instance(instance: BackpackManager.ItemInstance) -> Dictionary:
	return {
		"id": instance.data.id,
		"x": instance.root_pos.x,
		"y": instance.root_pos.y,
		"direction": int(instance.data.direction),
		"shape": _serialize_shape(instance.data.shape),
		"runtime_id": instance.data.runtime_id
	}

func _serialize_shape(shape: Array[Vector2i]) -> Array:
	var result = []
	for cell in shape:
		result.append({"x": cell.x, "y": cell.y})
	return result

func _deserialize_shape(value: Array, fallback: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in value:
		if cell is Dictionary:
			result.append(Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))))
	if result.is_empty():
		return fallback
	return result

func _get_initial_backpack_items() -> Array[Dictionary]:
	return _to_dictionary_array(INITIAL_BACKPACK_ITEMS).duplicate(true)

func _ensure_required_backpack_items(backpack: BackpackManager, item_db: Node) -> void:
	if _backpack_has_item(backpack, ROOT_DREAM_ID):
		return
	for entry in INITIAL_BACKPACK_ITEMS:
		if str(entry.get("id", "")) == ROOT_DREAM_ID:
			_place_required_backpack_item(backpack, item_db, entry)
			return

func _backpack_has_item(backpack: BackpackManager, item_id: String) -> bool:
	if backpack == null:
		return false
	for instance in backpack.get_all_instances():
		if instance != null and instance.data != null and instance.data.id == item_id:
			return true
	return false

func _place_required_backpack_item(backpack: BackpackManager, item_db: Node, entry: Dictionary) -> bool:
	var item_id = str(entry.get("id", ""))
	var item_data = item_db.get_item_by_id(item_id) if item_db != null and item_db.has_method("get_item_by_id") else null
	if item_data == null:
		return false

	item_data.direction = int(entry.get("direction", item_data.direction))
	item_data.shape = _deserialize_shape(Array(entry.get("shape", [])), item_data.shape)

	var root_pos = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	if backpack.can_place_item(item_data, root_pos):
		return backpack.place_item(item_data, root_pos)

	var fallback_pos = backpack.find_available_pos(item_data)
	if fallback_pos != Vector2i(-1, -1):
		return backpack.place_item(item_data, fallback_pos)
	return false

func _is_derived_item(instance: BackpackManager.ItemInstance) -> bool:
	return instance != null and instance.data != null and instance.data.tags.has("衍生物品")

func reset_route_progress(route_id: String = RouteConfig.DEFAULT_ROUTE_ID):
	current_route_id = RouteConfig.normalize_route_id(route_id)
	current_act = 1
	current_route_index = 0
	completed_route_nodes = []
	is_run_complete = false
	_emit_route_changed()

func get_route_nodes() -> Array:
	return RouteConfig.get_route_nodes(current_route_id)

func get_current_route_node() -> Dictionary:
	return RouteConfig.get_route_node(current_route_id, current_route_index)

func get_current_route_node_type() -> String:
	return get_current_route_node().get("type", "")

func can_enter_route_node(index: int) -> bool:
	return is_run_active and index == current_route_index and not get_current_route_node().is_empty()

func get_scene_type_for_node(node: Dictionary) -> int:
	var scene_key = RouteConfig.get_scene_key_for_node(node)
	match scene_key:
		RouteConfig.SCENE_BATTLE:
			return GlobalScene.SceneType.BATTLE
		RouteConfig.SCENE_SHOP:
			return GlobalScene.SceneType.SHOP
		RouteConfig.SCENE_EVENT:
			return GlobalScene.SceneType.EVENT
		RouteConfig.SCENE_HUB:
			return GlobalScene.SceneType.HUB
	return GlobalScene.SceneType.HUB

func get_current_node_scene_type() -> int:
	return get_scene_type_for_node(get_current_route_node())

func get_current_battle_config() -> Dictionary:
	var node_type = get_current_route_node_type()
	var node = get_current_route_node()
	var score_rule = RouteConfig.get_score_target_rule(node, current_act)
	var has_target = bool(score_rule.get("enabled", false))
	return {
		"node_type": node_type,
		"is_boss": RouteConfig.is_boss_node_type(node_type),
		"has_score_target": has_target,
		"target_score": int(score_rule.get("target", NO_SCORE_TARGET)) if has_target else NO_SCORE_TARGET
	}

func current_battle_has_score_target() -> bool:
	return bool(get_current_battle_config().get("has_score_target", false))

func get_current_battle_target_score() -> int:
	return int(get_current_battle_config().get("target_score", NO_SCORE_TARGET))

func is_current_battle_score_success(score: int) -> bool:
	var config = get_current_battle_config()
	if not config.get("has_score_target", false):
		return true
	return score >= int(config.get("target_score", NO_SCORE_TARGET))

func _get_boss_target_score() -> int:
	var node = get_current_route_node()
	var score_rule = RouteConfig.get_score_target_rule(node, current_act)
	if bool(score_rule.get("enabled", false)):
		return int(score_rule.get("target", NO_SCORE_TARGET))
	return NO_SCORE_TARGET

func advance_route_node(expected_node_id: String = "") -> Dictionary:
	if not is_run_active:
		return {}
	var current_node = get_current_route_node()
	if current_node.is_empty():
		return {}
	if expected_node_id != "" and current_node.get("id", "") != expected_node_id:
		return {}
	if not completed_route_nodes.has(current_route_index):
		completed_route_nodes.append(current_route_index)
	current_route_index += 1

	if current_route_index >= RouteConfig.get_route_size(current_route_id):
		if current_act >= RouteConfig.get_max_act():
			_complete_run()
			_emit_route_changed()
			return current_node
		current_act += 1
		current_route_index = 0
		completed_route_nodes = []

	save_current_state()
	_emit_route_changed()
	return current_node

func _complete_run() -> void:
	print("[RunManager] 已完成全部 ", RouteConfig.get_max_act(), " 个场景，整局胜利。")
	is_run_active = false
	is_run_complete = true
	current_act = RouteConfig.get_max_act()
	current_route_index = max(0, RouteConfig.get_route_size(current_route_id) - 1)
	completed_route_nodes = []
	if saver:
		saver.delete_save()
	run_finished.emit(true)

func _emit_route_changed():
	route_changed.emit(current_act, current_route_index, get_current_route_node())

## 存档序列化
func save_current_state():
	if not is_run_active: return
	if saver:
		saver.save_run(serialize_run())

func serialize_run() -> Dictionary:
	return {
		"shards": current_shards,
		"deck": current_deck,
		"backpack_items": current_backpack_items,
		"pending_item_rewards": pending_item_rewards,
		"next_pending_item_uid": next_pending_item_uid,
		"ornaments": current_ornaments,
		"backpack_usable_width": backpack_usable_width,
		"backpack_usable_height": backpack_usable_height,
		"shop_purchase_state": shop_purchase_state,
		"event_node_state": event_node_state,
		"seen_event_ids": seen_event_ids,
		"rng_seed": rng_seed,
		"rng_state": rng_state,
		"depth": current_depth,
		"route_id": current_route_id,
		"act": current_act,
		"route_index": current_route_index,
		"completed_route_nodes": completed_route_nodes,
		"is_active": is_run_active,
		"is_complete": is_run_complete
	}

func deserialize_run(data: Dictionary):
	if data.is_empty(): return
	current_shards = data.get("shards", INITIAL_SHARDS)
	current_deck = _to_string_array(data.get("deck", INITIAL_DECK))
	current_backpack_items = _to_dictionary_array(data.get("backpack_items", []))
	pending_item_rewards = _to_dictionary_array(data.get("pending_item_rewards", []))
	next_pending_item_uid = max(int(data.get("next_pending_item_uid", 1)), _get_next_pending_uid_from_entries())
	current_ornaments = _to_string_array(data.get("ornaments", []))
	backpack_usable_width = clampi(int(data.get("backpack_usable_width", INITIAL_BACKPACK_USABLE_WIDTH)), 1, BACKPACK_GRID_WIDTH)
	backpack_usable_height = clampi(int(data.get("backpack_usable_height", INITIAL_BACKPACK_USABLE_HEIGHT)), 1, BACKPACK_GRID_HEIGHT)
	shop_purchase_state = Dictionary(data.get("shop_purchase_state", {}))
	event_node_state = Dictionary(data.get("event_node_state", {}))
	seen_event_ids = _to_string_array(data.get("seen_event_ids", []))
	_restore_random_source(int(data.get("rng_seed", 0)), int(data.get("rng_state", 0)))
	current_depth = data.get("depth", 1)
	current_route_id = RouteConfig.normalize_route_id(data.get("route_id", RouteConfig.DEFAULT_ROUTE_ID))
	current_act = max(1, int(data.get("act", 1)))
	current_route_index = clampi(int(data.get("route_index", 0)), 0, max(0, RouteConfig.get_route_size(current_route_id) - 1))
	completed_route_nodes = []
	for index in Array(data.get("completed_route_nodes", [])):
		completed_route_nodes.append(int(index))
	is_run_active = data.get("is_active", true)
	is_run_complete = data.get("is_complete", false)
	pending_items_changed.emit(get_pending_item_rewards())
	_emit_route_changed()

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in Array(value):
		result.append(str(entry))
	return result

func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in Array(value):
		if entry is Dictionary:
			result.append(entry)
	return result

func _get_next_pending_uid_from_entries() -> int:
	var highest_uid := 0
	for entry in pending_item_rewards:
		highest_uid = max(highest_uid, int(entry.get("uid", 0)))
	return highest_uid + 1

func set_random_seed(seed_value: int) -> void:
	_initialize_random_source(seed_value)

func _initialize_random_source(seed_value: int = 0) -> void:
	rng_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	_run_rng.seed = rng_seed
	rng_state = _run_rng.state

func _restore_random_source(seed_value: int, state_value: int) -> void:
	if seed_value == 0:
		_initialize_random_source()
		return
	rng_seed = seed_value
	_run_rng.seed = rng_seed
	if state_value != 0:
		_run_rng.state = state_value
	rng_state = _run_rng.state

func _get_random_source() -> RandomNumberGenerator:
	if rng_seed == 0:
		_initialize_random_source()
	elif rng_state != 0:
		_run_rng.state = rng_state
	return _run_rng

func _sync_random_state() -> void:
	rng_state = _run_rng.state
## 获取当前战斗的目标分数。无分数目标时返回 NO_SCORE_TARGET。
func get_target_score() -> int:
	return get_current_battle_target_score()
