extends Node
## 存档单例（Autoload）。单机存档，只存局外数据，局内 Buff 等临时状态不落盘。
## 存档位置：user://save.json

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const SLOT_COUNT := 3

## 当前存档数据（金币 / 技能等级 / 统计 / 设置）
var data: Dictionary = {}
var current_slot: int = -1  # -1 表示未选择存档


func _ready() -> void:
	load_save()


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"settings": _default_settings(),
		"slots": [
			_empty_slot(),
			_empty_slot(),
			_empty_slot(),
		],
	}


func _default_settings() -> Dictionary:
	return {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"resolution": "1280x720",
		"window_mode": "windowed",  # windowed / fullscreen
		"lang": "zh_CN",
	}


func _empty_slot() -> Dictionary:
	return {
		"id": 0,
		"name": "",
		"created_at": 0,
		"last_played": 0,
		"playtime": 0.0,
		"gold": 0,
		"skill_levels": {},
		"owned_weapons": [],
		"equipped_weapon": 0,
		"stats": {"rounds": 0, "best_kills": 0},
	}


## 从磁盘加载存档；文件不存在或损坏时使用默认值
func load_save() -> void:
	data = _default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		var parsed_dict: Dictionary = parsed
		data = parsed_dict
		# 确保 slots 数组完整
		var slots: Array = data.get("slots", [])
		while slots.size() < SLOT_COUNT:
			slots.append(_empty_slot())
		# 兼容旧存档：补全缺失字段
		for i in range(slots.size()):
			var slot: Dictionary = slots[i]
			if not slot.has("skill_levels"):
				slot["skill_levels"] = {}
			if not slot.has("owned_weapons"):
				slot["owned_weapons"] = []
			if not slot.has("equipped_weapon"):
				slot["equipped_weapon"] = 0
			slots[i] = slot
		data["slots"] = slots
		# 确保 settings 存在
		if not data.has("settings"):
			data["settings"] = _default_settings()


## 写入存档到磁盘
func save() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveSystem] 无法写入存档: " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## 清空并重置存档（重置后立即落盘）
func reset() -> void:
	data = _default_data()
	save()


# ---- 存档槽操作 ----
func get_slot(slot_index: int) -> Dictionary:
	var slots: Array = data.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	var slot: Dictionary = slots[slot_index]
	return slot.duplicate(true)


func set_slot(slot_index: int, slot_data: Dictionary) -> void:
	var slots: Array = data.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return
	slots[slot_index] = slot_data
	data["slots"] = slots


func is_slot_empty(slot_index: int) -> bool:
	var slot: Dictionary = get_slot(slot_index)
	if slot.is_empty():
		return true
	return slot.get("name", "") == "" or slot.get("created_at", 0) == 0


func create_slot(slot_index: int, slot_name: String) -> void:
	var slot: Dictionary = _empty_slot()
	slot["id"] = slot_index
	slot["name"] = slot_name
	slot["created_at"] = Time.get_unix_time_from_system()
	slot["last_played"] = Time.get_unix_time_from_system()
	set_slot(slot_index, slot)
	save()


func delete_slot(slot_index: int) -> void:
	set_slot(slot_index, _empty_slot())
	if current_slot == slot_index:
		current_slot = -1
	save()


func select_slot(slot_index: int) -> bool:
	if is_slot_empty(slot_index):
		return false
	current_slot = slot_index
	var slot: Dictionary = get_slot(slot_index)
	slot["last_played"] = Time.get_unix_time_from_system()
	set_slot(slot_index, slot)
	save()
	return true


func get_playtime_text(seconds: float) -> String:
	var h: int = int(seconds / 3600.0)
	var m: int = int(int(seconds) % 3600 / 60.0)
	var s: int = int(seconds) % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]


func get_last_played_text(timestamp: int) -> String:
	if timestamp == 0:
		return "从未游玩"
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%d-%02d-%02d %02d:%02d" % [
		t.get("year", 0),
		t.get("month", 0),
		t.get("day", 0),
		t.get("hour", 0),
		t.get("minute", 0),
	]


