# 游戏场景切换逻辑架构图 (Scene Transition Architecture)

本文档描述了《GoDotGame》中不同游戏状态与场景之间的逻辑跳转关系，用于指导 UI 导航与玩家流程设计。

---

## 1. 核心流程图 (Flowchart)

```mermaid
graph TD
    %% 节点定义
    START((游戏启动))
    MENU[主菜单 MainMenu]
    HUB[整备室 HubScene]
    BATTLE[战斗场景 MainGameUI]
    GALLERY[物品图鉴 Gallery]
    SHOP[梦境商店 Shop]
    DEBUG[调试沙盒 DebugSandbox]
    
    %% 浮层节点
    BACKPACK_UI[[背包浮层 BackpackOverlay]]
    GAMEOVER{死亡结算}
    VICTORY{胜利结算}

    %% 流程关系
    START --> MENU
    
    MENU -- "开始新旅程 / 继续" --> HUB
    MENU -- "点击 图鉴" --> GALLERY
    MENU -- "F1 / 快捷进入" --> DEBUG
    
    HUB -- "进入梦境" --> BATTLE
    HUB -- "交互: 梦境商店" --> SHOP
    HUB -- "交互: 物品图鉴" --> GALLERY
    HUB -- "点击 整理背包" --> BACKPACK_UI
    HUB -- "ESC / 保存并退出" --> MENU
    
    BATTLE -- "梦值 <= 0" --> GAMEOVER
    BATTLE -- "Score >= Target" --> VICTORY
    BATTLE -- "ESC / 离开梦境" --> HUB
    
    GAMEOVER -- "清理存档" --> MENU
    VICTORY -- "发放奖励" --> HUB
    
    GALLERY -- "返回 / ESC" --> HUB
    GALLERY -- "返回 (无活跃Run时)" --> MENU
    SHOP -- "离开 / ESC" --> HUB
    DEBUG -- "ESC" --> MENU
    
    BACKPACK_UI -- "关闭 / ESC" --> HUB
```

---

## 2. 场景与浮层职责详解

### 2.1 主菜单 (Main Menu)
*   **功能**：存档检查、开启新梦境、继续旧梦境、进入全局图鉴。

### 2.2 整备室 (Hub Scene)
*   **核心功能**：战前整备、随机商店、物品图鉴、卡组管理。
*   **交互特点**：支持角色移动。通过 Overlay 模式实现无缝背包整理。

### 2.3 战斗场景 (Main Game UI)
*   **核心功能**：卡牌放置、连锁碰撞结算。
*   **逻辑转换**：胜利返回 Hub；失败退回主菜单。

### 2.4 辅助场景
*   **物品图鉴**：展示全物品数据。
*   **梦境商店**：消耗碎片购买新卡牌。
*   **调试沙盒**：开发者快速测试卡牌性能。

---

## 3. 状态持久化规则

1.  **局内进度**：当前深度、卡组。仅在当前 Run 进程中有效。
2.  **永久资产**：碎片总量、已解锁图鉴。永久保存。

---
*文档更新日期：2026年5月11日*
