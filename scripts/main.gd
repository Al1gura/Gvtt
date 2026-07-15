extends Node3D
## Gvtt — 3D 俯视交互地图引擎
## P1: 编辑↔运行切换 + 资产管理 + 地面纹理替换
##
## 编辑↔运行 状态由全局 autoload ModeGate 统一管理。
## main.gd 订阅 ModeGate.mode_changed 信号，在信号回调里集中处理
## 面板开关、gizmo 隐藏等跨态权限。状态真值只有 ModeGate 一处，
## _on_mode_btn_pressed 也只调 ModeGate.switch_to，不再自己改状态。

@export var grid_size: int = 100
@export var grid_color: Color = Color(0.5, 0.5, 0.6, 0.3)
@export var ground_color: Color = Color(0.3, 0.28, 0.24, 1.0)
@export var ground_tile_size: float = 2.0      ## 当前地面纹理平铺尺寸（单位/格，默认 2 格）

## 自由视角轨道相机参数（球坐标模型）。
## yaw=偏航(左右转,弧度), pitch=俯仰(抬头低头,弧度,0=水平 PI/2=正上),
## distance=相机离焦点多远, focus=相机盯着看的那个点。
## 依据：社区主流做法(three.js OrbitControls 移植思路),见 LucaJunge/godot_orbit_controls。
## 不直接拷其代码(GPL 不兼容本仓 MIT),仅参考数学模型,用 Godot 4.7 标准 API 自实现。
const ORBIT_MIN_DIST: float = 3.0
const ORBIT_MAX_DIST: float = 80.0
const ORBIT_MIN_PITCH: float = 0.01      ## 防 pitch 到 0 翻转
const ORBIT_MAX_PITCH: float = 1.5707    ## 接近 PI/2,不顶到正上
const ORBIT_DEFAULT_DIST: float = 25.0
const ORBIT_DEFAULT_YAW: float = 0.6      ## 约 34°
const ORBIT_DEFAULT_PITCH: float = 1.0   ## 约 57°,接近原 55° 倾斜

## 默认场景配置(2026-07-10 修 bug2:"默认场景该有专门记录")。
## 开机起始场景 + 新建场景都走这套:纯空舞台(无物件)+ 默认地面纹理/平铺/场景大小。
## 将来想改默认场景(比如默认铺某纹理、默认带示例物件)只改这里一处。
## 2026-07-15 改:场景支持长方形(宽≠高),地面边长按宽×高、网格画到宽×高范围。
## 2026-07-15 改:默认贴图走"铺满拉伸"模式——一张图永远铺满整个地面,场景变长方形/改大小
## 贴图都跟着拉伸铺满(不按格数重复)。其他纹理仍按 ground_tile_size 格数重复铺。
const DEFAULT_GROUND_TEX_BASE: String = "uv_checker_4096_v2"   ## 默认贴图(UV 检测图新版,assets/textures/ground/uv_checker_4096_v2/)
const DEFAULT_GROUND_TILE: float = 100.0       ## 非默认纹理的默认平铺格数(默认贴图走铺满模式,此值不影响它)
const DEFAULT_SCENE_WIDTH: float = 100.0        ## 默认场景宽(米),地面 X 轴边长,网格画到该范围
const DEFAULT_SCENE_HEIGHT: float = 100.0       ## 默认场景高(米),地面 Z 轴边长,网格画到该范围

## 窗口大小/位置的记忆与默认值。
## 第一次打开(没记忆文件)用 DEFAULT_WINDOW_*；之后用上次关掉时存的大小/位置。
## 存进 user://window.cfg（ConfigFile），打包成 exe 后 user:// 照样在。
## 依据：gdd_1239 ConfigFile（set_value/get_value/save/load）、gdd_0202 第12-22行
## 关程序截 NOTIFICATION_WM_CLOSE_REQUEST、gdd_0786 Window.size/position。
const WINDOW_CFG_PATH: String = "user://window.cfg"
const DEFAULT_WINDOW_WIDTH: int = 1280
const DEFAULT_WINDOW_HEIGHT: int = 720

## "游玩视角"——编辑态自由视角子模式下调好、按"保存视角"存下的那套。
## 权威只有这一套:运行态开机自动套用,运行态"恢复视角"也回到这套。
var _saved_orbit_dist: float = ORBIT_DEFAULT_DIST
var _saved_orbit_yaw: float = ORBIT_DEFAULT_YAW
var _saved_orbit_pitch: float = ORBIT_DEFAULT_PITCH
var _saved_orbit_focus: Vector3 = Vector3.ZERO

## 当前自由视角实时状态(可被 GM 临场转动,与 saved 不同则按"恢复"回到 saved)。
var _orbit_dist: float = ORBIT_DEFAULT_DIST
var _orbit_yaw: float = ORBIT_DEFAULT_YAW
var _orbit_pitch: float = ORBIT_DEFAULT_PITCH
var _orbit_focus: Vector3 = Vector3.ZERO

## 地图模式(正交俯视)状态:缩放范围 + 平移焦点。
var _map_size: float = 10.0
var _map_focus: Vector3 = Vector3.ZERO

## 右键旋转 / 中键平移时的"上一帧鼠标位置",用 event.position 差分累加。
var _orbit_dragging_yaw: bool = false
var _orbit_dragging_pan: bool = false
var _orbit_last_mouse: Vector2 = Vector2.ZERO

var camera: Camera3D
var _grid_manager: GridManager  ## 网格管理器（替换旧 _draw_grid PlaneMesh shader）

## 模型类栏位配置：每个栏位一项 {label, category, builtin_dir}。
## label=左栏显示名；category=user://library/<category>/ 子目录名；
## builtin_dir=res://assets/<子目录>/ 自带模型扫描目录（空字符串=没有自带目录，全靠导入）。
## 这些栏位共用同一套"合并自带+导入列表→建按钮→选中→左键放置"逻辑（_model_panelss 管）。
## 顺序对应左栏从上到下（地面纹理单独建，插在 terrain 和 wall 之间，不进此循环）。
const MODEL_PANELS: Array[Dictionary] = [
	{"label": "Token", "category": "token", "builtin_dir": "res://assets/tokens"},
	{"label": "地形", "category": "terrain", "builtin_dir": "res://assets/terrain"},
	{"label": "墙体", "category": "wall", "builtin_dir": "res://assets/walls"},
	{"label": "装饰", "category": "decor", "builtin_dir": "res://assets/models"},
	{"label": "交互物体", "category": "interactable", "builtin_dir": "res://assets/interactables"},
	{"label": "光源", "category": "light", "builtin_dir": "res://assets/lights"},
]

## 各模型栏位的运行时状态：category → {items, active_idx, container, import_btn}。
## items=Array[Dictionary] 每项 {source, path}（builtin=ResourceLoader.load(PackedScene)，
## imported=LibraryManager.load_model_runtime）；active_idx=当前选中项；container=按钮容器。
var _model_panelss: Dictionary = {}
var _ground_sets: Array[Dictionary] = []
var _active_ground_ts: Dictionary = {}          ## 当前选中的地面纹理 set
var _ui_layer: CanvasLayer
var _mode_btn: Button
## 场景根(关卡的"舞台"外壳)。骨架层挂这里:相机/光照/地面/网格——
## 这些是 GM 看场景的眼睛和基础舞台,所有场景共用,**不存盘**。
## 顶栏 UI/gizmo/cast_view 留在 Main 上不进它。
## 依据:Node owner 机制(gdd_0512 第691行 pack 只存 owner=根的节点)。
var _scene_root: Node3D
## 内容层根(场景特有内容)。建筑物件挂这里——这是各场景不同的部分,
## **存盘只 pack 这一棵**:切场景 = 清它的孩子 + 读目标场景挂回。
## 在 _scene_root 下、owner=_scene_root,但存盘时单独 pack 它(不是 pack _scene_root)。
## 2026-07-10 方案乙:骨架/内容两层分离,相机/光/地面不随场景存读,
## 避免"清空重建整棵"导致相机/投屏/gizmo 引用全废的连带影响。
var _content_root: Node3D
var _ground: MeshInstance3D  ## Ground 节点引用(便于换纹理时访问,Ground reparent 后 $Ground 失效)
var _scene_section: VBoxContainer  ## 左栏"场景"节内容容器,刷新列表时往里填场景按钮
var _save_scene_btn: Button  ## 保存场景按钮:把当前编辑态存进当前选中场景
var _new_scene_btn: Button   ## 新建场景按钮:自动起名场景N+1、切个空场景编辑
var _current_scene_name: String = ""  ## 左栏当前选中(高亮)的场景名,保存存进它
var _pending_switch_to: String = ""  ## 弹窗期间记"要切去哪个场景",回调读它
var _switch_dialog: AcceptDialog = null  ## 切场景确认弹窗(三选一)
## 场景脏标记:true=当前场景有未存改动,切场景时弹窗提醒存;false=干净(刚存过/刚切入)就直接切不弹。
## 置脏点:放物件(_place_building)、换纹理(_on_ground_clicked)、改平铺(_on_tile_changed)。
## 清脏点:存盘成功(_on_save_scene_pressed)、切场景完成(_switch_to_scene)。修 bug2。
var _scene_dirty: bool = false
var _mode_label: Label
var _sub_btn: Button                ## 地图 ↔ 自由视角 切换(两态都显示)
var _save_view_btn: Button          ## 保存视角(仅编辑态显示)
var _restore_view_btn: Button       ## 恢复视角(仅运行态显示)
var _cast_btn: Button               ## 投屏开关(两态都显示，旁路 ModeGate)
## 投屏窗口控制。旁路于 ModeGate，编辑/运行两态都可开投屏。
## 定位见 docs/design.md「三、3.1」与 docs/architecture.md「3.6」。
var _cast_view: Node = null          ## CastView 实例（cast_view.gd）
var _scene_width_input: SpinBox     ## 场景宽输入框(左栏"场景"节下,X 轴边长)
var _scene_height_input: SpinBox   ## 场景高输入框(左栏"场景"节下,Z 轴边长)
var _left_panel: PanelContainer
var _prop_panel: PanelContainer          ## 属性面板(选中物件后弹,绑 EntityProperties)
var _prop_target: Node3D = null          ## 当前选中的物件根(属性面板绑它的 EntityProperties)
var _prop_target_props: EntityProperties = null  ## 选中物件的属性组件
var _prop_name_edit: LineEdit
var _prop_destructible_chk: CheckBox
var _prop_los_chk: CheckBox
var _prop_max_hp_spin: SpinBox
var _prop_cover_chk: CheckBox
var _prop_vis_chk: CheckBox
var _prop_title: Label
var _tool_label: Label
var _tile_slider: HSlider
var _tile_spinbox: SpinBox
var _tile_control_area: VBoxContainer             ## 平铺控制区容器（不选纹理时隐藏）

## 素材库导入相关。导入按钮挂各栏位顶部，FileDialog 选中文件后复制进
## user://library/<栏位>/（LibraryManager 管）。_import_fd 记当前要导进哪个栏位。
## 依据：gdd_0596 FileDialog（ACCESS_FILESYSTEM + FILE_MODE_OPEN_FILE + add_filter）。
var _import_fd: FileDialog = null                 ## 运行时文件选择框（导入模型用，选文件）
var _import_dir_fd: FileDialog = null             ## 运行时文件选择框（导入地面纹理用，选文件夹）
var _import_target_category: String = ""          ## 当前导入操作的目标栏位标识
var _ground_import_btn: Button = null             ## 地面纹理栏"导入纹理文件夹"按钮
var _ground_list_container: VBoxContainer = null  ## 地面纹理栏纹理按钮列表容器

## LibraryManager 脚本引用。用 load() 拿脚本再调静态方法，不直接写全局类名
## LibraryManager——因为新建脚本的 class_name 在运行态全局类表注册有滞后
## (devlog 2026-07-09/07-10 记过此缓存坑)，load() 立即可用、不依赖编辑器缓存。
var _library_mgr: GDScript = load("res://scripts/library_manager.gd")


