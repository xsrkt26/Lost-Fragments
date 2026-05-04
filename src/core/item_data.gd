class_name ItemData
extends Resource

enum Direction { UP, DOWN, LEFT, RIGHT }
enum ImpactType { ON_PLACEMENT, ON_IMPACT, PASSIVE }

@export_group("Basic Info")
@export var id: String = ""
@export var item_name: String = "Unnamed Item"
@export var sell_value: int = 0

@export_group("Grid Properties")
## 物品占据的相对坐标集合。
## 默认 [Vector2i(0, 0)] 表示占据 1x1 的格子。
@export var shape: Array[Vector2i] = [Vector2i(0, 0)]
@export var direction: Direction = Direction.LEFT

@export_group("Effect Properties")
@export var impact_type: ImpactType = ImpactType.ON_IMPACT
## 物品的效果列表（可以包含多个效果，如同时加分和回血）
@export var effects: Array[ItemEffect] = []
