class_name LogRouter
extends RefCounted

## 日志路由器（泛化版）
##
## 接收 LogEvent，分发给所有注册的 LogSink。
## 每个 Sink 通过 accepts() 自行决定是否接收。
## 替换了原先战斗专用的 CombatLogRouter。
##
## 遵循开闭原则 (OCP)：新增输出通道只需注册新 Sink。

var sinks: Array[LogSink] = []


## 注册一个 Sink
func register_sink(sink: LogSink) -> void:
	sinks.append(sink)


## 移除一个 Sink
func remove_sink(sink: LogSink) -> void:
	sinks.erase(sink)


## 清空所有 Sink
func clear_sinks() -> void:
	sinks.clear()


## 路由一条日志事件到所有接收它的 Sink
func route(event: LogEvent) -> void:
	for sink in sinks:
		if sink.accepts(event):
			sink.write_log(event)
