extends Node3D
class_name PickProxy
## PickProxy —— 无实体物件的选中代理
##
## 问题:Godot 4 运行时 3D 拾取(CollisionObject3D._input_event)要求
## input_ray_pickable=true 且 collision_layer 有位(gdd_0554 第 148/163 行)。
## 但光源等无实体物件没有 mesh、没碰撞体,射线穿过去啥也撞不到。
##
## 解法:给这类物件挂一个 Area3D「拾取代理」——贴一个贴合可见标记的
## BoxShape3D,放专门拾取层(不参与物理推斥,monitoring=false)。
## 编辑态显示一个可视标记(半透球)给 GM 点;运行态隐藏标记(玩家不该
## 看到 GM 摆的灯位/机关位)。
##
## 通用机制:可挂到任何无实体节点(光源/机关/触发器)。光源专用外观
## 由挂载方决定,代理本身不写死成光源。
##
## 选中后,传入的 target_node 就是「真实物件根」(光源本身或其 root),
## main.gd 据此弹属性面板。代理只管"点中这件事",不关心物件是什么。

## 代理背靠的真实物件节点。点中代理 → main.gd 选中这个 target。
## ⚠ 必须 @export:场景存盘(pack)只序列化 @export/@export_storage 变量(离线文档
##   gdd_0306 第519行:普通 var 不存进文件)。2026-07-10 game_eval 实测坐实:
##   没加 @export 时存盘→读回 target_node 丢成 null,拾取盒退回 0.6 针孔、点物
##   件失灵。加 @export 后能否自动重连同样要 game_eval 实测(运行时 pack 存 Node
##   引用、读回重连行为文档未写死,见 ResourceSaver 第98行运行时不存 UID)。
@export var target_node: Node3D = null

## 是否显示可视标记球(编辑态可见)。默认 false——给实体物件(墙、房子等有 mesh
## 自带外观的)挂 PickProxy 时不显示标记,只用 Area3D 提供拾取,房子脚下不冒黄圈。
## 给无实体物件(将来看不见的光源/机关位)挂代理时显式设 true,GM 才有"这里有的点"
## 视觉提示。2026-07-09 经用户反馈"为什么脚下有黄圈"修正:此前标记球一概显示且
## 被同步缩成大球,正好挡视线。
@export var show_marker: bool = false

var _marker: MeshInstance3D = null
var _area: Area3D = null
var _shape: BoxShape3D = null

## 拾取盒真实尺寸+中心(本空间,相对 PickProxy 自身原点)。
## 由 main.gd 放房后调 fit_to_aabb() 塞进来——贴合房子真实包围盒,
## 让射线点房子任意位置都能命中,而不是只命中脚底一个 0.6 针孔。
## 2026-07-09 game_eval 实测:写死 0.6 贴原点 → 放出的房子约为 10 大,
## 射线点房身边必擦过针孔命中空(根因),改为贴真实 AABB。
## ⚠ @export(2026-07-13 修 bug3):存盘随场景文件存,读回 _ready 检测到已存值
##   就跳过 _fit_from_target 重算,避免读回时 global_transform 不同导致拾取盒偏移。
@export var _box_size: Vector3 = MARKER_SIZE
@export var _box_center: Vector3 = Vector3.ZERO

const MARKER_SIZE: Vector3 = Vector3(0.6, 0.6, 0.6)


