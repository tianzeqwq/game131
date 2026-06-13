class_name LogEvent
extends RefCounted

## 日志事件（通用数据结构）
##
## 所有业务系统通过此结构描述一条日志记录。
## 不包含任何格式化信息，仅携带纯数据。
## 遵循 DIP：高层策略依赖此抽象，而非具体输出通道。

## 日志严重级别
enum Severity {
	DEBUG,   ## 调试信息，仅开发阶段关注
	INFO,    ## 常规信息
	WARN,    ## 警告，潜在问题
	ERROR,   ## 错误，功能受影响
	FATAL,   ## 致命错误，系统可能崩溃
}

## 来源系统类别，如 "combat", "quest", "inventory", "system"
var category: String

## 严重级别
var severity: Severity

## 人类可读消息（不应包含富文本标记）
var message: String

## 结构化上下文数据，供 AnalyticsSink 等分析型 Sink 消费
var context: Dictionary

## 时间戳（Unix 时间，秒）
var timestamp: float


func _init(p_category: String, p_severity: Severity, p_message: String, p_context: Dictionary = {}) -> void:
	category = p_category
	severity = p_severity
	message = p_message
	context = p_context
	timestamp = Time.get_unix_time_from_system()


## 获取严重级别标签（用于纯文本输出）
static func severity_label(s: Severity) -> String:
	match s:
		Severity.DEBUG: return "DEBUG"
		Severity.INFO:  return "INFO"
		Severity.WARN:  return "WARN"
		Severity.ERROR: return "ERROR"
		Severity.FATAL: return "FATAL"
	return "UNKNOWN"