# ---- 当前存档便捷访问 ----
func get_current_slot() -> Dictionary:
	if current_slot < 0:
		return {}
	return get_slot(current_slot)


func update_current_slot(field: String, value) -> void:
	if current_slot < 0:
		return
	var slot: Dictionary = get_slot(current_slot)
	slot[field] = value
	set_slot(current_slot, slot)


# ---- 设置 ----
func get_setting(key: String, default = null):
	var s: Dictionary = data.get("settings", {})
	return s.get(key, default)


func set_setting(key: String, value) -> void:
	if not data.has("settings"):
		data["settings"] = _default_settings()
	var s: Dictionary = data["settings"]
	s[key] = value
	save()


# ---- 金币（当前存档）----
func get_gold() -> int:
	if current_slot < 0:
		return 0
	var slot: Dictionary = get_slot(current_slot)
	return int(slot.get("gold", 0))


func set_gold(value: int) -> void:
	if current_slot < 0:
		return
	update_current_slot("gold", value)


func add_gold(value: int) -> int:
	if current_slot < 0:
		return 0
	var slot: Dictionary = get_slot(current_slot)
	slot["gold"] = int(slot.get("gold", 0)) + value
	set_slot(current_slot, slot)
	return int(slot["gold"])


# ---- 技能等级（当前存档，局外养成）----
func get_skill_level(skill_id: int) -> int:
	if current_slot < 0:
		return 0
	var slot: Dictionary = get_slot(current_slot)
	var m: Dictionary = slot.get("skill_levels", {})
	return int(m.get(str(skill_id), 0))


func set_skill_level(skill_id: int, level: int) -> void:
	if current_slot < 0:
		return
	var slot: Dictionary = get_slot(current_slot)
	if not slot.has("skill_levels"):
		slot["skill_levels"] = {}
	var m: Dictionary = slot["skill_levels"]
	m[str(skill_id)] = level
	set_slot(current_slot, slot)


# ---- 武器（当前存档，局外永久）----
## 已购买武器 id 列表（不含表内 isDefault 的默认武器；判断是否可用请走 WeaponService.is_owned）
func get_owned_weapons() -> Array:
	if current_slot < 0:
		return []
	var slot: Dictionary = get_slot(current_slot)
	var owned: Array = slot.get("owned_weapons", [])
	return owned


## 记录一把已购买的武器（不落盘，调用方负责 save）
func add_owned_weapon(weapon_id: int) -> void:
	if current_slot < 0:
		return
	var slot: Dictionary = get_slot(current_slot)
	var owned: Array = slot.get("owned_weapons", [])
	for v in owned:
		if int(v) == weapon_id:
			return
	owned.append(weapon_id)
	slot["owned_weapons"] = owned
	set_slot(current_slot, slot)


## 当前装备的武器 id（0 表示存档未记录；取实际生效武器请走 WeaponService.get_equipped_id）
func get_equipped_weapon() -> int:
	if current_slot < 0:
		return 0
	var slot: Dictionary = get_slot(current_slot)
	return int(slot.get("equipped_weapon", 0))


## 设置当前装备的武器（不落盘，调用方负责 save）
func set_equipped_weapon(weapon_id: int) -> void:
	if current_slot < 0:
		return
	update_current_slot("equipped_weapon", weapon_id)


# ---- 统计（当前存档）----
func get_stat(key: String) -> int:
	if current_slot < 0:
		return 0
	var slot: Dictionary = get_slot(current_slot)
	var s: Dictionary = slot.get("stats", {})
	return int(s.get(key, 0))


func set_stat(key: String, value: int) -> void:
	if current_slot < 0:
		return
	var slot: Dictionary = get_slot(current_slot)
	if not slot.has("stats"):
		slot["stats"] = {}
	var s: Dictionary = slot["stats"]
	s[key] = value
	set_slot(current_slot, slot)
