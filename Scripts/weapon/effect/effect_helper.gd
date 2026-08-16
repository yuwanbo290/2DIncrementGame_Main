class_name EffectHelper
extends RefCounted

## ---------- 签名特技枚举 (核心差异化) ----------
enum Element {
	PHYSICAL,  ## 物理（默认）
	FIRE,      ## 火
	ELECTRIC,  ## 电
	EARTH,     ## 石
	ICE,       ## 冰
	POISON,    ## 毒
	STAR       ## 星
}

enum SignatureType {
	NONE,        ## 普通爆炸
	RICOCHET,    ## 弹射 (弩)
	CHAIN,       ## 连锁闪电 (电)
	SPLIT,       ## 分裂 (星)
	SHOCKWAVE,   ## 震波 (石)
	PERSISTENT,  ## 持续区域 (火/毒/冰)
	PIERCING     ## 穿透 (弩进阶)
}

## 获取圆形范围内的所有敌人
static func _get_enemies_in_radius(world: Node2D, center: Vector2, radius: float) -> Array:
	var result = []
	var all_enemies = world.get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(center) <= radius:
			result.append(enemy)
	return result

## 核心方法：根据武器元素类型，执行对应的效果
static func apply_effect(element: Element,attacker: Node2D,center: Vector2,world: Node2D,weapon: WeaponBase) -> void:
	var enemies = _get_enemies_in_radius(world, center, weapon.explosion_radius)
	match element:
		Element.PHYSICAL:
			print("方法")
			pass
		Element.FIRE:
			pass
		Element.ELECTRIC:
			pass
		Element.EARTH:
			_apply_earth_effect(enemies, attacker, center, weapon)
			pass
		Element.POISON:
			pass
		Element.STAR:
			pass



## ---------- 以下是各个元素的具体实现 ----------
## 🪨 石头效果：伤害 + 击退
static func _apply_earth_effect(enemies: Array, attacker: Node2D, center: Vector2, weapon: WeaponBase) -> void:
	print("🪨 石头碎裂！击退效果！")
	for enemy in enemies:
		# 1. 计算伤害（带距离衰减）
		var dist = enemy.global_position.distance_to(center)
		var falloff = 1.0 - (dist / weapon.explosion_radius) * 0.3
		var damage = weapon.base_damage * falloff
		
		# 2. 造成伤害
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, weapon.element, attacker)
		
		# 3. 石头专属：击退效果
		if enemy.has_method("knockback"):
			var direction = (enemy.global_position - center).normalized()
			enemy.knockback(direction * 500.0)  # 500是击退力度
