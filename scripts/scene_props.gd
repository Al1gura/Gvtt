extends Node
class_name SceneProps
## SceneProps —— 场景特有属性(非物件的场景状态)
##
## 挂在内容层根(_content_root)上。存"地面用哪套纹理 + 平铺多少格 + 场景多大"这种
## 属于场景、但不是某个建筑物件的状态。随内容层一起 pack 存进场景文件
## (Node 上的 @export 随 PackedScene 序列化,依据见 main.gd 的 @export 同理)。
##
## 读回切场景时,main.gd 按 ground_tex_base(纹理组名) 扫到对应纹理 set、
## 按 ground_tile(平铺尺寸) 重建地面材质上到 Ground 节点,实现"每场景纹理独立"。
## 2026-07-10 修 bug1:此前纹理状态只在 Ground 节点材质上(骨架层不存盘),
## 所有场景共用最后一套纹理;现在挪到这里随场景存。

## 地面纹理组名(对应 _ground_sets 里一套纹理的 _base,如 "stone_floor")。
## 空字符串=用默认纯色地面(ground_color),没贴纹理。
@export var ground_tex_base: String = ""

## 地面平铺尺寸(单位/格)。每次贴图循环多少米重复一次。
@export var ground_tile: float = 2.0

## 场景宽度(米)。地面在 X 轴方向的边长，网格线也画到这个范围。
## 随场景文件存盘，切场景读回时自动恢复。
## 2026-07-14 加:用户需求场景可调大小,不一定是正方形。
@export var scene_width: float = 100.0

## 场景高度(米)。地面在 Z 轴方向的边长。
@export var scene_height: float = 100.0
