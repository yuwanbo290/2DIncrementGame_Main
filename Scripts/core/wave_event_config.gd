class_name WaveEventConfig
extends Resource
## 波次事件配置：每个 waveEvents 事件对应一个 Resources/Events/wave_event_<id>.tres，
## 用于调整该事件的全部数值参数（不改代码即可配平）。

## 事件名（开场动画展示，实际展示名以 waveEvents 表为准）
@export var event_name: String = ""
## 效果持续时间（秒）；<=0 表示整个当前波次生效，直至体力耗尽或结算
@export var effect_time: float = 0.0

@export_group("雷暴天")
## 落雷最小 / 最大间隔（秒）
@export var thunder_interval_min: float = 4.0
@export var thunder_interval_max: float = 6.0
## 每次落雷数量范围
@export var thunder_count_min: int = 1
@export var thunder_count_max: int = 3
## Boss 被落雷命中扣除的血量比例（0.1 = 10%）
@export var thunder_boss_damage_ratio: float = 0.1

@export_group("火山爆发")
## 陨石最小 / 最大间隔（秒）
@export var meteor_interval_min: float = 2.0
@export var meteor_interval_max: float = 5.0
## 每次陨石数量范围
@export var meteor_count_min: int = 1
@export var meteor_count_max: int = 2
## 陨石直接伤害（命中敌人当前血量比例）
@export var meteor_damage_ratio: float = 0.5
## 点燃每秒伤害（当前血量比例）
@export var burn_damage_ratio: float = 0.1
## 点燃持续时间（秒；重复点燃刷新计时）
@export var burn_duration: float = 5.0
## 陨石命中半径（像素）
@export var meteor_radius: float = 70.0

@export_group("狂风瘟疫")
## 吹风最小 / 最大间隔（秒）
@export var plague_interval_min: float = 5.0
@export var plague_interval_max: float = 8.0
## 感染每秒伤害（当前血量比例）
@export var plague_damage_ratio: float = 0.1

@export_group("老虎机")
## 老虎机生成延迟（秒，开场动画结束后）
@export var slot_spawn_delay: float = 1.5
## 击破老虎机后出现精英敌人的概率（0~1）
@export var slot_elite_ratio: float = 0.5
## 精英敌人血量倍率
@export var slot_elite_hp_ratio: float = 2.0
## 精英敌人奖励（金币 / 经验）倍率
@export var slot_elite_reward_ratio: float = 2.0
## 击破老虎机的奖励金币
@export var slot_reward_gold: int = 50
