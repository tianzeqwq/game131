class_name CombatLogRouter
extends LogRouter

## ⚠️ 已废弃 — 请使用 LogRouter + CombatLogAdapter 替代
##
## 保留仅为向后兼容。
## 新代码请直接使用：
##   var router = LogRouter.new()
##   router.register_sink(...)
##   GameLogger.initialize(router)
##   CombatLogAdapter.new().start_listening()
##
## 此废弃类仍可工作，但内部已委托给新的通用组件。

var _adapter: CombatLogAdapter


## 开始监听 CombatEventBus（已废弃）
func start_listening() -> void:
	_adapter = CombatLogAdapter.new()
	_adapter.start_listening()


## 停止监听（已废弃）
func stop_listening() -> void:
	if _adapter:
		_adapter.stop_listening()
		_adapter = null
