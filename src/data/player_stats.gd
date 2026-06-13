extends CharacterStats
class_name PlayerStats

## 玩家角色属性
##
## 在 CharacterStats 基础上增加玩家独有的属性：
##   - hacking_intensity: 黑入强度（数字攻击补正）

@export_group("Hacking")
## 黑入强度 — 玩家特有的数字攻击补正属性
@export var hacking_intensity: float = 10.0
