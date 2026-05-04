# Lost Fragments - 技术设计文档 (Gameplay)

本文档旨在记录核心玩法系统的技术实现逻辑，作为后续代码编写的指导大纲。

## 1. 核心架构设计

遵循 Godot 的 **Data-Driven (数据驱动)** 与 **Signal-Based (信号驱动)** 原则，将逻辑分为三个核心层次。

### 1.1 数据层 (Model / Resource)
使用 `Resource` 类存储静态数据，方便美术和策划直接在编辑器配置。

- **`ItemData.gd` (src/core/item_data.gd)**:
    - `id`: String (物品唯一标识)
    - `item_name`: String
    - `shape`: Array[Vector2i] (占用格子的相对坐标，如 `[(0,0), (1,0)]` 表示横向两格)
    - `direction`: Enum (UP, DOWN, LEFT, RIGHT)
    - `impact_type`: Enum (触发条件：被撞击触发、入场触发等)
    - `effect_script`: Script / Reference (记录该物品具体逻辑的脚本)

### 1.2 逻辑层 (Logic / Manager)
负责处理网格运算、碰撞算法和回合流程。

- **`BackpackManager.gd` (src/core/backpack_mgr.gd)**:
    - `grid`: Dictionary[Vector2i, ItemInstance] (存储网格坐标与物品实例的映射)
    - `size`: Vector2i (背包尺寸)
    - `check_fit(item, pos)`: 检查物品是否能放下。
    - `place_item(item, pos)`: 更新字典。
- **`ImpactResolver.gd`**:
    - **撞击算法核心**：
        1. 接收起始坐标 `start_pos` 和撞击方向 `dir`。
        2. 沿方向进行步进，查询 `BackpackManager` 中的 `grid`。
        3. 若击中物品，将该物品加入 `ImpactList`。
        4. 检查该物品是否具有“穿透”或“二次传播”属性，若是，则继续传播。
        5. 递归或循环执行，直到撞击链结束。
        6. 依次触发 `ImpactList` 中所有物品的 `on_impact()` 效果。

### 1.3 表现层 (View / Controller)
负责 UI 渲染、拖拽交互和动画。

- **`MainGameUI.tscn`**: 根场景。
- **`BackpackGrid.tscn`**: 使用 `TextureRect` 绘制背景，动态生成格子线。
- **`ItemUI.tscn`**: 物品的可视化对象。
    - 负责播放“被撞击”时的抖动动画、粒子效果。
    - 处理鼠标拖拽交互。

## 2. 核心游戏循环 (Game Loop)

1. **Wait_Input**: 等待玩家点击“抽卡”。
2. **Draw_Stage**: 
    - 扣除 San 值。
    - 随机从池中实例化一个 `ItemData`。
    - 播放抽取动画。
3. **Placing_Stage**:
    - 玩家将物品拖入背包。
    - 物品“入场”触发器启动。
4. **Resolution_Stage (重点)**:
    - 执行 `ImpactResolver` 算法。
    - 物品效果结算（加分、加San、属性变更）。
    - 更新 UI 数值显示。
5. **Check_End**: 如果 San <= 0，进入结算，否则返回 Step 1。

## 3. 扩展性设计

- **Buff 系统**: 角色身上或背包格子可能带有 Buff，影响物品效果结算。
- **物品方向修改**: 某些物品的效果可能是“被撞击时，使周围物品旋转 90 度”，这需要 `ImpactResolver` 支持动态改变网格状态。
