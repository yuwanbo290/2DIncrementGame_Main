extends UIBase


func _ready() -> void:
	($TopBar/BackBtn as Button).pressed.connect(_on_back_pressed)
	($MainContainer/VBox/MainRow/LeftVBox/UpgradeBtn as Button).pressed.connect(_on_upgrade_pressed)
	($MainContainer/VBox/MainRow/LeftVBox/ShopBtn as Button).pressed.connect(_on_shop_pressed)
	($MainContainer/VBox/MainRow/CenterVBox/WeaponBtn as Button).pressed.connect(_on_weapon_pressed)
	($MainContainer/VBox/MainRow/CenterVBox/StartHuntBtn as Button).pressed.connect(_on_start_battle_pressed)
	super()


func refresh() -> void:
	_refresh_top_bar()


func _refresh_top_bar() -> void:
	var gold_label: Label = $TopBar/GoldLabel as Label
	var slot_info: Label = $TopBar/SlotInfo as Label
	_refresh_gold_label(gold_label)
	if slot_info:
		var slot: Dictionary = SaveSystem.get_current_slot()
		slot_info.text = slot.get("name", "未选择存档")


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
