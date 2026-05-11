extends "res://addons/gut/test.gd"

## 专门针对 Tooltip 系统崩溃 Bug 的集成测试
## 验证 ItemInstance 在 Tooltip 中的属性访问正确性

func test_tooltip_with_real_item_instance():
	# 1. 模拟环境
	var item_db = get_node_or_null("/root/ItemDatabase")
	assert_not_null(item_db, "ItemDatabase should exist")
	
	var item_data = item_db.get_item_by_id("apple")
	assert_not_null(item_data, "Apple data should exist")
	
	# 2. 创建真实的 ItemInstance (而不是 Dictionary)
	var instance = BackpackManager.ItemInstance.new(item_data, Vector2i(0, 0))
	instance.current_pollution = 5
	
	# 3. 触发 GlobalTooltip 调用 (模拟鼠标移入)
	# 如果代码中有错误（如调用了不存在的 get() 方法），此处会直接导致引擎报错/测试中断
	GlobalTooltip.show_item(item_data, instance)
	
	# 等待 Tooltip 延迟显示 (0.2s)
	await wait_seconds(0.3)
	
	# 4. 验证 Tooltip 节点是否成功显示且没有崩溃
	var tooltip_node = get_tree().get_first_node_in_group("card_tooltip")
	if tooltip_node == null:
		# 尝试从 GlobalTooltip 内部寻找
		tooltip_node = GlobalTooltip._tooltip_instance
		
	assert_not_null(tooltip_node, "Tooltip node should exist")
	assert_true(tooltip_node.is_panel_visible(), "Tooltip should be visible now")
	
	# 5. 验证内容
	var status_label = tooltip_node.get_node("PanelContainer/MarginContainer/VBoxContainer/StatusLabel")
	assert_true(status_label.visible, "Status label should be visible for polluted items")
	assert_string_contains(status_label.text, "5", "Status label should show pollution count")
	
	# 清理
	GlobalTooltip.hide()
	await wait_seconds(0.2)
