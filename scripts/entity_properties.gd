extends Node
class_name EntityProperties
## EntityProperties —— 战术地图物件的属性组件
##
## 挂在物件根 Node3D 上(放建筑时 add_child 进去),持本引擎战术物件
## 的属性字段。依据 docs/entity_properties_schema.md(schema 草稿)。
##
## 属于「功能自报归属」规矩:每件物件自己持有自己的属性,不在 main.gd
## 集中堆。类型安全(每个字段强类型),将来场景保存/加载序列化干净。
##
## 不装 token(角色)字段——那套 20+ 字段留 P2,见 schema 三。
## penetrable 枚举取消(2026-07-09 经用户反问推翻),其语义由 los_occluder
## 布尔重新承载、判定更正为 GM 手标属性(详见文件头【判定更正】段)。
##
## 字段归属判据(满足其一才进 schema):
##   ① GM 世界设定选择(同物理墙可定承重/活动)
##   ② 从物件自身派生不出来的元数据(显示名、投屏可见层)
##
## 【2026-07-09 判定更正】los_occluder(可透光/挡视线)。旧草稿曾把它定性
## "物理事实不进 schema",后经 GM 反问点破:引擎无法从导入的 mesh 分辨透
## 不透光 mesh 没任何语义属性标"是玻璃",材质 transparency 也只能判渲染
## 透明度、判不了"战争迷雾算不算它挡视线"(实心画窗也可挡视线、透明画
## 物也可挡)。唯一可靠来源是 GM 手标。故正式推翻旧判定,los_occluder 进
## schema 为 GM 手标属性。
##
## 战争迷雾预留接口:los_occluder 变化时 emit los_occluder_changed。
## 将来 LOS/迷雾系统 subscribe 这个信号重算该物件;破坏系统把物件砸毁时
## 调 set_los_occluder(false) 同样触发重算。信号现先留,未订阅零副作用。

## GM 给物件起的名字,独立于节点名。
@export var display_name: String = ""

## 是否可破坏。GM 世界设定:同物理墙可定承重砸不动或活动墙可砸穿。
@export var destructible: bool = false

## 最大生命。destructible=true 才有意义。当前仅存字段,不做自动伤害规则(不做规则系统)。
## 默认 20(2026-07-09 按 GM 拍板的默认状态调)。
@export var max_hp: int = 20

## 掩体等级。依据赛博红规则「掩体黄金三定律」:要么能挡子弹要么不能。
## NONE=不能当掩体;FULL=能当掩体(挡子弹)。GM 按场景战术意义判断。
## 默认 FULL(2026-07-09 按 GM 拍板的默认状态调:物件默认可当掩体)。
enum CoverLevel { NONE, FULL }
@export var cover_level: CoverLevel = CoverLevel.FULL

## 可见层归属。决定物件在哪个渲染层 + 投屏相机是否看得到。
## BOTH=玩家+GM 都看得到;GM_ONLY=仅 GM 看,投屏那头被 cull_mask 关掉。
## 默认 BOTH(玩家可见)。
enum Visibility { BOTH, GM_ONLY }
@export var visibility: Visibility = Visibility.BOTH

## 挡不挡视线(战争迷雾接口)。true=挡视线(不透光),战争中角色视线被它隔开;
## false=不挡(透光,如玻璃物件)。引擎无法从 mesh 自动判透不透光,只能 GM 手标
## (2026-07-09 推翻旧"物理事实"判定,见文件头)。默认 true(物件默认不透光)。
## 战争迷雾系统(待做 P2)读这个字段决定是否把它转成雾的遮挡体。
@export var los_occluder: bool = true

## los_occluder 被勾改或被破坏系统调要时 emit。将来 LOS/迷雾系统订阅重算。
signal los_occluder_changed(target: Node, occluder: bool)

## 设 los_occluder 的统一入口(发信号,避免直接赋值漏掉迷雾重算)。
## 破坏系统将来调这个把被砸毁物件设为 false(不再挡视线)。
func set_los_occluder(root: Node, p_occluder: bool) -> void:
	if los_occluder == p_occluder:
		return
	los_occluder = p_occluder
	los_occluder_changed.emit(root, p_occluder)


## 把 visibility 枚举值换算成实际渲染层号(见 GvttRenderLayers)。
## 物件根上的 VisualInstance3D 子节点(模型/光源)用这个层。
func get_render_layer() -> int:
	if visibility == Visibility.GM_ONLY:
		return GvttRenderLayers.RENDER_LAYER_GM_ONLY
	return GvttRenderLayers.RENDER_LAYER_PUBLIC


## 物件被设为某可见层后,要把物件树下所有 VisualInstance3D 的 layers
## 同步过去(CS/装饰模型 + 光源都在 VisualInstance3D 层)。由调用方
## (main.gd 放物件后、属性面板改 visibility 后)调用。
func apply_render_layer_to(root: Node) -> void:
	var mask: int = get_render_layer()
	_apply_layer_recursive(root, mask)

## 递归把节点树下所有 VisualInstance3D 的 layers 设成给定的层掩码。
## 注:VisualInstance3D.layers 是按位掩码(第 N 位=层 N),不是层号本身。
static func _apply_layer_recursive(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child in node.get_children():
		if child is Node3D:
			_apply_layer_recursive(child, layer_mask)