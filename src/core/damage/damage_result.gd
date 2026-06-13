class_name DamageResult
extends RefCounted

## 伤害计算结果 DTO — 纯数据对象，无逻辑
##
## 只包含原始数值，不含任何格式化文本或 UI 信息。
## 日志格式化已交由 CombatLogFormatter 处理。
##
## 包含完整计算过程的中间值，供 CombatLogFormatter 展示详细计算过程。

# ============================================================
#  输出字段（计算结果）
# ============================================================

# 是否命中
var is_hit: bool = false
# 是否暴击
var is_crit: bool = false
# 是否打击了弱点属性
var is_weakness: bool = false

# 演算伤害（clamp 前的原始值）
var raw_damage: float = 0.0
# 执行伤害（clamp + 随机浮动 + 强制免伤后，已四舍五入）
var final_damage: float = 0.0
# 有效伤害（不超过目标剩余 HP）
var effective_damage: float = 0.0

# ============================================================
#  计算过程中间值（供详细日志展示）
# ============================================================

# 阶段 4: 基础伤害计算
var atk_stat: float = 0.0        # 攻击方攻击力（phys_atk / digi_atk）
var def_stat: float = 0.0        # 受击方防御力（phys_def / digi_def）
var def_multiplier: float = 0.5  # 防御倍率（0.5 正常 / 0.65 防御状态）
var attack_value: float = 0.0    # 攻击值 = atk_stat × skill_mult
var defense_value: float = 0.0   # 防御值 = def_stat × def_mult
var base_damage: float = 0.0     # 基础伤害 = max(0, 攻击值 - 防御值) × bp_mult

# 阶段 5: 演算伤害
var ability_mod: float = 1.0     # 能力加成
var status_mod: float = 1.0      # 状态加成总倍率
var level_mult: float = 0.58     # 等级倍率
var calculated_damage: float = 0.0 # 演算伤害 = base × ability × status × level

# 阶段 6: 执行伤害
var random_factor: float = 1.0   # 随机浮动因子
var forced_reduction: float = 1.0 # 强制免伤

# 上下文参数（供详细日志展示）
var skill_multiplier: float = 1.0  # 技能倍率
var bp_multiplier: float = 1.0     # BP 倍率
var hp_before_damage: float = 0.0  # 受击前 HP（用于展示有效伤害计算）

func _to_string() -> String:
	return "DamageResult(is_hit=%s, is_crit=%s, is_weakness=%s, raw=%.1f, final=%.1f, effective=%.1f)" % [
		is_hit, is_crit, is_weakness, raw_damage, final_damage, effective_damage
	]