func _ready() -> void:
	# 可视标记:仅当 show_marker=true 时建(给无实体物件用)。实体物件(墙/房等
	# 有 mesh 自带外观)默认 false → 不建、脚下不冒黄圈。标记本身是 VisualInstance3D,
	# 要按物件可见层走(由挂载方调 entity_properties.apply_render_layer_to 同步),不写死。
	if show_marker:
		_create_marker()
	# 拾取 Area3D:贴 BoxShape3D,专门拾取层,不监控物理。
	_area = Area3D.new()
	_area.name = "PickProxyArea"
	_area.input_ray_pickable = true
	_area.collision_layer = 1 << (GvttRenderLayers.PICK_PHYSICS_LAYER - 1)
	_area.collision_mask = 0   # 不扫任何别的层 → 不会被任何物理体触发信号
	# monitoring 必须 true:2026-07-09 实测 intersect_ray 不检测 monitoring=false
	# 的 Area3D(命中空)。设 monitoring=true 让射线能拾取;因 collision_mask=0,
	# 它不会被别的物件 overlap 触发,算力开销可忽略。
	_area.monitoring = true
	_shape = BoxShape3D.new()
	_shape.size = _box_size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = _shape
	_area.add_child(col)
	_area.position = _box_center
	add_child(_area)
	# ⚠ 职责边界(2026-07-14 全盘架构定):PickProxy 只管「点击选中代理」。
	#   挡枪线/战争迷雾将来自有独立的碰撞表征层(战斗层 CombatBody、迷雾层 LOSOccluder),
	#   不许往 PickProxy 里塞战斗/视线判定逻辑。分层理由:AABB 不跟物件旋转,
	#   选中容错高可接受,但挡枪线用旋转后变大的 AABB 会误判(斜物件被当大方块挡枪)。
	#
	# 盒尺寸来源分两种情况:
	# ① 读回(从场景文件加载):_box_size 已是存盘的精确值(非默认 MARKER_SIZE 边长 0.6),
	#   直接用存盘值重建 Area3D 位置,不重算——避免读回 global_transform 跟存盘时不同导致盒偏移。
	# ② 新放置(_place_model 新建):_box_size 还是默认 0.6,**这里不算盒**——
	#   旧版在 _ready 里立刻调 _fit_from_target 算盒,但此刻 instance.scale 刚设、
	#   还没传播到子节点 global_transform,算出错误盒中心(实测:模型中心(0,0,0)、
	#   盒中心却算成(-2.45,5,-0.03),屏幕偏左94px → 点击错位)。
	#   现在改由 main.gd _place_model 放完物件后 force_update_transform 强制同步,
	#   再扫真实世界 AABB 调 fit_to_aabb 塞盒(见 main.gd _place_model)。
	var already_fitted: bool = (_box_size != MARKER_SIZE)
	if already_fitted:
		# 读回:用存盘的 _box_size/_box_center 重建 Area3D 位置(节点是重建的)
		if is_instance_valid(_shape):
			_shape.size = _box_size
		if is_instance_valid(_area):
			_area.position = _box_center
	# 新放置(already_fitted=false):不在此算盒,等 main.gd 调 fit_to_aabb 塞。


## 把拾取盒贴合一个给定的本地 AABB(放房后由 main.gd 调)。
## box 是相对 PickProxy 本空间的真实包围盒(position=盒角,size=尺寸)。
## 让 BoxShape3D.size=盒尺寸、Area3D.position=盒中心,标记球缩到盒尺寸。
## 依据:GeometryInstance3D.get_aabb() 返回本地 AABB(离线文档 4.7 核对);
##       BoxShape3D.size 是盒的 x/y/z 边长;Area3D 局部位移=PickProxy 本空间内盒中心。
func fit_to_aabb(box: AABB) -> void:
	_box_size = box.size
	_box_center = box.position + box.size * 0.5
	if is_instance_valid(_shape):
		_shape.size = _box_size
	if is_instance_valid(_area):
		_area.position = _box_center
	# 标记球缩到贴合盒(让 GM 也能粗看拾取范围);半径取盒半对角近似。
	if is_instance_valid(_marker):
		var sphere: SphereMesh = _marker.mesh as SphereMesh
		if sphere:
			var r: float = (_box_size.length() * 0.5) * 0.5
			sphere.radius = clampf(r, 0.1, 5.0)


## 公开入口:扫 target_node 子树真实世界 AABB,贴合拾取盒。
## 由 main.gd _place_model 放完物件、force_update_transform 同步 transform 后调。
## 取代旧版 _ready 里过早调 _fit_from_target(那时 scale 没传到 global_transform → 盒错位)。
## 调用方负责保证 transform 已同步(节点已在树里 + force_update_transform)。
func fit_from_target_synced() -> void:
	_fit_from_target()


