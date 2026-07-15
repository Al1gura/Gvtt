@tool
class_name PostImportCenter
extends EditorScenePostImport
## PostImportCenter —— 导入3D模型后自动屏蔽模型自带的位置信息
##
## 配给 FBX 的"Import Script"。导入完成后自动跑:
##  1) 清所有子节点 position=0(模型自带的脏位置,如 mesh 节点 position=-95)
##  2) 算整棵合并 AABB 中心,给根节点设 position=-(中心),让模型几何中心落到根原点
##
## 这样模型资源进来就是"几何居中在原点"的干净状态——
## 放房时物件根 position=地面点,模型几何中心也在地面点,物件显示在哪=物件根 position。
## 存读不再有模型自带脏位置冒出来(修 bug3:切场景回来模型偏移)。
## 依据:离线文档 gdd_1276 EditorScenePostImport._post_import(scene) 拿根节点改后 return。
##
## 用法:Godot 导入 dock → Import Script → Path 选这个 .gd → Reimport。


func _post_import(scene: Node) -> Node:
	if scene == null:
		return null
	# 1) 清所有子节点(非根)的 position/rotation=0,scale 保留导入值(通常1)
	_clear_transforms_recursive(scene, true)
	# 2) 算整棵合并 AABB 中心(几何中心),给根节点设位移让几何居中到原点
	var center: Vector3 = _calc_combined_aabb_center(scene)
	if center.length_squared() > 0.0001 and scene is Node3D:
		(scene as Node3D).position = -center
	return scene


## 递归清节点 position/rotation(scale 保留)。is_root=true 时不清根节点(根位移留给第2步设)。
func _clear_transforms_recursive(node: Node, is_root: bool) -> void:
	if not is_root and node is Node3D:
		(node as Node3D).position = Vector3.ZERO
		(node as Node3D).rotation = Vector3.ZERO
	for c in node.get_children():
		_clear_transforms_recursive(c, false)


## 算整棵树合并 AABB 的几何中心(世界空间)。用成员 _acc_* 累加避开 GDScript 传引用坑。
var _acc_aabb: AABB = AABB()
var _acc_has: bool = false
func _calc_combined_aabb_center(node: Node) -> Vector3:
	_acc_aabb = AABB()
	_acc_has = false
	var root_xf: Transform3D = Transform3D.IDENTITY
	if node is Node3D:
		root_xf = (node as Node3D).transform
	_walk(node, root_xf)
	if not _acc_has:
		return Vector3.ZERO
	return _acc_aabb.position + _acc_aabb.size * 0.5


## 遍历节点树,把每个 GeometryInstance3D 的本地 get_aabb() 经**本节点 transform**
## (不是 global_transform——post-import 时节点还没进场景树,global_transform 拿不到)
## 累加世界位置合并进成员 _acc_aabb。用父链累计 transform 而非 global_transform。
func _walk(node: Node, parent_xf: Transform3D) -> void:
	if node is GeometryInstance3D:
		var gi: GeometryInstance3D = node as GeometryInstance3D
		var local: AABB = gi.get_aabb()
		if local.size.length_squared() > 0.0001:
			var xf: Transform3D = parent_xf * (gi as Node3D).transform
			for p in _aabb_corners(local):
				var wp: Vector3 = xf * p
				if not _acc_has:
					_acc_aabb = AABB(wp, Vector3.ZERO)
					_acc_has = true
				else:
					_acc_aabb = _acc_aabb.expand(wp)
	for c in node.get_children():
		if c is Node3D:
			_walk(c, parent_xf * (c as Node3D).transform)
		else:
			_walk(c, parent_xf)


func _aabb_corners(b: AABB) -> Array:
	var p: Vector3 = b.position
	var s: Vector3 = b.size
	return [p, p + Vector3(s.x,0,0), p + Vector3(0,s.y,0), p + Vector3(0,0,s.z),
			p + Vector3(s.x,s.y,0), p + Vector3(s.x,0,s.z), p + Vector3(0,s.y,s.z), p + s]
