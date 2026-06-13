extends Node

## 全局战斗事件总线 (Autoload)
##
## 作为领域事件的集散地，战斗核心逻辑只通过此总线发布事件，
## 日志系统及其他观察者通过监听此总线获取事件。
## 遵循依赖倒置原则 (DIP)：核心逻辑不依赖具体输出通道。

signal event_dispatched(event: CombatEvent)

func publish(event: CombatEvent) -> void:
	event_dispatched.emit(event)
