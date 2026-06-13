# BattleScene — 外部调用接口

> 面向需要集成战斗系统的开发者。

---

## 基本用法

```gdscript
var battle = preload("res://src/scenes/battle/battle_scene.tscn").instantiate()
add_child(battle)

battle.init_battle(party_stats, enemy_stats)
battle.start_fight()

var result = await battle.battle_finished
print("战斗结果: ", result)

battle.queue_free()
```

---

## API 参考

| 方法/信号 | 说明 |
|-----------|------|
| `init_battle(player_stats, enemy_stats)` | 初始化战斗，传入双方队伍配置 |
| `start_fight()` | 开始战斗循环 |
| `battle_finished(result)` | 战斗结束时触发 |
| `is_in_battle` | 当前是否在战斗中 |

### 参数说明

- `player_stats: Array[CharacterStats]` — 玩家队伍
- `enemy_stats: Array[CharacterStats]` — 敌人队伍
- `result: Dictionary` — 战斗结果

### 结果字段

```gdscript
{
	"won": true/false,      # 玩家是否获胜
	"money": 150,           # 获得金币
	"drops": ["道具A"],     # 掉落物品
}
```

---

## 场景结构

```
BattleScene (Node3D)
├── WorldEnvironment    ← 赛博朋克后处理
├── Camera3D
├── Stage
│   ├── PlayerSpawns    ← 玩家出生点 (Marker3D ×4)
│   └── EnemySpawns     ← 敌人出生点 (Marker3D ×4)
└── CanvasLayer/UI
	├── CombatLog
	├── TimelineBar
	└── (运行时生成 HUD)
```

出生点位置由场景中 Marker3D 决定，无需硬编码。

---

## 调试入口

直接打开 `Main.tscn` 运行即可。策划可在 Inspector 中替换 `player_stats_templates` / `enemy_stats_templates` 来快速测试不同阵容。
