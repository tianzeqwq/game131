class_name UISink
extends LogSink

## UI 日志槽
##
## 将日志输出到 RichTextLabel 节点，支持 BBCode 染色。
## 默认只显示 "combat"、"flow"、"system" 类别的日志。
## 每个日志类别可附带自定义颜色。

var target_label: RichTextLabel

## 允许的日志类别列表（空数组 = 允许全部）
var allowed_categories: Array[String] = ["combat", "flow", "system"]

## 类别 → BBCode 颜色映射
var category_colors: Dictionary = {
	"combat": "white",
	"flow": "cyan",
	"system": "green",
}


func _init(p_label: RichTextLabel) -> void:
	target_label = p_label


func accepts(event: LogEvent) -> bool:
	if allowed_categories.is_empty():
		return true
	return event.category in allowed_categories


func write_log(event: LogEvent) -> void:
	if not is_instance_valid(target_label):
		return

	var color := _color_for(event)
	var line: String

	if event.severity >= LogEvent.Severity.ERROR:
		line = "[color=red]%s[/color]" % event.message
	elif event.severity == LogEvent.Severity.WARN:
		line = "[color=orange]%s[/color]" % event.message
	else:
		line = "[color=%s]%s[/color]" % [color, event.message]

	target_label.append_text(line + "\n")


## 获取类别对应的 BBCode 颜色
func _color_for(event: LogEvent) -> String:
	if category_colors.has(event.category):
		return category_colors[event.category]
	return "white"
