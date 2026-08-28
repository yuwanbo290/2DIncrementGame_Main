extends UIBase


@onready var _back_btn: Button = $TopBar/BackBtn
@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _slot_info: Label = $TopBar/SlotInfo
@onready var _start_hunt_btn: Button = $MainContainer/VBox/StartHuntBtn
@onready var _upgrade_btn: Button = $MainContainer/VBox/MainRow/UpgradeBtn
@onready var _shop_btn: Button = $MainContainer/VBox/MainRow/ShopBtn
@onready var _weapon_btn: Button = $MainContainer/VBox/MainRow/WeaponBtn
@onready var _feature_cards: Array[Control] = [_upgrade_btn, _shop_btn, _weapon_btn]


func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_shop_btn.pressed.connect(_on_shop_pressed)
	_weapon_btn.pressed.connect(_on_weapon_pressed)
	_start_hunt_btn.pressed.connect(_on_start_battle_pressed)
	super()


func refresh() -> void:
	_refresh_top_bar()
	_reveal_feature_cards()


func get_default_focus() -> Control:
	return _start_hunt_btn


func _refresh_top_bar() -> void:
	_refresh_gold_label(_gold_label)
	var slot: Dictionary = SaveSystem.get_current_slot()
	_slot_info.text = str(slot.get("name", "未选择存档"))


## 页面首次进入及缓存界面重新打开时，都从干净状态错峰展示三张功能卡。
func _reveal_feature_cards() -> void:
	for index in _feature_cards.size():
		var card: Control = _feature_cards[index]
		card.modulate = Color.WHITE
		card.scale = Vector2.ONE
		UIBase.reveal_card(card, index)


func _on_back_pressed() -> void:
	UIManager.close_ui("preparation")
	UIManager.open_ui("save_select", "res://Scenes/ui/save_select.tscn")


func _on_upgrade_pressed() -> void:
	UIManager.open_ui("out_of_battle_upgrade", "res://Scenes/ui/out_of_battle_upgrade.tscn")


func _on_shop_pressed() -> void:
	UIManager.open_ui("shop", "res://Scenes/ui/shop.tscn")


func _on_weapon_pressed() -> void:
	UIManager.open_ui("weapon", "res://Scenes/ui/weapon.tscn")


func _on_start_battle_pressed() -> void:
	SaveSystem.save()
	UIManager.clear_all()
	get_tree().change_scene_to_file("res://Scenes/battle.tscn")
