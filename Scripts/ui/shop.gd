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

const ROW_HEIGHT := 112.0
const BUTTON_SIZE := Vector2(112, 44)
const STAT_LABEL_WIDTH := 265.0
const STATUS_LABEL_WIDTH := 120.0
const COST_LABEL_WIDTH := 110.0

const COLOR_TEXT := Color(0.94902, 0.917647, 0.843137, 1)
const COLOR_DESC := Color(0.666667, 0.713725, 0.67451, 1)
const COLOR_STAT := Color(0.658824, 0.827451, 0.356863, 1)
const COLOR_GOLD := Color(0.901961, 0.721569, 0.290196, 1)
const COLOR_DISABLED := Color(0.666667, 0.713725, 0.67451, 0.65)
const COLOR_WARN := Color(0.886275, 0.415686, 0.239216, 1)

@onready var _back_btn: Button = %BackBtn
@onready var _gold_label: Label = %GoldLabel
@onready var _shop_list: VBoxContainer = %ShopList

## 当前列表行用于排版完成后执行错峰入场。
var _item_rows: Array[Control] = []
## 仅记录可操作按钮，键盘上下导航会自动跳过不可购买项。
var _action_buttons: Array[Button] = []


func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	super()


func refresh() -> void:
	_refresh_gold()
	_build_shop_list()


func _refresh_gold() -> void:
	_refresh_gold_label(_gold_label)


func _get_list() -> VBoxContainer:
	return _shop_list


func _clear_shop_list() -> void:
	_clear_container(_get_list())


func _build_shop_list() -> void:
	_clear_shop_list()
	_item_rows.clear()
	_action_buttons.clear()

	var list: VBoxContainer = _get_list()
	if list == null:
		push_error("[商店] 找不到商品列表容器 ShopList")
		return

	var rows: Array[Dictionary] = TableDB.rows_of(TABLE_NAME)
	if rows.is_empty():
		list.add_child(_create_empty_hint("商店暂无商品"))
		_configure_action_focus()
		return

	for item in rows:
		var item_row: Panel = _create_item_row(item)
		list.add_child(item_row)
		_item_rows.append(item_row)
	_configure_action_focus()
	call_deferred("_reveal_item_rows")


## 构建一行商品（名称说明 + 属性 + 状态 + 价格 + 购买按钮）。
func _create_item_row(item: Dictionary) -> Panel:
	var row_node: Panel = _create_list_row(ROW_HEIGHT)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 9)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 信息列：商品名与关联武器描述。
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 4)

	var name_label: Label = Label.new()
	name_label.text = str(item.get(FIELD_PROP_NAME, "未知商品"))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)

	var desc_label: Label = Label.new()
	desc_label.text = "暂不支持的商品类型"
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	# 商品属性与描述都取关联对象，避免在 shop 表重复维护。
	var stat_label: Label = Label.new()
	stat_label.text = "—"
	if str(item.get(FIELD_ITEM_TYPE, "")) == ITEM_TYPE_WEAPON:
		var weapon: Dictionary = WeaponService.get_by_id(int(item.get(FIELD_REF_ID, 0)))
		if weapon.is_empty():
			desc_label.text = "关联武器不存在（refId=%d）" % int(item.get(FIELD_REF_ID, 0))
		else:
			desc_label.text = str(weapon.get(WeaponService.FIELD_DESC, ""))
			stat_label.text = "攻击 %.1f  ·  射速 %.2f/秒\n每秒伤害 %.2f" % [
				float(weapon.get(WeaponService.FIELD_ATK, 0.0)),
				float(weapon.get(WeaponService.FIELD_ATK_SPEED, 0.0)),
				WeaponService.get_dps(weapon),
			]
	stat_label.custom_minimum_size = Vector2(STAT_LABEL_WIDTH, 0)
	stat_label.add_theme_font_size_override("font_size", 15)
	stat_label.add_theme_color_override("font_color", COLOR_STAT)
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	info_vbox.add_child(name_label)
	info_vbox.add_child(desc_label)

	# 状态与价格分别展示，操作按钮只承担动作。
	var state: Dictionary = _resolve_state(item)
	var can_buy: bool = bool(state.get("can_buy", false))
	var state_color: Color = state.get("color", COLOR_TEXT)

	var status_label: Label = Label.new()
	status_label.text = str(state.get("text", ""))
	status_label.custom_minimum_size = Vector2(STATUS_LABEL_WIDTH, 0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", state_color)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var cost_label: Label = Label.new()
	cost_label.text = "%d 金币" % int(item.get(FIELD_COST, 0))
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", COLOR_GOLD)
	cost_label.custom_minimum_size = Vector2(COST_LABEL_WIDTH, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 购买按钮（状态在点击时会二次校验，避免界面残留状态导致误购）
	var buy_btn: Button = _create_text_button("购买" if can_buy else "不可用", BUTTON_SIZE, COLOR_TEXT if can_buy else COLOR_DISABLED)
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_btn.disabled = not can_buy
	if can_buy:
		buy_btn.theme_type_variation = &"PrimaryButton"
		buy_btn.pressed.connect(_on_buy_pressed.bind(item))
		_action_buttons.append(buy_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(stat_label)
	hbox.add_child(status_label)
	hbox.add_child(cost_label)
	hbox.add_child(buy_btn)
	margin.add_child(hbox)
	row_node.add_child(margin)
	# Panel 不是容器，子节点需手动铺满
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return row_node


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

	return {"text": "可购买", "can_buy": true, "color": COLOR_STAT}


## 列表完成布局后错峰展示前八项；更多项目沿用第八项延迟。
func _reveal_item_rows() -> void:
	for index in _item_rows.size():
		var row: Control = _item_rows[index]
		if is_instance_valid(row) and not row.is_queued_for_deletion():
			UIBase.reveal_card(row, index)


## 仅在可购买按钮之间建立上下循环，返回键始终可达。
func _configure_action_focus() -> void:
	_back_btn.focus_neighbor_top = NodePath()
	_back_btn.focus_neighbor_bottom = NodePath()
	if _action_buttons.is_empty():
		return

	_back_btn.focus_neighbor_top = _back_btn.get_path_to(_action_buttons.back())
	_back_btn.focus_neighbor_bottom = _back_btn.get_path_to(_action_buttons[0])
	for index in _action_buttons.size():
		var button: Button = _action_buttons[index]
		var previous: Control = _back_btn if index == 0 else _action_buttons[index - 1]
		var next: Control = _back_btn if index == _action_buttons.size() - 1 else _action_buttons[index + 1]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)


## 购买后原按钮会变为不可用，焦点移到下一个有效操作或返回键。
func _focus_after_purchase() -> void:
	if not _action_buttons.is_empty():
		_action_buttons[0].grab_focus()
	else:
		_back_btn.grab_focus()


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
	call_deferred("_focus_after_purchase")


func _on_back_pressed() -> void:
	UIManager.close_ui("shop")
