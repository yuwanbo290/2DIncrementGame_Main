# weapon_base.gd
class_name WeaponBase
extends Resource

## ---------- 基础信息 ----------
## 武器的显示名称，会出现在UI中
@export var weapon_name: String = "未命名武器"
## 武器在背包、快捷栏或战斗界面中显示的小图标
@export var icon: Texture2D
## 武器的文字描述，用于展示给玩家（如：“一把沉重的石锤”）
@export var description: String = ""

## ---------- 战斗属性 ----------
## 基础伤害值，最终会根据命中距离产生衰减
@export var base_damage: float = 10.0
## 爆炸/范围效果的作用半径（单位：像素）
@export var explosion_radius: float = 50.0
## 两次攻击之间的冷却时间（单位：秒）
@export var cooldown: float = 1.0
## 投掷物飞行的速度（单位：像素/秒），越大飞得越快
@export var throw_speed: float = 800.0
## 垂直弧线高度：0为完全直线，数值越大飞行过程中拱起越高（抛物线）
@export var arc_height: float = 100.0
## 侧向弯曲幅度：正数会向右偏转，负数向左偏转，0为不偏转
@export var lateral_curve: float = 0.0

## ---------- 元素属性 ----------
## 武器的元素类型（影响伤害类型和附加效果）
@export var element: EffectHelper.Element = EffectHelper.Element.PHYSICAL

## 武器的签名特技类型，决定命中后的特殊行为（如弹射、分裂等）
@export var signature: EffectHelper.SignatureType = EffectHelper.SignatureType.NONE

## ---------- 特技参数 ----------
## 弹射特技的弹射次数（仅当 signature 为 RICOCHET 时生效）
@export var ricochet_count: int = 3
## 连锁特技的最大连锁目标数（仅当 signature 为 CHAIN 时生效）
@export var chain_targets: int = 5
## 分裂特技分裂出的子弹数量（仅当 signature 为 SPLIT 时生效）
@export var split_count: int = 5
## 持续区域特技的持续时间（秒）（仅当 signature 为 PERSISTENT 时生效）
@export var persistent_duration: float = 3.0

## ---------- 特效资源 ----------
## 飞行中的投掷物场景（必须包含 Projectile.gd 脚本）
@export var projectile_scene: PackedScene
## 命中时的爆炸/碰撞特效场景
@export var impact_effect: PackedScene
## 持续区域特效场景（如毒雾、火墙），仅用于 PERSISTENT 类型
@export var persistent_area_scene: PackedScene
## 命中时播放的音效
@export var hit_sound: AudioStream

## ---------- 核心攻击方法 ----------
## attacker：攻击者（通常是玩家节点），target_position：目标位置（世界坐标）
func perform_attack(attacker: Node2D, target_position: Vector2) -> void:
	# 1. 生成投掷物
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		projectile.weapon_data = self
		projectile.attacker = attacker
		projectile.target_position = target_position
		projectile.global_position = attacker.global_position
		# 投掷物会自己飞向目标，到达后触发范围效果
		attacker.get_tree().current_scene.add_child(projectile)

func trigger_area_effect(attacker: Node2D, center: Vector2, world: Node2D) -> void:
	# 直接调用静态方法，把自身（weapon）传进去供读取数据
	EffectHelper.apply_effect(element, attacker, center, world, self)
