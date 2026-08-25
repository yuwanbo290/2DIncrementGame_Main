# AI 开发规范（2D 像素风增量游戏）

> **文档定位**：本文件是本项目 AI 开发的最高准则（"宪法"），约束后续所有 AI 会话的编码行为。
> **适用对象**：所有参与本项目开发的 AI（含当前会话与后续会话）。
> **优先级**：本文件 > `接口文档.md` > `项目进程汇报.md`。三者冲突时以本文件为准。
> **强制约定**：**每次开发前必读本文件 + `接口文档.md` + `项目进程汇报.md`；开发完成后必须同步更新 `接口文档.md`（接口变化时）与 `项目进程汇报.md`（追加修改历史）。**

---

## 一、项目定位与核心玩法（所有开发必须围绕此展开）

- **游戏类型**：2D 俯视角（Top-down）像素风增量射击游戏（讨伐哥布林）。
- **核心循环**：
  ```
  单局战斗（击败哥布林得金币）
    → 用金币强化实力（技能 / 养成，待用户提供表结构后实现）
    → 变强
    → 进入下一局打出更高收益
  ```
- **两大成长维度（不可混用）**：
  1. **局内成长（Run）**：单局内通过技能 / 局内 Buff 临时增强，局结束即清零，**不落盘**。
  2. **局外成长（Meta）**：金币 / 统计（当前已实现）；养成等级 / 武器等永久强化维度**待用户提供表结构后实现**，永久保留，**必须落盘**。
- **已确认的玩家行为**：按住鼠标左键持续射击（`click` 输入动作）。
- **必须遵守的用户硬性规则**：
  - 表结构由用户设定；**只有拿到对应模块的表结构后才开发该模块**，禁止 AI 臆造/擅自增删字段。
  - **不添加与需求无关的冗余文件**。

---

## 二、技术栈与硬性约束

| 项 | 约定 |
|---|---|
| 引擎版本 | Godot **4.7**（config/features 为 `"4.7"`） |
| 语言 | GDScript（禁止引入 C# / GDExtension，除非用户明确要求） |
| 渲染 | Forward Plus，Windows 用 d3d12；`textures/canvas_textures/default_texture_filter=0`（最近邻，保证像素清晰） |
| 物理 | Jolt Physics（`3d/physics_engine`；2D 用 Godot 内置 2D 物理） |
| 窗口拉伸 | `canvas_items` + `expand`（像素风缩放必须保持此设置，禁止改为 viewport） |

**硬性禁止事项**：
- 禁止用 `:=` 推断 `Dictionary.get()`、`JSON.parse_string()` 等返回 `Variant` 的表达式——**必须显式声明类型**（如 `var parsed: Variant = ...`）。
- 禁止使用 Godot 3 的 `get_tree().has_node()`（Godot 4 无此方法，用 `get_tree().root.has_node()`）。
- **TextureButton 没有 `texture` 属性**（.tscn 与脚本都没有）。设底图必须用 `texture_normal`，写 `texture = ...` 会被 Godot 静默丢弃、按钮底图永不显示。
- **TextureButton 必须同时设 `ignore_texture_size = true`**：底图 `btn_plain.png` 为 2240×692，不忽略原图尺寸会把按钮最小尺寸撑到原图大小、直接破坏布局。忽略后由 `custom_minimum_size` 决定尺寸，且**必须显式设 `stretch_mode = STRETCH_KEEP_ASPECT_COVERED`**——Godot 4.7 的 TextureButton 默认 `stretch_mode = STRETCH_KEEP`（按原始像素绘制），不显式设置时 2240 宽的底图会直接溢出按钮、盖住半个界面。
- 动态创建按钮统一调 `UIBase._create_text_button()`，不要手搓（该方法已含上述两项）。
- 禁止用 ColorRect 当 UI 背景（用 `TextureRect + menu_bg.png`）。

---

## 三、目录结构规范（新增文件必须落在正确位置）

