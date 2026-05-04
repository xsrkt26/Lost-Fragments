class_name ItemData
extends Resource

## 物品数据资源类 (Model)
## 定义物品的静态属性、形状以及携带的效果

enum Direction { UP, DOWN, LEFT, RIGHT }
enum TransmissionMode { NORMAL, OMNI, NONE }

@export var id: String
@export var item_name: String
@export var tags: Array[String] = [] # 类别词条，如 ["运动", "神秘", "书籍"]
@export var price: int = 5 # 物品价值
@export var base_cost: int = -1 # 基础消耗 San 值 (如果为负，则使用公式计算)
@export var can_draw: bool = true # 是否可以被抽到
@export var runtime_id: int = -1 # 运行时唯一 ID，用于逻辑与 UI 绑定
@export var icon: Texture2D
@export var shape: Array[Vector2i] = [Vector2i(0, 0)] # 占用的格子相对偏移
@export var direction: Direction = Direction.RIGHT
@export var transmission_mode: TransmissionMode = TransmissionMode.NORMAL
@export var hit_filter_tags: Array[String] = [] # 仅能撞击包含这些标签的物品 (为空则撞击所有)
@export var effects: Array[ItemEffect] = [] # 物品携带的效果列表
