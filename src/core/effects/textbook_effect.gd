class_name TextbookEffect
extends ItemEffect

## 英语课本效果：被撞 +5分，如果被“书籍”类物品撞击，改为 +15分

@export var normal_score: int = 5
@export var book_bonus_score: int = 15

func on_hit(_instance, _source, _resolver, _context) -> GameAction:
	var final_score = normal_score
	
	# 检查撞击来源是否包含 "书籍" 标签
	if _source and _source.data.tags.has("书籍"):
		final_score = book_bonus_score
		print("[Effect] 课本联动！受到书籍撞击，加分翻倍: ", final_score)
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "阅读课本")
	action.value = {"type": "score", "amount": final_score}
	return action
