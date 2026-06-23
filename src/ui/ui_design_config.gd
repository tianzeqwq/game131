class_name UIDesignConfig
extends RefCounted

## ═══════════════════════════════════════════════════════════
##  UI 设计系统配置（Design Tokens）
##  基于 UI/UX Pro Max 生成的 Cyberpunk 设计语言
##  所有面板的视觉常量集中在此，修改一处全局生效
## ═══════════════════════════════════════════════════════════


# ── 字体（Font Resources） ──
# 推荐字体方案（从 UI/UX Pro Max typography 数据库选取）：
#   方案A（最推荐）: Orbitron（标题）+ Exo 2（正文）— 未来感 + 可读性
#   方案B: Syncopate（标题）+ Space Mono（正文）— 动感 + 终端感
#   方案C: Space Grotesk（标题）+ DM Sans（正文）— 现代科技
# 使用前需下载对应 .ttf 并创建 DynamicFont .tres 资源

## 标题字体资源路径（预留，当前使用 Godot 默认字体）
const FONT_PATH_HEADING: String = "res://assets/fonts/Orbitron/Orbitron-Regular.ttf"
## 正文字体资源路径
const FONT_PATH_BODY: String = "res://assets/fonts/Exo2/Exo2-Regular.ttf"
## 等宽字体（终端风格）
const FONT_PATH_MONO: String = "res://assets/fonts/SpaceMono/SpaceMono-Regular.ttf"


# ── 字体大小（基于 16px 基准缩放） ──
# UI/UX Pro Max 推荐：标题比正文大 50-100%，正文 14-16px 最佳可读性

## 标题/大号文字
const FONT_SIZE_TITLE: int = 22
## 增幅面板文字（← 增幅 →）
const FONT_SIZE_BOOST: int = 18
## 操作名称（攻击/技能/防御）
const FONT_SIZE_ACTION_NAME: int = 16
## 技能名称
const FONT_SIZE_SKILL_NAME: int = 15
## 描述文本
const FONT_SIZE_DESCRIPTION: int = 14
## 小号标签/状态
const FONT_SIZE_SMALL: int = 12


# ── 颜色（Cyberpunk Palette） ──
# 基于 UI/UX Pro Max Cyberpunk UI 风格 + Retro-Futurism
# 核心策略：深色背景 + 霓虹点缀，高对比度

## ── 主色调 ──

## 主色：霓虹紫（选中高亮、活跃边框）
const COLOR_PRIMARY: Color = Color(0.486, 0.227, 0.929)  # #7C3AED
## 次要色：淡紫（次级信息、描述背景）
const COLOR_SECONDARY: Color = Color(0.655, 0.545, 0.980)  # #A78BFA
## 操作/危险色：玫瑰红（攻击指令、危险状态、敌人高亮）
const COLOR_ACTION: Color = Color(0.957, 0.247, 0.369)  # #F43F5E
## 增幅激活色：亮青（保留原设计，BP 增幅状态）
const COLOR_BOOST_ACTIVE: Color = Color(0.0, 1.0, 0.8)  # #00FFCC

## ── 背景色 ──

## 最深层背景
const COLOR_BG_DEEP: Color = Color(0.063, 0.063, 0.137)  # #0F0F23
## 面板背景色（主菜单/子菜单）
const COLOR_PANEL_BG: Color = Color(0.04, 0.04, 0.1, 0.96)
## 描述面板背景色（半透明）
const COLOR_DESC_BG: Color = Color(0.03, 0.03, 0.1, 0.88)
## 增幅面板背景色
const COLOR_BOOST_BG: Color = Color(0.08, 0.08, 0.12, 0.92)

## ── 文字色 ──

## 主文字色（高对比）
const COLOR_TEXT_PRIMARY: Color = Color(0.886, 0.910, 0.941)  # #E2E8F0
## 描述文字（次级）
const COLOR_DESCRIPTION: Color = Color(0.72, 0.72, 0.82)
## 增幅未激活态
const COLOR_BOOST_INACTIVE: Color = Color(0.6, 0.6, 0.7)
## 禁用态
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4)

## ── 边框与装饰 ──

## 边框色（霓虹蓝紫）
const COLOR_BORDER: Color = Color(0.2, 0.7, 0.95, 0.5)
## 霓虹发光色（用于 glow 效果叠加）
const COLOR_NEON_GLOW: Color = Color(0.486, 0.227, 0.929, 0.3)  # 紫色发光

## ── 状态色 ──

## 原本的高亮色保留为选中光标色
const COLOR_HIGHLIGHT: Color = Color(0.0, 0.9, 1.0)  # #00E6FF
## 警告色（低血量、瘫痪）
const COLOR_WARNING: Color = Color(1.0, 0.3, 0.3)
## 增益色（正面状态）
const COLOR_BUFF: Color = Color(0.3, 0.9, 0.5)
## 倒下/死亡
const COLOR_DEAD: Color = Color(0.4, 0.4, 0.4)


