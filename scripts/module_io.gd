extends Node
class_name ModuleIo
## ModuleIo —— 模组/带团存档的存读盘封装 + owner 陷阱处理
##
## 设计依据:docs/multi_scene_draft.md 第 4 节 + 第 8 节坑 1。
## 把"场景保存/加载"所有 Godot API 调用收在这一个文件,
## main.gd / ModuleGate 只调本模块的语义方法,不直接碰 PackedScene/ResourceSaver。
## 依据集中在一处,API 变了只改本文件。
##
## ⚠ 状态:随身带的 API 骨架,方法体能跑但未接入 main.gd 调用。本会话只立结构。


## ⚠ 关键 API 依据(离线文档 4.7 实读核对,非猜测):
##   - PackedScene.pack(node) 把运行中节点树打包成可存盘资源 → gdd_1006 第 135 行
##   - pack 只打包"有 owner 关系"的节点!没设 owner 的子节点被漏 → gdd_1006 第 31-45 行
##   - PackedScene.instantiate() 装回节点树 → gdd_1006 第 129 行
##   - ResourceSaver.save(...) 存盘 → gdd_1477
##   - ResourceLoader.load(path, type_hint, cache_mode) 读回 → gdd_1476 第 165 行
## main.gd _place_building 放物件时未设 owner → 存场景会漏物件(草案坑1)。
## 此模块负责正面解决:存盘前遍历树补 owner。不准绕过去(CLAUDE.md 永远不准逃避问题)。


## 把"一棵运行中节点树"打成 PackedScene 并存盘。返回存盘 Error。
## 存盘前先调 _ensure_ownership 修 owner 陷阱(没 owner 的子节点 pack 时被漏)。
## 依据:PackedScene.pack(gdd_1006 第135行) + ResourceSaver.save(gdd_1477)。
static func save_scene_tree(root: Node, save_path: String) -> int:
	if root == null or not is_instance_valid(root):
		push_error("ModuleIo.save_scene_tree: root 无效")
		return ERR_INVALID_PARAMETER
	# 正面修 owner 陷阱:存盘前确保 root 下所有子树 owner=root,pack 才不漏。
	_ensure_ownership(root, root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	if err != OK:
		push_error("ModuleIo: pack 失败 code=%d path=%s" % [err, save_path])
		return err
	err = ResourceSaver.save(packed, save_path)
	if err != OK:
		push_error("ModuleIo: ResourceSaver.save 失败 code=%d path=%s" % [err, save_path])
	return err


## 把一个存盘的场景读回成节点树(未挂进场景树,调用方 add_child)。
## 依据:ResourceLoader.load(gdd_1476 第165行) + PackedScene.instantiate(gdd_1006 第129行)。
static func load_scene_tree(save_path: String) -> Node:
	if not ResourceLoader.exists(save_path):
		push_warning("ModuleIo.load_scene_tree: 路径不存在 %s" % save_path)
		return null
	var packed: Resource = ResourceLoader.load(save_path, "PackedScene",
		ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
	if packed == null or not (packed is PackedScene):
		push_error("ModuleIo: 载入非 PackedScene: %s" % save_path)
		return null
	return (packed as PackedScene).instantiate()


## 存一个带团存档(Playthrough Resource)到磁盘。
static func save_playthrough(session: Playthrough, save_path: String) -> int:
	if session == null:
		return ERR_INVALID_PARAMETER
	return ResourceSaver.save(session, save_path)


## 读一个带团存档。
static func load_playthrough(save_path: String) -> Playthrough:
	if not ResourceLoader.exists(save_path):
		return null
	var res: Resource = ResourceLoader.load(save_path, "Playthrough",
		ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
	if res == null or not (res is Playthrough):
		return null
	return res as Playthrough


## 读一个模组清单。
static func load_manifest(manifest_path: String) -> ModuleManifest:
	if not ResourceLoader.exists(manifest_path):
		return null
	var res: Resource = ResourceLoader.load(manifest_path, "ModuleManifest",
		ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
	if res == null or not (res is ModuleManifest):
		return null
	return res as ModuleManifest


## 递归把 root 下所有节点 owner 设成 root——修 pack 的 owner 陷阱。
## 依据:gdd_1006 第 31-45 行原文举例:pack 只打包"有 owner 联结"的节点。
## main.gd _place_building 放物件 add_child 未设 owner → 存盘会漏物件。
## 此方法在 save_scene_tree 内部调用,调用方无需关心。
## 注:Godot 里 Node.owner 主要服务于编辑器场景编辑;运行时场景基本不设。
##      这里临时补上仅为 pack 能抓全节点——存完之后是否回退
##      (避运行时意外副作用)留给落地测(game_eval 实证存→读→树完整)。
static func _ensure_ownership(node: Node, owner: Node) -> void:
	for c: Node in node.get_children():
		if c.owner != owner and c.owner == null:
			c.set_owner(owner)
		_ensure_ownership(c, owner)