```
2DIncrementGame_Main/
├── Scenes/
│   ├── GameManager.tscn          # 唯一入口（Autoload 由引擎加载，不在此实例化）
│   ├── battle.tscn               # 战斗场景（change_scene_to_file 进入）
│   ├── battle/                   # [未来] 战斗子场景：敌人/子弹/掉落物/Boss 等
│   └── ui/                       # 所有全屏 UI 场景（继承 UIBase）
├── Scripts/
│   ├── core/                     # 纯逻辑核心系统（不挂场景节点，RefCounted 或 Autoload）
│   ├── manager/                  # 管理器（Autoload 单例 + 场景级管理器）
│   ├── ui/                       # UI 脚本（一场景一脚本）
│   ├── battle/                   # [未来] 战斗逻辑：敌人/武器/子弹/技能/波次/Boss/Buff
│   └── autoload/                 # [可选] 若未来单例增多，集中存放 Autoload 脚本
├── Resources/
│   ├── Tables/                   # 导表产物 .tres（只读，勿手改）
│   └── Config/                   # base_config.tres 等基础配置资源
├── data/                         # 源表 .xlsx（策划维护，AI 不手改 .tres）
├── Textures/
│   ├── ui/                       # UI 纹理（menu_bg / btn_* / icon_* / goblin_emblem）
│   ├── PNG/                      # 通用像素图标素材库（勿乱放，仅供素材）
│   ├── goblins/                  # [未来] 哥布林敌人纹理与 SpriteFrames
│   └── weapons/                  # [未来] 武器/子弹纹理
├── Audio/                        # [未来] 音频（music/ sfx/）
└── addons/table_exporter/        # 导表插件（勿改，除非用户要求）
```

**落盘规则**：
- 脚本放 `Scripts/<分层>/`，场景放 `Scenes/<对应>/`，纹理放 `Textures/<分类>/`，音频放 `Audio/`。
- 文件名用 snake_case（见第四节），与场景/资源/脚本三者同名同目录。

---

## 四、命名规范（统一 snake_case，消除现状混乱）

### 4.1 文件与类名
| 对象 | 规范 | 正例 | 反例（现状） |
|---|---|---|---|
| 脚本文件 | snake_case | `game_manager.gd` | `Gamemanager.gd`、`startui.gd` |
| 场景文件 | snake_case | `save_select.tscn` | — |
| `class_name` | PascalCase | `TableDB`、`BaseConfig` | — |
| Autoload 单例名 | PascalCase（注册名） | `UIManager`、`SaveSystem` | — |

> **整改方向（需用户确认后执行）**：`Gamemanager.gd` → `game_manager.gd`，`startui.gd` → `start_ui.gd`。改名必须同步更新 `project.godot` 的 autoload 路径、`GameManager.tscn` 的 script 引用、以及 `接口文档.md`。

### 4.2 变量 / 函数 / 信号
- **变量、函数、信号**：一律 snake_case。私有成员前缀 `_`（`_ui_managed`、`_add_hover`）。
- **常量**：SCREAMING_SNAKE_CASE（`SAVE_PATH`、`SLOT_COUNT`）。
- **布尔变量**：用 `is_`/`has_`/`can_` 前缀（`is_open`、`_ui_managed`）。
- **回调函数**：统一 `_on_<对象>_<事件>`（`_on_back_pressed`）。

### 4.3 数据表字段命名（重要）
- **用户提供的表**（`Enemy`/`Skill`/`generateProbability`/`skillLevel`/`shop`/`weapons`/`Buff`/`buffLevel`/`waveBoss`）：字段名**以用户原表为准，禁止擅自改名**。
- **未来 AI 新增的表**：字段名**必须 snake_case**（`fire_rate`、`base_cost`），表名 snake_case 小写。
- **表名与源文件名一致**：`<表名>.xlsx` ↔ 表名 `<表名>` ↔ `<表名>.tres`（CSV 仅为兼容输入）。
- 若未来用户要求统一既有 8 张表字段命名，须由用户拍板后批量同步 xlsx / .tres / 引用代码，一次性完成，不留半迁移状态。

### 4.4 场景节点命名
- 节点名 PascalCase（`TopBar`、`GoldLabel`、`BackBtn`、`MainContainer`）。
- 动态生成的节点变量名 snake_case（`row_node`、`buy_btn`）。
- 同类节点带编号后缀（`Slot0`/`Slot1`/`Slot2`）。

---

## 五、GDScript 代码风格规范

1. **缩进**：Tab（Godot 默认），禁止混用空格。
2. **类型标注**：所有成员变量、函数参数、函数返回值显式标注类型（`var gold: int = 0`、`func add_gold(value: int) -> int:`）。
   - 例外：`Variant` 类型可省略但需保证语义正确；能确定类型时不要省略。
