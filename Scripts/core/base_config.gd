@tool
class_name BaseConfig
extends Resource
## 基础配置资源：所有游戏基础设置单独存为一个可编辑的 .tres。
## 位置：res://Resources/Config/base_config.tres


@export_category("单局")
## 初始单局游戏时间（秒）
@export var round_time: float = 60.0

@export_category("玩家基础")
## 初始攻击力
@export var base_attack: float = 10.0
## 初始攻击速度（次/秒）
@export var base_attack_speed: float = 1.0
## 初始暴击率（0 ~ 1）
@export var base_crit_rate: float = 0.05
## 初始暴击伤害倍率
@export var base_crit_dmg: float = 1.5

@export_category("刷怪")
## 初始刷怪间隔（秒）
@export var spawn_interval: float = 2.0
## 每次刷出的哥布林数量
@export var spawn_per_wave: int = 1
## 每击杀多少只哥布林切换下一阶段刷怪区间（10以内=1，10-19=2，以此类推）
@export var kills_per_stage: int = 10

@export_category("Boss")
## 触发 Boss 所需的累计击杀数节点
@export var boss_nodes: Array[int] = [20, 50, 100, 250]

@export_category("局内Buff")
## 击杀多少只哥布林触发一次 3 选 1
@export var buff_trigger_kills: Array[int] = [10, 25, 45]
## 每次 3 选 1 的可选数量
@export var buff_choice_count: int = 3

@export_category("战斗")
## 子弹飞行速度（像素/秒）
@export var bullet_speed: float = 640.0
## 多弹散布半角（弧度）：多弹齐发时单发相对瞄准方向的最大偏移
@export var spread_half_angle: float = 0.12
## 子弹生成点距玩家中心的距离（像素）
@export var muzzle_offset: float = 26.0
