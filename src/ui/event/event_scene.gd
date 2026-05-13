extends Control

const RouteConfig = preload("res://src/core/route/route_config.gd")

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label = $MarginContainer/VBoxContainer/DescLabel
@onready var continue_button = $MarginContainer/VBoxContainer/ContinueButton

func _ready():
	GlobalInput.set_context(GlobalInput.Context.UI)
	GlobalAudio.play_bgm("hub")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		var node = rm.get_current_route_node()
		title_label.text = node.get("label", "事件")
		desc_label.text = "事件系统尚未实装。本节点用于验证局外路线推进。"
	continue_button.pressed.connect(_on_continue_pressed)

func _input(event):
	if not GlobalInput.can_cancel():
		return
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_continue_pressed()

func _on_continue_pressed():
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.get_current_route_node_type() == RouteConfig.NODE_EVENT:
		rm.advance_route_node()
	var next_scene = GlobalScene.SceneType.MAIN_MENU if rm and rm.is_run_complete else GlobalScene.SceneType.HUB
	GlobalScene.transition_to(next_scene, false)