## 扫 target_node 子树所有 GeometryInstance3D 的世界 AABB,合并总盒,
## 映射回 PickProxy 本空间(用自己 global_transform.affine_inverse 折回,不靠
## "与根同原点"假设),贴拾取盒。不带"已 fit"返回值,结果直接喂 fit_to_aabb。
## 依据:GeometryInstance3D.get_aabb() 返回本空间 AABB;
##       global_transform * 点 = 世界点;PickProxy.global_transform.affine_inverse()
##       * 世界点 = PickProxy 本空间点;AABB.expand(点) 累计合并包络。
func _fit_from_target() -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	if not (target_node is Node3D):
		return
	_acc_world = AABB()
	_acc_has = false
	_walk_collect(target_node)
	if not _acc_has or _acc_world.size.length_squared() < 0.0001:
		return
	# 世界盒 8 角点经 PickProxy.global_transform.affine_inverse() 折回本空间,
	# 重新合并成本空间 AABB(用反变换处理 PickProxy 本地任何偏移/旋转)。
	var inv: Transform3D = global_transform.affine_inverse()
	var local_box: AABB = AABB()
	var first: bool = true
	for p in _aabb_corners(_acc_world):
		var lp: Vector3 = inv * p
		if first:
			local_box = AABB(lp, Vector3.ZERO)
			first = false
		else:
			local_box = local_box.expand(lp)
	fit_to_aabb(local_box)


# 递归把 node 子树里所有 GeometryInstance3D 的本空间 AABB 经其 global_transform
# 转世界角点,累计合并进成员 _acc_world(避开 GDScript 传引用坑用成员)。
var _acc_world: AABB = AABB()
var _acc_has: bool = false
func _walk_collect(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi: GeometryInstance3D = node as GeometryInstance3D
		var la: AABB = gi.get_aabb()  # 本空间 AABB
		var gt: Transform3D = gi.global_transform
		for p in _aabb_corners(la):
			var wp: Vector3 = gt * p
			if not _acc_has:
				_acc_world = AABB(wp, Vector3.ZERO)
				_acc_has = true
			else:
				_acc_world = _acc_world.expand(wp)
	for c in node.get_children():
		_walk_collect(c)


# 取一个 AABB 的 8 个角点(本空间或世界空间都行,标量函数)。
func _aabb_corners(b: AABB) -> Array[Vector3]:
	var p: Vector3 = b.position
	var s: Vector3 = b.size
	var arr: Array[Vector3] = []
	arr.append(p)
	arr.append(p + Vector3(s.x, 0, 0))
	arr.append(p + Vector3(0, s.y, 0))
	arr.append(p + Vector3(0, 0, s.z))
	arr.append(p + Vector3(s.x, s.y, 0))
	arr.append(p + Vector3(s.x, 0, s.z))
	arr.append(p + Vector3(0, s.y, s.z))
	arr.append(p + s)
	return arr


## 建半透发光球标记(仅 show_marker=true 时由 _ready 调,给无实体物件用)。
## 标记本身也是 VisualInstance3D,可见层由挂载方调 entity_properties.apply_render_layer_to 同步。
func _create_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "PickProxyMarker"
	_marker.mesh = SphereMesh.new()
	(_marker.mesh as SphereMesh).radius = 0.3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 0.8
	# 4.7 用 shading_mode = SHADING_MODE_UNSHADED(do "不受光照" emissive 标记球)
	# (flags_unshaded 是 Godot 3 旧名,4.7 已改名——离线文档 gdd_0864
	#  BaseMaterial3D 第 112/317/1670 行)。no_depth_test 在 4.7 仍是此名不变(第 90 行)。
	mat.shading_mode = BaseMaterial3D.ShadingMode.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_marker.set_surface_override_material(0, mat)
	add_child(_marker)


## 编辑态显示标记、运行态隐藏。由 main.gd 在 mode_changed 时调。
func set_edit_visible(p_visible: bool) -> void:
	if is_instance_valid(_marker):
		_marker.visible = p_visible