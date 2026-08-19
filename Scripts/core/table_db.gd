class_name TableDB
extends RefCounted
## 运行时表查询接口。
## 表资源加载自 res://Resources/Tables/<表名>.tres，惰性缓存。
## 由于表可能含重复 Id，查询接口返回「全部匹配行」，而非唯一行。


const TABLES_DIR := "res://Resources/Tables"

static var _cache: Dictionary = {}


## 获取整张表（按表名惰性加载并缓存）
static func get_table(table_name: String) -> TableResource:
	if _cache.has(table_name):
		return _cache[table_name]
	var path: String = TABLES_DIR.path_join(table_name + ".tres")
	if not ResourceLoader.exists(path):
		push_error("[TableDB] 表不存在: %s" % path)
		return null
	var res: Resource = load(path)
	if res is TableResource:
		_cache[table_name] = res
		return res
	push_error("[TableDB] 资源类型错误: %s" % path)
	return null


## 返回整张表的所有行（数组）
static func rows_of(table_name: String) -> Array[Dictionary]:
	var t: TableResource = get_table(table_name)
	if t == null:
		return []
	return t.rows


## 按「字段 == 值」返回全部匹配行（重复 Id 全部保留）
static func get_all(table_name: String, field: String, value) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in rows_of(table_name):
		if row.has(field) and row[field] == value:
			out.append(row)
	return out


## 按「字段 == 值」返回第一条匹配行；无匹配时返回空字典
static func get_first(table_name: String, field: String, value) -> Dictionary:
	var all: Array[Dictionary] = get_all(table_name, field, value)
	if all.is_empty():
		return {}
	return all[0]


## 清空缓存（一般用于编辑器里重新导表后刷新）
static func clear_cache() -> void:
	_cache.clear()