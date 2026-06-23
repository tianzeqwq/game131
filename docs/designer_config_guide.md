# 角色配置指南

> 说明如何配置角色、敌人和技能。
> 所有配置均在 Godot 编辑器中通过 `.tres` 资源文件完成，无需编写代码。

---

## 一、角色属性体系

角色属性按 Clean Architecture 原则分为三层继承结构：

```
CharacterStats（基类 — 所有角色共有属性）
├── PlayerStats（玩家独有：黑入强度）
└── EnemyStats（敌人独有：掉落/奖励）
```

### 属性上限一览

| 属性 | 上限 | 说明 |
|------|:----:|------|
| 速度 / 命中 / 会心 / 回避 | **999** | 核心战斗属性 |
| 护盾点数 | **99** | 物理 Break，每次命中 -1 |
| 热量 | **100** | 超额触发过载惩罚 |
| HP | 无硬上限（由策划决定） | 由 `max_hp` 控制 |

---

## 一A、基类 — CharacterStats（所有角色共用）

数据类：[`src/data/character_stats.gd`](src/data/character_stats.gd)

| 字段 | 类型 | 说明 |
|------|------|------|
| `unit_name` | String | 角色名称 |
| `avatar` | Texture2D | 头像（行动条用） |
| `sprite_frames` | SpriteFrames | **帧动画资源**。详见下方"动画配置"章节。 |
| `level` | int | 等级（≥1） |
| `ability_modifier` | float | 战斗外能力加成（装备等） |
| `bp` / `max_bp` | int | 当前/最大 BP |
| `max_hp` / `hp` | float | 最大/当前生命值 |
| `phys_atk` | float | 物理攻击力 |
| `digi_atk` | float | 数字攻击力 |
| `phys_def` | float | 物理防御力 |
| `digi_def` | float | 数字防御力 |
| `speed` | int | 速度（0~999，影响行动顺序 & 降低对方暴击率） |
| `accuracy` | int | 命中（0~999，提高命中率） |
| `evasion` | int | 回避（0~999，降低对方命中率） |
| `crit` | int | 会心（0~999，提高暴击率） |
| `max_shield_points` / `shield_points` | int | 护盾点数（0~99，物理 Break，每次命中 -1） |
| `max_firewall_hp` / `firewall_hp` | float | 防火墙 HP（数字 Break，按伤害值削减） |
| `weaknesses` | Array[String] | 弱点类型列表 |
| `skills` | Array[SkillConfig] | 可用技能列表 |
| `heat` | float | 热量（0~100） |

> **注意**：玩家角色的 shield / firewall 通常设为 0（无破防层），仅敌人拥有可击破的护盾/防火墙。

---

## 一B、玩家 — PlayerStats

数据类：[`src/data/player_stats.gd`](src/data/player_stats.gd)

在 CharacterStats 基础上增加：

| 字段 | 类型 | 说明 |
|------|------|------|
| `hacking_intensity` | float | 黑入强度（数字攻击补正） |

编辑器路径：`data/actors/players/`

### 现有角色参考

**玩家 — 黑客·零**（[`hacker_player.tres`](data/actors/players/hacker_player.tres)）
```
phys_atk=8, digi_atk=20, speed=12
hacking_intensity=15
weaknesses=["digital"]
skills=["黑客入侵", "超频冲击", "病毒扩散", "数据风暴"]
sprite_frames=res://data/animations/hacker_sprites.tres
```

---

## 一C、敌人 — EnemyStats

数据类：[`src/data/enemy_stats.gd`](src/data/enemy_stats.gd)

在 CharacterStats 基础上增加：

| 字段 | 类型 | 说明 |
|------|------|------|
| `money` | int | 击败后获得的金币 |
| `drop_items` | Array[String] | 掉落道具列表 |
| `held_item` | String | 携带道具（特殊的固定掉落） |

编辑器路径：`data/actors/enemies/`

### 现有角色参考

**敌人 — 巡逻无人机**（[`drone_enemy.tres`](data/actors/enemies/drone_enemy.tres)）
```
phys_atk=12, max_hp=60
max_shield=2, max_firewall=30
weaknesses=["physical", "digital"]
skills=["物理攻击"]
money=150
sprite_frames=res://data/animations/drone_sprites.tres
```

---

## 二、技能配置（SkillConfig）

编辑器路径：`data/skills/`
数据类：[`src/data/skills/skill_config.gd`](src/data/skills/skill_config.gd)

### 字段说明

| 字段 | 类型 | 说明 | 可选值 |
|------|------|------|--------|
| `skill_name` | String | 技能名称 | |
| `damage_type` | String | 伤害类型 | `"physical"` / `"digital"` |
| `damage_multiplier` | float | 技能基础伤害倍率 | 0.0 ~ |
| `accuracy` | float | 命中率 | 0.0 ~ 1.0 |
| `hit_mode` | String | 段数计算方式 | `"single"`(始终1段) / `"linear"`(1+增幅级数段) / `"random"`(固定段数) |
| `target_type` | String | 目标选择类型 | `"single"`(单体需选目标) / `"all_enemies"`(全体自动) / `"random"`(随机目标) |
| `random_hit_count` | int | 随机命中次数（仅 `hit_mode="random"` 生效） | 1~ |
| `boost_limit` | int | 增幅上限（1~3） | 1 / 2 / 3 |
| `boost_effect` | String | 增幅效果类型 | `"hits"`(加段数) / `"damage"`(加伤害倍率) |
| `heat_generated` | float | 产热量 | 0 ~ 100 |
| `requires_target` | bool | 是否需要目标 | true / false |

### 现有技能参考

