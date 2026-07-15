extends Node
## CastView —— 投屏窗口（玩家视图输出层）
##
## 创建一个独立原生 Window 显示运行态场景的实时呈现给玩家看。
## 不是第三个 AppMode，旁路于 ModeGate——编辑/运行两态都可开投屏。
## 定位见 docs/design.md「三、3.1」与 docs/architecture.md「3.6」。
##
## PPT 双屏比喻：GM 笔记本屏幕 = main.gd 主窗口（有控件、缩略图），
## 投影/电视 = 这里创建的投屏 Window（纯 3D 画面，无 GM UI）。
##
## 同步原理：Window 继承自 Viewport（gdd_0786 第 3 行），可直接渲染
## 3D 场景。我们显式把投屏 Window 的 world_3d 设成主窗口 view 的
## world_3d 同一资源对象（gdd_0774 第 1177 行 set_world_3d），让它俩
## 共享同一份 World3D——GM 在主窗口拖 Token/砸墙/关灯，投屏窗口实时
## 看到。不靠 own_world_3d=false 隐式继承，因跨原生 Window 祖先关系弱。
##
## 相机：投屏 Window 内挂一颗只读 Camera3D 并 current=true，作为该
## Window 视口的 active 相机（每个 Viewport 一个 active 相机，见
## gdd_0296 第 55-73 行）。主相机在主 Window 仍是它那边的 active，
## 互不抢占。投屏相机默认镜像主相机的姿态位置，每帧同步。

const DEFAULT_SIZE: Vector2i = Vector2i(1280, 720)
const DEFAULT_TITLE: String = "Gvtt — 玩家视角（投屏）"

var _cast_window: Window = null
var _cast_camera: Camera3D = null
var _main_camera: Camera3D = null
var _is_open: bool = false


## 降画质预案开关。默认 false（投屏窗与主窗同等画质）。
## 真在 GM 机上实测发现卡了再设 true 拨开：会把投屏窗的实时阴影等
## 最贵的 3D 特性关掉，玩家那头画面稍糙换流畅。GM 主窗不受影响。
## 注：设的就是投屏 Window（继承自 Viewport，gdd_0786 第 3 行）的
## Viewport 渲染属性，故每个 Viewport 资源独立。这些 Viewport 属性
## 全部经离线文档 4.7 核对（见 _apply_low_quality 注释）。但「在原生
## Window 节点上设这些属性是否就生效」属引擎推断（Window 继承 Viewport）
## 未有官方明示示范，故**需实测**——日后开开关跑游戏验证阴影确实消失
## 才算坐实；否则退回 SubViewport 方案（见 architecture.md 3.6 末段）。
var _low_quality: bool = false


## 由 main.gd 在 _ready 调一次，传主相机引用，用来每帧镜像姿态。
func setup(main_camera: Camera3D) -> void:
	_main_camera = main_camera


func is_open() -> bool:
	return _is_open


## 设置投屏窗是否走降画质模式。可在 open 前调（开关存住），也可事后调
## （若投屏窗已开则即时应用）。默认 false。日后 GM 机实测卡了才拨 true。
## 见上方 _low_quality 注释与 _apply_low_quality 的实测要求。
func set_low_quality(enabled: bool) -> void:
	_low_quality = enabled
	if _is_open and is_instance_valid(_cast_window):
		_apply_low_quality()


## 打开投屏窗口。已在开则忽略。_window_scene_root 是主场景根（Main），
## 用于把投屏 Window 挂进树（保证它随主场景一起释放）。
func open(parent_node: Node) -> void:
	if _is_open and is_instance_valid(_cast_window):
		_cast_window.show()
		_cast_window.grab_focus()
		return
	if _main_camera == null:
		push_warning("CastView: 主相机未注入（未调 setup），投屏镜不到姿态。")
	# 构造投屏 Window
	_cast_window = Window.new()
	_cast_window.name = "CastView"
	_cast_window.title = DEFAULT_TITLE
	_cast_window.size = DEFAULT_SIZE
	_cast_window.borderless = false
	_cast_window.unfocusable = false
	# 注：要让投屏窗变成独立 OS 窗口（能拖到第二屏、被腾讯会议单独共享），
	# 关键在项目设置 display/window/subwindows/embed_subwindows=false。
	# Window.force_native 实测在 embed_subwindows=true 时不生效（引擎强制
	# 保持 false），故不在此设 force_native，改靠全局设置统一关闭嵌入。
	# 代价：所有 Window 派生类（含将来对话框）都变独立 OS 窗——对 GM 桌面
	# 工具反而合适。详见 docs/architecture.md 3.6。
	# 关掉即当隐藏处理（不真释放），方便反复开/关
	_cast_window.close_requested.connect(_on_close_requested)
	# 共享主场景的 World3D：直接设同一资源对象，
	# 两个 Viewport（主窗 + 投屏窗）渲染同一份世界。
	if _main_camera != null:
		var main_vp: Viewport = _main_camera.get_viewport()
		if main_vp != null:
			_cast_window.world_3d = main_vp.world_3d
	# 投屏相机：只读、镜像主相机
	_cast_camera = Camera3D.new()
	_cast_camera.name = "CastCamera"
	_cast_camera.current = true               # 该 Window 视口用这颗相机
	_cast_camera.projection = Camera3D.ProjectionType.PROJECTION_PERSPECTIVE
	_cast_camera.fov = 60.0
	_cast_camera.keep_aspect = Camera3D.KeepAspect.KEEP_HEIGHT
	# 投屏相机 cull_mask = 玩家可见层(关掉 GM-only 第20层)。
	# GM-only 物件(EntityProperties.visibility=GM_ONLY，VisualInstance3D.layers=20)
	# 在玩家投屏那头被 cull_mask 关掉这一层→不渲染。主窗 GM 相机仍全开看得到。
	# cull_mask 不会受 _sync_cast_camera 覆盖(下文只同步 transform/fov/size 等)。
	_cast_camera.cull_mask = GvttRenderLayers.CULL_MASK_PLAYER
	_cast_window.add_child(_cast_camera)
	parent_node.add_child(_cast_window)
	_cast_window.show()
	_cast_window.grab_focus()
	_apply_low_quality()   # 按当前 _low_quality 开关渲染投屏窗
	_sync_cast_camera()
	set_process(true)
	_is_open = true


