class_name EventData
extends Resource

@export var id: String = ""
@export var event_name: String = ""
@export_multiline var description: String = ""
@export var earliest_act: int = 1
@export var weight: float = 1.0
@export var risk: float = 0.0
@export var reward: float = 0.0
@export var tags: Array[String] = []
@export var choices: Array[Dictionary] = []
