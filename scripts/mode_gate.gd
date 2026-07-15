extends Node
## ModeGate —— 编辑↔运行 状态权限闸
## 全局唯一(autoload)，持有"当前态"这个唯一真值。
## 切态时广播 mode_changed 信号；各功能自己 connect 并响应（关门/开门）。
## 设计依据：design.md「三、编辑态↔运行态」无缝切换。
## gizmo3D.gd 的 _unhandled_input 在 !visible 时退出，故"运行态隐藏 gizmo"
## 这个动作由 main.gd 订阅本信号完成，不再散落判断 if current_mode == EDIT。

enum AppMode { EDIT, RUN }
enum EditSubMode { MAP, ORBIT }

signal mode_changed(mode: AppMode)
# 注:此处给信号加类型注解会触发 Godot 4.7 的 autoload 遮蔽检查
# (Class "ModeGate" hides an autoload singleton),故 EditSubMode 信号暂不加类型。
signal edit_sub_mode_changed

var _current_mode: AppMode = AppMode.EDIT
var _edit_sub_mode: EditSubMode = EditSubMode.MAP


func _ready() -> void:
	# 开机默认编辑态 + 地图模式(正交俯视)。先广播一次,让已挂树上的功能对齐初始态。
	emit_signal("mode_changed", _current_mode)
	emit_signal("edit_sub_mode_changed", _edit_sub_mode)


func switch_to(mode: AppMode) -> void:
	if mode == _current_mode:
		return
	_current_mode = mode
	emit_signal("mode_changed", mode)


func switch_edit_sub_mode(sub: EditSubMode) -> void:
	# 子模式(地图/自由视角)与主态(编辑/运行)独立,两个态都能切。
	# 真值仍只在 ModeGate 一处,符合"功能自报归属"规矩。
	if sub == _edit_sub_mode:
		return
	_edit_sub_mode = sub
	emit_signal("edit_sub_mode_changed", sub)


func current() -> AppMode:
	return _current_mode


func current_sub_mode() -> EditSubMode:
	return _edit_sub_mode


func is_edit() -> bool:
	return _current_mode == AppMode.EDIT


func is_run() -> bool:
	return _current_mode == AppMode.RUN


func is_sub_map() -> bool:
	return _edit_sub_mode == EditSubMode.MAP


func is_sub_orbit() -> bool:
	return _edit_sub_mode == EditSubMode.ORBIT