| 技能 | 类型 | 倍率 | 命中 | 段数模式 | 目标 | 产热 | 增幅效果 |
|------|:----:|:----:|:----:|:--------:|:----:|:----:|:--------:|
| [`basic_attack_physical.tres`](data/skills/basic_attack_physical.tres) — 物理攻击 | physical | 1.0 | 95% | linear | single | 0 | hits |
| [`basic_hack_digital.tres`](data/skills/basic_hack_digital.tres) — 黑客入侵 | digital | 0.8 | 90% | linear | single | 0 | hits |
| [`overdrive_skill.tres`](data/skills/overdrive_skill.tres) — 超频冲击 | **digital** | 40.0 | 95% | single | single | 35 | damage |
| [`virus_spread.tres`](data/skills/virus_spread.tres) — 病毒扩散 | digital | 0.6 | 85% | single | **all_enemies** | 10 | damage |
| [`data_storm.tres`](data/skills/data_storm.tres) — 数据风暴 | digital | 0.5 | 85% | **random(3段)** | **random** | 15 | damage |

> **注意**：`"随机"` 目标类型的技能，每次命中独立随机选择目标，适合实现"五月雨斩"等多段乱击效果。
> 增幅上限 `boost_limit` 可在技能级别限制（最小1，最大3），UI 会同时受角色当前 BP 限制。

---

## 三、动画配置（SpriteFrames）

> 所有角色统一使用 SpriteFrames 帧动画系统。没有旧版单帧模式。

### SpriteFrames 是什么

SpriteFrames 是 Godot 内置的资源类型，可以在编辑器中管理动画帧序列。每个轨道包含一组图片帧，可独立设置循环和播放速度。

### 动画轨道命名约定

SpriteFrames 资源中的动画轨道必须使用以下命名：

| 轨道名 | 是否必须 | 是否循环 | 说明 |
|--------|:--------:|:--------:|------|
| `"idle"` | ✅ 必配 | ✅ 循环 | 待机/站立动画 |
| `"attack"` | ✅ 必配 | ❌ 一次 | 攻击动作（播完自动回到 idle） |
| `"hit"` | ❌ 可选 | ❌ 一次 | 受击动画（缺失则自动红色闪烁） |
| `"death"` | ❌ 可选 | ❌ 一次 | 死亡动画（缺失则自动淡出） |

### 配置步骤

```
1. 在 Godot 编辑器中，右键 → New Resource → SpriteFrames
2. 保存为 data/animations/角色名_sprites.tres
3. 在 SpriteFrames 编辑器中添加轨道：
   - "idle" 轨道：拖入待机帧图片，设 FPS=2~4, Looping=ON
   - "attack" 轨道：拖入攻击帧图片，设 FPS=8~12, Looping=OFF
   - "hit" 轨道（可选）：拖入受击帧图片，设 FPS=6~8, Looping=OFF
   - "death" 轨道（可选）：拖入死亡帧图片，设 FPS=4~6, Looping=OFF
4. 打开角色的 .tres 文件（如 data/actors/players/hacker_player.tres）
5. 将 xxx_sprites.tres 拖入 "sprite_frames" 字段
6. 保存，运行游戏
```

### 如何控制动画时长

| 参数 | 效果 | 示例 |
|------|------|------|
| 帧数 | 越多数帧越慢 | 3帧 ÷ 10FPS = 0.3s，6帧 ÷ 10FPS = 0.6s |
| FPS | 越高播放越快 | 4帧 ÷ 8FPS = 0.5s，4帧 ÷ 12FPS ≈ 0.33s |

攻击动画播完后自动回到 idle，代码等待 `animation_finished` 信号。

### 动画缺失回退

- 缺少 `hit` 轨道 → 自动红色闪烁
- 缺少 `death` 轨道 → 自动淡出消失

### 现有动画资源

| 角色 | SpriteFrames 文件 | 包含轨道 |
|------|:-----------------:|:--------:|
| 黑客·零 | [`data/animations/hacker_sprites.tres`](data/animations/hacker_sprites.tres) | `idle`（单帧/3FPS 循环）, `attack`（单帧/4FPS 一次） |
| 巡逻无人机 | [`data/animations/drone_sprites.tres`](data/animations/drone_sprites.tres) | `idle`（单帧/3FPS 循环） |

> 目前所有角色使用单帧 SpriteFrames（等效显示静态图片）。如需让角色真正动起来，只需打开对应的 SpriteFrames 文件，把多帧序列图片拖入轨道即可。

---

## 四、战斗机制说明

### Break（破防）

| 途径 | 触发条件 | 削减方式 | 依赖弱点 |
|------|----------|----------|----------|
| 物理 Break | 护盾归零 | 每次命中 -1 点 | `weaknesses` 含 `"physical"` |
| 数字 Break | 防火墙归零 | 按伤害值削减 | `weaknesses` 含 `"digital"` |

Break 效果：跳过行动 → 受伤害 2.0 倍 → 恢复后绝对先手

### BP 增幅

| 增幅 | 消耗 BP | 物理段数（`boost_effect="hits"`） | 伤害倍率（`boost_effect="damage"`） |
|:----:|:-------:|:--------:|:--------:|
| 0 | 0 | 1 | 1.0× |
| 1 | 1 | 2 | 1.5× |
| 2 | 2 | 3 | 2.0× |
| 3 | 3 | 4 | 2.5× |

### 热量

- `heat` 范围 0~100，使用技能积累
- ≥80：每回合开始受 `max_hp × 30%` 热损伤
- ≥100：过载，立即受 `max_hp × 30%` 伤害，heat 清零

### 行动顺序

```
ABSOLUTE_FIRST(3) > PREEMPTIVE(2) > NORMAL(1) > POSTEMPTIVE(0)
同层级：防御中 > 速度+随机 > 玩家优先
```