func _ready() -> void:
	# 窗口最小尺寸兜底（锁字号模式下拖太小会挤乱 UI），先设再恢复窗口大小。
	# 依据：gdd_0786 Window.size/position/min_size、gdd_1239 ConfigFile。
	get_window().min_size = Vector2i(1024, 576)
	_apply_window_state()
	# 场景根(骨架层):相机/光/地/网格这些"GM 眼睛+基础舞台"挂它下、owner=它。
	# 所有场景共用,不存盘。main.gd 脚本/UI/gizmo/cast_view 留在 Main、不进它。
	_scene_root = Node3D.new()
	_scene_root.name = "SceneRoot"
	add_child(_scene_root)
	# 内容层根(场景特有内容):建筑物件挂它下。存盘只 pack 这棵;切场景=清它+读目标挂回。
	# 在 _scene_root 下,owner=_scene_root,但存盘单独 pack _content_root(不 pack _scene_root)。
	# 挂 SceneProps 脚本:用它存地面纹理信息(纹理组名+平铺尺寸),随内容层 pack 存进场景
	# 文件(修 bug1:此前纹理在 Ground 骨架层不存盘,所有场景共用最后一套)。
	_content_root = Node3D.new()
	_content_root.name = "ContentRoot"
	_content_root.set_script(load("res://scripts/scene_props.gd"))
	_scene_root.add_child(_content_root)
	_content_root.set_owner(_scene_root)
	_setup_camera()
	_setup_ground()
	_setup_cast_view()
	_init_grid_manager()
	_adopt_scene_content()
	_scan_all()
	_build_ui()
	# 多场景系统:开机=全新空模组(不扫磁盘旧 .scn,要用旧模组靠将来"导入模组")。
	# 内存清单空则建一个"场景1"作起始场景,选中它,并设成默认空场景状态。
	_sync_scene_list()
	if ModuleGate.list_scene_names().is_empty():
		ModuleGate.add_scene()  # 默认建场景1
	_current_scene_name = ModuleGate.current_location()
	if _current_scene_name == "" and not ModuleGate.list_scene_names().is_empty():
		_current_scene_name = ModuleGate.list_scene_names()[0]
		ModuleGate.set_current_location(_current_scene_name)
	# 开机起始场景=默认空场景(纯空舞台+默认纹理/平铺,无物件)。
	_apply_default_scene()
	_scene_dirty = false  # 开机干净
	_sync_scene_list()
	# 共享单套 gizmo(全场唯一):左键点中物件 select 它、手柄移到它身上;
	# 点空白 clear。多选(Shift 加选)暂不做。gizmo 是 GM 工具不进 _scene_root。
	_gizmo = Gizmo3D.new()
	_gizmo.name = "SharedGizmo"
	_gizmo.use_local_space = true
	# gizmo 是 GM 编辑工具,放 GM-only 渲染层(第20层)——主窗 GM 相机可见,
	# 投屏相机 cull_mask 关第20层看不到手柄,玩家不被编辑工具干扰。
	_gizmo.layers = 1 << (GvttRenderLayers.RENDER_LAYER_GM_ONLY - 1)
	add_child(_gizmo)
	# 订阅 ModuleGate 场景列表变化 → 左栏刷新。
	ModuleGate.scene_list_changed.connect(_sync_scene_list)
	# 订阅全局模式闸。ModeGate _ready 时已广播一次初始态,
	# 但 main.gd 还没 connect,故这里手动对齐一次编辑态 UI。
	ModeGate.mode_changed.connect(_on_mode_changed)
	ModeGate.edit_sub_mode_changed.connect(_on_edit_sub_mode_changed)
	_on_mode_changed(ModeGate.current())
	_on_edit_sub_mode_changed(ModeGate.current_sub_mode())


## 开机恢复窗口大小/位置：读 user://window.cfg，有就用记忆值，没有用默认 1280×720。
## 这样也解决了"改 project.godot 后窗口没变成 1280×720"——因为这里主动设窗口大小，
## 不依赖 Godot 编辑器那次的旧配置。依据 gdd_1239 ConfigFile load/get_value、gdd_0786 Window。
func _apply_window_state() -> void:
	var win: Window = get_window()
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(WINDOW_CFG_PATH)
	if err == OK:
		# 有记忆文件：读大小和位置（带默认值兜底，防文件在但某项缺了）
		var w: int = cfg.get_value("window", "width", DEFAULT_WINDOW_WIDTH)
		var h: int = cfg.get_value("window", "height", DEFAULT_WINDOW_HEIGHT)
		var x: int = cfg.get_value("window", "x", 0)
		var y: int = cfg.get_value("window", "y", 0)
		win.size = Vector2i(w, h)
		win.position = Vector2i(x, y)
	else:
		# 第一次开/文件丢了/读失败 → 默认尺寸，位置交给系统（居中等）
		win.size = Vector2i(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT)


## 关程序前存窗口大小/位置到 user://window.cfg。
## 依据 gdd_0202 第12-22行：Node 收到 NOTIFICATION_WM_CLOSE_REQUEST 时可存数据。
## 最大化状态下不存（记最大化前的尺寸才有意义）——取 size 会拿到最大化后的大尺寸，
## 故先排除 maximized/fullscreen/exclusive_fullscreen 三种铺满态。
func _save_window_state() -> void:
	var win: Window = get_window()
	# 铺满态（最大化/全屏）不记，避免存成"铺满屏"的尺寸，下次开一直铺满。
	if win.mode == Window.MODE_MAXIMIZED or win.mode == Window.MODE_FULLSCREEN \
			or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("window", "width", win.size.x)
	cfg.set_value("window", "height", win.size.y)
	cfg.set_value("window", "x", win.position.x)
	cfg.set_value("window", "y", win.position.y)
	cfg.save(WINDOW_CFG_PATH)


## 截获窗口关闭通知：在关程序那一刻存窗口大小/位置。
## 依据 gdd_0202 第12-22行 NOTIFICATION_WM_CLOSE_REQUEST（桌面关窗口标题栏 x 时触发）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_window_state()


func _sync_scene_list() -> void:
	# 把 ModuleGate 当前场景列表填进左栏"场景"节。
	# _scene_section 前 4 个固定孩子(按钮行 + 分隔线 + 场景大小行 + 分隔线)保留,
	# 从第 5 个起才是场景按钮,每次先清掉它们再按当前列表重建。
	if _scene_section == null:
		return
	# 清掉固定按钮行+分隔符之后的所有动态场景按钮。
	while _scene_section.get_child_count() > 4:
		var c: Node = _scene_section.get_child(2)
		_scene_section.remove_child(c)
		c.queue_free()
	var names: Array[String] = ModuleGate.list_scene_names()
	for nm: String in names:
		_scene_section.add_child(_btn_scene(nm))
	# 顶栏"保存此场景"按钮的状态:有选中当前场景才允许点(没选则灰显)。
	if _save_scene_btn != null:
		_save_scene_btn.disabled = (_current_scene_name == "")


## 建一个左栏场景按钮。选中态视觉:当前 _current_scene_name == 它则样式区别。
func _btn_scene(nm: String) -> Button:
	var b: Button = Button.new()
	b.text = nm
	b.custom_minimum_size = Vector2(0, 36)
	b.flat = false
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(_on_scene_selected.bind(nm))
	# 视觉区分当前选中场景(此版:文字色)。
	if nm == _current_scene_name:
		b.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	return b


## 点左栏某场景:选中它作"当前编辑场景"。
## 当前场景有未存改动(_scene_dirty)→弹窗三选一(存/不存/取消);干净→直接切不弹。
## 真换舞台走 _switch_to_scene(清内容层物件+读目标场景挂回)。
func _on_scene_selected(nm: String) -> void:
	if nm == _current_scene_name:
		return  # 点当前场景,不切
	if not _scene_dirty:
		_switch_to_scene(nm)  # 干净,直接切,不弹窗(修 bug2:存过了不该再问)
		return
	_pending_switch_to = nm  # 记下要切去哪,弹窗回调读它
	_show_switch_dialog(nm)


## 新建场景:向 ModuleGate 加一个新场景(自动起名场景N+1)、切到它。
## 新场景没存过=空内容层(没物件)。当前有未存改动→弹窗;干净→直接切。
func _on_new_scene_pressed() -> void:
	var nm: String = ModuleGate.add_scene()
	if not _scene_dirty:
		_switch_to_scene(nm)  # 干净,直接切
		return
	# 当前有改动,弹窗提醒存
	_pending_switch_to = nm
	_show_switch_dialog(nm)


## 切场景弹窗(三选一)。nm = 要切去的目标场景名,弹窗文案里显示。
## 三个按钮:保存后切换(confirmed)/ 不保存直接切换(custom_action"discard")/ 取消(canceled)。
## API 依据:gdd_0513 AcceptDialog — ok_button_text(第109行)、add_cancel_button(第132行,
## 触发 canceled 信号)、add_button(第120行,触发 custom_action(action) 信号 第63行)、
## dialog_text(第100行)、popup_centered(显示,Window.popup_* 系列 第23行提示)。
func _show_switch_dialog(nm: String) -> void:
	if _switch_dialog != null and is_instance_valid(_switch_dialog):
		_switch_dialog.queue_free()  # 旧弹窗没清就新建,先释放
	_switch_dialog = AcceptDialog.new()
	_switch_dialog.title = "切换场景"
	_switch_dialog.dialog_text = "要切到「%s」吗?\n当前场景的物件可能还没保存,切走前要不要存一下?" % nm
	_switch_dialog.ok_button_text = "保存后切换"
	_switch_dialog.add_button("不保存直接切换", false, "discard")
	_switch_dialog.add_cancel_button("取消切换")
	_switch_dialog.confirmed.connect(_on_switch_dialog_save)
	_switch_dialog.canceled.connect(_on_switch_dialog_cancel)
	_switch_dialog.custom_action.connect(_on_switch_dialog_custom)
	add_child(_switch_dialog)
	_switch_dialog.popup_centered(Vector2i(420, 0))


## 弹窗[保存后切换]:先把当前场景存盘,再真换舞台到 _pending_switch_to。
func _on_switch_dialog_save() -> void:
	var target: String = _pending_switch_to
	_pending_switch_to = ""
	# 先存当前(若当前有场景名且内容层有物件)
	if _current_scene_name != "" and _content_root != null and _content_root.get_child_count() > 0:
		var err: int = ModuleGate.save_current_scene(_current_scene_name, _content_root)
		if err != OK:
			_tool_label.text = "保存失败 code=" + str(err) + ",已取消切换"
			_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			return
	_switch_to_scene(target)


## 弹窗[不保存直接切换]:直接真换舞台,_pending_switch_to，当前未存改动丢弃。
func _on_switch_dialog_custom(action: String) -> void:
	if action != "discard":
		return
	var target: String = _pending_switch_to
	_pending_switch_to = ""
	_switch_to_scene(target)


## 弹窗[取消]:不清空 _pending_switch_to 的话换个写法——这里直接清,不做任何切换。
func _on_switch_dialog_cancel() -> void:
	_pending_switch_to = ""
	_tool_label.text = "已取消切换,留在「" + _current_scene_name + "」"
	_tool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


## 场景宽输入框值改变回调:只改宽(X 轴),高保持。重设地面/网格/UV,写进 SceneProps 存盘。
## 写进 SceneProps 随场景存盘,切场景读回时自动恢复(2026-07-14 用户需求:场景可调大小)。
## 2026-07-15 改:场景支持长方形,宽高各一个输入框各自回调,只动自己那一维。
func _on_scene_width_changed(new_w: float) -> void:
	if new_w < 5.0:
		new_w = 5.0
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.scene_width = new_w
	var h: float = _current_scene_height()
	_apply_scene_size(new_w, h)
	_scene_dirty = true
	_tool_label.text = "场景大小设为: %.0f×%.0f 米" % [new_w, h]
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 场景高输入框值改变回调:只改高(Z 轴),宽保持。同上。
func _on_scene_height_changed(new_h: float) -> void:
	if new_h < 5.0:
		new_h = 5.0
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.scene_height = new_h
	var w: float = _current_scene_width()
	_apply_scene_size(w, new_h)
	_scene_dirty = true
	_tool_label.text = "场景大小设为: %.0f×%.0f 米" % [w, new_h]
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 取当前场景的真宽/真高。优先读 _content_root 的 SceneProps 存值(切场景后权威),
## 没有就用 DEFAULT_SCENE_*。给宽高回调各自算"另一维"用,避免回调里读输入框
## 还没刷新的旧值导致两边互相覆盖。
func _current_scene_width() -> float:
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		return _content_root.scene_width
	return DEFAULT_SCENE_WIDTH


func _current_scene_height() -> float:
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		return _content_root.scene_height
	return DEFAULT_SCENE_HEIGHT


## 应用场景大小到地面/网格/纹理:地面 PlaneMesh、网格范围、UV 平铺(保持纹理重复格数)。
## 从 _on_scene_width/height_changed / _apply_default_scene / _switch_to_scene 调,不重复。
## 2026-07-15 改:接收宽×高两参数,地面 PlaneMesh 用 Vector2(w,h),网格 set_grid_size(w,h),
## UV 平铺按宽高各自重复(平铺格数 ground_tile_size 不变,只是每轴米数不同)。
func _apply_scene_size(width: float, height: float) -> void:
	if _ground == null or not is_instance_valid(_ground) or _grid_manager == null:
		return
	var g: MeshInstance3D = _ground
	g.mesh = PlaneMesh.new()
	g.mesh.size = Vector2(width, height)
	_grid_manager.set_grid_size(width, height)
	_refresh_grid()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	_apply_texture_set(_active_ground_ts, mat)
	# UV 平铺:默认贴图铺满拉伸(跟着场景宽高变形),其他纹理按 ground_tile_size 重复。
	mat.uv1_scale = _ground_uv_scale(_active_ground_ts.get("_base", ""), width, height, ground_tile_size)
	g.set_surface_override_material(0, mat)
	# grid_size 是 @export 备用整数(部分逻辑还读它),取宽高较大值近似保持兼容。
	grid_size = int(maxf(width, height))