func close() -> void:
	set_process(false)
	if is_instance_valid(_cast_window):
		_cast_window.hide()
		_cast_window.queue_free()
	_cast_window = null
	_cast_camera = null
	_is_open = false


func _on_close_requested() -> void:
	# 用户点窗口 X：当成「关闭投屏」处理，不退整个程序
	close()


func _process(_delta: float) -> void:
	# 每帧把投屏相机姿态/视野镜到主相机——玩家看到的 = GM 看到的那个画面
	if not _is_open or _cast_camera == null or _main_camera == null:
		set_process(false)
		return
	if not is_instance_valid(_cast_camera) or not is_instance_valid(_main_camera):
		set_process(false)
		return
	_sync_cast_camera()


func _sync_cast_camera() -> void:
	if _cast_camera == null or _main_camera == null:
		return
	if not is_instance_valid(_cast_camera) or not is_instance_valid(_main_camera):
		return
	_cast_camera.global_transform = _main_camera.global_transform
	_cast_camera.projection = _main_camera.projection
	_cast_camera.fov = _main_camera.fov
	_cast_camera.near = _main_camera.near
	_cast_camera.far = _main_camera.far
	_cast_camera.keep_aspect = _main_camera.keep_aspect
	# 正交模式靠 size 决定视野范围；透视模式不用 size。两个子模式都要同步，
	# 否则 GM 在地图模式缩放改 _map_size → 主 camera.size，投屏相机不跟，
	# 两边看到的地块范围会差很多（实测修前 main_size=25 vs cast_size=1）。
	if _main_camera.projection == Camera3D.ProjectionType.PROJECTION_ORTHOGONAL:
		_cast_camera.size = _main_camera.size


## 为日后「GM 能看玩家看不到的隐藏信息」留接口：把投屏相机的 cull_mask
## 关掉若干层（GM-only 层），实现「玩家可见性过滤」。当前不做，先空着。
func set_player_visible_layers(mask: int) -> void:
	if _cast_camera != null and is_instance_valid(_cast_camera):
		_cast_camera.cull_mask = mask


## 降画质预案实现。只在 _low_quality=true 时关投屏窗的贵特性；false 时保持
## 与主窗同等（不做反向恢复——默认开窗就是引擎默认值，等同于高质量）。
##
## 关的是哪些（API 依据 gdd_0774_Viewport.md，属性真实名逐行核对）：
## - positional_shadow_atlas_size（第 955 行，默认 2048）：设 0 = 投屏窗不
##   渲染实时阴影。3D 里阴影最贵之一，design P0 就是光源+实时阴影，关掉
##   这一个就能省掉相当一部分 GPU 双倍绘制里最吃帧的部分。GM 主窗阴影不受
##   影响（每 Viewport 各自一套阴影图资源）。
## - msaa_3d（第 835 行，默认 DISABLED）：保持默认 0=0ff。降画质时也设 0。
##   若以前给投屏开过 MSAA 现在 reset 回 off。
## - use_taa（第 1104 行）：同上 reset 回 false。
## - mesh_lod_threshold（第 809 行，默认 1.0）：提到 2.0 让玩家那头用更粗
##   的 LOD（远处的物件用低面数模型），换性能。
##
## 没动的（有意留拟真）：方向光阴影属 WorldEnvironment/DirectionalLight3D，
## 本身就随 World3D 共享、不重复独立算；体积雾属 Environment，跨 Viewport
## 共享，没法只在投屏那边关——真要关得另给投屏窗配独立 Environment，那
## 架构改动较大，先不做。当前这条降画质预案 = 关投屏窗独立的位置阴影图
## + 粗 LOD，是最小改动、命中"双倍绘制里最贵的阴影那块"。
##
## **实测要求（重要）**：这是预案框架，真正生效与否要到运行时验证——
## 在 Window 节点（非 SubViewport）上调这些 Viewport 属性，文档无明示
## 示范，靠 Window 继承 Viewport 的推断。日后拨 true 后需跑游戏确认投屏
## 那头阴影确实消失/帧率起来才算坐实；若不生效，退回用 SubViewport 方案
## （Window 内嵌 SubViewportContainer→SubViewport，给 SubViewport 设这些
## 属性就有官方明确支持），见 architecture.md 3.6 末段。
func _apply_low_quality() -> void:
	if _cast_window == null or not is_instance_valid(_cast_window):
		return
	if _low_quality:
		_cast_window.positional_shadow_atlas_size = 0
		_cast_window.msaa_3d = Viewport.MSAA.MSAA_DISABLED
		_cast_window.use_taa = false
		_cast_window.mesh_lod_threshold = 2.0
	else:
		# 与引擎默认一致，留显式注释方便日后排查
		_cast_window.positional_shadow_atlas_size = 2048
		_cast_window.msaa_3d = Viewport.MSAA.MSAA_DISABLED
		_cast_window.use_taa = false
		_cast_window.mesh_lod_threshold = 1.0