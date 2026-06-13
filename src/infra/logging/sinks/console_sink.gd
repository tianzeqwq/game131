class_name ConsoleSink
extends LogSink

## 控制台日志槽
##
## 将格式化后的日志文本输出到 IDE 控制台。
## 仅接收 INFO 及以上级别的日志，过滤 DEBUG 噪音。
## 自动添加类别和级别前缀。

## 最低输出级别（低于此级别的日志被忽略）
var min_severity: LogEvent.Severity = LogEvent.Severity.INFO


func _init(p_min_severity: LogEvent.Severity = LogEvent.Severity.INFO) -> void:
	min_severity = p_min_severity


func accepts(event: LogEvent) -> bool:
	return event.severity >= min_severity


func write_log(event: LogEvent) -> void:
	var prefix := "[%s][%s]" % [event.category, LogEvent.severity_label(event.severity)]
	print("%s %s" % [prefix, event.message])
