class_name GameLogger
extends RefCounted

## 游戏全局日志接口
##
## 所有业务系统通过此类的静态方法记录日志，
## 不依赖任何具体输出通道，也不依赖事件总线。
##
## 用法：
##   GameLogger.info("quest", "任务完成: %s", quest_name)
##   GameLogger.warn("inventory", "背包已满")
##   GameLogger.error("combat", "非法状态", { "unit": "boss" })
##
## 只要 GameLogger.initialize() 在游戏启动时被调用一次，
## 任何 .gd 文件的任何地方都可以直接调用这些静态方法。
## 遵循依赖倒置原则 (DIP)：高层策略依赖此抽象接口。

static var _router: LogRouter


## 初始化 GameLogger（游戏启动时调用一次）
static func initialize(router: LogRouter) -> void:
	_router = router


## 获取当前路由器（用于测试或检查状态）
static func get_router() -> LogRouter:
	return _router


# ----- 便捷静态方法 -----

static func debug(category: String, message: String, context: Dictionary = {}) -> void:
	_emit(LogEvent.Severity.DEBUG, category, message, context)


static func info(category: String, message: String, context: Dictionary = {}) -> void:
	_emit(LogEvent.Severity.INFO, category, message, context)


static func warn(category: String, message: String, context: Dictionary = {}) -> void:
	_emit(LogEvent.Severity.WARN, category, message, context)


static func error(category: String, message: String, context: Dictionary = {}) -> void:
	_emit(LogEvent.Severity.ERROR, category, message, context)


static func fatal(category: String, message: String, context: Dictionary = {}) -> void:
	_emit(LogEvent.Severity.FATAL, category, message, context)


# ----- 内部方法 -----

static func _emit(severity: LogEvent.Severity, category: String, message: String, context: Dictionary) -> void:
	if _router == null:
		# 优雅降级：GameLogger 未初始化时打印到控制台，不崩溃
		print("[GameLogger未初始化][%s][%s] %s" % [category, LogEvent.severity_label(severity), message])
		return

	var event := LogEvent.new(category, severity, message, context)
	_router.route(event)
