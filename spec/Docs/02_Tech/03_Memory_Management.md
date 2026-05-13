# 内存与生命周期管理规范

本文档定义 Godot 项目中的对象生命周期约定，目标是避免测试和运行时出现 orphan node、资源残留和共享可变状态污染。

## 一、核心原则

1. 创建者必须明确对象归属。
   - `Node` 必须挂到父节点、交给 GUT 的 `autofree` / `autoqfree`，或在同一逻辑路径中显式释放。
   - 不允许长期保留裸 `Node.new()` 且没有释放责任。

2. 运行时 `Node` 优先交给场景树管理。
   - UI、音频播放器、战斗管理器、序列播放器等对象应挂到明确父节点。
   - 临时节点完成工作后使用 `queue_free()`。

3. `RefCounted` 不手动释放。
   - `GameAction`、`GameContext`、`ImpactResolver` 等引用计数对象由引用生命周期控制。
   - 避免 `RefCounted` 之间形成循环引用。

4. `Resource` 不承载共享运行时可变状态。
   - `ItemData` 等静态资源从数据库取出后，如果要进入战斗实例，必须 `duplicate(true)`。
   - 背包中的物品实例状态必须隔离，不能直接修改数据库源资源。

## 二、测试代码规范

1. GUT 测试中的 `Node` 创建规则：
   - 普通节点：使用 `autofree(Node.new())`。
   - 需要进入场景树的节点：使用 `add_child_autofree(node)`。
   - 会被业务逻辑 `queue_free()` 的节点：使用 `autoqfree(node)`，并根据需要 `add_child(node)`。

2. `queue_free()` 后必须等待释放帧。
   - 如果测试断言涉及释放结果，应至少等待一个 `process_frame`。
   - 如果对象可能在多个路径中排队释放，建议等待两个 `process_frame`。

3. 常规测试禁止使用动态 `GDScript.new()` 作为 mock。
   - 动态脚本不是稳定资源文件，GUT 在 orphan 格式化时可能无法正确解析。
   - mock 应放在 `test/support/` 下作为固定脚本，例如 `test/support/mock_item_ui.gd`。

4. 非 GUT 工具脚本不能放在 `test/` 树下并使用 `test_` 前缀。
   - GUT 会尝试收集这类文件，导致无效测试警告。
   - 工具脚本应放在仓库级 `tools/` 下，文件名不使用 `test_` 前缀。

5. 新增涉及释放逻辑的测试应加 `assert_no_new_orphans()`。
   - 丢弃、移除、弹窗、临时 UI、临时战斗对象等测试尤其需要覆盖。

## 三、运行时代码规范

1. 动态 UI 节点：
   - 创建后立即加入明确父节点。
   - 被关闭、刷新或替换时使用 `queue_free()`。
   - 清空容器时遍历子节点并 `queue_free()`。

2. 临时流程节点：
   - 类似 `SequencePlayer` 这类对象应在流程结束后 `queue_free()`。
   - 如果流程可能提前中断，应确保中断路径也释放。

3. Autoload 中的长期节点：
   - 初始化时创建的子节点必须挂到 Autoload 本身。
   - 不要在成员变量默认值里直接 `Node.new()` 创建子节点；应在 `_ready()` 中创建并 `add_child()`。
   - `_exit_tree()` 中应停止音频、断开长期资源引用或清空缓存。

4. 数据库缓存：
   - 数据库可以持有静态资源缓存。
   - 对外返回运行时可修改对象时必须返回深拷贝。

## 四、当前清理记录

- `test_discard_logic.gd` 已移除动态 `GDScript.new()` mock。
- 新增 `test/support/mock_item_ui.gd` 作为固定 mock UI。
- `test_discard_logic.gd` 的 mock UI 已统一由 GUT 管理，并对丢弃释放路径增加 orphan 断言。
- 非 GUT 工具脚本 `test_instance_ui.gd` 已移动为 `tools/godot/check_instance_ui.gd`，避免被 GUT 收集。
- 根目录工具脚本已归档到 `tools/audio/`、`tools/ui/` 和 `tools/run_tests_silent.ps1`；手工调试场景已归档到 `src/debug/manual/`，避免混在核心逻辑目录中。
- `GlobalAudio` 在 headless 测试环境下不创建音频播放器，避免 BGM 淡入淡出流程在测试退出期残留 `AudioStreamPlaybackWAV` 资源。
- `test_hub_player.gd` 中的 `CharacterBody2D` mock 已改为挂树管理，避免物理对象裸实例造成退出期资源警告。
- `BackpackManager._exit_tree()` 已统一清空运行时 `grid`，释放物品实例与其深拷贝资源引用。
- `RunManager` 的 `SaveManager` 子节点已改为 `_ready()` 中创建并挂树，避免纯逻辑测试路径产生裸节点。
- `test_rotation_logic.gd` 在脚本结束后等待短生命周期 Tween / 音频资源释放，避免测试进程退出阶段误报资源残留。
- `BackpackManager.replace_item_data()` 已统一保留原物品 `runtime_id` 并广播替换事件，避免物品变身/进化后 UI 映射持有失效资源身份。