3. **注释**：每个类顶部用 `##` 写职责说明；公开方法写 `##` 说明 + 参数说明（`[param xxx]`）；复杂逻辑写行内注释。
4. **常量优先**：魔法数字提为 `const`（存档路径、槽位数、默认值、UI 尺寸等）。
5. **判空**：`FileAccess.open`、`load`、`get_node` 返回值必须判空后再用。
6. **字典取值**：`Dictionary.get(key, default)` 优先于 `dict[key]`（避免 KeyError）。
7. **信号连接**：优先在 `on_create()` 里一次性连接，禁止在 `_ready()` 里重复连接（历史已踩坑）。
8. **资源引用**：运行时 `load("res://...")`；同文件资源用 `preload` 常量化。

---

## 六、架构分层与依赖规则

### 6.1 分层职责
| 层 | 目录 | 职责 | 可依赖 |
|---|---|---|---|
| 核心层 | `Scripts/core/` | 数据/配置/存档/查询，纯逻辑无 UI | 引擎 + TableResource |
| 管理层 | `Scripts/manager/` | 场景生命周期、UI 导航、战斗流程编排 | 核心层 |
| UI 层 | `Scripts/ui/` | 界面展示与交互 | 核心层 + 管理层（经 Autoload） |
| 战斗层 | `Scripts/battle/`（未来） | 敌人/武器/技能/波次逻辑 | 核心层（读表读配置） |

### 6.2 依赖方向（单向，禁止反向）
```
core ← manager ← ui
        ↖ battle ← core
```
- **core 层不依赖任何 manager/ui/battle**（保持纯逻辑，可独立测试）。
- **ui 层不直接操作战斗实体**，通过管理器或信号驱动。
- **禁止场景间直接引用对方节点**；跨场景通信一律走 Autoload 单例或信号总线。

### 6.3 Autoload 单例（现有 3 个，职责边界固定）
| 单例 | 职责 | 禁止 |
|---|---|---|
| `UIManager` | UI 场景的打开/关闭/销毁/缓存 | 不得承载业务逻辑或存档数据 |
| `ConfigSystem` | 只读暴露 `base_config.tres` | 不得被写入/修改 |
| `SaveSystem` | 存档读写、槽位、设置、金币、统计 | 不得保存局内临时状态（Buff/血量/子弹） |

> 新增单例需先在 `接口文档.md` 登记，并在 `project.godot [autoload]` 注册；单例间依赖保持无环。

---

## 七、数据驱动开发规范

### 7.1 导表流程（唯一数据入口）
- 策划改 `data/*.xlsx` → 点编辑器「导表」按钮（`addons/table_exporter`）→ 生成 `Resources/Tables/*.tres`。
- **源表格式统一用 `.xlsx`**：内部是 UTF-8 的 XML，不存在中文编码问题；且 Godot 不识别该扩展名，不会误当翻译表导入。
- `.csv` 通道仍保留兼容，但**必须是 UTF-8**；非 UTF-8（中文系统 Excel 另存默认是 GBK）会被导表器报错拦截并跳过。同名时 `.xlsx` 优先。
- **AI 不手改 `.tres`**（那是产物）；改数据必须改源表后重新导表。
- 导表前请先在 Excel/WPS 中**关闭该文件**（占用中会导致 ZIPReader 打不开）；`~$xxx.xlsx` 锁文件会被自动跳过。
- 源表五段式格式（**缺一不可**）：
  ```
  第 1 行：字段名
  第 2 行：类型（int / float / bool / string）
  第 3 行：中文备注（导出跳过，必须保留）
  第 4 行：默认值（导出跳过，必须保留）
  第 5 行起：数据行
  ```
- 类型转换规则：int 空→0、float 空→0.0、bool 空→false、string 空→""。
- **重复 Id 合法**：表行用 `Array[Dictionary]` 保存，查询用 `TableDB.get_all` / `get_first` / `rows_of`，禁止假设 Id 唯一。

### 7.2 运行时查询（统一走 TableDB）
```gdscript
var enemies: Array[Dictionary] = TableDB.rows_of("Enemy")
var enemy: Dictionary = TableDB.get_first("Enemy", "enemyID", 1)
var levels: Array[Dictionary] = TableDB.get_all("skillLevel", "Id", 1)
```
- 查询结果为空返回 `[]` / `{}`，**调用方必须判空**（`row.is_empty()`）。
- 禁止绕过 TableDB 直接 `load("res://Resources/Tables/xxx.tres")`。

