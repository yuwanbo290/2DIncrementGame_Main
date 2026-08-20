class_name WeaponService
extends RefCounted
## 武器域服务（核心层）：把 weapons 表与存档拼成运行时可用的武器状态，供商店 / 武器界面 / 未来战斗层共用。
##
## 「是否拥有」= 表内 isDefault=1 的默认武器 ∪ 存档 owned_weapons（已购买）。
## 默认武器由表决定、不写入存档，因此改表即生效，也不需要存档迁移。
##
## 依赖：同为核心层的 TableDB 与 SaveSystem（单例），无反向依赖，不构成环。


## 表名与字段名（字段名以用户原表为准，禁止擅自改名）
const TABLE_NAME := "weapons"
const FIELD_ID := "weaponId"
const FIELD_NAME := "weaponName"
const FIELD_DESC := "desc"
const FIELD_ATK := "atk"
const FIELD_ATK_SPEED := "atkSpeed"
const FIELD_IS_DEFAULT := "isDefault"
const FIELD_TEXTURE := "texture"

## isDefault 取该值代表开局默认拥有
const IS_DEFAULT_YES := 1


## 全部武器行（按表内顺序）
static func get_all() -> Array[Dictionary]:
	return TableDB.rows_of(TABLE_NAME)


## 按武器 id 取表行（无匹配返回空字典，调用方必须判空）
static func get_by_id(weapon_id: int) -> Dictionary:
	return TableDB.get_first(TABLE_NAME, FIELD_ID, weapon_id)


## 表内标记为开局默认拥有的武器 id 列表
static func get_default_ids() -> Array[int]:
	var out: Array[int] = []
	for row in get_all():
		if int(row.get(FIELD_IS_DEFAULT, 0)) == IS_DEFAULT_YES:
			out.append(int(row.get(FIELD_ID, 0)))
	return out


## 是否为表内默认武器
static func is_default(weapon_id: int) -> bool:
	var row: Dictionary = get_by_id(weapon_id)
	if row.is_empty():
		return false
	return int(row.get(FIELD_IS_DEFAULT, 0)) == IS_DEFAULT_YES


## 是否已拥有（默认武器 + 存档内已购买的武器）
static func is_owned(weapon_id: int) -> bool:
	if weapon_id <= 0:
		return false
	if is_default(weapon_id):
		return true
	for v in SaveSystem.get_owned_weapons():
		if int(v) == weapon_id:
			return true
	return false


## 实际生效的装备武器 id（存档值缺失或已失效时回退到第一把默认武器；都没有返回 0）
static func get_equipped_id() -> int:
	var equipped: int = SaveSystem.get_equipped_weapon()
	if equipped > 0 and is_owned(equipped):
		return equipped
	var defaults: Array[int] = get_default_ids()
	if not defaults.is_empty():
		return defaults[0]
	return 0


## 装备一把武器；未拥有则拒绝并返回 false。**不落盘**，调用方负责 SaveSystem.save()
static func equip(weapon_id: int) -> bool:
	if not is_owned(weapon_id):
		return false
	SaveSystem.set_equipped_weapon(weapon_id)
	return true


## 授予一把武器（商店购买成功后调用）。**不落盘**，调用方负责 SaveSystem.save()
static func grant(weapon_id: int) -> void:
	if weapon_id <= 0:
		return
	SaveSystem.add_owned_weapon(weapon_id)


## 当前装备武器的表行（供未来战斗层读取属性；无有效武器返回空字典）
static func get_equipped_stats() -> Dictionary:
	var weapon_id: int = get_equipped_id()
	if weapon_id <= 0:
		return {}
	return get_by_id(weapon_id)


## 每秒理论伤害（atk × atkSpeed），用于界面横向比较武器强度
static func get_dps(row: Dictionary) -> float:
	return float(row.get(FIELD_ATK, 0.0)) * float(row.get(FIELD_ATK_SPEED, 0.0))
