class_name FileSink
extends LogSink

## 文件日志槽
##
## 将日志持久化到本地日志文件。
## 接收全部类别和级别，自动添加时间戳。
## 适用于发布版本的 Bug 复现分析。

var log_file_path: String = "user://logs/game.log"
var file: FileAccess


func _init(p_file_path: String = "user://logs/game.log") -> void:
	log_file_path = p_file_path
	DirAccess.make_dir_recursive_absolute("user://logs")
	file = FileAccess.open(log_file_path, FileAccess.WRITE_READ)
	if file:
		file.seek_end()
		file.store_line("--- New Log Session: %s ---" % Time.get_datetime_string_from_system())


func write_log(event: LogEvent) -> void:
	if not file:
		return

	var timestamp := Time.get_time_string_from_system()
	var severity := LogEvent.severity_label(event.severity)
	var line := "[%s][%s][%s] %s" % [timestamp, event.category, severity, event.message]

	# 附加结构化上下文（如果有）
	if not event.context.is_empty():
		line += " | data: %s" % JSON.stringify(event.context)

	file.store_line(line)
	file.flush()
