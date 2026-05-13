# 开发计划与路线图 (Implementation Roadmap)

## 一、 当前开发目标：实装“污染流”机制

为了验证乘法底层逻辑，当前阶段的核心目标是实装污染机制的基建。

**实施步骤**：
1. **数据基建阶段**：
    * 在 `ItemInstance` 中新增 `pollution` 状态变量及增减方法。
    * 完善 `GlobalEventBus`，打通全局监听信号。
2. **核心结算升级**：
    * 重构 `ImpactResolver`，将污染的乘法逻辑 (1+N次结算) 与 San 值扣除逻辑嵌入到底层撞击管线中。
    * 引入全局修饰器系统（供“隔离箱”等饰品生效）。
3. **组件量产与测试**：
    * 优先实现三个核心验证件：“纸团”(自我叠层)、“漏水钢笔”(传染)、“垃圾袋”(净化)。
    * 建立独立测试场景验证乘法数值和扣血逻辑。
4. **周边系统补全**：
    * 实装垃圾桶丢弃 (`on_discard`) 逻辑。
    * 实装第三排固定的撞击源发射逻辑。

## 二、 长期技术重构目标 (Tech Debt)
*摘自早期评审记录，需在后续开发中持续推进。*

1. **逻辑与表现彻底解耦**: 彻底剥离 `BackpackUI` 中的残余逻辑计算，交由 `BattleManager` 处理。
2. **多格碰撞精确性**: 改进 `ImpactResolver`，使撞击逻辑支持复杂多格形状的具体“碰撞入口”与“出口”判定。
3. **资源实例的强制隔离**: 确保进入背包的 `ItemData` 及 `ItemEffect` 正确隔离，防止不同实例间共享可变状态。
4. **依赖注入 (DI)**: 全面采用 Context 传入模式，减少 `get_node("/root/...")` 的硬编码，方便单元测试。

## 三、 待开发功能 (Pending Features)

### 1. 全自动测试工作流 (Automated Testing Workflow)
*   **状态**: 已完成基础版本。
*   **目标**: 引入标准测试框架，支持逻辑的回归测试，保证重构与新增功能不破坏原有机制。
*   **加固标准 (Reinforced Standards)**:
    *   **多场景覆盖**: 每张卡牌必须包含 2-3 个场景测试，包括：
        *   *边界场景*: 放在网格边缘、角落或触发数值临界点（如 San 值为 1）。
        *   *极端场景*: 极端高污染、San 值归零触发 Game Over、极长路径传导。
        *   *空载场景*: 在无目标、无污染或无效标签环境下的安全运行。
    *   **联动稳定性 (Synergy & Stability)**: 建立专门的联动测试集，模拟跨流派连招（如机械+书籍、污染+净化），验证单帧高频 Action 产出下的系统稳定性。
*   **方案**: 引入 **GUT (Godot Unit Test)** 框架，在 `test/` 目录下建立单元测试与集成测试。
*   **执行方式**: 支持编辑器内 GUI 面板一键执行，以及命令行 Headless 运行以接入 CI/CD。
*   **当前实现**:
    *   本地全量命令使用 Godot 4.6.2 headless 执行 `addons/gut/gut_cmdln.gd`。
    *   `.github/workflows/gut.yml` 已接入 GitHub Actions，在 `main` 分支 push 和 pull request 时自动下载 Godot 4.6.2 stable Linux 版并运行全量 GUT。
    *   工作流缓存 Godot 可执行文件，避免每次运行重复下载。

### 2. 鼠标悬浮显示卡牌信息 (Card Hover Tooltip)
*   **状态**: 已完成基础版本。
*   **目标**: 在游戏主界面实时查看卡牌效果及当前附加的动态状态（如污染层数）。
*   **数据层**: 在 `ItemData` 中新增 `@export_multiline var description: String` 效果描述字段。
*   **UI层**: 新建全局复用的 `CardTooltip.tscn` 悬浮窗组件。
*   **交互逻辑**: 在 `ItemUI` 中监听 `mouse_entered` 触发延迟（如 0.3 秒）显示，`mouse_exited` 隐藏，并能动态读取 `ItemInstance` 的状态进行渲染。
*   **当前实现**:
    *   `GlobalTooltip` 作为 Autoload 统一管理卡牌悬浮窗，负责延迟显示、关键词高亮、自动定位和空数据隐藏。
    *   `ItemUI` 在鼠标悬停时显示卡牌说明，拖拽时隐藏；绑定 `ItemInstance.pollution_changed` 后实时刷新污染角标和悬浮窗动态状态。
    *   商店物品商品复用同一套全局卡牌悬浮窗，饰品商品仍使用按钮 tooltip 展示饰品效果文本。
    *   `CardTooltip` 进入 `card_tooltip` 分组，便于测试和调试定位。
*   **自动化测试**: `test/unit/test_card_tooltip.gd` 覆盖污染 UI 同步、动态污染悬浮显示和空物品数据保护。
