class_name RouteConfig
extends RefCounted

const DEFAULT_ROUTE_ID := "default"
const MAX_ACT := 6

const NODE_BATTLE := "battle"
const NODE_BOSS_BATTLE := "boss_battle"
const NODE_SHOP := "shop"
const NODE_EVENT := "event"

const ROUTES := {
	DEFAULT_ROUTE_ID: [
		{"id": "battle_1", "type": NODE_BATTLE, "label": "局内游戏"},
		{"id": "shop_1", "type": NODE_SHOP, "label": "商店"},
		{"id": "event_1", "type": NODE_EVENT, "label": "事件"},
		{"id": "battle_2", "type": NODE_BATTLE, "label": "局内游戏"},
		{"id": "shop_2", "type": NODE_SHOP, "label": "商店"},
		{"id": "event_2", "type": NODE_EVENT, "label": "事件"},
		{"id": "boss_1", "type": NODE_BOSS_BATTLE, "label": "Boss局内游戏"},
		{"id": "shop_3", "type": NODE_SHOP, "label": "商店"},
		{"id": "event_3", "type": NODE_EVENT, "label": "事件"},
	]
}

static func normalize_route_id(route_id: String) -> String:
	if ROUTES.has(route_id):
		return route_id
	return DEFAULT_ROUTE_ID

static func get_route_nodes(route_id: String = DEFAULT_ROUTE_ID) -> Array:
	var normalized_id = normalize_route_id(route_id)
	return ROUTES[normalized_id].duplicate(true)

static func get_route_node(route_id: String, index: int) -> Dictionary:
	var nodes = get_route_nodes(route_id)
	if index < 0 or index >= nodes.size():
		return {}
	return nodes[index].duplicate(true)

static func get_route_size(route_id: String = DEFAULT_ROUTE_ID) -> int:
	return get_route_nodes(route_id).size()

static func is_battle_node_type(node_type: String) -> bool:
	return node_type == NODE_BATTLE or node_type == NODE_BOSS_BATTLE
