extends Node

const EVENT_DATA_PATH := "res://data/events/events.json"
const EventDataScript = preload("res://src/core/events/event_data.gd")

var events: Dictionary = {}

func _ready() -> void:
	load_all_events()

func load_all_events() -> void:
	events.clear()
	if not FileAccess.file_exists(EVENT_DATA_PATH):
		push_error("[EventDatabase] Missing event table: " + EVENT_DATA_PATH)
		return

	var file = FileAccess.open(EVENT_DATA_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("[EventDatabase] Invalid event table JSON")
		return

	for entry in parsed:
		if not (entry is Dictionary):
			continue
		var event_data = _create_event_data(entry)
		if event_data.id != "":
			events[event_data.id] = event_data
	print("[EventDatabase] Loaded events: ", events.size())

func get_event_by_id(event_id: String):
	if events.has(event_id):
		return events[event_id].duplicate(true)
	return null

func get_all_events() -> Array:
	var result: Array = []
	for key in events:
		result.append(events[key].duplicate(true))
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func get_available_events(act: int) -> Array:
	var result: Array = []
	for event_data in events.values():
		if event_data.earliest_act <= act:
			result.append(event_data.duplicate(true))
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func pick_event_for_run(run_manager: Node):
	var act = 1
	var route_index = 0
	if run_manager != null:
		act = max(1, int(run_manager.get("current_act")))
		route_index = max(0, int(run_manager.get("current_route_index")))
	var available = get_available_events(act)
	if available.is_empty():
		return null
	return available[(act + route_index) % available.size()]

func _create_event_data(entry: Dictionary):
	var data = EventDataScript.new()
	data.id = str(entry.get("id", ""))
	data.event_name = str(entry.get("title", "事件"))
	data.description = str(entry.get("description", ""))
	data.earliest_act = int(entry.get("earliest_act", 1))
	data.choices = _to_dictionary_array(entry.get("choices", []))
	return data

func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in Array(value):
		if entry is Dictionary:
			result.append(entry)
	return result