## 把当前场景设成默认空场景(纯空舞台):清内容层所有物件 + 设默认地面纹理/平铺/场景大小
## (DEFAULT_GROUND_TEX_BASE/TILE + DEFAULT_SCENE_WIDTH/HEIGHT) + 写进 _content_root 的 SceneProps。
## 开机起始场景、新建场景、切到没存过的场景都走这里——"默认场景有专门记录"。
## 将来改默认场景长相只改 DEFAULT_* 常量这一处(2026-07-10 修 bug2)。
## 2026-07-15 改:默认场景宽×高两值(支持长方形)。
func _apply_default_scene() -> void:
	# 清内容层所有物件
	if is_instance_valid(_content_root):
		for c: Node in _content_root.get_children():
			_content_root.remove_child(c)
			c.queue_free()
	_deselect()
	# 设默认纹理/平铺/场景宽高,写进 SceneProps 随内容层存
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.ground_tex_base = DEFAULT_GROUND_TEX_BASE
		_content_root.ground_tile = 0.0  # 铺满模式:tile 占位 0(不参与 UV,见 _ground_uv_scale)
		_content_root.scene_width = DEFAULT_SCENE_WIDTH
		_content_root.scene_height = DEFAULT_SCENE_HEIGHT
	_apply_ground_texture_for_scene(DEFAULT_GROUND_TEX_BASE, 0.0)
	_apply_scene_size(DEFAULT_SCENE_WIDTH, DEFAULT_SCENE_HEIGHT)
	# 同步输入框值(不触发回调)
	if _scene_width_input != null:
		_scene_width_input.set_value_no_signal(DEFAULT_SCENE_WIDTH)
	if _scene_height_input != null:
		_scene_height_input.set_value_no_signal(DEFAULT_SCENE_HEIGHT)


## 真换舞台:把内容层(_content_root)清空 → 读目标场景文件挂回(没存过就空着)。
## 骨架层(相机/光/地面)不动——所有场景共用(方案乙),所以相机/投屏/gizmo 引用不重连。
## 读回的树整棵是 _content_root 那一层(pack 存的就是它),直接把它的孩子搬进当前 _content_root。
func _switch_to_scene(target_name: String) -> void:
	if target_name == "":
		return
	# 1) 清空内容层当前所有物件
	for c: Node in _content_root.get_children():
		_content_root.remove_child(c)
		c.queue_free()
	# 2) 清选中状态(旧物件没了一个也不该选中)——复用现有 _deselect
	_deselect()
	# 3) 读目标场景:看它存过没(ResourceLoader.exists)。存过→读回挂进内容层;没存过→空内容层。
	var ref: LocationRef = null
	for l: LocationRef in ModuleGate.current_manifest().locations:
		if l.display_name == target_name:
			ref = l
			break
	if ref != null and ref.canonical_path != "" and ResourceLoader.exists(ref.canonical_path):
		var loaded: Node = ModuleIo.load_scene_tree(ref.canonical_path)
		if loaded != null and is_instance_valid(loaded):
			# 读回的树根(就是当时 pack 的 _content_root)带着 SceneProps 的 export 值
			# (ground_tex_base/ground_tile/scene_width/scene_height)。先把它们读到当前 _content_root,再搬孩子。
			# 2026-07-15 改:宽×高两值。兼容老存档(只存了 scene_size 单值)——有 scene_width 读新字段,没有则退回 scene_size 当正方形。
			var loaded_base: String = ""
			var loaded_tile: float = 2.0
			var loaded_w: float = DEFAULT_SCENE_WIDTH
			var loaded_h: float = DEFAULT_SCENE_HEIGHT
			if loaded.get_script() != null and loaded.get("ground_tex_base") != null:
				loaded_base = loaded.ground_tex_base
				loaded_tile = loaded.ground_tile
				if loaded.get("scene_width") != null:
					loaded_w = loaded.scene_width
					loaded_h = loaded.scene_height
				elif loaded.get("scene_size") != null:
					loaded_w = loaded.scene_size
					loaded_h = loaded.scene_size
			print("[BUG1] _switch_to_scene 切=%s 读回 base=%s tile=%s w=%s h=%s" % [target_name, loaded_base, loaded_tile, loaded_w, loaded_h])
			_content_root.ground_tex_base = loaded_base
			_content_root.ground_tile = loaded_tile
			_content_root.scene_width = loaded_w
			_content_root.scene_height = loaded_h
			# 把读回树的孩子搬进当前 _content_root、owner 改设当前 _content_root。
			for c: Node in loaded.get_children():
				loaded.remove_child(c)
				_content_root.add_child(c)
				_ensure_owner_recursive(c, _content_root)
			loaded.queue_free()  # 搬完孩子,读回的壳释放
			# 按读回的纹理信息重建地面材质上到骨架 Ground(修 bug1:每场景纹理独立)。
			_apply_ground_texture_for_scene(loaded_base, loaded_tile)
			_apply_scene_size(loaded_w, loaded_h)
			# 同步输入框值(不触发回调)
			if _scene_width_input != null:
				_scene_width_input.set_value_no_signal(loaded_w)
			if _scene_height_input != null:
				_scene_height_input.set_value_no_signal(loaded_h)
		else:
			# 场景文件读不出来/没存过→清成默认空场景
			_apply_default_scene()
	else:
		# 没存过的新场景→默认空场景(纯空舞台+默认纹理/平铺)
		_apply_default_scene()
	# 4) 切当前场景名 + 广播 + 刷左栏 + 清脏(新切入是干净的)
	_current_scene_name = target_name
	ModuleGate.set_current_location(target_name)
	_sync_scene_list()
	_scene_dirty = false  # 刚切入,无未存改动
	_tool_label.text = "已切到场景:「" + target_name + "」"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 递归把 node 子树所有节点 owner 设成 owner_node(修 pack 的 owner 陷阱)。
## 搬读回树的孩子进当前 _content_root 后,owner 要重指当前 _content_root,否则下次存盘漏。
func _ensure_owner_recursive(node: Node, owner_node: Node) -> void:
	node.set_owner(owner_node)
	for c: Node in node.get_children():
		_ensure_owner_recursive(c, owner_node)



## 保存当前编辑态:_content_root 这棵子树(建筑物件)存进当前选中场景的文件。
## 方案乙:只存内容层(物件),骨架层(相机/光/地面)不随场景存。
## 走 ModuleGate.save_current_scene → module_io.save_scene_tree(内含 owner 陷阱处理)。
func _on_save_scene_pressed() -> void:
	if _current_scene_name == "":
		_tool_label.text = "请先在左栏点选一个场景"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		return
	if _content_root == null or not is_instance_valid(_content_root):
		return
	print("[BUG1] _on_save_scene_pressed 存场景=%s 当时tex_base=%s tile=%s" % [_current_scene_name, _content_root.ground_tex_base, _content_root.ground_tile])
	var err: int = ModuleGate.save_current_scene(_current_scene_name, _content_root)
	if err == OK:
		_scene_dirty = false  # 存盘成功→清脏(修 bug2:之后切场景不再问要不要存)
		_tool_label.text = "已保存场景:" + _current_scene_name
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		_tool_label.text = "保存失败 code=" + str(err)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


## 把"场景内容"节点(相机/光照/地面/网格)挪到 _scene_root 下、owner 设成 _scene_root。
## 这样 pack(_scene_root) 存场景时它们是内容会被存;gizmo/UI/cast_view 不进它→不存。
## 依据:Node.reparent(gdd_0512 第142/1668行) + owner=pack根 才进存盘(gdd_0512 第691行)。
func _adopt_scene_content() -> void:
	# main.tscn 里写死的孩子(相机/方向光/WorldEnvironment/CameraPivot/Ground)现 owner=Main,
	# reparent 到 SceneRoot;GridOverlay 是 _draw_grid 动态建的,_draw_grid 里已 add_child(self),
	# 这里统一挪。rep前不能加 if 判断不存在的节点($ 访问会被 null 跳过)。
	for child: Node in get_children():
		if child == _scene_root:
			continue
		if child is Camera3D or child is DirectionalLight3D or child is WorldEnvironment \
				or child is Node3D and child.name == "CameraPivot":
			_reparent_own(child, _scene_root)
	# Ground 按名字认（另一地面 MeshInstance3D，同样不进 reparent）。
	# GridOverlay 现在是 GridManager 的子节点，不再直接从 main 下认。
	for child: Node in get_children():
		if child == _scene_root:
			continue
		if child.name == "Ground":
			_reparent_own(child, _scene_root)


## reparent 一个节点到 new_parent 并把 owner 设成 new_parent。
func _reparent_own(node: Node, new_parent: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() == new_parent:
		# 已在目标父下:只改 owner 即可(reparent 同父会触发不必要信号)。
		node.set_owner(new_parent)
		return
	node.reparent(new_parent, true)  # keep_global_transform=true 保留世界位姿(文档第142行)
	node.set_owner(new_parent)


func _scan_all() -> void:
	# 地面纹理自带集扫进 _ground_sets（导入的纹理在 _rebuild_ground_buttons 时合并扫）
	_scan_textures("res://assets/textures/ground", _ground_sets)
	# 模型类栏位的 items 不在这里建——_build_ui 时 _build_model_section 调
	# _rebuild_model_items 各自扫自带+导入。开机 _scan_all 在 _build_ui 前跑只管纹理。



## 重建某模型栏位的统一 items 列表：自带模型(builtin_dir) + 导入模型(user://library/<category>/)。
## 自带标记 source="builtin"，放置走 ResourceLoader.load(PackedScene)；
## 导入标记 source="imported"，放置走 LibraryManager.load_model_runtime(GLTFDocument)。
## 依据：gdd_0372 res:// 打包后只读、user:// 永远可写；gdd_0187 运行时加载 3D 模型。
## 返回 items 数组（不直接存进 _model_panelss，调用方自己存）。
func _rebuild_model_items(category: String, builtin_dir: String) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	# 自带模型（开发时随 exe 打包）
	if builtin_dir != "":
		var dd: DirAccess = DirAccess.open(builtin_dir)
		if dd != null:
			dd.list_dir_begin()
			var fn: String = dd.get_next()
			while fn != "":
				if not dd.current_is_dir():
					var low: String = fn.to_lower()
					if low.ends_with(".glb") or low.ends_with(".gltf") or low.ends_with(".fbx"):
						items.append({"source": "builtin", "path": builtin_dir + "/" + fn})
				fn = dd.get_next()
			dd.list_dir_end()
	# 导入模型（GM 用导入按钮加进来的，存 user://library/<category>/）
	var imported: Array[String] = _library_mgr.scan_category(category, "model")
	for p: String in imported:
		items.append({"source": "imported", "path": p})
	return items


## 刷新某模型栏位的按钮列表。清掉该栏位容器旧孩子，按 items 重建。
## 导入新素材后调它，左栏立刻出现新按钮。
func _rebuild_model_buttons(category: String) -> void:
	if not _model_panelss.has(category):
		return
	var panel: Dictionary = _model_panelss[category]
	var container: VBoxContainer = panel["container"]
	var items: Array[Dictionary] = panel["items"]
	for c: Node in container.get_children():
		container.remove_child(c)
		c.queue_free()
	for i: int in items.size():
		container.add_child(_btn_model(category, i))


## 建一个模型栏位按钮。显示文件名（去扩展名），点击选中该项作待放置工具。
func _btn_model(category: String, index: int) -> Button:
	var btn: Button = Button.new()
	var item: Dictionary = _model_panelss[category]["items"][index]
	btn.text = item["path"].get_file().get_basename()
	btn.custom_minimum_size = Vector2(0, 44)
	# 导入的项文字前加个标记，让 GM 一眼区分自带/导入
	if item["source"] == "imported":
		btn.text = "📥 " + btn.text
	btn.pressed.connect(_on_model_clicked.bind(category, index))
	# 给按钮存元数据：右键时靠 gui_get_hovered_control 找到按钮再读它，
	# 知道该删哪个素材。不用 gui_input 信号——实测 Button 的 gui_input 收不到
	# MouseButton 事件（只收 MouseMotion），改在 _unhandled_input 里统一处理右键。
	btn.set_meta("category", category)
	btn.set_meta("index", index)
	btn.set_meta("kind", "model")
	return btn


## 真删除一个导入模型：删 user://library/<category>/<文件> → 重建该栏列表。
func _delete_model_item(category: String, index: int) -> void:
	var item: Dictionary = _model_panelss[category]["items"][index]
	var file_name: String = item["path"].get_file()
	if not _library_mgr.delete_model(category, file_name):
		_tool_label.text = "删除失败：" + file_name
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	var panel: Dictionary = _model_panelss[category]
	panel["items"] = _rebuild_model_items(category, panel["builtin_dir"])
	panel["active_idx"] = -1
	_rebuild_model_buttons(category)
	_tool_label.text = "已删除" + panel["label"] + "：" + file_name
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 模型栏位项点击：选中/取消选中作待放置工具。所有模型栏位共用。
func _on_model_clicked(category: String, index: int) -> void:
	var panel: Dictionary = _model_panelss[category]
	var items: Array[Dictionary] = panel["items"]
	var label: String = panel["label"]
	# 先清所有栏位的选中（单选语义：同时只能有一个栏位的工具被选中）
	_clear_all_model_selections()
	if panel["active_idx"] == index:
		panel["active_idx"] = -1
		_tool_label.text = "未选中工具"
		_tool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		panel["active_idx"] = index
		_tool_label.text = label + "：" + items[index]["path"].get_file().get_basename()
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.5, 0.9))


