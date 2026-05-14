class_name WeightedRandom
extends RefCounted

static func pick_index(candidates: Array, rng: RandomNumberGenerator = null, weight_key: String = "weight") -> int:
	if candidates.is_empty():
		return -1
	if rng == null:
		return _pick_highest_weight_index(candidates, weight_key)

	var total_weight := 0.0
	for candidate in candidates:
		if candidate is Dictionary:
			total_weight += max(0.0, float(candidate.get(weight_key, 0.0)))

	if total_weight <= 0.0:
		return rng.randi_range(0, candidates.size() - 1)

	var roll := rng.randf() * total_weight
	var cursor := 0.0
	for index in candidates.size():
		var candidate = candidates[index]
		if not (candidate is Dictionary):
			continue
		cursor += max(0.0, float(candidate.get(weight_key, 0.0)))
		if roll <= cursor:
			return index
	return candidates.size() - 1

static func pick(candidates: Array, rng: RandomNumberGenerator = null, weight_key: String = "weight") -> Dictionary:
	var index := pick_index(candidates, rng, weight_key)
	if index < 0:
		return {}
	var candidate = candidates[index]
	return candidate if candidate is Dictionary else {}

static func _pick_highest_weight_index(candidates: Array, weight_key: String) -> int:
	var best_index := 0
	var best_weight := -1.0e20
	for index in candidates.size():
		var candidate = candidates[index]
		var weight := 0.0
		if candidate is Dictionary:
			weight = float(candidate.get(weight_key, 0.0))
		if weight > best_weight:
			best_weight = weight
			best_index = index
	return best_index
