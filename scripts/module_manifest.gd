extends Resource
class_name ModuleManifest
## ModuleManifest —— 一个模组(一场跑团)的地点清单 + 叙事占位
##
## 设计依据:docs/multi_scene_draft.md 第 6 节。
## 一个"模组"=一场跑团(下午两点到晚上九点那种一局)装的所有地点集合。
## GM 备团时搭好各地点(各一个 .scn),在此清单里登记它们 + 指开场地点。
## 与 Playthrough(带团存档)分开存文件——底本可复用重跑,带团存档是一次性快照。
##
## 叙事文本(notes)先留字段不做 UI(决策5):Resource 加 String 字段近零成本,
## 将来加 UI 只是挂 TextEdit 绑它;不留则将来续兼容旧存档难。

## 模组名(给 GM 在"打开模组"界面看)。
@export var module_name: String = ""

## 这个模组装的地点清单。每个 LocationRef 指向一个底本场景文件路径。
@export var locations: Array[LocationRef] = []

## 开场默认进哪个地点(填 location_ref.display_name)。
@export var start_location: String = ""

## 叙事占位:模组级的 GM 笔记(背景/剧情概要/线索)。先不接 UI。
@export var notes: String = ""


func add_location(loc: LocationRef) -> void:
	locations.append(loc)


func find_location(display_name: String) -> LocationRef:
	for l: LocationRef in locations:
		if l.display_name == display_name:
			return l
	return null