# ── 动效参数 ──
# UI/UX Pro Max UX 准则：
#   - 进入动效用 ease-out（自然减速）
#   - 退出动效用 ease-in（加速消失）
#   - 避免 linear（机械感）
#   - 动效时长 150-300ms（用户已使用 CUBIC + EASE_OUT，符合最佳实践）

## 面板滑入时长（秒）
const ANIM_SLIDE_IN_DURATION: float = 0.25
## 面板滑出时长
const ANIM_SLIDE_OUT_DURATION: float = 0.2
## 淡入淡出时长
const ANIM_FADE_DURATION: float = 0.15
## 描述面板切换时长
const ANIM_DESC_SWITCH_DURATION: float = 0.1
## 飞离动效时长（执行技能时）
const ANIM_FLYOUT_DURATION: float = 0.35
## Glitch 抖动时长
const ANIM_GLITCH_DURATION: float = 0.3

## 进入动效缓动类型（推荐 ease-out）
const ANIM_EASE_IN: int = Tween.EASE_OUT
## 退出动效缓动类型（推荐 ease-in）
const ANIM_EASE_OUT: int = Tween.EASE_IN
## 默认缓动类型
const ANIM_TRANS_TYPE: int = Tween.TRANS_CUBIC

## 进入动效缩放起始值
const ANIM_SCALE_ENTER_FROM: float = 0.95
## 选中行放大倍率
const ANIM_HIGHLIGHT_SCALE: float = 1.05
## 目标选择放大倍率
const ANIM_TARGET_SCALE: float = 1.15


# ── 视觉效果参数 ──
# Cyberpunk 风格推荐效果：霓虹发光 + Glitch + 扫描线

## 霓虹发光强度（用于 add_theme_constant_override 的 outline_size）
const EFFECT_GLOW_OUTLINE_SIZE: int = 2
## 高亮选中时的发光强度
const EFFECT_GLOW_HIGHLIGHT_SIZE: int = 3
## 扫描线透明度（0=关闭，建议 0.03-0.08）
const EFFECT_SCANLINE_OPACITY: float = 0.05
## Glitch 偏移量（像素）
const EFFECT_GLITCH_OFFSET: float = 2.0
## 边框发光动画周期（秒，0=关闭）
const EFFECT_BORDER_PULSE_DURATION: float = 2.0
## 文字发光动画周期（秒）
const EFFECT_TEXT_GLOW_DURATION: float = 1.5


# ── 间距与尺寸 ──

## 描述面板相对于选中行的水平缩进（px）
const DESC_PANEL_X_OFFSET: float = 16.0
## 描述面板在选中行下方的间距（px）
const DESC_ANCHOR_GAP: float = 4.0
## 描述面板内部边距
const DESC_MARGIN_LEFT: float = 8.0
const DESC_MARGIN_TOP: float = 4.0
const DESC_MARGIN_RIGHT: float = 8.0
const DESC_MARGIN_BOTTOM: float = 4.0

## 子面板相对于父面板选中行的水平缩进（px）
const SUB_PANEL_X_OFFSET: float = 16.0
## 技能列表中每行高度（含间距）
const SKILL_ROW_HEIGHT: float = 22.0
## 技能列表面板上下内边距
const SKILL_LIST_PADDING: float = 12.0

## 行动面板（CombatActionPanel）每行高度（含间距）
const ACTION_ROW_HEIGHT: float = 26.0
## 行动面板上下内边距总和（含 VBox separation + ActionList separation + 边框）
const ACTION_LIST_PADDING: float = 16.0


# ── 圆角 ──

## 小圆角（描述面板）
const CORNER_RADIUS_SMALL: int = 3
## 中圆角（主菜单/子菜单面板）
const CORNER_RADIUS_MEDIUM: int = 4
## 大圆角
const CORNER_RADIUS_LARGE: int = 6


# ── 面板 StyleBox 工厂方法 ──

## 创建通用面板 StyleBox
## bg_color: 背景色，默认 COLOR_PANEL_BG
## corner_radius: 圆角，默认 CORNER_RADIUS_MEDIUM
## border: 是否显示 1px 边框，默认 true
## border_color: 边框颜色，默认 COLOR_BORDER
static func make_panel_style(
	bg_color: Color = COLOR_PANEL_BG,
	corner_radius: int = CORNER_RADIUS_MEDIUM,
	border: bool = true,
	border_color: Color = COLOR_BORDER
) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	if border:
		style.content_margin_left = 0
		style.content_margin_top = 0
		style.content_margin_right = 0
		style.content_margin_bottom = 0
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = border_color
	return style


## 创建 BoostPanel 专用 StyleBox（带边框，中圆角，特殊背景色）
static func make_boost_style() -> StyleBoxFlat:
	return make_panel_style(COLOR_BOOST_BG, CORNER_RADIUS_MEDIUM, true, COLOR_BORDER)
