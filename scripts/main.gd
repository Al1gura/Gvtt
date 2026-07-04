extends Node3D
## Gvtt P0 主场景脚本
## 正交相机 + 网格地面 + 光源 + 阴影

@export var camera_angle: float = 55.0          ## 相机倾斜角度（度）
@export var camera_height: float = 25.0         ## 相机高度
@export var camera_size: float = 25.0           ## 正交相机视野大小
@export var grid_size: int = 50                 ## 网格尺寸
@export var show_grid: bool = true              ## 是否显示网格
@export var grid_color: Color = Color(0.5, 0.5, 0.5, 0.6)  ## 网格线颜色
@export var ground_color: Color = Color(0.3, 0.28, 0.24, 1.0)  ## 地面颜色

var camera: Camera3D


func _ready() -> void:
	_setup_camera()
	_setup_ground()
	if show_grid:
		_draw_grid()


func _setup_camera() -> void:
	camera = $Camera3D
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	_update_camera_transform()


func _update_camera_transform() -> void:
	var angle_rad := deg_to_rad(camera_angle)
	var pivot := $CameraPivot
	# 相机在俯视倾斜角度——用 CameraPivot 做旋转锚点
	var pos_x := 0.0
	var pos_y := camera_height * cos(angle_rad)
	var pos_z := camera_height * sin(angle_rad)
	camera.position = Vector3(pos_x, pos_y, pos_z)
	# 相机看向原点
	camera.look_at(Vector3(0, 0, 0), Vector3(0, 1, 0))


func _setup_ground() -> void:
	var ground := $Ground
	# 创建地面材质
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ground_color
	mat.roughness = 0.9
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(grid_size, grid_size)
	ground.set_surface_override_material(0, mat)


func _draw_grid() -> void:
	var grid_drawer := ImmediateMesh.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GridOverlay"
	add_child(mesh_instance)

	# 在 PlaneMesh 上方略高一点绘制网格
	mesh_instance.position = Vector3(0, 0.02, 0)

	var material := StandardMaterial3D.new()
	material.albedo_color = grid_color
	material.flags_unshaded = true
	material.flags_no_depth_test = true
	mesh_instance.set_surface_override_material(0, material)

	var half := float(grid_size) / 2.0
	# ImmediateMesh 绘制网格线
	grid_drawer.clear_surfaces()
	grid_drawer.surface_begin(Mesh.PRIMITIVE_LINES)

	var current_x := -half
	while current_x <= half:
		grid_drawer.surface_add_vertex(Vector3(current_x, 0, -half))
		grid_drawer.surface_add_vertex(Vector3(current_x, 0, half))
		grid_drawer.surface_add_vertex(Vector3(-half, 0, current_x))
		grid_drawer.surface_add_vertex(Vector3(half, 0, current_x))
		current_x += 1.0

	grid_drawer.surface_end()
	mesh_instance.mesh = grid_drawer


func _input(event: InputEvent) -> void:
	# 鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_size = max(5.0, camera_size - 2.0)
			camera.size = camera_size
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_size = min(80.0, camera_size + 2.0)
			camera.size = camera_size


func _physics_process(delta: float) -> void:
	# 鼠标中键平移
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var motion := Input.get_last_mouse_velocity()
		camera.position.x -= motion.x * delta * 0.5
		camera.position.z -= motion.y * delta * 0.5
		$CameraPivot.position.x += motion.x * delta * 0.5
		$CameraPivot.position.z += motion.y * delta * 0.5
