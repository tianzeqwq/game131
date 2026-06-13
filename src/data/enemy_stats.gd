extends CharacterStats
class_name EnemyStats

## 敌人角色属性
##
## 在 CharacterStats 基础上增加敌人独有的属性：
##   - money / drop_items / held_item：掉落与奖励系统

@export_group("Loot & Rewards")
## 击败后获得的金币
@export var money: int = 0
## 掉落道具列表
@export var drop_items: Array[String] = []
## 携带道具（特殊的固定掉落）
@export var held_item: String = ""