### 7.3 数据源一致性
- **一张表 = 一个源表（.xlsx）+ 一个 .tres**，二者必须同时存在。
- 当前 9 张表（Enemy / Skill / generateProbability / skillLevel / shop / weapons / Buff / buffLevel / waveBoss）均为 xlsx 源，已对齐。
- 新增表时：先建 xlsx → 导表 → 在 `接口文档.md` 登记表结构 → 再写查询代码。

---

## 八、UI 开发规范

### 8.1 生命周期（UIBase，禁止破坏）
```
on_create()   首次创建：绑定按钮信号、一次性初始化（覆盖需调 super()）
on_open()     每次打开：刷新动态数据（覆盖需调 super()）
on_close()    每次关闭：隐藏（覆盖需调 super()）
on_destroy()  销毁：清理动态创建的子节点（覆盖需调 super()）
```
- **所有全屏 UI 继承 `UIBase`**，根节点 `Control + anchors_preset=15`。
- 由 `UIManager` 管理的 UI：`_ready()` 不自动初始化（`_ui_managed=true`）；`change_scene_to_file` 直接加载的 UI 才走 `_ready` 自动初始化。
- **UI 导航必须通过 UIManager**（`open_ui`/`close_ui`），战斗场景除外（用 `change_scene_to_file`）。

### 8.2 像素风 UI 规范（统一标准）
- 背景：`TextureRect + menu_bg.png`（禁用 ColorRect）。
- 布局：`TopBar`（高 60）+ `MainContainer`（margin 80/20/80/40 + `offset_top=60`）；主菜单 start_ui 例外用 CenterContainer 居中。
- 标题：黄色 `(1, 0.85, 0.2)` + 黑色描边 `outline_size=4` + 字号 36。
- 按钮：`TextureButton` + `Label` 文字标识；底图用 `texture_normal = btn_plain.png`，**且必须同时设** `ignore_texture_size = true` **和** `stretch_mode = 6`（KEEP_ASPECT_COVERED，等比铺满不溢出）；**子节点 `mouse_filter=2`**（否则拦截点击）。
- 面板：`StyleBoxFlat` 深色背景 `(0.08, 0.1, 0.14, 0.92)` + 边框 + 圆角 8。
- hover：所有按钮调 `_add_hover(btn)`（正常态 modulate=1.15，hover 1.3）。
- 资源路径：`Textures/ui/`，命名 `menu_bg.png` / `btn_plain.png` / `goblin_emblem.png` / `icon_coin.jpg`。
- **`btn_plain.png` 素材说明**：当前为无文字的苔绿木石按钮底图，可复用于所有按钮；按钮文字必须由 Label 渲染，不得写死在纹理内。

### 8.3 动态构建 UI（列表类界面）
- 用 UIBase 公共方法 `_create_list_row` / `_clear_container` / `_refresh_gold_label`，**禁止重复造轮子**。
- 动态按钮子 Label 必须 `mouse_filter = Control.MOUSE_FILTER_IGNORE`。
- **先 `add_child()` 再访问 `@onready` 变量**（历史踩坑：动态实例化场景若先 setup 后 add_child 会空指针）。
- 列表刷新前先 `_clear_container`，避免残留。

### 8.4 资源清理与 ext_resource
- Godot 编辑器保存场景会自动清理"未使用"的 ext_resource，若按钮纹理被删，ext_resource 一并消失——改 .tscn 后必须重跑验证，勿留悬空引用。

---

## 九、存档与设置规范

- 存档文件 `user://save.json`，`SAVE_VERSION` 当前为 `2`，3 个槽位；槽位只存 `id/name/created_at/last_played/playtime/gold/skill_levels/stats`。
- **扩展存档字段的流程（必须遵守）**：
  1. 在 `_empty_slot()` / `_default_data()` 补充字段默认值；
  2. 在 `load_save()` 加字段缺失补全逻辑（向后兼容旧档）；
  3. 若结构破坏性变更，递增 `SAVE_VERSION` 并写迁移函数 `_migrate_vX_to_vY`；
  4. 同步更新 `接口文档.md` 的存档槽结构表。
- 金币 / 技能等级 / 统计改动后**必须 `SaveSystem.save()` 落盘**；`update_current_slot` / `set_gold` / `set_skill_level` / `set_stat` 只改内存不落盘，调用方负责 save。
- 设置项即时保存（settings.gd 的 `_save_immediate` 模式），设置 key 见 `接口文档.md`。