## 清所有模型栏位的选中状态（单选语义：跨栏位同时只能选中一个放置工具）。
func _clear_all_model_selections() -> void:
	for category: String in _model_panelss:
		_model_panelss[category]["active_idx"] = -1


## 返回当前选中的模型项 {category, index, item}，没有选中返回空字典。
## 放置时左键点击调用，决定放哪个物件。
func _get_active_model_item() -> Dictionary:
	for category: String in _model_panelss:
		var panel: Dictionary = _model_panelss[category]
		var idx: int = panel["active_idx"]
		if idx >= 0 and idx < panel["items"].size():
			return {"category": category, "index": idx, "item": panel["items"][idx]}
	return {}


## 点某模型栏位"导入"按钮：弹文件选择框选模型文件。category 由按钮 bind 带入。
## FileDialog 一次性建，复用；选完后 _on_import_file_selected 走导入流程。
func _on_model_import_pressed(category: String) -> void:
	_import_target_category = category
	_show_import_dialog("选一个 3D 模型导入" + _model_panelss[category]["label"] + "库",
		["*.glb ;glTF Binary（推荐，自带贴图）", "*.gltf ;glTF"])


## 建/复用导入文件选择框并弹出。filters 是 add_filter 的参数对（扩展名;描述）。
## 依据 gdd_0596：access=ACCESS_FILESYSTEM 能选电脑任意位置的文件；
## file_mode=FILE_MODE_OPEN_FILE 单选；add_filter 限制可选类型。
func _show_import_dialog(title_text: String, filters: Array) -> void:
	if _import_fd == null or not is_instance_valid(_import_fd):
		_import_fd = FileDialog.new()
		_import_fd.access = FileDialog.ACCESS_FILESYSTEM  # 能选电脑任意文件
		_import_fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE  # 单选一个文件
		_import_fd.use_native_dialog = true  # 用系统原生选择框，GM 更熟
		_import_fd.file_selected.connect(_on_import_file_selected)
		add_child(_import_fd)
	_import_fd.clear_filters()
	for f: Variant in filters:
		_import_fd.add_filter(f[0], f[1])
	_import_fd.title = title_text
	_import_fd.popup_file_dialog()


## 文件选择框选完文件回调：复制进目标栏位素材库 → 重建该栏位列表 → 刷新左栏按钮。
## 依据 gdd_0596 file_selected 信号（第 113 行）传选中文件路径。
func _on_import_file_selected(path: String) -> void:
	if path == "" or _import_target_category == "":
		return
	var category: String = _import_target_category
	_import_target_category = ""
	var dest: String = _library_mgr.import_file(path, category)
	if dest == "":
		_tool_label.text = "导入失败：" + path.get_file()
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	# 重建该栏位的 items + 按钮
	var panel: Dictionary = _model_panelss[category]
	panel["items"] = _rebuild_model_items(category, panel["builtin_dir"])
	_rebuild_model_buttons(category)
	_tool_label.text = "已导入" + panel["label"] + "：" + dest.get_file()
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 点地面纹理栏"导入纹理文件夹"按钮：弹文件夹选择框。
## 地面纹理按 PBR 多图一组：选一个文件夹，里面多张图按文件名分类。
func _on_ground_import_pressed() -> void:
	_show_import_dir_dialog("选一个文件夹导入地面纹理（里面多张图按文件名自动分类）")


## 建/复用文件夹选择框并弹出。地面纹理导入用（选文件夹不是选文件）。
## 依据 gdd_0596：file_mode=FILE_MODE_OPEN_DIR 只选文件夹；dir_selected 信号（第 107 行）传选中目录。
func _show_import_dir_dialog(title_text: String) -> void:
	if _import_dir_fd == null or not is_instance_valid(_import_dir_fd):
		_import_dir_fd = FileDialog.new()
		_import_dir_fd.access = FileDialog.ACCESS_FILESYSTEM
		_import_dir_fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR  # 选文件夹
		_import_dir_fd.use_native_dialog = true
		_import_dir_fd.dir_selected.connect(_on_import_dir_selected)
		add_child(_import_dir_fd)
	_import_dir_fd.title = title_text
	_import_dir_fd.popup_file_dialog()


## 文件夹选择框选完回调：复制整个文件夹进地面纹理库 → 重建地面纹理列表。
## 依据 gdd_0596 dir_selected 信号传选中目录路径。
func _on_import_dir_selected(dir_path: String) -> void:
	if dir_path == "":
		return
	var dest: String = _library_mgr.import_texture_folder(dir_path)
	if dest == "":
		_tool_label.text = "导入纹理失败：" + dir_path.get_file()
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	_rebuild_ground_buttons()  # 重扫自带+导入纹理，刷新按钮
	_tool_label.text = "已导入纹理：" + dest.get_file()
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 重建地面纹理按钮列表：清容器 → 合并自带(_ground_sets) + 导入(scan_ground_textures)
## → 按每组纹理建按钮。导入新纹理后调它刷新。
func _rebuild_ground_buttons() -> void:
	if _ground_list_container == null:
		return
	# 合并自带 + 导入的地面纹理（加 source 标记判断右键能否删）
	var all_sets: Array[Dictionary] = []
	for s: Dictionary in _ground_sets:
		var copy: Dictionary = s.duplicate()
		copy["source"] = "builtin"  # 自带，res:// 打包后只读删不掉
		all_sets.append(copy)
	var imported: Array[Dictionary] = _library_mgr.scan_ground_textures()
	for s: Dictionary in imported:
		var copy: Dictionary = s.duplicate()
		copy["source"] = "imported"  # 导入的，user:// 可删
		all_sets.append(copy)
	# 清旧按钮
	for c: Node in _ground_list_container.get_children():
		_ground_list_container.remove_child(c)
		c.queue_free()
	# 按每组纹理建按钮
	for s: Dictionary in all_sets:
		_ground_list_container.add_child(_btn_ground(s))


func _scan_textures(dir_path: String, out_arr: Array[Dictionary]) -> void:
	## 扫子文件夹=扫纹理组。每个子文件夹是一个材质,文件夹名=纹理组名。
	## 文件夹内的文件按关键词分类(albedo/normal/roughness等)；
	## 如果文件夹内只有一个文件则不分类别,直接当整张贴图(albedo)。
	var dd: DirAccess = DirAccess.open(dir_path)
	if dd == null:
		return
	dd.list_dir_begin()
	var subdir: String = dd.get_next()
	while subdir != "":
		if subdir == "." or subdir == "..":
			subdir = dd.get_next()
			continue
		if dd.current_is_dir():
			_scan_texture_folder(dir_path.path_join(subdir), subdir, out_arr)
		subdir = dd.get_next()
	dd.list_dir_end()


func _scan_texture_folder(folder_path: String, folder_name: String, out_arr: Array[Dictionary]) -> void:
	var dd: DirAccess = DirAccess.open(folder_path)
	if dd == null:
		return
	var files: Array[String] = []
	dd.list_dir_begin()
	var fn: String = dd.get_next()
	while fn != "":
		if not dd.current_is_dir():
			var low: String = fn.to_lower()
			if low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg"):
				files.append(fn)
		fn = dd.get_next()
	dd.list_dir_end()
	if files.is_empty():
		return
	# 单文件 → 整个当 albedo，不分关键字匹配
	if files.size() == 1:
		out_arr.append({"_base": folder_name, "albedo": folder_path.path_join(files[0])})
		print("Gvtt: tex set " + folder_name + " (single file)")
		return
	# 多文件 → 逐文件分类。同类型只认第一个（避免多张同类型图互相覆盖）。
	var group: Dictionary = {"_base": folder_name}
	for f: String in files:
		var parsed: Dictionary = _classify_texture(f)
		if not group.has(parsed["type"]):  # 该类型还没图 → 存；已有 → 跳过不覆盖
			group[parsed["type"]] = folder_path.path_join(f)
	out_arr.append(group)
	print("Gvtt: tex set " + folder_name + " (%d files)" % files.size())


func _classify_texture(filename: String) -> Dictionary:
	var stem: String = filename.get_basename().get_file().to_lower()
	stem = stem.replace("-", "_")
	# 关键词子串搜索（不管类型词在文件名哪个位置），按长度降序先匹配更具体的。
	# 跟 library_manager.gd _classify_one_texture 同规则，保持自带/导入纹理一致。
	var rules: Array[Array] = [
		["ambient_occlusion", "ao"], ["ambientocclusion", "ao"],
		["base_color", "albedo"], ["basecolor", "albedo"],
		["metalness", "metallic"],
		["roughness", "roughness"], ["glossiness", "roughness"],
		["emission", "emission"], ["emissive", "emission"],
		["normal_gl", "normal"], ["normalgl", "normal"],
		["diffuse", "albedo"], ["albedo", "albedo"],
		["metallic", "metallic"],
		["normal", "normal"],
		["gloss", "roughness"],
		["_orm", "orm"], ["orm", "orm"],
		["_ao", "ao"], ["ao", "ao"],
		["color", "albedo"],
	]
	for rule: Array in rules:
		var kw: String = rule[0]
		var pos: int = stem.find(kw)
		if pos >= 0:
			var base_name: String = stem.substr(0, pos).strip_edges()
			return {"base": base_name, "type": rule[1]}
	return {"base": stem, "type": "albedo"}


func _apply_texture_set(ts: Dictionary, mat: StandardMaterial3D) -> void:
	for key: String in ["albedo", "normal", "roughness", "metallic", "ao"]:
		if ts.has(key):
			var img: Image = Image.load_from_file(ts[key])
			if img:
				var tex: ImageTexture = ImageTexture.create_from_image(img)
				match key:
					"albedo": mat.albedo_texture = tex
					"normal": mat.normal_texture = tex; mat.normal_enabled = true
					"roughness": mat.roughness_texture = tex; mat.roughness_enabled = true
					"metallic": mat.metallic_texture = tex; mat.metallic_enabled = true
					"ao": mat.ao_texture = tex; mat.ao_enabled = true


func _setup_camera() -> void:
	camera = $Camera3D
	camera.projection = Camera3D.ProjectionType.PROJECTION_ORTHOGONAL
	camera.size = _map_size
	_apply_camera_for_mode(ModeGate.current())


func _setup_cast_view() -> void:
	# 投屏窗口(CastView)——把运行态场景实时投到第二个原生窗口给玩家看。
	# 旁路于 ModeGate，不订阅 mode_changed(投屏与编辑/运行正交)。
	# 把主相机注入 CastView，它每帧镜姿态到投屏相机。
	var CastViewClass: GDScript = load("res://scripts/cast_view.gd")
	_cast_view = CastViewClass.new()
	_cast_view.name = "CastView"
	add_child(_cast_view)
	_cast_view.setup(camera)


func _apply_camera_for_mode(mode: ModeGate.AppMode) -> void:
	# 相机模式由"主态 + 编辑子模式"共同决定:
	#   - 地图模式(任一态):正交俯视,锁定 90° 朝下,缩放=size,平移=_map_focus
	#   - 自由视角(任一态):透视,球坐标(yaw/pitch/dist)绕 focus,可转可拉
	# 编辑态/运行态这套相机逻辑一样,只是显示的工具(面板/gizmo/按钮)不同。
	if ModeGate.is_sub_map():
		# 地图模式:正交 + 正上方俯视
		camera.projection = Camera3D.ProjectionType.PROJECTION_ORTHOGONAL
		camera.size = _map_size
		camera.position = _map_focus + Vector3(0, 25.0, 0)
		camera.rotation = Vector3(-PI / 2, 0, 0)
	else:
		# 自由视角:透视 + 球坐标。每次切进自由视角都从 saved 的"游玩视角"套用。
		# saved 是权威:编辑态按"保存视角"存;没存过用代码默认值(ORBIT_DEFAULT_*)。
		# GM 临场转动只改 _orbit_*,改不动 saved,按"恢复视角"即回 saved。
		_orbit_dist = _saved_orbit_dist
		_orbit_yaw = _saved_orbit_yaw
		_orbit_pitch = _saved_orbit_pitch
		_orbit_focus = _saved_orbit_focus
		camera.projection = Camera3D.ProjectionType.PROJECTION_PERSPECTIVE
		camera.fov = 60.0
		_update_orbit_camera()
	_refresh_grid()


