class_name EconomyConfig
extends RefCounted

const MIN_ACT := 1
const MAX_ACT := 6

const NORMAL_BATTLE_SHARDS_BASE := 8
const NORMAL_BATTLE_SHARDS_PER_ACT := 2
const BOSS_BATTLE_SHARDS_BASE := 18
const BOSS_BATTLE_SHARDS_PER_ACT := 4

const SHOP_REFRESH_BASE_COST := 5
const SHOP_REFRESH_ACT_STEP := 2
const SHOP_REFRESH_REPEAT_STEP := 3

const ITEM_PRICE_ACT_STEP_PERCENT := 7
const ORNAMENT_PRICE_ACT_STEP_PERCENT := 9
const ORNAMENT_ADVANCED_SURCHARGE_PERCENT := 8
const ORNAMENT_RARE_SURCHARGE_PERCENT := 15

const RARITY_COMMON := "普通"
const RARITY_ADVANCED := "进阶"
const RARITY_RARE := "稀有"


static func battle_reward_shards(act: int, is_boss: bool) -> int:
	var clamped_act = _clamp_act(act)
	if is_boss:
		return BOSS_BATTLE_SHARDS_BASE + (clamped_act - 1) * BOSS_BATTLE_SHARDS_PER_ACT
	return NORMAL_BATTLE_SHARDS_BASE + (clamped_act - 1) * NORMAL_BATTLE_SHARDS_PER_ACT


static func shop_refresh_cost(act: int, refresh_count: int) -> int:
	return max(1, SHOP_REFRESH_BASE_COST + _clamp_act(act) * SHOP_REFRESH_ACT_STEP + max(0, refresh_count) * SHOP_REFRESH_REPEAT_STEP)


static func shop_item_price(base_price: int, act: int) -> int:
	var sanitized_price = max(1, abs(base_price))
	return _apply_percent(sanitized_price, shop_item_price_multiplier_percent(act))


static func shop_ornament_price(base_price: int, rarity: String, act: int) -> int:
	var sanitized_price = max(1, base_price)
	return _apply_percent(sanitized_price, shop_ornament_price_multiplier_percent(rarity, act))


static func shop_item_price_multiplier_percent(act: int) -> int:
	return 100 + (_clamp_act(act) - 1) * ITEM_PRICE_ACT_STEP_PERCENT


static func shop_ornament_price_multiplier_percent(rarity: String, act: int) -> int:
	return 100 + (_clamp_act(act) - 1) * ORNAMENT_PRICE_ACT_STEP_PERCENT + _ornament_rarity_surcharge_percent(rarity)


static func act_economy_snapshot(act: int) -> Dictionary:
	var clamped_act = _clamp_act(act)
	var normal_shards = battle_reward_shards(clamped_act, false)
	var boss_shards = battle_reward_shards(clamped_act, true)
	return {
		"act": clamped_act,
		"normal_battle_shards": normal_shards,
		"boss_battle_shards": boss_shards,
		"route_battle_shards": normal_shards * 2 + boss_shards,
		"first_refresh_cost": shop_refresh_cost(clamped_act, 0),
		"item_price_multiplier_percent": shop_item_price_multiplier_percent(clamped_act),
		"common_ornament_price_multiplier_percent": shop_ornament_price_multiplier_percent(RARITY_COMMON, clamped_act),
		"advanced_ornament_price_multiplier_percent": shop_ornament_price_multiplier_percent(RARITY_ADVANCED, clamped_act),
		"rare_ornament_price_multiplier_percent": shop_ornament_price_multiplier_percent(RARITY_RARE, clamped_act),
	}


static func _clamp_act(act: int) -> int:
	return clamp(act, MIN_ACT, MAX_ACT)


static func _apply_percent(base_price: int, multiplier_percent: int) -> int:
	return max(1, roundi(float(base_price) * float(multiplier_percent) / 100.0))


static func _ornament_rarity_surcharge_percent(rarity: String) -> int:
	match rarity:
		RARITY_ADVANCED:
			return ORNAMENT_ADVANCED_SURCHARGE_PERCENT
		RARITY_RARE:
			return ORNAMENT_RARE_SURCHARGE_PERCENT
	return 0
