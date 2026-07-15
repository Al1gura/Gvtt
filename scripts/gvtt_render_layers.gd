extends RefCounted
class_name GvttRenderLayers
## GvttRenderLayers —— 渲染层 / 拾取层 归口常量

const RENDER_LAYER_PUBLIC: int = 1
const RENDER_LAYER_GM_ONLY: int = 20
const CULL_MASK_ALL: int = 0xFFFFF
const CULL_MASK_PLAYER: int = 0xFFFFF ^ (1 << (RENDER_LAYER_GM_ONLY - 1))
const PICK_PHYSICS_LAYER: int = 20