class_name ItemData
extends Resource

## 物品数据资源类 (Model)
## 定义物品的静态属性、形状以及携带的效果

enum Direction { UP, DOWN, LEFT, RIGHT }

@export var id: String
@export var item_name: String
var runtime_id: int = -1 # 运行时唯一 ID，用于逻辑与 UI 绑定
@export var icon: Texture2D
@export var shape: Array[Vector2i] = [Vector2i(0, 0)] # 占用的格子相对偏移
@export var direction: Direction = Direction.RIGHT
@export var effects: Array[ItemEffect] = [] # 物品携带的效果列表
