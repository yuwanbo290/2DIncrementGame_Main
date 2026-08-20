extends UIBase
## 局外养成界面：以 Skill 表为数据源，展示技能并支持用金币升级（等级存存档）。
## 升级消耗来自 skillLevel 表（每技能每级 upCost）；前置技能（previouId）需至少 1 级解锁。


const ROW_HEIGHT := 110.0
const BUTTON_SIZE := Vector2(130, 50)

const COLOR_TEXT := Color(1, 1, 1, 1)
const COLOR_DESC := Color(0.7, 0.7, 0.7, 1)
const COLOR_GOLD := Color(1, 0.85, 0.2, 1)
const COLOR_DISABLED := Color(0.5, 0.5, 0.5, 1)
const COLOR_WARN := Color(1, 0.3, 0.3, 1)


func on_create():
	var back_btn: TextureButton = $TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_add_hover(back_btn)


func on_open():
	super()
	_refresh_gold()
	_build_skill_list()


func on_close():
	super()


func on_destroy():
	super()
	_clear_skill_list()


func _refresh_gold() -> void:
	_refresh_gold_label($TopBar/GoldLabel as Label)


func _clear_skill_list() -> void:
	_clear_container($MainContainer/Panel/VBox/Margin/ScrollContainer/SkillList as VBoxContainer)


func _build_skill_list() -> void:
	_clear_skill_list()

	var list: VBoxContainer = $MainContainer/Panel/VBox/Margin/ScrollContainer/SkillList as VBoxContainer
	var rows: Array[Dictionary] = TableDB.rows_of("Skill")

	for row in rows:
		var skill_id: int = int(row.get("Id", 0))
		var level: int = SaveSystem.get_skill_level(skill_id)
		var max_level: int = int(row.get("maxLevel", 1))
		var previou_id: int = int(row.get("previouId", 0))

		# 升级到下一级的消耗（来自 skillLevel 表）
		var cost: int = -1
		if level < max_level:
			cost = _get_level_cost(skill_id, level + 1)

		# 升级状态判定
		var status: String = ""
		var can_upgrade: bool = false
		if level >= max_level or cost < 0:
			status = "已满级"
		elif previou_id != 0 and SaveSystem.get_skill_level(previou_id) < 1:
			status = "需前置技能"
		else:
			status = "升级 %d" % cost
			can_upgrade = true

		var row_node: Panel = _create_list_row(ROW_HEIGHT)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# 信息列
		var info_vbox: VBoxContainer = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 5)

		var name_label: Label = Label.new()
		name_label.text = str(row.get("skillName", "未知"))
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", COLOR_TEXT)

		var desc_label: Label = Label.new()
		desc_label.text = str(row.get("desc", ""))
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", COLOR_DESC)

		info_vbox.add_child(name_label)
		info_vbox.add_child(desc_label)

		# 等级列
		var level_vbox: VBoxContainer = VBoxContainer.new()
		level_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		level_vbox.add_theme_constant_override("separation", 5)

		var level_label: Label = Label.new()
		level_label.text = "等级 %d / %d" % [level, max_level]
		level_label.add_theme_font_size_override("font_size", 18)
		level_label.add_theme_color_override("font_color", COLOR_GOLD)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		level_vbox.add_child(level_label)

		# 升级按钮：先定好文字颜色，再用 UIBase 统一原语创建（内含 ignore_texture_size）
		var btn_color: Color = COLOR_DISABLED
		var is_clickable: bool = false
		if can_upgrade:
			if SaveSystem.get_gold() < cost:
				btn_color = COLOR_WARN  # 金币不足：标红并禁用
			else:
				btn_color = COLOR_TEXT
				is_clickable = true

		var upg_btn: TextureButton = _create_text_button(status, BUTTON_SIZE, btn_color)
		upg_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		upg_btn.disabled = not is_clickable
		if is_clickable:
			upg_btn.pressed.connect(_on_upgrade_pressed.bind(skill_id, cost))
			_add_hover(upg_btn)

		# 组装
		hbox.add_child(info_vbox)
		hbox.add_child(level_vbox)
		hbox.add_child(upg_btn)

		margin.add_child(hbox)
		row_node.add_child(margin)
		# Panel 不是容器，子节点需手动铺满，否则内容不会跟随行宽
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		list.add_child(row_node)


func _get_level_cost(skill_id: int, level: int) -> int:
	var rows: Array[Dictionary] = TableDB.get_all("skillLevel", "Id", skill_id)
	for row in rows:
		if int(row.get("skillLevel", 0)) == level:
			return int(row.get("upCost", 0))
	return -1


func _on_upgrade_pressed(skill_id: int, cost: int) -> void:
	var gold: int = SaveSystem.get_gold()
	if gold < cost:
		return
	var level: int = SaveSystem.get_skill_level(skill_id)
	SaveSystem.set_gold(gold - cost)
	SaveSystem.set_skill_level(skill_id, level + 1)
	SaveSystem.save()
	_refresh_gold()
	_build_skill_list()


func _on_back_pressed() -> void:
	UIManager.close_ui("out_of_battle_upgrade")
