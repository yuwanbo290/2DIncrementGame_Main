# 哥布林动画资产说明

本目录按 `data/Enemy.xlsx` 的 `Enemy` 表逐行生成，共 17 个敌人。

## 最终资源规格

- 每个敌人包含 `idle` 与 `move` 两套动作，每套 6 帧。
- 单帧为 `128 x 128`、RGBA 透明 PNG。
- 角色统一朝右，脚底使用下中（bottom-center）锚点。
- `sheet.png` 为 `768 x 256` 的 6 列 x 2 行图集：上排 `idle`，下排 `move`。
- `preview.png` 仅用于检查动画，不应作为游戏运行时资源。
- `source/` 保存 ImageGen 原始结果，部分原图含烘焙棋盘底，不应直接导入游戏。

## Enemy ID 对照

| ID | 表内名称 | 最终目录 |
|---:|---|---|
| 1 | 小哥布林 | `enemy_001_small_goblin` |
| 2 | 哥布林 | `enemy_002_goblin` |
| 3 | 大哥布林 | `enemy_003_large_goblin` |
| 4 | 哥布林斥候 | `enemy_004_scout` |
| 5 | 哥布林弓箭手 | `enemy_005_archer` |
| 6 | 哥布林战士 | `enemy_006_warrior` |
| 7 | 哥布林骑士 | `enemy_007_knight` |
| 8 | 哥布林法师 | `enemy_008_mage` |
| 9 | 野蛮哥布林 | `enemy_009_barbarian` |
| 10 | 哥布林祭祀 | `enemy_010_shaman` |
| 11 | 哥布林boss1 | `enemy_011_boss_01_chieftain` |
| 12 | 哥布林boss2 | `enemy_012_boss_02_warlord` |
| 13 | 哥布林boss3 | `enemy_013_boss_03_warlock` |
| 14 | 哥布林boss4 | `enemy_014_boss_04_berserker` |
| 15 | 哥布林boss5 | `enemy_015_boss_05_high_shaman` |
| 16 | 哥布林boss6 | `enemy_016_boss_06_black_knight` |
| 17 | 哥布林boss7 | `enemy_017_boss_07_goblin_king` |

## Godot 导入建议

优先使用每个目录下的 `idle/` 与 `move/` 独立帧创建 `SpriteFrames`。如果使用图集切片，则导入 `sheet.png`，按 `6` 列、`2` 行切分，并将第一行设为 `idle`、第二行设为 `move`。
