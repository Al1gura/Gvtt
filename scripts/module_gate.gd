extends Node
## ModuleGate —— 模组/地点/带团存档 的跨场景全局真值闸
##
## ⚠ 不写 class_name:autoload 单例名 ModuleGate 本身就是全局访问名。
##   若同时声明 class_name ModuleGate,Godot 解析 main.gd 时会把 ModuleGate
##   当成"脚本类"而非 autoload 实例 → 报"不能直接调非静态方法,要先建实例"。
##   autoload 不需要 class_name(文档 gdd_0374),删掉更干净。
##
## 与 ModeGate 平级的 autoload,持有"当前在哪个模组 / 第几个地点 /
## 当前带团 session"这个跨场景唯一真值,对齐 ModeGate"功能自报归属"规矩。
## 职责边界:ModeGate 管编辑/运行权限;ModuleGate 管当前这场跑团走到哪。正交。
##
## 2026-07-09 落地第一段:开机自动建一个"测试模组",左栏场景存进它。
## ⚠ "测试模组"是临时硬编码名,等"导入/新建模组"UI 做出来用户能自命名+多模组时,
##   这段硬编码会移除——已标 TODO,不让它成永久技术债。
##
## 设计依据:docs/multi_scene_draft.md 第 1/3/5/6 节。

signal current_location_changed(location_name: String)
## 场景列表有变(新增/保存/重命名)→ 左栏 UI 订阅刷新。
signal scene_list_changed

## 当前模组的清单资源(ModuleManifest),决定这场装了哪些地点。
var _current_manifest: ModuleManifest = null

## 当前带团存档(Playthrough)。第一段不真用带团存档,先建空壳占位。
var _current_session: Playthrough = null

## 当前所在地点的显示名。第一段=当前选中场景名;切场景广播。
var _current_location_name: String = ""

## ⚠ 临时硬编码:默认模组名。等"新建/导入模组"UI 做出来后移除此硬编码。
const DEFAULT_MODULE_NAME: String = "测试模组"

## 这个模组的场景存盘根目录。场景文件放 modules/<模组名>/_canonical/<场景名>.scn。
func _module_dir() -> String:
	return "res://modules/" + DEFAULT_MODULE_NAME + "/_canonical"


func _ready() -> void:
	# 开机自动建一个默认模组(内存里的 ModuleManifest,先不落盘到 modules/...manifest.tres,
	# 第一段纯内存管理就够给左栏列场景用;落盘整模组是 P4 后续步骤)。
	_current_manifest = ModuleManifest.new()
	_current_manifest.module_name = DEFAULT_MODULE_NAME
	_current_manifest.start_location = ""
	_current_session = Playthrough.new()
	_current_session.session_name = "默认带团"
	_current_session.module_path = ""
	_current_session.current_location = ""
	# 确保场景存盘目录存在(不存在则建)。依据 DirAccess.make_dir_recursive_absolute(gdd_1241 第115行)。
	if not DirAccess.dir_exists_absolute(_module_dir()):
		DirAccess.make_dir_recursive_absolute(_module_dir())


## 新加一个场景到当前模组:自动起名"场景N"(跳过内存清单已用名),返回显示名。
## 由 main.gd 的"新建场景"按钮调用。场景这时还没有存盘文件(空场景);真正点
## "保存场景"才把当前编辑态节点树 pack 进来落到 canonical_path 指向的文件。
## ⚠ 开机不扫磁盘已有 .scn 进清单——存了场景但没存进"模组存档"的,关软件就废弃
##   (2026-07-13 用户拍板:如同正常软件,关掉没存进模组文件的就丢)。真存档靠将来
##   "模组存档系统"(P4,导出模组=把清单+各场景打包成模组文件)。当前 _canonical/*.scn
##   是临时落盘,不当作持久存档。所以起名只跳内存清单已用名即可,不跳磁盘(磁盘散文件
##   开机不认,不会撞名)。
func add_scene() -> String:
	# 收集清单已用名
	var used: Dictionary = {}
	for l: LocationRef in _current_manifest.locations:
		used[l.display_name] = true
	var n: int = _current_manifest.locations.size() + 1
	var name: String = "场景" + str(n)
	while used.has(name):
		n += 1
		name = "场景" + str(n)
	var ref: LocationRef = LocationRef.new()
	ref.display_name = name
	# canonical_path:存盘文件路径,本场景存盘时填(starts empty 表示还没存过)。
	ref.canonical_path = _module_dir() + "/" + name + ".scn"
	_current_manifest.locations.append(ref)
	if _current_manifest.start_location == "":
		_current_manifest.start_location = name
	_current_location_name = name
	scene_list_changed.emit()
	return name


