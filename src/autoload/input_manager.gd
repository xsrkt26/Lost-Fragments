extends Node

## 输入管理器：管理全局输入上下文 (Input Context)
## 解决“开启 UI 时还能移动角色”等交互冲突问题

signal context_changed(new_context: Context)

enum Context {
	MENU,      # 主菜单模式
	WORLD,     # 大世界探索：允许移动、允许按 E 触发交互
	BATTLE,    # 战斗状态：允许拖拽卡牌、允许旋转、允许点击抽卡
	UI,        # 纯 UI 模式：如整备室开启背包浮窗、商店、图鉴，禁止角色移动
	LOCKED     # 全锁定：用于转场动画、剧情、结算界面
}

var current_context: Context = Context.WORLD:
	set(v):
		if current_context == v: return
		current_context = v
		print("[InputManager] 上下文切换至: ", Context.keys()[v])
		context_changed.emit(v)

## 检查是否处于特定上下文
func is_context(context: Context) -> bool:
	return current_context == context

## 检查当前是否允许角色移动
func can_move() -> bool:
	return current_context == Context.WORLD

## 检查当前是否允许点击/拖拽卡牌
func can_interact_with_cards() -> bool:
	return current_context == Context.BATTLE or current_context == Context.UI

## 检查当前是否允许 ESC 返回/取消
func can_cancel() -> bool:
	return current_context != Context.LOCKED

## 强制设置模式
func set_context(context: Context):
	current_context = context