## 球坐标 → 笛卡尔偏移,再放到相机并 look_at 焦点。
## pitch=0 水平,PI/2 正上。Godot 无现成球坐标 API,按文档手算三行。
func _update_orbit_camera() -> void:
	var p: float = _orbit_pitch
	var y: float = _orbit_yaw
	var r: float = _orbit_dist
	var offset: Vector3 = Vector3(
		r * cos(p) * sin(y),
		r * sin(p),
		r * cos(p) * cos(y)
	)
	camera.position = _orbit_focus + offset
	camera.look_at(_orbit_focus, Vector3.UP)


func _setup_ground() -> void:
	_ground = $Ground
	var g: MeshInstance3D = _ground
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = ground_color
	mat.roughness = 0.9
	g.mesh = PlaneMesh.new()
	g.mesh.size = Vector2(grid_size, grid_size)
	g.set_surface_override_material(0, mat)


func _init_grid_manager() -> void:
	## 网格管理器（Godot 3D 编辑器网格方案）。
	## GridManager 自己作为节点挂到 main 下，里面建 GridOverlay MeshInstance3D 子节点。
	_grid_manager = load("res://scripts/grid_manager.gd").new()
	_grid_manager.name = "GridManager"
	add_child(_grid_manager)
	_refresh_grid()


func _refresh_grid() -> void:
	## 计算当前 px（每像素覆盖地面米数）并通知网格管理器重建。
	if _grid_manager == null or camera == null:
		return
	var proj: int = camera.projection as int
	var px: float
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.y <= 0:
		return
	if proj == 1:
		# 正交：视口高度(米) / 视口高度(像素)
		var view_height_m: float = 2.0 * camera.size
		px = view_height_m / vp_size.y
	else:
		# 透视：相机前方 cam_dist 处的视口宽度 / 视口像素
		# 用 orbit_dist 近似覆盖距离（pitch 接近垂直时退化，但足够 GM 工具）
		var d: float = _orbit_dist if ModeGate.is_sub_map() == false else 25.0
		var fov_rad: float = deg_to_rad(camera.fov)
		var view_height_m: float = 2.0 * d * tan(fov_rad * 0.5)
		px = view_height_m / vp_size.y
	_grid_manager.update_grid(px)


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI_Layer"
	add_child(_ui_layer)
	_left_panel = PanelContainer.new()
	_left_panel.name = "ItemPanel"
	_left_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE, true)
	_left_panel.set_offset(SIDE_TOP, 10)
	_left_panel.set_offset(SIDE_RIGHT, -210)
	_left_panel.custom_minimum_size = Vector2(200, 0)
	_ui_layer.add_child(_left_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_panel.add_child(scroll)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	_tool_label = Label.new()
	_tool_label.text = "未选中工具"
	_tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tool_label)
	# 多场景系统:左栏"场景"节。顶部两按钮(新建/保存) + 下面场景列表(_scene_section)。
	# 按 _add_section 规矩:节内容容器由它返回,按钮/列表都挂内容容器。
	_scene_section = _add_section(vbox, "场景")
	# 顶部操作按钮行
	var scene_btn_row: HBoxContainer = HBoxContainer.new()
	scene_btn_row.add_theme_constant_override("separation", 4)
	_new_scene_btn = Button.new()
	_new_scene_btn.text = "新建"
	_new_scene_btn.custom_minimum_size = Vector2(70, 32)
	_new_scene_btn.tooltip_text = "新建一个空场景,起名 场景N+1"
	_new_scene_btn.pressed.connect(_on_new_scene_pressed)
	scene_btn_row.add_child(_new_scene_btn)
	_save_scene_btn = Button.new()
	_save_scene_btn.text = "保存此场景"
	_save_scene_btn.custom_minimum_size = Vector2(110, 32)
	_save_scene_btn.tooltip_text = "把当前编辑态存进当前选中场景(覆盖)"
	_save_scene_btn.pressed.connect(_on_save_scene_pressed)
	scene_btn_row.add_child(_save_scene_btn)
	_scene_section.add_child(scene_btn_row)
	_scene_section.add_child(HSeparator.new())
	# 场景大小输入行:宽/高各一个输入框(2026-07-15 改:支持长方形场地)。
	# 跟其他栏位的导入按钮同样的位置和风格。
	var size_row: HBoxContainer = HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	var w_lbl: Label = Label.new()
	w_lbl.text = "宽"
	w_lbl.custom_minimum_size = Vector2(30, 0)
	w_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_row.add_child(w_lbl)
	_scene_width_input = SpinBox.new()
	_scene_width_input.min_value = 5.0
	_scene_width_input.max_value = 500.0
	_scene_width_input.step = 5.0
	_scene_width_input.value = DEFAULT_SCENE_WIDTH
	_scene_width_input.custom_minimum_size = Vector2(80, 32)
	_scene_width_input.tooltip_text = "地面 X 轴边长(米),改后地面/网格/纹理一起适配"
	_scene_width_input.value_changed.connect(_on_scene_width_changed)
	size_row.add_child(_scene_width_input)
	var h_lbl: Label = Label.new()
	h_lbl.text = "高"
	h_lbl.custom_minimum_size = Vector2(30, 0)
	h_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(h_lbl)
	_scene_height_input = SpinBox.new()
	_scene_height_input.min_value = 5.0
	_scene_height_input.max_value = 500.0
	_scene_height_input.step = 5.0
	_scene_height_input.value = DEFAULT_SCENE_HEIGHT
	_scene_height_input.custom_minimum_size = Vector2(80, 32)
	_scene_height_input.tooltip_text = "地面 Z 轴边长(米),改后地面/网格/纹理一起适配"
	_scene_height_input.value_changed.connect(_on_scene_height_changed)
	size_row.add_child(_scene_height_input)
	_scene_section.add_child(size_row)
	_scene_section.add_child(HSeparator.new())
	# 下面场景列表空着——_sync_scene_list() 往里填按钮(MenuGate 列表变化时也连它刷新)。
	# 模型类栏位：循环建 MODEL_PANELS 配置的 6 个栏位，地面纹理插在 terrain 和 wall 之间。
	# 每个模型栏位 = 可折叠节 + 导入按钮 + 列表容器（刷新时往里填物件按钮）。
	for i: int in MODEL_PANELS.size():
		var cfg: Dictionary = MODEL_PANELS[i]
		# 地面纹理栏插在 terrain(索引1) 之后、wall(索引2) 之前
		if cfg["category"] == "wall":
			_build_ground_section(vbox)
		_build_model_section(vbox, cfg)
	var tr: HBoxContainer = HBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	tr.set_offset(SIDE_LEFT, -460)
	tr.set_offset(SIDE_TOP, 10)
	tr.set_offset(SIDE_RIGHT, -10)
	tr.custom_minimum_size = Vector2(440, 40)
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_theme_constant_override("separation", 6)
	_ui_layer.add_child(tr)
	# 子模式切换:地图 ↔ 自由视角。两个态都显示。
	_sub_btn = Button.new()
	_sub_btn.text = "地图"
	_sub_btn.custom_minimum_size = Vector2(80, 36)
	_sub_btn.pressed.connect(_on_sub_btn_pressed)
	tr.add_child(_sub_btn)
	# 保存视角:仅编辑态显示。把当前自由视角四量存为"游玩视角"权威。
	_save_view_btn = Button.new()
	_save_view_btn.text = "保存视角"
	_save_view_btn.custom_minimum_size = Vector2(90, 36)
	_save_view_btn.pressed.connect(_on_save_view_pressed)
	tr.add_child(_save_view_btn)
	# 恢复视角:仅运行态显示。一按把 _orbit_* 拉回 saved。
	_restore_view_btn = Button.new()
	_restore_view_btn.text = "恢复视角"
	_restore_view_btn.custom_minimum_size = Vector2(90, 36)
	_restore_view_btn.pressed.connect(_on_restore_view_pressed)
	tr.add_child(_restore_view_btn)
	# 投屏开关:两个态都能按,不归 ModeGate 管。按一下开/关玩家视角窗口。
	_cast_btn = Button.new()
	_cast_btn.text = "投屏 ⧉"
	_cast_btn.custom_minimum_size = Vector2(80, 36)
	_cast_btn.toggle_mode = false
	_cast_btn.pressed.connect(_on_cast_btn_pressed)
	tr.add_child(_cast_btn)
	_mode_btn = Button.new()
	_mode_btn.text = "运行 ▶"
	_mode_btn.custom_minimum_size = Vector2(90, 36)
	_mode_btn.pressed.connect(_on_mode_btn_pressed)
	tr.add_child(_mode_btn)
	_mode_label = Label.new()
	_mode_label.text = "编辑态"
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_label.custom_minimum_size = Vector2(60, 36)
	tr.add_child(_mode_label)
	# 属性面板:选中物件后右侧弹,绑 EntityProperties 字段。编辑态才显示选中。
	_build_prop_panel()


## 建一个模型类栏位（Token/地形/墙体/装饰/交互物体/光源 共用）。
## cfg = MODEL_PANELS 的一项 {label, category, builtin_dir}。
## 栏位 = 可折叠节 + 导入按钮 + 列表容器。状态存进 _model_panelss[category]。
func _build_model_section(parent: VBoxContainer, cfg: Dictionary) -> void:
	var category: String = cfg["category"]
	var items: Array[Dictionary] = _rebuild_model_items(category, cfg["builtin_dir"])
	var count: int = items.size()
	var sec: VBoxContainer = _add_section(parent, "%s (%d)" % [cfg["label"], count])
	# 导入按钮：栏位顶部。点下弹文件选择框，选 GLB/glTF 复制进素材库。
	# 主推 GLB（贴图嵌文件内），FBX 兼容但贴图可能丢（见 memory gvtt_model_embedded_textures_only）。
	var import_btn: Button = Button.new()
	import_btn.text = "＋ 导入模型"
	import_btn.custom_minimum_size = Vector2(0, 32)
	import_btn.tooltip_text = "从电脑选 GLB（推荐，自带贴图）或 glTF 模型，存进素材库反复用"
	import_btn.pressed.connect(_on_model_import_pressed.bind(category))
	sec.add_child(import_btn)
	# 列表容器：刷新时往里填物件按钮
	var list_container: VBoxContainer = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 4)
	sec.add_child(list_container)
	# 状态存进 _model_panelss，供刷新/选中/放置用
	_model_panelss[category] = {
		"items": items,
		"active_idx": -1,
		"container": list_container,
		"import_btn": import_btn,
		"label": cfg["label"],
		"builtin_dir": cfg["builtin_dir"],
	}
	_rebuild_model_buttons(category)


