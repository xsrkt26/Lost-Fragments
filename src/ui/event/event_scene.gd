extends Control

const RouteConfig = preload("res://src/core/route/route_config.gd")

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label = $MarginContainer/VBoxContainer/DescLabel
@onready var choice_container = $MarginContainer/VBoxContainer/ChoiceContainer
@onready var continue_button = $MarginContainer/VBoxContainer/ContinueButton

var current_event = null
var choices_pending := false

func _ready():
	GlobalInput.set_context(GlobalInput.Context.UI)
	GlobalAudio.play_bgm("hub")
	continue_button.pressed.connect(_on_continue_pressed)
	_populate_event()

func _populate_event() -> void:
	var rm = get_node_or_null("/root/RunManager")
	var event_db = get_node_or_null("/root/EventDatabase")
	for child in choice_container.get_children():
		child.queue_free()

	if rm and event_db and event_db.has_method("pick_event_for_run"):
		current_event = event_db.pick_event_for_run(rm)
	if current_event != null:
		title_label.text = current_event.event_name
		desc_label.text = current_event.description
		choices_pending = not current_event.choices.is_empty()
		continue_button.visible = not choices_pending
		for choice in current_event.choices:
			_add_choice_button(choice)
	elif rm:
		var node = rm.get_current_route_node()
		title_label.text = node.get("label", "事件")
		desc_label.text = "当前没有可用事件。"
		choices_pending = false
		continue_button.visible = true

func _add_choice_button(choice: Dictionary) -> void:
	var btn = Button.new()
	btn.text = "%s\n%s" % [str(choice.get("title", "选择")), str(choice.get("description", ""))]
	btn.tooltip_text = str(choice.get("description", ""))
	btn.custom_minimum_size = Vector2(420, 72)
	btn.pressed.connect(func(): _on_choice_pressed(choice, btn))
	choice_container.add_child(btn)

func _input(event):
	if not GlobalInput.can_cancel():
		return
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if choices_pending:
			return
		_on_continue_pressed()

func _on_choice_pressed(choice: Dictionary, button: Button) -> void:
	if not choices_pending:
		return
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not rm.has_method("apply_event_choice"):
		return
	if not rm.apply_event_choice(choice):
		button.disabled = true
		button.text = str(choice.get("title", "选择")) + "\n条件不足"
		return
	choices_pending = false
	_on_continue_pressed()

func _on_continue_pressed():
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.get_current_route_node_type() == RouteConfig.NODE_EVENT:
		rm.advance_route_node()
	var next_scene = GlobalScene.SceneType.MAIN_MENU if rm and rm.is_run_complete else GlobalScene.SceneType.HUB
	GlobalScene.transition_to(next_scene, false)