---

## 十、战斗系统开发规范（增量游戏核心，未来开发重点）

> 战斗场景已实现核心玩法（射击/刷怪/金币/结算与局内 Buff 三选一，敌人仍为代码绘制占位造型，Boss 待做）。以下为架构约定与后续待办。

### 10.1 场景结构约定
```
battle.tscn (Node2D + battle_manager.gd)
├── World (Node2D)            # 游戏世界：玩家/敌人/子弹/掉落物
├── UI (CanvasLayer)          # 局内 HUD：金币/时间/血量/波次
└── Camera2D
```
- 战斗逻辑脚本放 `Scripts/battle/`，场景放 `Scenes/battle/`。
- 敌人、子弹、掉落物各自独立脚本 + 独立场景，由管理器统一 spawn/管理。

### 10.2 哥布林（敌人）规范
- 属性从 `Enemy` 表读：`enemyID`/`goblinName`/`healthNum`/`coin`/`exp`/`moveSpeed`/`texture`/`spriteFrames`。
- 敌人节点统一挂 `enemy.gd`，实例化后注入表行数据（**不硬编码数值**）。
- 死亡：给金币（`coin` 字段），累加击杀统计（`SaveSystem.set_stat("best_kills", ...)`），局内计数，局结束落盘。

### 10.3 武器 / 子弹规范（待用户提供表结构）
- 武器属性**待用户提供 weapon 表结构后按表读取**（当前武器系统已清理，禁止 AI 擅自造表）。
- 攻击方式 = 按住左键持续射击（`Input.is_action_pressed("click")`），射速由表内 `fire_rate` 控制冷却。
- 子弹独立场景/脚本，按 `spread` 随机散布，按 `range` 判定消亡。

### 10.4 技能系统规范
- 技能树：`Skill` 表（`Id`/`previouId`/`maxLevel`）定义解锁前置与满级；`skillLevel` 表定义每级消耗与效果（`changeAttr1~3` + `attrValue1~3` + `specialEffect`）。
- 局外养成界面为**传统技能树**：按 `previouId` 分层（缺失/0 = 根节点，BFS 算深度），同层水平均分整层居中；节点面板显示名称/描述/等级/升级按钮，前置连线由 `skill_tree_canvas.gd`（`SkillTreeCanvas._draw`）绘制，解锁亮绿/未解锁暗灰。
- 属性改动用 `changeAttr*` 字符串映射到运行时属性（如 `atk`/`bulletCount`/`ricochetCount`/`burstCount`），也支持直接写 base_config 字段名（`base_attack`/`base_attack_speed`/`base_crit_rate`/`base_crit_dmg`/`round_time`/`spawn_interval`/`spawn_per_wave`，战斗开始应用、退出恢复）；特殊能力用 `specialEffect` key 分发（如 `UnlockSuperBullet`）。
- 局外养成的技能等级存 `skill_levels`（落盘）；局内技能/临时增益不落盘；局外存金币 + 技能等级 + 统计。

### 10.5 波次 / Boss 规范
- 波次推进由 `waveBoss` 表驱动：当前波内普通敌人击杀数达到 `CreateCost` → 刷新 Boss；击杀 Boss → 进入下一波；最后一波 Boss 击杀后直接结算。
- 普通刷怪按 `generateProbability` 表（`waveNumber`/`enemyId`/`weight`）加权随机；Boss 按 `waveBoss` 表（`waveNumber`/`enemyId`/`weight`）加权随机。
- 刷怪节奏用 `base_config` 的 `spawn_interval` / `spawn_per_wave`；单局时长 `round_time`。Boss 存活期间仍正常刷小怪；击杀 Boss 后场上小怪保留、直接进入下一波。

### 10.6 局内 Buff 规范
- 击杀敌人获得经验（`Enemy.exp` 列）→ 经验攒满 `Exp(level) = exp_base × level^exp_power + exp_linear × (level-1)` 后升级并扣除该级所需经验，每次升级触发 `buff_choice_count` 选 1（3 选 1）。
- `buffLevel` 表使用 `changeAttr1~4`/`attrValue1~4` + 每级 `desc`（策划效果文案，升级卡面直接展示）；属性 key 与技能表共用同一入口（`_apply_attribute_change`），支持 base_config 字段名（`base_attack`/`base_attack_speed`/`base_crit_rate`/`base_crit_dmg` 等）。
- Buff 效果为**局内临时**，保存在战斗管理器内存字典中，**绝不写 SaveSystem**。

