class_name LogSink
extends RefCounted

## 日志槽基类（抽象接口）
##
## 所有输出通道（控制台、UI、文件、网络等）均继承此类。
## 每个 Sink 自行决定：
##   1. accepts() — 是否接受某个类别的日志
##   2. write_log() — 如何格式化并输出
##
## 遵循开闭原则 (OCP)：新增输出通道无需修改任何现有代码。


## 判断此 Sink 是否接受指定类别和严重级别的日志。
## 子类可重写此方法实现过滤。
func accepts(event: LogEvent) -> bool:
	return true


## 写入一条日志。
## 子类在此方法中自行决定格式化方式（BBCode、纯文本、JSON 等）。
func write_log(event: LogEvent) -> void:
	pass