## 建地面纹理栏：可折叠节 + 导入按钮 + 平铺控件 + 纹理按钮列表。
## 地面纹理导入按文件夹（PBR 多图一组），复用 _classify_texture 文件名分类。
func _build_ground_section(parent: VBoxContainer) -> void:
	var ground_sec: VBoxContainer = _add_section(parent, "地面纹理")
	# 导入按钮：选一个文件夹（里面多张图按文件名分类成颜色/法线/粗糙等）
	var ground_import_btn: Button = Button.new()
	ground_import_btn.text = "＋ 导入纹理文件夹"
	ground_import_btn.custom_minimum_size = Vector2(0, 32)
	ground_import_btn.tooltip_text = "选一个文件夹（里面多张图按文件名自动分类成颜色/法线/粗糙等 PBR 贴图）"
	ground_import_btn.pressed.connect(_on_ground_import_pressed)
	ground_sec.add_child(ground_import_btn)
	_ground_import_btn = ground_import_btn
	# 平铺尺寸控制区（不选纹理时隐藏）——分成上下两行
	_tile_control_area = VBoxContainer.new()
	_tile_control_area.add_theme_constant_override("separation", 6)
	_tile_control_area.visible = false
	# 第一行：标签 + 数字输入框
	var _tile_top_row: HBoxContainer = HBoxContainer.new()
	_tile_top_row.add_theme_constant_override("separation", 6)
	var _tile_label: Label = Label.new()
	_tile_label.text = "平铺尺寸"
	_tile_label.custom_minimum_size = Vector2(80, 0)
	_tile_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tile_top_row.add_child(_tile_label)
	_tile_spinbox = SpinBox.new()
	_tile_spinbox.min_value = 0.1
	_tile_spinbox.max_value = 100.0
	_tile_spinbox.step = 0.25
	_tile_spinbox.value = ground_tile_size
	_tile_spinbox.custom_minimum_size = Vector2(60, 30)
	_tile_spinbox.value_changed.connect(_on_tile_changed)
	_tile_top_row.add_child(_tile_spinbox)
	_tile_control_area.add_child(_tile_top_row)
	# 第二行：滑条单独占满宽度
	_tile_slider = HSlider.new()
	_tile_slider.custom_minimum_size = Vector2(0, 32)
	_tile_slider.min_value = 0.5
	_tile_slider.max_value = 100.0
	_tile_slider.step = 0.5
	_tile_slider.value = ground_tile_size
	_tile_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 给滑条轨道的样式，一眼能看见条在哪
	var slider_box: StyleBoxFlat = StyleBoxFlat.new()
	slider_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	slider_box.content_margin_top = 2
	slider_box.content_margin_bottom = 2
	slider_box.corner_radius_top_left = 4
	slider_box.corner_radius_top_right = 4
	slider_box.corner_radius_bottom_left = 4
	slider_box.corner_radius_bottom_right = 4
	_tile_slider.add_theme_stylebox_override("slider", slider_box)
	_tile_slider.add_theme_stylebox_override("grabber_area", slider_box)
	# 滑块圆点做大，高亮
	var grabber_box: StyleBoxFlat = StyleBoxFlat.new()
	grabber_box.bg_color = Color(0.5, 0.5, 0.5)
	grabber_box.content_margin_left = 8
	grabber_box.content_margin_right = 8
	grabber_box.content_margin_top = 10
	grabber_box.content_margin_bottom = 10
	grabber_box.corner_radius_top_left = 12
	grabber_box.corner_radius_top_right = 12
	grabber_box.corner_radius_bottom_left = 12
	grabber_box.corner_radius_bottom_right = 12
	var grabber_hl: StyleBoxFlat = grabber_box.duplicate()
	grabber_hl.bg_color = Color(0.7, 0.7, 0.7)
	_tile_slider.add_theme_stylebox_override("grabber", grabber_box)
	_tile_slider.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	_tile_slider.add_theme_stylebox_override("grabber_pressed", grabber_hl)
	_tile_slider.value_changed.connect(_on_tile_changed)
	_tile_control_area.add_child(_tile_slider)
	ground_sec.add_child(_tile_control_area)
	# 纹理按钮列表容器（刷新时往里填）
	_ground_list_container = VBoxContainer.new()
	_ground_list_container.add_theme_constant_override("separation", 4)
	ground_sec.add_child(_ground_list_container)
	_rebuild_ground_buttons()


## 属性面板:右侧弹一栏,字段绑选中物件的 EntityProperties。
## 选中物件 = 该物件根上挂的 EntityProperties 组件。改控件回写属性。
func _build_prop_panel() -> void:
	_prop_panel = PanelContainer.new()
	_prop_panel.name = "PropPanel"
	_prop_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE, true)
	_prop_panel.set_offset(SIDE_TOP, 50)
	_prop_panel.set_offset(SIDE_BOTTOM, -10)
	_prop_panel.set_offset(SIDE_RIGHT, -10)
	_prop_panel.set_offset(SIDE_LEFT, -260)
	_prop_panel.custom_minimum_size = Vector2(240, 0)
	_prop_panel.visible = false
	_ui_layer.add_child(_prop_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_prop_panel.add_child(scroll)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	_prop_title = Label.new()
	_prop_title.text = "未选中物件"
	_prop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_prop_title)
	vbox.add_child(HSeparator.new())
	# 显示名
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	var nlbl: Label = Label.new()
	nlbl.text = "名字"
	nlbl.custom_minimum_size = Vector2(50, 0)
	nlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(nlbl)
	_prop_name_edit = LineEdit.new()
	_prop_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_name_edit.text_changed.connect(_on_prop_name_changed)
	name_row.add_child(_prop_name_edit)
	vbox.add_child(name_row)
	# 玩家可见(勾选框):勾上=玩家+GM 都看得到(visibility=BOTH);
	# 勾掉=仅 GM 看,投屏那头被 cull_mask 关掉(visibility=GM_ONLY)。
	_prop_vis_chk = CheckBox.new()
	_prop_vis_chk.text = "玩家可见"
	_prop_vis_chk.toggled.connect(_on_prop_vis_toggled)
	vbox.add_child(_prop_vis_chk)
	# 可透光(勾选框):勾上=透光→los_occluder=false(不挡视线,战争迷雾不算它);
	# 勾掉=不透光→los_occluder=true(挡视线)。引擎无法从 mesh 自动判透光,
	# 只能 GM 手标(2026-07-09 推翻旧"物理事实"判定)。默认勾掉(不透光)。
	_prop_los_chk = CheckBox.new()
	_prop_los_chk.text = "可透光"
	_prop_los_chk.toggled.connect(_on_prop_los_toggled)
	vbox.add_child(_prop_los_chk)
	# 可破坏(勾选框)
	_prop_destructible_chk = CheckBox.new()
	_prop_destructible_chk.text = "可破坏"
	_prop_destructible_chk.toggled.connect(_on_prop_destructible_toggled)
	vbox.add_child(_prop_destructible_chk)
	# 可当掩体(勾选框):勾上=能挡子弹(cover_level=FULL),勾掉=NONE。
	_prop_cover_chk = CheckBox.new()
	_prop_cover_chk.text = "可当掩体"
	_prop_cover_chk.toggled.connect(_on_prop_cover_toggled)
	vbox.add_child(_prop_cover_chk)
	# 最大生命(放最下面)
	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	var hlbl: Label = Label.new()
	hlbl.text = "最大生命"
	hlbl.custom_minimum_size = Vector2(80, 0)
	hlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_row.add_child(hlbl)
	_prop_max_hp_spin = SpinBox.new()
	_prop_max_hp_spin.min_value = 1
	_prop_max_hp_spin.max_value = 9999
	_prop_max_hp_spin.value = 10
	_prop_max_hp_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_max_hp_spin.value_changed.connect(_on_prop_max_hp_changed)
	hp_row.add_child(_prop_max_hp_spin)
	vbox.add_child(hp_row)


## 加一个可折叠的栏位。返回它的内容容器——栏位里的按钮/控件都挂这个容器上,
## 别直接挂总 vbox。点标题切内容容器显隐,标题前的 ▼/▶ 标展开/收起态。
## 依据:Button.flat=true 既保留按钮的可点性又去掉框线,视觉上等同原 Label;
## lambda 闭包捕获 content/btn/title,GDScript 4.x 支持(离线文档 gdd_1590 @GDScript)。
func _add_section(parent: VBoxContainer, title: String) -> VBoxContainer:
	parent.add_child(HSeparator.new())
	var btn: Button = Button.new()
	btn.text = "▼ " + title
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.flat = true
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	parent.add_child(btn)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	parent.add_child(content)
	btn.pressed.connect(func() -> void:
		content.visible = not content.visible
		btn.text = ("▼ " if content.visible else "▶ ") + title
	)
	return content


func _btn_ground(ts: Dictionary) -> Button:
	var btn: Button = Button.new()
	btn.text = str(ts["_base"]).capitalize()
	btn.custom_minimum_size = Vector2(0, 44)
	if ts.has("albedo"):
		var img: Image = Image.load_from_file(ts["albedo"])
		if img:
			img.resize(48, 48, Image.INTERPOLATE_LANCZOS)
			btn.icon = ImageTexture.create_from_image(img)
			btn.expand_icon = true
	btn.pressed.connect(_on_ground_clicked.bind(ts))
	# 存元数据供右键删除用（跟模型栏同一套：_unhandled_input 里 gui_get_hovered_control 找按钮读 meta）
	btn.set_meta("kind", "ground")
	btn.set_meta("group", str(ts["_base"]))
	btn.set_meta("source", ts.get("source", "builtin"))
	return btn


func _delete_ground_item(group_name: String) -> void:
	if not _library_mgr.delete_ground_texture(group_name):
		_tool_label.text = "删除失败：" + group_name
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	# 若当前地面正在用这套纹理，清掉选中避免指向已删文件
	if _active_ground_ts.get("_base", "") == group_name:
		_active_ground_ts = {}
		_tile_control_area.visible = false
	_rebuild_ground_buttons()
	_tool_label.text = "已删除纹理：" + group_name
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _on_ground_clicked(ts: Dictionary) -> void:
	print("Gvtt: on_ground_clicked base=" + str(ts.get("_base", "?")) + " has_albedo=" + str(ts.has("albedo")))
	if _active_ground_ts == ts:
		return  # 同一纹理重复点击不重建材质
	_active_ground_ts = ts
	var base_name: String = ts.get("_base", "")
	# 铺满模式(默认贴图):一张图永远铺满整个地面,跟场景拉伸。平铺控件藏掉(铺满模式调平铺没意义)。
	# 重复模式(其他纹理):按 ground_tile_size 格数重复铺,默认每张 5m×5m 一格,显示平铺控件给 GM 调。
	var is_fill: bool = base_name == DEFAULT_GROUND_TEX_BASE
	_tile_control_area.visible = not is_fill
	if is_fill:
		# 铺满模式:ground_tile_size 不参与 UV(见 _ground_uv_scale),存个占位值随场景存盘即可
		ground_tile_size = 0.0
	else:
		ground_tile_size = 5.0
	# 同步平铺控件值(不触发 value_changed 递归)
	if _tile_slider != null:
		_tile_slider.set_value_no_signal(ground_tile_size)
	if _tile_spinbox != null:
		_tile_spinbox.set_value_no_signal(ground_tile_size)
	# 把"用了哪套纹理"写进内容层 SceneProps,随场景存盘(修 bug1)。
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.ground_tex_base = base_name
		_content_root.ground_tile = ground_tile_size
	print("[BUG1] _on_ground_clicked 场景=%s 写入tex_base=%s tile=%s" % [_current_scene_name, _content_root.ground_tex_base, _content_root.ground_tile])
	_scene_dirty = true  # 改了纹理=当前场景有未存改动
	_apply_ground_texture()


func _on_tile_changed(value: float) -> void:
	ground_tile_size = value
	# 滑条和数字框双向同步，锁住递归
	if _tile_slider.value != value:
		_tile_slider.set_value_no_signal(value)
	if _tile_spinbox.value != value:
		_tile_spinbox.set_value_no_signal(value)
	# 把平铺尺寸写进内容层 SceneProps,随场景存盘(修 bug1)。
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.ground_tile = value
	_scene_dirty = true  # 改平铺=未存改动
	_apply_ground_texture()
	_tool_label.text = "地面平铺：%.1f 格" % value
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 算当前地面贴图的 UV 平铺缩放(Vector3，前两维给 uv1_scale.x/y)。
## 两种模式:
##   - 铺满模式(默认贴图):一张图永远铺满整个地面,场景变长方形/改大小贴图都跟着拉伸。
##     UV 缩放 = 场景宽高(一张图覆盖整个地面,不重复)。依据:uv1_scale 是 UV 坐标乘数,
##     scale=尺寸时整张贴图被映射到 [0,尺寸] 即整个 PlaneMesh(gdd_0407 StandardMaterial3D.uv1_scale)。
##   - 重复模式(其他纹理):按 ground_tile_size 格数重复铺(一张图覆盖 tile_size 米,场景大就重复多次)。
##     UV 缩放 = 尺寸 / tile_size。
## base = 当前纹理组名; w/h = 场景真实宽高; tile = 平铺格数。
func _ground_uv_scale(base: String, w: float, h: float, tile: float) -> Vector3:
	if base == DEFAULT_GROUND_TEX_BASE:
		# 默认贴图:一张铺满整个地面,场景变长方形/改大小都跟着 PlaneMesh 拉伸。
		# uv1_scale=(1,1) 让贴图整张映射到 PlaneMesh 的 [0,1] UV 范围(整个平面),
		# PlaneMesh size 变了 UV 范围不变,贴图自动跟着拉伸铺满。
		# 依据:gdd_0864 BaseMaterial3D.uv1_scale="UV 坐标乘以这个值",PlaneMesh 默认 UV=[0,1]。
		# (此前误写成 Vector3(w,h) → UV 变 [0,w]×[0,h] 贴图重复 w×h 次,是重复不是铺满,已修)
		return Vector3(1.0, 1.0, 1.0)
	return Vector3(1.0 / tile * w, 1.0 / tile * h, 1.0)


