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
## 每次刷出的鸭子数量
@export var spawn_per_wave: int = 1

@export_category("Boss")
## 触发 Boss 所需的累计击杀数节点
@export var boss_nodes: Array[int] = [20, 50, 100, 250]

@export_category("局内Buff")
## 击杀多少只鸭子触发一次 3 选 1
@export var buff_trigger_kills: Array[int] = [10, 25, 45]
## 每次 3 选 1 的可选数量
@export var buff_choice_count: int = 3