## 保存当前编辑态的节点树到"指定场景"的存盘文件。由 main.gd"保存场景"按钮调。
## target_name = 要存进哪个场景(场景文件名=显示名)。若该场景还没登记,顺手 add 一条。
## 若 root 为空,报错返回。返回 ResourceSaver 的 Error code。
func save_current_scene(target_name: String, scene_root: Node) -> int:
	if scene_root == null or not is_instance_valid(scene_root):
		push_error("ModuleGate.save_current_scene: scene_root 无效")
		return ERR_INVALID_PARAMETER
	var ref: LocationRef = _find_location(target_name)
	if ref == null:
		# 还没在清单里 → 自动加一条占位再存
		ref = LocationRef.new()
		ref.display_name = target_name
		ref.canonical_path = _module_dir() + "/" + target_name + ".scn"
		_current_manifest.locations.append(ref)
		if _current_manifest.start_location == "":
			_current_manifest.start_location = target_name
	# 真正存盘:走 module_io 的 save_scene_tree(内含 owner 陷阱正面修复)。
	var err: int = ModuleIo.save_scene_tree(scene_root, ref.canonical_path)
	if err == OK:
		_current_location_name = target_name
		scene_list_changed.emit()
	return err


## 主场景根要 pack 时,main.gd 把"当前 VM 场景外真正装景物的那棵子树"传进来。
## 本版第一段:整个 main 的 Main 节点直接当 scene_root 传(它的子物件事前已 set_owner)。
## 详见 main.gd 调用点注释。


func _find_location(target_name: String) -> LocationRef:
	for l: LocationRef in _current_manifest.locations:
		if l.display_name == target_name:
			return l
	return null


## 返回当前模组的场景显示名数组,供左栏 UI 建按钮。顺序=加进来的先后。
func list_scene_names() -> Array[String]:
	var out: Array[String] = []
	if _current_manifest == null:
		return out
	for l: LocationRef in _current_manifest.locations:
		out.append(l.display_name)
	return out


## 选定"当前场景"=点左栏某场景按钮时调。第一段只切当前指针,不真换场景树
## (换场景树=切地点,要 pack 当前+load 目标,下一步专题做)。
func set_current_location(name: String) -> void:
	if _current_location_name == name:
		return
	_current_location_name = name
	current_location_changed.emit(name)


# —— 切地点的完整实现(第一段不做,留 TODO 见草案第 4 节+第 8 节坑 3/4)——

## 切到另一个地点。真正落地按 docs/multi_scene_draft.md 第 4 节做:
## 1) 当前地点 pack 存进 _current_session 对应槽位(切幕写盘,决策4)
## 2) 读入目标地点(没进过则从底本 _canonical 复制初始状态)
## 3) 挂回场景树 + 广播 current_location_changed
## 4) 主相机/投屏 CastView 订阅信号重对焦/重连 World3D(草案坑3)
## 编辑态切地点=换舞台备团 vs 运行态切地点=带团走到新地方(草案坑4)须按 ModeGate 分流。
func switch_location(location_name: String) -> void:
	if _current_location_name == location_name:
		return
	# TODO: 第一段先不上真换树(只切指针);真换树等切地点专题。
	_current_location_name = location_name
	current_location_changed.emit(location_name)


func current_location() -> String:
	return _current_location_name


func current_manifest() -> ModuleManifest:
	return _current_manifest


func current_session() -> Playthrough:
	return _current_session