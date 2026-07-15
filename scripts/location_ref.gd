extends Resource
class_name LocationRef
## LocationRef —— 模组清单里一个"地点"的引用(不是场景本体)
##
## 一个"地点"=一个搭好的舞台场景文件,物理上一个 .scn/.tscn。
## LocationRef 只是清单里的一行:显示名 + 指向底本场景文件的路径。
## 设计依据:docs/multi_scene_draft.md 第 1/6 节。

## 给 GM 看的名字("镇广场"、"地牢一层")。
@export var display_name: String = ""

## 这个地点底本场景文件的 res:// 路径。
@export var canonical_path: String = ""