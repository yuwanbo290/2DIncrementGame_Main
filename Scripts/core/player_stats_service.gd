class_name PlayerStatsService
extends RefCounted
## 玩家属性汇总服务（core 层）：把 base_config 基础值 + 当前武器 + 局外技能加成（skillLevel 已学等级）
## + 可选的局内 Buff 加成，汇总成统一的展示属性，供武器界面与暂停界面共用。
##
## 属性统一命名（对应「体力」等新描述）：
##   attack 攻击力 / attack_speed 攻击速度 / crit_rate 暴击 / crit_dmg 暴击伤害 /
##   stamina 体力 / bullet_split 子弹分裂 / burst_rounds 攻击轮数


## 计算有效暴击：暴击率超过 100% 时，每 1% 溢出暴击率转化为 1.5% 暴击伤害（隐藏机制，不展示）。
static func get_effective_crit(crit_rate: float, crit_dmg: float) -> Dictionary:
	var rate: float = crit_rate
	var dmg: float = crit_dmg
	if rate > 1.0:
		dmg += (rate - 1.0) * 1.5
		rate = 1.0
	return {"rate": rate, "dmg": dmg}


## 汇总属性。
## [param core_base] config 基础值字典（{base_attack / base_attack_speed / base_crit_rate / base_crit_dmg / round_time}）
## [param bonuses]   属性加成字典（attr key -> 累加值，来自 skillLevel 或 buffLevel）
## [param weapon]    武器行字典（atk / atkSpeed）
## [param split_override] 子弹分裂实际值（局内 battle_manager 提供；-1 时按 bonuses 计算）
## [param burst_override] 攻击轮数实际值（局内提供；-1 时按 bonuses 计算）
static func compute(
	core_base: Dictionary,
	bonuses: Dictionary,
	weapon: Dictionary,
	split_override: int = -1,
	burst_override: int = -1
) -> Dictionary:
	var attack: float = (
		float(core_base.get("base_attack", 0.0))
		+ float(weapon.get("atk", 0.0))
		+ float(bonuses.get("atk", 0.0))
		+ float(bonuses.get("base_attack", 0.0))
	)
	var attack_speed: float = (
		float(core_base.get("base_attack_speed", 1.0))
		+ float(bonuses.get("base_attack_speed", 0.0))
	) * float(weapon.get("atkSpeed", 1.0))
	var crit_rate: float = float(core_base.get("base_crit_rate", 0.05)) + float(bonuses.get("base_crit_rate", 0.0))
	var crit_dmg: float = float(core_base.get("base_crit_dmg", 1.5)) + float(bonuses.get("base_crit_dmg", 0.0))
	var stamina: float = float(core_base.get("round_time", 60.0)) + float(bonuses.get("round_time", 0.0))
	var bullet_split: int = split_override if split_override >= 0 else (1 + int(bonuses.get("bulletCount", 0.0)))
	var burst_rounds: int = burst_override if burst_override >= 0 else (1 + int(bonuses.get("burstCount", 0.0)))
	return {
		"attack": attack,
		"attack_speed": attack_speed,
		"crit_rate": crit_rate,
		"crit_dmg": crit_dmg,
		"stamina": stamina,
		"bullet_split": bullet_split,
		"burst_rounds": burst_rounds,
	}


## 汇总局外技能（skillLevel 已学等级）的属性加成字典。
static func get_skill_bonuses() -> Dictionary:
	var bonuses: Dictionary = {}
	for skill_row in TableDB.rows_of("Skill"):
		var skill_id: int = int(skill_row.get("Id", 0))
		var level: int = SaveSystem.get_skill_level(skill_id)
		if level <= 0:
			continue
		for lv_row in TableDB.get_all("skillLevel", "Id", skill_id):
			if int(lv_row.get("skillLevel", 0)) <= level:
				_accumulate_row(bonuses, lv_row)
	return bonuses


## 局外（Meta）属性面板：基础 + 当前武器 + 局外技能（不含局内 Buff）。
static func get_meta_stats() -> Dictionary:
	var cfg: BaseConfig = ConfigSystem.config
	var base := {
		"base_attack": cfg.base_attack,
		"base_attack_speed": cfg.base_attack_speed,
		"base_crit_rate": cfg.base_crit_rate,
		"base_crit_dmg": cfg.base_crit_dmg,
		"round_time": cfg.round_time,
	}
	return compute(base, get_skill_bonuses(), WeaponService.get_equipped_stats())


## 把属性字典格式化为多行展示文本（武器界面 / 暂停界面共用）。
## Buff 提供的加成以（）显示在对应数值后；stats["buff_bonus"] 缺省为空即局外属性面板。
static func format_stats(stats: Dictionary) -> String:
	var buff: Dictionary = stats.get("buff_bonus", {})
	var lines: Array[String] = []

	var atk_buff: float = float(buff.get("base_attack", 0.0)) + float(buff.get("atk", 0.0))
	lines.append("攻击力　：%s%s" % [_num(float(stats.get("attack", 0.0))), _buff_suffix(atk_buff, _num(atk_buff))])

	var spd_buff: float = float(buff.get("base_attack_speed", 0.0))
	lines.append("攻击速度：%.2f 次/秒%s" % [float(stats.get("attack_speed", 0.0)), _buff_suffix(spd_buff, "%.2f" % spd_buff)])

	var crit_buff: float = float(buff.get("base_crit_rate", 0.0))
	lines.append("暴击　　：%d%%%s" % [roundi(float(stats.get("crit_rate", 0.0)) * 100.0), _buff_suffix(crit_buff, "%d%%" % roundi(crit_buff * 100.0))])

	var cdmg_buff: float = float(buff.get("base_crit_dmg", 0.0))
	lines.append("暴击伤害：%d%%%s" % [roundi(float(stats.get("crit_dmg", 0.0)) * 100.0), _buff_suffix(cdmg_buff, "%d%%" % roundi(cdmg_buff * 100.0))])

	var stam_buff: float = float(buff.get("round_time", 0.0))
	lines.append("体力　　：%s 秒%s" % [_num(float(stats.get("stamina", 0.0))), _buff_suffix(stam_buff, "%.0f" % stam_buff)])

	var split_buff: float = float(buff.get("bulletCount", 0.0))
	lines.append("子弹分裂：%d 发%s" % [int(stats.get("bullet_split", 1)), _buff_suffix(split_buff, "%d" % int(split_buff))])

	var burst_buff: float = float(buff.get("burstCount", 0.0))
	lines.append("攻击轮数：%d 轮%s" % [int(stats.get("burst_rounds", 1)), _buff_suffix(burst_buff, "%d" % int(burst_buff))])

	return "\n".join(lines)


## 数值显示：整数不带小数，否则保留 1 位。
static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## Buff 括号文本：无加成返回空串，否则返回 "（+x）"。
static func _buff_suffix(value: float, display: String) -> String:
	if value <= 0.0:
		return ""
	return "（+%s）" % display


## 把一行配置的 changeAttr/attrValue 累加到 bonuses 字典。
static func _accumulate_row(bonuses: Dictionary, row: Dictionary) -> void:
	for i in range(1, 5):
		var attr: String = str(row.get("changeAttr%d" % i, ""))
		var value: float = float(row.get("attrValue%d" % i, 0.0))
		if attr != "":
			bonuses[attr] = bonuses.get(attr, 0.0) + value