### 10.7 战斗循环结束
- 单局结束（时间到 / 死亡）→ 结算金币与统计落盘 → `UIManager.clear_all()` + 返回 `preparation.tscn`（或 `change_scene_to_file`）。

---

## 十一、增量游戏数值设计规范

> 增量游戏的核心是"成长 → 收益 → 更强成长"的指数循环。数值错误会导致游戏秒通关或卡死。

1. **成本增长**：养成升级成本建议按 `base_cost × cost_multiplier^level` 增长，`cost_multiplier` 建议 1.4~1.7（等比增长，避免线性廉价）。
2. **收益增长**：单局金币收益应随养成等级**近线性~弱超线性**增长，保证"跑一局能显著推进若干级养成"。
3. **数值范围**：金币/伤害等长尾数值须预留大数空间；UI 显示用整数，超 1e6 时用缩写（K/M/B/T）。
4. **暴击/概率**：暴击率 0~1、暴击伤害倍率 ≥1；概率类字段统一 0~1（`base_crit_rate=0.05`），加权刷怪用整数 weight。
5. **平衡验证**：每新增一个养成维度，给出一条"单局收益 / 满级成本"的估算，避免数值爆炸。
6. **禁止魔法数字**：所有平衡参数进 `base_config.tres` 或数据表，不散落在脚本里。

---

## 十二、AI 开发流程规范（SOP，每次任务强制执行）

### 12.1 开发前（读）
1. 读本文件 + `接口文档.md` + `项目进程汇报.md`，确认接口与历史教训。
2. 确认任务属于"用户已提供表结构的模块"，否则先向用户索取表结构，**不臆造**。
3. 用 `glob`/`read`/`grep` 定位涉及文件，不凭记忆改代码。

### 12.2 开发中（守）
1. 只改与需求相关的文件，**不添加冗余文件**。
2. 遵守第五~十一章全部规范。
3. 破坏性重构（改名/改生命周期/改表结构）必须先说明影响面再动手。

### 12.3 开发后（验 + 记）
1. **自检**：类型标注、判空、信号重复连接、`mouse_filter`、`texture_normal`、Variant 显式类型。
2. **验证**：确认无脚本报错（若环境允许跑 Godot 无头模式或经用户运行验证）；导航链路、存档读写、导表结果正确。
3. **更新文档（强制）**：
   - 接口有变化 → 更新 `接口文档.md`；
   - 任何修改 → 在 `项目进程汇报.md` 末尾追加「修改历史」条目（日期 + 标题 + 改动点 + 原因/经验）。

### 12.4 提交交付
- 交付时列出本次**主要产出文件**（Markdown inline code 路径），并说明是否更新了两份文档。

---

## 十三、验收标准与质量门槛

满足以下全部才算"完成"，否则不算交付：
- [ ] 无 GDScript 报错 / 警告（尤其 `Dictionary.get()` 用 `:=`、整数除法、`texture` 误用）。
- [ ] 新代码类型标注完整、判空完整、命名符合第四节。
- [ ] 数据变更走 CSV 导表，无手改 .tres。
- [ ] UI 改动遵守像素风规范 + UIManager 导航 + 子节点 `mouse_filter=2`。
- [ ] 存档字段变更做了向后兼容 + 版本迁移。
- [ ] 已同步更新 `接口文档.md` / `项目进程汇报.md`。
- [ ] 未新增与需求无关的文件。

---

## 十四、历史踩坑清单（务必避免重犯）

