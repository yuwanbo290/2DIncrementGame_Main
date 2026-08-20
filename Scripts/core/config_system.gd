extends Node
## 基础配置单例（Autoload）。
## 启动时加载 res://Resources/Config/base_config.tres，全局只读访问 ConfigSystem.config。


const CONFIG_PATH := "res://Resources/Config/base_config.tres"

## 基础配置资源（启动后可用；字段见 BaseConfig）
var config: BaseConfig


func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		config = load(CONFIG_PATH) as BaseConfig
	if config == null:
		push_error("[ConfigSystem] 加载基础配置失败，使用默认值: " + CONFIG_PATH)
		config = BaseConfig.new()