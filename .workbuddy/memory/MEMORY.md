# 项目长期记忆：2DIncrementGame_Main（GOBLIN RUSH）

## 项目定位
Godot 4.7 / GDScript / Forward Plus 的 2D 像素风增量射击游戏（讨伐哥布林）。
核心循环：单局战斗得金币 → 局外养成变强 → 下一局更高收益。

## 强制开发流程（每次任务必走）
1. 开发前必读 `AI开发规范.md` + `接口文档.md`；`项目进程汇报.md` 只看当前状态，历史查 Git。
2. 只有用户给了表结构的模块才开发，**禁止臆造/擅自增删表字段**。
3. 改数据 → 改 `data/*.xlsx`（五段式：字段名/类型/中文备注/默认值/数据行）→ 编辑器「导表」→ `Resources/Tables/*.tres`。**AI 绝不手改 .tres**。
4. 交付前自检 + 更新 `接口文档.md`；修改原因写进 Git 提交信息。

## 优先级
`AI开发规范.md` > `接口文档.md` > `项目进程汇报.md`

## 关键架构
- Autoload（4 个）：`UIManager` / `ConfigSystem` / `SaveSystem` / `DebugSystem`
- 分层依赖单向：`core ← manager ← ui`，`battle ← core`。core 不依赖 manager/ui/battle。
- 表查询统一走 `TableDB`（`rows_of` / `get_all` / `get_first`），禁止直接 load .tres。
- 表行是 `Array[Dictionary]`，**重复 Id 合法**，查询返回全部匹配行，调用方必须判空。
- 战斗开始时 `ConfigSystem.config.duplicate(true)` 得到本局副本，所有技能/Buff 修改只作用于副本。
- 局内 Buff / 临时状态**绝不写 SaveSystem**；局外金币、技能等级、武器、统计必须 `SaveSystem.save()` 落盘。
- `SaveSystem.set_*` / `WeaponService.equip|grant` 都**不落盘**，由调用方统一 save。

## 硬性编码禁令
- 禁止对 `Dictionary.get()` / `JSON.parse_string()` 用 `:=` 推断 → 必须 `var x: Variant = ...`
- 禁用 Godot 3 的 `get_tree().has_node()` → 用 `get_tree().root.has_node()`
- 整数除法陷阱：`int(seconds / 3600.0)`，不能写 `int(seconds) / 3600`
- 信号只在 `_ready()` 连接一次，`refresh()` 只刷数据不连信号
- 按钮统一 `Button` + `Resources/button_theme.tres`；动态按钮用 `UIBase._create_text_button()`
- 禁止 ColorRect 当 UI 背景 → 用 `TextureRect + menu_bg.png`
- 先 `add_child()` 再访问 `@onready`

## 属性系统入口
- `changeAttr1~4` / `attrValue1~4` 是 skillLevel 与 buffLevel 共用的属性槽，由 `_apply_attribute_change` 统一处理。
- 战斗内部属性：`atk` / `bulletCount` / `ricochetCount` / `burstCount`
- base_config 字段名亦可作为 key：`base_attack` / `base_attack_speed` / `base_crit_rate` / `base_crit_dmg` / `round_time` / `spawn_interval` / `spawn_per_wave` / `exp_gain_rate` / `coin_gain_rate`
- 暴击率 >100% 时每 1% 溢出转 1.5% 暴击伤害（`PlayerStatsService.get_effective_crit`，隐藏机制不显示）

## 用户偏好
- 表结构由用户设定，AI 不得擅自决定
- 不添加与需求无关的冗余文件
- 改动 `AI开发规范.md` 需用户确认