func _apply_ground_texture() -> void:
	if _ground == null or not is_instance_valid(_ground):
		return
	var g: MeshInstance3D = _ground
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	_apply_texture_set(_active_ground_ts, mat)
	# UV 平铺:默认贴图铺满拉伸,其他纹理按 ground_tile_size 重复。
	# 场景真实宽高从 _content_root 的 SceneProps 读(点纹理按钮时不改尺寸,读当前存值)。
	var w: float = _current_scene_width()
	var h: float = _current_scene_height()
	mat.uv1_scale = _ground_uv_scale(_active_ground_ts.get("_base", ""), w, h, ground_tile_size)
	g.set_surface_override_material(0, mat)


## 切场景读回后按"纹理组名 + 平铺尺寸"重建地面材质上到骨架 Ground。
## 修 bug1:每场景纹理独立。base=""=没贴纹理用裸色(ground_color);否则按组名在
## _ground_sets 里找对应那套 ts。tile=平铺尺寸。同步左栏平铺控件值(不触发递归)。
func _apply_ground_texture_for_scene(base: String, tile: float) -> void:
	print("[BUG1] _apply_ground_texture_for_scene 重建 base=%s tile=%s" % [base, tile])
	ground_tile_size = tile
	# 按组名扫 _ground_sets 找对应纹理 set;找不到(含 base="")→空 set=裸色地面。
	var found_ts: Dictionary = {}
	if base != "":
		for s: Dictionary in _ground_sets:
			if s.get("_base", "") == base:
				found_ts = s
				break
	_active_ground_ts = found_ts
	# 同步左栏平铺控件(不触发 value_changed 递归)
	if _tile_slider != null:
		_tile_slider.set_value_no_signal(tile)
	if _tile_spinbox != null:
		_tile_spinbox.set_value_no_signal(tile)
	if _tile_control_area != null:
		# 平铺控件只在"重复模式"(非默认贴图)显示;没贴纹理 或 默认贴图(铺满模式)都藏。
		_tile_control_area.visible = (base != "" and base != DEFAULT_GROUND_TEX_BASE)
	_apply_ground_texture()


func _on_mode_btn_pressed() -> void:
	if ModeGate.is_edit():
		ModeGate.switch_to(ModeGate.AppMode.RUN)
	else:
		ModeGate.switch_to(ModeGate.AppMode.EDIT)


# —— 子模式切换 / 保存视角 / 恢复视角 ——
func _on_sub_btn_pressed() -> void:
	# 在 地图 ↔ 自由视角 之间切。两态都能按。真值交给 ModeGate。
	if ModeGate.is_sub_map():
		ModeGate.switch_edit_sub_mode(ModeGate.EditSubMode.ORBIT)
	else:
		ModeGate.switch_edit_sub_mode(ModeGate.EditSubMode.MAP)


func _on_save_view_pressed() -> void:
	# 编辑态专用:把当前自由视角四量存为"游玩视角"权威(saved)。
	# 之后切运行态自动套用、运行态"恢复视角"也回到这套。
	_saved_orbit_dist = _orbit_dist
	_saved_orbit_yaw = _orbit_yaw
	_saved_orbit_pitch = _orbit_pitch
	_saved_orbit_focus = _orbit_focus
	_tool_label.text = "已保存游玩视角"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _on_restore_view_pressed() -> void:
	# 运行态专用:GM 临场转飘了,一按回到 saved 的游玩视角。
	_orbit_dist = _saved_orbit_dist
	_orbit_yaw = _saved_orbit_yaw
	_orbit_pitch = _saved_orbit_pitch
	_orbit_focus = _saved_orbit_focus
	_update_orbit_camera()
	_refresh_grid()
	_tool_label.text = "已恢复游玩视角"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


# —— 投屏开关 ——
# 投屏窗口旁路于 ModeGate(见 docs/architecture.md 3.6),编辑/运行两态都能按。
# 本地窗口,不联网;腾讯会议可「只共享这个窗口」。
func _on_cast_btn_pressed() -> void:
	if _cast_view == null or not is_instance_valid(_cast_view):
		return
	if _cast_view.is_open():
		_cast_view.close()
		_cast_btn.text = "投屏 ⧉"
		_tool_label.text = "投屏已关闭"
		_tool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		_cast_view.open(self)
		_cast_btn.text = "停止投屏"
		_tool_label.text = "投屏窗口已开（玩家视角）"
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _on_edit_sub_mode_changed(sub: ModeGate.EditSubMode) -> void:
	# 子模式变了:刷新顶栏按钮文字 + 重算相机(正交↔透视)。
	_apply_topbar_for_mode(ModeGate.current())
	_apply_camera_for_mode(ModeGate.current())


func _on_mode_changed(mode: ModeGate.AppMode) -> void:
	# 只做协调：每个跨态功能自己关自己的开关，互不干扰。
	_apply_topbar_for_mode(mode)
	_apply_panel_for_mode(mode)
	_apply_camera_for_mode(mode)
	_apply_gizmo_for_mode(mode)


# —— 功能自报归属规矩示范 ——
# 每个跨态功能写一个自己的 _apply_xxx_for_mode(mode)，只管自己那一摊。
# 新加功能（Token/光源/破坏）照此各加一个，不准把开关逻辑堆进 _on_mode_changed。

func _apply_topbar_for_mode(mode: ModeGate.AppMode) -> void:
	if mode == ModeGate.AppMode.EDIT:
		_mode_btn.text = "运行 ▶"
		_mode_label.text = "编辑态"
		# 保存视角=编辑态专属(调"游玩视角"权威);恢复视角不用,因为编辑就是权威的家。
		_save_view_btn.visible = true
		_restore_view_btn.visible = false
	else:
		_mode_btn.text = "◀ 编辑"
		_mode_label.text = "运行态"
		# 运行态:保存权限不在你这;转飘了用"恢复视角"回到 saved。
		_save_view_btn.visible = false
		_restore_view_btn.visible = true
	# 子模式按钮文字:两态都显示,指明当前是哪种相机模式。
	# 注:子模式保存是"会话级",GM 在运行态切的也可带回编辑态(因真值在 ModeGate)。
	if ModeGate.is_sub_map():
		_sub_btn.text = "地图"
	else:
		_sub_btn.text = "自由视角"


func _apply_panel_for_mode(mode: ModeGate.AppMode) -> void:
	if mode == ModeGate.AppMode.EDIT:
		_left_panel.visible = true
	else:
		_left_panel.visible = false
		_clear_all_model_selections()  # 运行态清所有栏位选中（单选语义）


## 全场唯一共享 gizmo(单选模式)。左键点中物件 → clear+select 目标;
## 点空白 → clear_selection(手柄全没)。与 Godot 编辑器/Blender 的"点哪个
## 出现哪个"单选做法一致(一套手柄绑当前 active 物件)。多选(Shift 加选)暂不做。
var _gizmo: Gizmo3D = null

func _apply_gizmo_for_mode(mode: ModeGate.AppMode) -> void:
	# 单套 gizmo 的跨态开关。三连约束(gizmo3D _process 每帧重置 visible):
	# 编辑态 set_process(true)+交给 _update_transform_gizmo 按 count>0 自显;
	# 运行态 clear_selection + set_process(false) + visible=false 全关手柄。
	if _gizmo == null or not is_instance_valid(_gizmo):
		return
	if mode == ModeGate.AppMode.EDIT:
		_gizmo.set_process(true)
		# visible 不这里硬设——gizmo _process 会按当前选中数自动决定显隐。
		# 切回编辑态时若仍记得上次选中,select 会恢复手柄;暂不恢复(单选语义下
		# 切态即清选中更符合直觉),故这里不主动 reselect。
	else:
		_gizmo.clear_selection()
		_gizmo.set_process(false)
		_gizmo.visible = false


func _input(event: InputEvent) -> void:
	# 右键菜单：最先处理。右键按下 + 鼠标在左栏 → 弹删除菜单，标记已处理（不转相机）。
	# 必须在下面"右键转相机"逻辑之前，否则右键按下会被转相机抢走、菜单弹不出。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _left_panel != null and _left_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
			_handle_right_click_menu()
			get_viewport().set_input_as_handled()
			return
	# 滚轮缩放:两个子模式都吃滚轮,但意义不同。
	# 地图模式 → 改 _map_size(正交视野范围);自由视角 → 改 _orbit_dist(拉远拉近)。
	if event is InputEventMouseButton and event.pressed:
		var wheel_up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
		var wheel_dn: bool = event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		if wheel_up or wheel_dn:
			var dir: float = -1.0 if wheel_up else 1.0   # 向上滚=拉近
			# 等比缩放:每滚一格乘 1.12(~12%变化),比例手感全程一致。
			# 线性加减(+=常数)的毛病:近处一跳巨大、远处几乎不动。
			var zoom_factor: float = 1.0 + dir * 0.12
			if ModeGate.is_sub_map():
				_map_size = clampf(_map_size * zoom_factor, 5.0, 80.0)
				camera.size = _map_size
			else:
				_orbit_dist = clampf(_orbit_dist * zoom_factor, ORBIT_MIN_DIST, ORBIT_MAX_DIST)
				_update_orbit_camera()
			_refresh_grid()
			return
	# 中键/右键按下:记下"开始拖拽"标记和起始鼠标位置(用 event.position 差分)。
	# 鼠标在左栏面板上时不抢右键/中键——让 UI 自己处理（右键弹删除菜单）。
	# 注意用全局鼠标坐标 get_mouse_position()，跟 _left_panel.get_global_rect() 同坐标系；
	# 用 event.position（相对坐标）会跟全局矩形对不上、判断永远不成立（曾因此 bug 右键被抢）。
	if event is InputEventMouse and _left_panel != null and _left_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_orbit_dragging_yaw = event.pressed
		if event.pressed:
			_orbit_last_mouse = event.position
		else:
			_orbit_last_mouse = Vector2.ZERO
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_orbit_dragging_pan = event.pressed
		if event.pressed:
			_orbit_last_mouse = event.position
		else:
			_orbit_last_mouse = Vector2.ZERO
		return
	# 鼠标拖动位移:用 event.relative(每帧增量,文档原文推荐用法)。
	# Windows 松键会发假 motion(relative=0),用差分天然不受影响。
	if event is InputEventMouseMotion:
		_handle_orbit_mouse_motion(event)


func _handle_orbit_mouse_motion(event: InputEventMouseMotion) -> void:
	# 地图模式:中键拖=平移正交相机的 _map_focus(在地面平面挪)。
	# 自由视角:右键拖=转 yaw/pitch,中键拖=平移 focus(用相机自身朝向投影)。
	if ModeGate.is_sub_map():
		if _orbit_dragging_pan:
			var d: Vector2 = event.relative
			# 符号修正(2026-07-14):鼠标往哪拖画面往哪走(直接操纵感)。
			# 地图模式下鼠标右→画面右→相机左移→focus 减小,故用 -=。
			_map_focus.x -= d.x * camera.size * 0.0015
			_map_focus.z -= d.y * camera.size * 0.0015
			camera.position = _map_focus + Vector3(0, 25.0, 0)
		return
	# 自由视角
	if _orbit_dragging_yaw:
		var d: Vector2 = event.relative
		# 按屏幕高度归一化(社区踩坑提醒:否则不同分辨率手感不一致)。
		# 符号修正(2026-07-14):鼠标往右拖→画面右转(直接操纵感),yaw 减小。
		_orbit_yaw -= d.x * 0.005
		_orbit_pitch = clampf(_orbit_pitch - d.y * 0.005, ORBIT_MIN_PITCH, ORBIT_MAX_PITCH)
		_update_orbit_camera()
	elif _orbit_dragging_pan:
		# 平移 = 沿相机右方向 + 相机前方向(投影到地面)移动焦点,距离越远移得越多。
		var d: Vector2 = event.relative
		var right: Vector3 = camera.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		var fwd: Vector3 = camera.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var pan_scale: float = _orbit_dist * 0.0015
		_orbit_focus -= right * d.x * pan_scale
		_orbit_focus -= fwd * d.y * pan_scale
		_update_orbit_camera()


func _unhandled_input(event: InputEvent) -> void:
	# 放置/选中/删除是编辑态专属操作。运行态直接 return——
	# 权限真值由 ModeGate 持有，不再用本地 current_mode 变量。
	if not ModeGate.is_edit():
		return
	# 删除选中物件：Backspace / Delete / X 任一键按下触发。
	# 安全点：GM 在属性面板"名字"输入框打字时按退格/X是删字，不能删物件——
	# 用 gui_get_focus_owner 拿当前焦点控件，是输入类控件则不响应（文档 gdd_0774 第1341行）。
	# 键码常量依据 gdd_1591 @GlobalScope：KEY_BACKSPACE(第387行)/KEY_DELETE(第403行)/KEY_X(第1079行)。
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_BACKSPACE, KEY_DELETE, KEY_X]:
			if _can_delete_selected():
				_delete_selected()
			return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if _left_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	if _prop_panel.visible and _prop_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	# 左键的两种含义:选了仓库物件 → 放置;没选 → 选中已放物件弹属性面板。
	var active: Dictionary = _get_active_model_item()
	if not active.is_empty():
		_place_model(active["category"], active["index"])
	else:
		_try_select_at_mouse()


