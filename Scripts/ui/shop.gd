extends UIBase
## 商店界面：以 shop 表为数据源，用金币购买商品。
##
## 商品经 itemType + refId 关联到具体对象（当前仅 itemType="weapon" → weapons 表的 weaponId）；
## purchaseLimit=1 表示一次性解锁（已拥有后置灰），0 表示不限次购买。
## 商品描述不在 shop 表里重复维护，统一取关联武器的 desc。
## 购买成功后扣金币 + 记录已购武器，并立即落盘。


## shop 表名与字段名（字段名以用户原表为准，禁止擅自改名）
const TABLE_NAME := "shop"
const FIELD_ITEM_TYPE := "itemType"
const FIELD_REF_ID := "refId"
const FIELD_PROP_NAME := "propName"
const FIELD_COST := "costNum"
const FIELD_LIMIT := "purchaseLimit"

## itemType 取值：武器
const ITEM_TYPE_WEAPON := "weapon"
## purchaseLimit 取值：仅可购买一次
const LIMIT_ONCE := 1

const ROW_HEIGHT := 100.0
const BUTTON_SIZE := Vector2(150, 50)
const COST_LABEL_WIDTH := 120.0

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
	_build_shop_list()


func on_close():
	super()


func on_destroy():
	super()
	_clear_shop_list()


func _refresh_gold() -> void:
	_refresh_gold_label($TopBar/GoldLabel as Label)


func _get_list() -> VBoxContainer:
	return $MainContainer/Panel/VBox/Margin/ScrollContainer/ShopList as VBoxContainer


func _clear_shop_list() -> void:
	_clear_container(_get_list())


func _build_shop_list() -> void:
	_clear_shop_list()

	var list: VBoxContainer = _get_list()
	if list == null:
		push_error("[商店] 找不到商品列表容器 ShopList")
		return

	var rows: Array[Dictionary] = TableDB.rows_of(TABLE_NAME)
	if rows.is_empty():
		list.add_child(_create_empty_hint("商店暂无商品"))
		return

	for item in rows:
		list.add_child(_create_item_row(item))


## 构建一行商品（信息列 + 价格列 + 购买按钮）
func _create_item_row(item: Dictionary) -> Panel:
	var row_node: Panel = _create_list_row(ROW_HEIGHT)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 10)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 信息列：商品名 + 关联武器描述
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 5)

	var name_label: Label = Label.new()
	name_label.text = str(item.get(FIELD_PROP_NAME, "未知商品"))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)

	var desc_label: Label = Label.new()
	desc_label.text = _get_item_desc(item)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)

	info_vbox.add_child(name_label)
	info_vbox.add_child(desc_label)

	# 价格列
	var cost_label: Label = Label.new()
	cost_label.text = "价格 %d" % int(item.get(FIELD_COST, 0))
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", COLOR_GOLD)
	cost_label.custom_minimum_size = Vector2(COST_LABEL_WIDTH, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 购买按钮（状态在点击时会二次校验，避免界面残留状态导致误购）
	var state: Dictionary = _resolve_state(item)
	var can_buy: bool = bool(state.get("can_buy", false))
	var btn_text: String = str(state.get("text", ""))
	var btn_color: Color = state.get("color", COLOR_TEXT)

	var buy_btn: TextureButton = _create_text_button(btn_text, BUTTON_SIZE, btn_color)
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_btn.disabled = not can_buy
	if can_buy:
		buy_btn.pressed.connect(_on_buy_pressed.bind(item))
		_add_hover(buy_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(cost_label)
	hbox.add_child(buy_btn)
	margin.add_child(hbox)
	row_node.add_child(margin)
	# Panel 不是容器，子节点需手动铺满
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return row_node


## 商品描述：武器类商品取 weapons 表的 desc 与属性，避免文案在两张表里重复维护
func _get_item_desc(item: Dictionary) -> String:
	if str(item.get(FIELD_ITEM_TYPE, "")) != ITEM_TYPE_WEAPON:
		return "暂不支持的商品类型"

	var ref_id: int = int(item.get(FIELD_REF_ID, 0))
	var weapon: Dictionary = WeaponService.get_by_id(ref_id)
	if weapon.is_empty():
		return "关联武器不存在（refId=%d）" % ref_id

	return "%s ｜ 攻击 %.1f ｜ 射速 %.2f/秒 ｜ 每秒伤害 %.2f" % [
		str(weapon.get(WeaponService.FIELD_DESC, "")),
		float(weapon.get(WeaponService.FIELD_ATK, 0.0)),
		float(weapon.get(WeaponService.FIELD_ATK_SPEED, 0.0)),
		WeaponService.get_dps(weapon),
	]


## 解析商品可购买状态，返回 {text: String, can_buy: bool, color: Color}
func _resolve_state(item: Dictionary) -> Dictionary:
	var item_type: String = str(item.get(FIELD_ITEM_TYPE, ""))
	if item_type != ITEM_TYPE_WEAPON:
		return {"text": "暂不支持", "can_buy": false, "color": COLOR_DISABLED}

	var ref_id: int = int(item.get(FIELD_REF_ID, 0))
	if WeaponService.get_by_id(ref_id).is_empty():
		return {"text": "配置缺失", "can_buy": false, "color": COLOR_WARN}

	var limit: int = int(item.get(FIELD_LIMIT, 0))
	if limit == LIMIT_ONCE and WeaponService.is_owned(ref_id):
		return {"text": "已拥有", "can_buy": false, "color": COLOR_DISABLED}

	var cost: int = int(item.get(FIELD_COST, 0))
	if SaveSystem.get_gold() < cost:
		return {"text": "金币不足", "can_buy": false, "color": COLOR_WARN}

	return {"text": "购买", "can_buy": true, "color": COLOR_TEXT}


func _on_buy_pressed(item: Dictionary) -> void:
	# 点击时二次校验，防止列表状态过期
	var state: Dictionary = _resolve_state(item)
	if not bool(state.get("can_buy", false)):
		return

	var cost: int = int(item.get(FIELD_COST, 0))
	var ref_id: int = int(item.get(FIELD_REF_ID, 0))

	SaveSystem.set_gold(SaveSystem.get_gold() - cost)
	WeaponService.grant(ref_id)
	SaveSystem.save()

	_refresh_gold()
	_build_shop_list()


func _on_back_pressed() -> void:
	UIManager.close_ui("shop")
