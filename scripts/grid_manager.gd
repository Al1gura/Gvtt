class_name GridManager
extends Node3D
## Gvtt 网格管理器 —— 移植 Godot 编辑器 3D 网格的方案。
## CPU 算网格线几何体（顶点位置+顶点颜色），shader 只输出颜色。
##
## 核心逻辑翻译自 Godot 源码 node_3d_editor_plugin.cpp 的 _init_grid()：
## - 对数选档：log(px_m_per_px) / log(base) → round → pow = 当前间距
## - 颜色插值（transition 小数部分）用于主/次色 fade
## - 轴线始终不参与 fade/选档
##
## 2026-07-15 改：支持长方形场景（宽≠高），网格范围按场景宽×高画。

const PRIMARY_STEPS: int = 5       ## 每档细分倍数，跟 Godot 编辑器一致（= subdivisions）
const BASE_STEP: float = 1.0       ## 最小网格间距(米)
const LINE_WIDTH: float = 2.0      ## 目标线宽(屏幕像素)

var _grid_width: float = 100.0     ## 场景宽(米)，X 轴方向
var _grid_height: float = 100.0    ## 场景高(米)，Z 轴方向
var _grid_size: float = 100.0      ## 备用(取最大边长，用做 px 选档阈值)

var primary_color: Color = Color(0.85, 0.85, 0.95, 0.7)
var secondary_color: Color = Color(0.5, 0.5, 0.6, 0.35)
var axis_x_color: Color = Color(0.95, 0.35, 0.35, 1.0)
var axis_z_color: Color = Color(0.35, 0.45, 0.95, 1.0)

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _last_px: float = -1.0  ## 缓存的 px 值，变化才重建


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/grid_line.gdshader")
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "GridOverlay"
	_mesh_instance.position = Vector3(0, 0.03, 0)
	add_child(_mesh_instance)


## 设置场景尺寸（宽×高）。下次 update_grid 时网格线会画到新范围。
## 调用方（main.gd）调完这个后应主动调一次 update_grid 让重建生效。
func set_grid_size(width: float, height: float) -> void:
	if width < 1.0:
		width = 1.0
	if height < 1.0:
		height = 1.0
	_grid_width = width
	_grid_height = height
	_grid_size = max(width, height)
	_last_px = -1.0  # 强制下次重建（不依赖 px 阈值）


## 主入口。px = 每像素覆盖的地面米数（main.gd 算好传入）。
## 当 px 变化超过阈值时重建网格几何体。
func update_grid(px: float) -> void:
	if px <= 0:
		px = 0.001
	if abs(px - _last_px) < 0.0001:
		return
	_last_px = px

	# 对数选档（跟 Godot 编辑器一致）
	var d_log: float = log(px / BASE_STEP * 50.0) / log(float(PRIMARY_STEPS))
	var rounded_log: float = round(d_log)
	var space_mult: float = pow(float(PRIMARY_STEPS), rounded_log)
	var spacing: float = BASE_STEP * space_mult
	var transition: float = clampf((d_log - rounded_log) * 2.0 + 0.5, 0.0, 1.0)

	# 世界坐标线宽
	var half_lw: float = px * LINE_WIDTH * 0.5
	var half_w: float = _grid_width * 0.5
	var half_d: float = _grid_height * 0.5  # depth = Z 轴

	# 主/次间距
	var major_spacing: float = spacing * PRIMARY_STEPS

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grid_color: Color = primary_color.lerp(secondary_color, transition)
	var sub_color: Color = Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.0).lerp(
		secondary_color, 1.0 - transition
	)

	var draw_sub: bool = spacing < _grid_size * 0.5
	var steps_x: int = ceili(half_w / spacing)
	var steps_z: int = ceili(half_d / spacing)

	if draw_sub:
		# 次网格线（垂直于 Z 轴，即沿 X 方向）→ 限制 Z 范围到 half_d，沿 X 走到 half_w
		for i in range(-steps_z, steps_z + 1):
			var x: float = float(i) * spacing
			if abs(x) > half_w:
				continue
			if i % PRIMARY_STEPS == 0:
				continue
			_add_line_quad(st, Vector3(x, 0, -half_d), Vector3(x, 0, half_d), half_lw, sub_color)

		# 次网格线（垂直于 X 轴，即沿 Z 方向）→ 限制 X 范围到 half_w，沿 Z 走到 half_d
		for i in range(-steps_x, steps_x + 1):
			var z: float = float(i) * spacing
			if abs(z) > half_d:
				continue
			if i % PRIMARY_STEPS == 0:
				continue
			_add_line_quad(st, Vector3(-half_w, 0, z), Vector3(half_w, 0, z), half_lw, sub_color)

	# 主网格线（每 PRIMARY_STEPS 线合一条，粗一点）
	var major_steps_x: int = ceili(half_w / major_spacing)
	var major_steps_z: int = ceili(half_d / major_spacing)
	for i in range(-major_steps_z, major_steps_z + 1):
		var x: float = float(i) * major_spacing
		if abs(x) > half_w:
			continue
		_add_line_quad(st, Vector3(x, 0, -half_d), Vector3(x, 0, half_d), half_lw * 1.5, grid_color)

	for i in range(-major_steps_x, major_steps_x + 1):
		var z: float = float(i) * major_spacing
		if abs(z) > half_d:
			continue
		_add_line_quad(st, Vector3(-half_w, 0, z), Vector3(half_w, 0, z), half_lw * 1.5, grid_color)

	# 轴线：红 X 蓝 Z，始终在最上层，不参与 fade
	_add_line_quad(st, Vector3(-half_w, 0, 0), Vector3(half_w, 0, 0), half_lw * 2.0, axis_x_color)
	_add_line_quad(st, Vector3(0, 0, -half_d), Vector3(0, 0, half_d), half_lw * 2.0, axis_z_color)

	# 提交给 ArrayMesh
	var mesh: ArrayMesh = st.commit()
	_mesh_instance.mesh = mesh
	var surf_count: int = mesh.get_surface_count()
	for s in range(surf_count):
		_mesh_instance.set_surface_override_material(s, _material)


## 生成一条网格线的几何体（一个四边形=2个三角形=6顶点）。
## start/end 是世界坐标，half_w 是线半宽(世界坐标米)。
func _add_line_quad(st: SurfaceTool, start: Vector3, end: Vector3, half_w: float, color: Color) -> void:
	var dx: float = end.x - start.x
	var dz: float = end.z - start.z
	var len_sq: float = dx * dx + dz * dz
	if len_sq < 0.0001:
		return
	var inv_len: float = 1.0 / sqrt(len_sq)
	var ndx: float = dx * inv_len
	var ndz: float = dz * inv_len
	var pdx: float = -ndz     # 垂直方向（旋转 90°）
	var pdz: float = ndx

	# 世界坐标偏移（垂直方向）
	var offset: Vector3 = Vector3(pdx * half_w, 0, pdz * half_w)

	# 4 个角
	var v0: Vector3 = start + offset
	var v1: Vector3 = start - offset
	var v2: Vector3 = end + offset
	var v3: Vector3 = end - offset

	st.set_color(color)
	st.set_normal(Vector3.UP)

	# 三角形 v0-v1-v2
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	# 三角形 v1-v3-v2
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v2)
