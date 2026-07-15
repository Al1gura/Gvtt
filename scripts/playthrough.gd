extends Resource
class_name Playthrough
## Playthrough —— 一次实际跑团的带团存档(快照,能接续)
##
## 设计依据:docs/multi_scene_draft.md 第 3/6 节。
## 与 ModuleManifest(底本)分开:一个模组底本能跑无数场不同的带团。
## 带一次团砸了镇上墙 → 这里记着,不影响底本;下次接这个 session 继续跑。
##
## visited 用地点显示名做 key;value 是这个地点的"当前已变状态"场景存盘路径
## (没进过的地点不在此 dict 里,切进去时从底本复制一份初始状态)。

## 这场带团的名字("2026-07-09 周三团")。
@export var session_name: String = ""

## 指向哪个模组底本清单(res:// 路径)。
@export var module_path: String = ""

## 当前在哪个地点(填 LocationRef.display_name)。切幕 relocate 此字段。
@export var current_location: String = ""

## {地点显示名 -> 已变状态场景存盘路径}。没进过 → 不在表里。
## 切地点那一刻(决策4"切幕+手动两道保存")把当前地点 pack 进此表对应槽。
@export var visited: Dictionary = {}

## 叙事占位:这场带团的历史笔记(GM 边带边记的剧情进展)。先不做 UI。
@export var historical_notes: String = ""


func mark_visited(location_name: String, state_scene_path: String) -> void:
	visited[location_name] = state_scene_path


func is_visited(location_name: String) -> bool:
	return visited.has(location_name)