## 判断当前能不能删选中物件：得有选中(_prop_target 非空)，且焦点不在输入类控件上
## （GM 在名字框打字时按退格是删字不是删物件）。输入类控件：LineEdit/TextEdit/SpinBox
## 都能接收键盘输入。依据 gdd_0774 Viewport.gui_get_focus_owner(第1341行)。
func _can_delete_selected() -> bool:
	if _prop_target == null or not is_instance_valid(_prop_target):
		return false
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and (focus is LineEdit or focus is TextEdit or focus is SpinBox):
		return false
	return true


## 删除当前选中物件：从内容层摘下并释放 → 清手柄 → 关属性面板 → 置脏（场景有改动）。
## 选中真值在 _prop_target（_select_entity 设的）。删后选中清空。
func _delete_selected() -> void:
	var target: Node3D = _prop_target
	# 先清选中状态（手柄/属性面板），免得释放节点后引用悬空
	_deselect()
	# 从父节点摘下并释放。物件挂在 _content_root 下（_place_building 里 add_child 的）
	target.get_parent().remove_child(target)
	target.queue_free()
	_scene_dirty = true  # 删了物件=当前场景有未存改动(存盘语义一致)
	_tool_label.text = "已删除物件"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 右键在素材按钮上弹"删除"菜单。
## 用 gui_get_hovered_control 拿鼠标下的控件（文档 gdd_0774 第1349行），
## 沿父链找带 "kind" meta 的按钮（hovered 可能是按钮的图标/文字子控件），
## 读 meta 知道删哪个素材。自带素材"删除"灰掉——res:// 打包后只读。
## 用坐标命中检测找按钮（不靠 gui_get_hovered_control——实测在本项目窗口配置下
## 返回 null）。遍历所有素材按钮，鼠标坐标落在哪个按钮的矩形里就弹那个的菜单。
## 跟左键放置判 _left_panel 矩形同源，已被验证可靠。
func _handle_right_click_menu() -> void:
	var mp: Vector2 = get_viewport().get_mouse_position()
	# 遍历模型栏位所有按钮，找鼠标命中的那个
	for category: String in _model_panelss:
		var panel: Dictionary = _model_panelss[category]
		var container: VBoxContainer = panel["container"]
		for c: Node in container.get_children():
			if not (c is Button) or not c.has_meta("kind"):
				continue
			if c.get_global_rect().has_point(mp):
				_popup_delete_menu_model(c, category, c.get_meta("index"))
				return
	# 地面纹理栏按钮
	if _ground_list_container != null:
		for c: Node in _ground_list_container.get_children():
			if not (c is Button) or not c.has_meta("kind"):
				continue
			if c.get_global_rect().has_point(mp):
				_popup_delete_menu_ground(c, c.get_meta("group"), c.get_meta("source"))
				return


## 给命中的模型按钮弹删除菜单。
func _popup_delete_menu_model(btn: Button, category: String, index: int) -> void:
	var is_imported: bool = _model_panelss[category]["items"][index]["source"] == "imported"
	var menu: PopupMenu = PopupMenu.new()
	add_child(menu)
	menu.add_item("删除", 0)
	if not is_imported:
		menu.set_item_disabled(0, true)
		menu.set_item_tooltip(0, "自带素材打包后只读，删不掉")
	else:
		menu.set_item_tooltip(0, "从素材库删除这个模型")
	menu.id_pressed.connect(func(id: int) -> void:
		if id == 0 and is_imported:
			_delete_model_item(category, index)
	)
	menu.close_requested.connect(menu.queue_free)
	# 弹在鼠标位置。用屏幕坐标（DisplayServer.mouse_get_position）——本项目
	# embed_subwindows=false，PopupMenu 是独立 OS 窗口，position 要屏幕坐标；
	# get_viewport().get_mouse_position() 是窗口内局部坐标，会偏到窗口外（曾因此 bug）。
	menu.popup(Rect2(DisplayServer.mouse_get_position(), Vector2.ZERO))


## 给命中的地面纹理按钮弹删除菜单。
func _popup_delete_menu_ground(btn: Button, group_name: String, source: String) -> void:
	var is_imported: bool = source == "imported"
	var menu: PopupMenu = PopupMenu.new()
	add_child(menu)
	menu.add_item("删除", 0)
	if not is_imported:
		menu.set_item_disabled(0, true)
		menu.set_item_tooltip(0, "自带素材打包后只读，删不掉")
	else:
		menu.set_item_tooltip(0, "删除素材库里的「" + group_name + "」纹理文件夹")
	menu.id_pressed.connect(func(id: int) -> void:
		if id == 0 and is_imported:
			_delete_ground_item(group_name)
	)
	menu.close_requested.connect(menu.queue_free)
	menu.popup(Rect2(DisplayServer.mouse_get_position(), Vector2.ZERO))


## 射线拾取:从鼠标位置射一条线,命中场景里的物件根就选中它。
## 拾取靠物理层 + Area3D(CollisionObject3D._input_event 要求 collision_layer 有位,
## 见 gdd_0554 第 163 行)。放物件时给物件根挂了一个拾取 Area3D(见 _place_building)。
func _try_select_at_mouse() -> void:
	var mp: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mp)
	var to: Vector3 = from + camera.project_ray_normal(mp) * 1000.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, 1 << (GvttRenderLayers.PICK_PHYSICS_LAYER - 1))
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		_deselect()
		return
	var collider: Object = hit["collider"]
	if not (collider is Area3D):
		_deselect()
		return
	# 命中的 Area3D 是物件根的 PickProxy 或实体物件的拾取代理 → 向上找到物件根。
	var root: Node3D = _find_entity_root(collider as Area3D)
	if root == null:
		_deselect()
		return
	_select_entity(root)


## 命中的 Area3D 往上找「挂了 EntityProperties 的物件根」。
func _find_entity_root(area: Area3D) -> Node3D:
	var node: Node = area
	while node != null:
		for c in node.get_children():
			if c is EntityProperties:
				return node as Node3D
		node = node.get_parent()
	return null


## 选中某物件根:绑手柄(只有它的手柄出现)+ 弹属性面板绑它的 EntityProperties。
func _select_entity(root: Node3D) -> void:
	# 单选手柄:先清旧选中,再 select 目标 → 手柄移到这个物件上,其余物件不显示手柄。
	# 与 Godot 编辑器/Blender 的单选做法一致(一套手柄绑当前 active 物件)。
	if _gizmo != null and is_instance_valid(_gizmo):
		_gizmo.clear_selection()
		_gizmo.select(root)
	_prop_target = root
	_prop_target_props = null
	for c in root.get_children():
		if c is EntityProperties:
			_prop_target_props = c as EntityProperties
			break
	_prop_panel.visible = true
	if _prop_target_props == null:
		_prop_title.text = "无属性组件"
		return
	_prop_title.text = "选中:" + (_prop_target_props.display_name if _prop_target_props.display_name != "" else root.name)
	_prop_name_edit.set_text(_prop_target_props.display_name)
	_prop_vis_chk.set_pressed_no_signal(_prop_target_props.visibility == EntityProperties.Visibility.BOTH)
	_prop_los_chk.set_pressed_no_signal(not _prop_target_props.los_occluder)
	_prop_destructible_chk.set_pressed_no_signal(_prop_target_props.destructible)
	_prop_cover_chk.set_pressed_no_signal(_prop_target_props.cover_level == EntityProperties.CoverLevel.FULL)
	_prop_max_hp_spin.set_value_no_signal(_prop_target_props.max_hp)


func _deselect() -> void:
	# 取消选中:清手柄(单选语义下点空白手柄全没)+ 关属性面板。
	if _gizmo != null and is_instance_valid(_gizmo):
		_gizmo.clear_selection()
	_prop_target = null
	_prop_target_props = null
	_prop_panel.visible = false


# —— 属性面板回写:改控件 → 写回 EntityProperties → 触发投屏可见层同步 ——
func _on_prop_name_changed(new_text: String) -> void:
	if _prop_target_props == null:
		return
	_prop_target_props.display_name = new_text
	if _prop_target != null:
		_prop_title.text = "选中:" + (new_text if new_text != "" else _prop_target.name)


func _on_prop_destructible_toggled(pressed: bool) -> void:
	if _prop_target_props == null:
		return
	_prop_target_props.destructible = pressed


## 可透光勾选框回写:勾上=透光→los_occluder=false;勾掉=不透光→los_occluder=true。
## 走 set_los_occluder 统一入口(发信号,将来战争迷雾系统订阅重算)。
func _on_prop_los_toggled(pressed: bool) -> void:
	if _prop_target_props == null:
		return
	if _prop_target != null:
		_prop_target_props.set_los_occluder(_prop_target, not pressed)
	else:
		_prop_target_props.set_los_occluder(null, not pressed)


func _on_prop_max_hp_changed(value: float) -> void:
	if _prop_target_props == null:
		return
	_prop_target_props.max_hp = int(value)


func _on_prop_cover_toggled(pressed: bool) -> void:
	if _prop_target_props == null:
		return
	_prop_target_props.cover_level = EntityProperties.CoverLevel.FULL if pressed else EntityProperties.CoverLevel.NONE


func _on_prop_vis_toggled(pressed: bool) -> void:
	if _prop_target_props == null:
		return
	# 勾上=玩家可见(玩家+GM=Visibility.BOTH);勾掉=仅 GM(Visibility.GM_ONLY)。
	_prop_target_props.visibility = EntityProperties.Visibility.BOTH if pressed else EntityProperties.Visibility.GM_ONLY
	# 改可见层 → 同步物件所有 VisualInstance3D 的渲染层 → 投屏相机按 cull_mask 自动筛。
	if _prop_target != null:
		_prop_target_props.apply_render_layer_to(_prop_target)


## 放置模型物件（所有模型栏位共用）。按来源分流加载模型实例：
##   builtin（自带）= ResourceLoader.load 拿 PackedScene 再 instantiate（开发时已导入）；
##   imported（导入）= LibraryManager.load_model_runtime 走 GLTFDocument 运行时加载（gdd_0187）。
## 后续缩放 + 挂 EntityProperties + PickProxy 两来源共用。
func _place_model(category: String, index: int) -> void:
	var item: Dictionary = _model_panelss[category]["items"][index]
	var path: String = item["path"]
	var mp: Vector2 = get_viewport().get_mouse_position()
	var org: Vector3 = camera.project_ray_origin(mp)
	var d: Vector3 = camera.project_ray_normal(mp)
	if abs(d.y) < 0.0001:
		return
	var tt: float = -org.y / d.y
	if tt <= 0:
		return
	var pos: Vector3 = org + d * tt
	# 按来源分流加载模型实例（两者后续都拿到一个 Node instance，共用下面的逻辑）
	var instance: Node = null
	if item["source"] == "imported":
		instance = _library_mgr.load_model_runtime(path)
		if instance == null:
			_tool_label.text = "模型加载失败：" + path.get_file()
			_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			return
	else:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if not (res is PackedScene):
			return
		instance = res.instantiate()
	_reset_all_transforms(instance)
	var root: Node3D = Node3D.new()
	root.position = pos
	root.name = path.get_file().get_basename()
	_content_root.add_child(root)
	root.set_owner(_content_root)
	root.add_child(instance)
	instance.set_owner(_content_root)
	var props: EntityProperties = EntityProperties.new()
	props.name = "EntityProperties"
	root.add_child(props)
	props.set_owner(_content_root)
	var proxy: PickProxy = PickProxy.new()
	proxy.name = "PickProxy"
	proxy.target_node = root
	root.add_child(proxy)
	proxy.set_owner(_content_root)
	root.force_update_transform()
	proxy.fit_from_target_synced()
	_scene_dirty = true
	_clear_all_model_selections()
	_tool_label.text = "已放置：" + path.get_file().get_basename()
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
## 递归把 node 子树所有节点的 transform 归零:position/rotation 清 0、scale 设 ONE。
## 用途:模型自带子节点 position(如 FBX mesh 子节点原点偏 -95)会让几何飘,
## 从导入源头清——_place_model 加载实例后立即调它归零,几何回到原点。
## scale 保留为 ONE(不缩放,保留 glb 原始真实尺寸,2026-07-14 改)。
## 依据:Node3D 的 position/rotation/scale 属性(gdd_0673),归零等价设 transform=Transform3D.IDENTITY。
func _reset_all_transforms(node: Node) -> void:
	if node is Node3D:
		var n: Node3D = node
		n.position = Vector3.ZERO
		n.rotation = Vector3.ZERO
		n.scale = Vector3.ONE
	for c: Node in node.get_children():
		_reset_all_transforms(c)
