extends Node

## 物品数据库：负责加载和管理所有物品资源 (Autoload)

var items: Dictionary = {} # key: id (String), value: ItemData
var drawable_items: Array[ItemData] = []

func _ready():
	load_all_items()

## 扫描 res://data/items/ 目录加载所有 .tres 资源
func load_all_items():
	items.clear()
	drawable_items.clear()
	
	var path = "res://data/items/"
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
		
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# 核心修复：处理导出后的 .remap 扩展名
				var clean_name = file_name.trim_suffix(".remap")
				if clean_name.ends_with(".tres") or clean_name.ends_with(".res"):
					var full_path = path + clean_name
					var item = load(full_path)
					if item is ItemData:
						# 如果 ID 为空，使用文件名作为 ID
						if item.id == "":
							item.id = clean_name.get_basename()
						items[item.id] = item
						if item.can_draw:
							drawable_items.append(item)
						print("[ItemDatabase] 已加载物品: ", item.item_name, " (ID: ", item.id, ")")
			file_name = dir.get_next()
	
	print("[ItemDatabase] 总计加载物品: ", items.size(), ", 可抽取的物品: ", drawable_items.size())

## 获取所有已加载物品的列表 (用于调试 UI)
func get_all_items() -> Array[ItemData]:
	var list: Array[ItemData] = []
	for key in items:
		list.append(items[key])
	return list

## 获取随机一个可抽取的物品
func get_random_item() -> ItemData:
	if drawable_items.is_empty():
		push_error("[ItemDatabase] 错误: 没有可抽取的物品！")
		return null
	
	var index = randi() % drawable_items.size()
	# 返回副本，防止修改原始资源
	return drawable_items[index].duplicate(true)

## 根据 ID 获取物品数据
func get_item_by_id(item_id: String) -> ItemData:
	if items.has(item_id):
		return items[item_id].duplicate(true)
	return null