1. **信号重复连接**：`_ready()` 里 `on_create` 导致 11 处 ERROR → 信号连接只在 `on_create()` 一次。
2. **TextureButton 子节点 `mouse_filter=2`**，否则点击被 Label 拦截。
3. **TextureButton 底图**：`.tscn` 与脚本都必须用 `texture_normal`（无 `texture` 属性），并配 `ignore_texture_size = true`。
4. **Variant 返回值显式类型**（`JSON.parse_string`、`Dictionary.get`），禁用 `:=`。
5. **Godot 4 无 `get_tree().has_node()`**，用 `get_tree().root.has_node()`。
6. **`AudioServer.set_bus_volume_db` 传 int 索引**（先 `get_bus_index()`）。
7. **动态实例化场景先 `add_child()` 再访问 `@onready`**，否则空指针。
8. **场景切换后 Autoload 的 ui_root 失效**（`change_scene_to_file` 销毁旧场景），`open_ui` 需回退到 `get_tree().root`。
9. **编辑器保存会清理未用 ext_resource**，勿留悬空纹理引用。
10. **整数除法**：`int(seconds) / 3600` 会截断 → 用 `int(seconds / 3600.0)`。
11. **CSV 被 Godot 误当翻译表导入**：data/ 下产生 `.translation` 冗余 → 已根治：`.csv.import` 内 `importer="keep"`；且源表已全面改用 `.xlsx`（Godot 不识别该扩展名，根本不会导入）。
12. **无源表的表是"孤儿数据"**：擅自造表（无 xlsx 源）会导致数据源不一致，最终被清理——新增表必须先建源表再导表。
13. **中文系统 Excel 另存 CSV 默认是 GBK**：导表器按 UTF-8 读会把中文解成 `U+FFFD` 并**静默写入 .tres**，且不同文字可能损坏成同一串乱码（`手枪`/`步枪` 曾都变成 `��ǹ`）。现已改用 xlsx + CSV 编码校验拦截。
14. **xlsx 不会为空单元格写 `<c>` 节点**：解析必须按 `r="B3"` 坐标换算列号补齐空列/空行，否则字段整体错位。
15. **TextureButton 的 `texture` 属性不存在**：全项目曾有 20 个按钮写成 `texture = ExtResource(...)` 被静默丢弃，底图从未渲染过；且底图 2240×1680，正确设 `texture_normal` 后若不加 `ignore_texture_size = true` 会把布局撑爆。二者必须同时满足。
16. **Panel 不是容器**：`_create_list_row` 返回的 Panel 添加子节点后必须 `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`，否则内容不随行宽铺开。

---

## 十五、现状诊断与整改清单

> 2026-08-19 已完成一次大清理：回归 `data/` 4 张 CSV，删除无 CSV 的 weapon_table/upgrade_table 及派生代码（商店/装备/局外养成），存档精简为金币 + 统计。
> 2026-08-20 已完成：源表全面迁移到 `.xlsx`（6 张）、导表器支持 xlsx、`.translation` 冗余根治、全项目 34 个 TextureButton 底图修正、商店/武器模块落地。以下为剩余待办。

### 15.1 建议整改（P1，需用户确认）
1. **文件命名统一**：`Gamemanager.gd` → `game_manager.gd`，`startui.gd` → `start_ui.gd`（同步改 autoload/脚本引用）。
2. **表字段命名统一**：用户表字段为 camelCase/PascalCase（`enemyID`/`Id`/`maxLevel`）。建议由用户决定是否统一，统一时一次性迁移源表 + .tres + 引用代码。
3. **`confirm_dialog.gd` 重复 `_add_hover`**：与 UIBase 重复，可复用 UIBase 版本（需确认 ConfirmDialog 不继承 UIBase 的原因）。

### 15.2 待补（P2，随功能开发补齐）
5. **关卡与 Boss 待实现**：核心射击、哥布林刷怪和局内 Buff 已完成；正式关卡波数、击杀门槛与关底 Boss 仍需在设计确认后开发。
6. **商店/武器系统**：已基于 `shop` / `weapons` 表实现（购买 + 装备，落盘 `owned_weapons`/`equipped_weapon`）；数值待用户配置。
7. **哥布林正式美术资源缺失**：`Enemy.xlsx` 已预留 `goblin_scout_1`/`goblin_warrior_1`/`fast` 资源键，当前敌人仍使用代码绘制的尖耳色块占位造型。
8. **音频缺失**：设置页有音量 + AudioServer 引用 Master/Music/SFX 总线，但 `Audio/` 无音频文件。
9. **版本控制**：Git 基线已建立；提交时继续排除 `.godot/`、临时验证文件与本地用户设置。

---

## 十六、文档维护约定

- 本文件是规范，**改动需用户确认**，不随日常开发频繁变。
- 新增硬性规则 / 踩坑 / 架构决策时，追加到对应章节并在 `项目进程汇报.md` 记录。
- 三份文档职责：
  - `AI开发规范.md`（本文件）：**怎么开发**（规则、流程、质量门槛）。
  - `接口文档.md`：**有什么接口可用**（单例/类/场景/表结构）。
  - `项目进程汇报.md`：**改过什么、为什么**（历史与经验）。
