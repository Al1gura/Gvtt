# Gvtt 开发日志

> 实时更新。每次会话结束前由 Claude 更新。

---

## 当前状态

- **当前优先级：** P1 网格换几何体方案完成。场景保存/加载（存→读+切场景换树+纹理随场景存+脏标记+默认空场景+模型偏移从导入源头清 全部 game_eval 闭环通过 2026-07-13，待用户手动跑游戏最终认体感）
- **本轮（2026-07-14 网格重构）**：网格系统从旧 PlaneMesh+fragment shader 替换为 Godot 几何体路线（SurfaceTool 生成网格线几何体 + 顶点颜色 fade）。 移植自 Godot 引擎 node_3d_editor_plugin.cpp 的 _init_grid()。 新增 scripts/grid_manager.gd + shaders/grid_line.gdshader， 改 main.gd（_draw_grid → _init_grid_manager+_refresh_grid，滚轮/切模式触发刷新）。 MAP 正交/ORBIT 透视都支持。⚠待你手动确认视觉效果。
- **复盘教训写入 CLAUDE.md**：①搜索现成方案必须三层（引擎源码→官方文档→社区），涉编辑器行为时引擎源码是权威；②用户说"去看某来源"是停止符和转向指令；③疑问句不一定在提问。
- **当前任务：** 素材库运行时导入系统（用户需求"给每个栏位加导入按钮存进素材库反复用"）。**第一轮**跑通装饰栏位验证整条链路（见下）。**第二轮（本轮）扩到全部 7 栏位**：用户手动测装饰通了后拍板"全部都做了"。**用户两条设计决定**：①模型只支持内置贴图（GLB 嵌入式），FBX 外部贴图路径不管——已存 memory gvtt_model_embedded_textures_only；②地面纹理按文件夹导入（PBR 多图一组），接口留好支持多图，复用自带 _classify_texture 文件名分类——已存 memory gvtt_ground_texture_folder_import。**实现（抽通用逻辑避免代码复制六遍）**：main.gd 加 MODEL_PANELS 常量配置 6 个模型栏位（token/terrain/wall/decor/interactable/light，各带 label/category/builtin_dir）、_model_panels 字典存各栏位运行时状态（items/active_idx/container/import_btn）。通用函数：_build_model_section 循环建栏位、_rebuild_model_items 合并自带+导入、_rebuild_model_buttons/_btn_model 刷新按钮、_on_model_clicked 选中（跨栏位单选，_clear_all_model_selections）、_get_active_model_item 查当前选中、_place_model 按来源分流加载（builtin=ResourceLoader.load(PackedScene)，imported=load_model_runtime）、_on_model_import_pressed/_show_import_dialog/_on_import_file_selected 导入文件。地面纹理独立：_build_ground_section 建栏、_on_ground_import_pressed/_show_import_dir_dialog/_on_import_dir_selected 导入文件夹（FILE_MODE_OPEN_DIR + dir_selected 信号）、_rebuild_ground_buttons 合并自带 _ground_sets + LibraryManager.scan_ground_textures。LibraryManager 加 import_texture_folder（复制整个文件夹）+ scan_ground_textures + _scan_one_ground_folder + _classify_one_texture（跟 main.gd _classify_texture 同规则）。删旧 _decor_items/_decor_list_container/_active_decor_idx/_decor_import_btn/_building_list/_scan_models/_rebuild_decor_items/_rebuild_decor_buttons/_btn_decor/_on_decor_clicked/_on_decor_import_pressed/_place_decor 全部死代码。栏位顺序保持原左栏：场景→Token→地形→地面纹理→墙体→装饰→交互物体→光源（地面纹理插在 terrain/wall 间，循环里判 category=="wall" 时插建）。**game_eval 全验证通过**：①_model_panels 6 栏位全建（cats=[token,terrain,wall,decor,interactable,light]）；②各栏位 items+导入按钮都在（decor=5items=4自带FBX+1用户真导的"网行者test.glb"，其余0items对应 res 空目录）；③地面纹理 ground_sets=2自带+0导入、导入按钮在；④import_texture_folder 复制 stone_floor 文件夹成功、scan_ground_textures 扫到；⑤用户真导的 GLB load_model_runtime 加载返回 Node3D kids=1 无贴图报错（坐实 GLB 稳）。测试导入的 stone_floor 已清理。⚠未验：真人点 7 个导入按钮+选文件/文件夹（game_eval 不能真点 UI），待你手动实操认体感。⚠小瑕疵：导入纹理文件夹名跟自带重了会显示两个同名按钮（如 stone_floor），属使用习惯，导入时换不同文件夹名即可，不堵。下一步：你手动跑游戏测 7 栏位导入体感
- **Git 状态：** 有未提交改动（上一轮全部 + 本轮 main.gd 大改：MODEL_PANELS 常量+_model_panels 字典+_build_model_section/_build_ground_section 循环建栏+通用模型栏位函数族+地面纹理文件夹导入函数族+删旧装饰专用死代码；library_manager.gd 加 import_texture_folder/scan_ground_textures/_scan_one_ground_folder/_classify_one_texture；docs/memory 改）

---

## 开发环境

| 组件 | 状态 | 备注 |
|------|------|------|
| Godot 4.7-stable | ✅ | |
| Godot AI MCP v2.9.1 | ✅ | batch_execute 一次确认 |
| godot-skill | ✅ | GDScript 规范 |
| godot45-gdscript | ✅ | 1050+ 类 API 参考（4.5 版） |
| GodotPrompter | ✅ | 54 技能（2026-07-07） |
| gdstyle v0.1.7 CLI | ✅ | 54 规则 |
| gdstyle 编辑器插件 | ✅ | 编辑器内实时诊断 |
| GdUnit4 v6.x | ✅ | 测试框架 |
| Godot 4.7 离线文档 | ✅ | 1593 文件，15MB（reference/） |
| Gizmo3D v1.0.0 | ✅ | Godot 4.7 零报错加载。集成完成：放置建筑自动绑定 gizmo 手柄（移动/旋转/缩放）。接口：Gizmo3D.select(target)/deselect(target)/clear_selection() |

---

## P1 启动前检查（全部完成）

- [x] .editorconfig（utf-8, LF, GDScript tab, Markdown space）
- [x] .gitignore（*.uid, sandbox/, export_presets.cfg）
- [x] 项目骨架（entities/walls/ terrain/ tokens/, maps/, ui/, sandbox/）
- [x] 命名规范写入 CLAUDE.md
- [x] Input Map ui_drag（左键拖拽，deadzone 0.2）
- [x] 文件结构（已创建功能分组骨架）
- [ ] gdstyle lint（不阻塞 P1）
- [ ] 冒烟测试（不阻塞 P1）

---

## 功能进度

### P0（✅ 2026-07-04）
- [x] 正交相机 + 倾斜视角 + 缩放/平移
- [x] 网格地面 + 光源 + 阴影 + 天空照明
- [x] main.tscn + main.gd

### P1（进行中）
- [x] 编辑↔运行切换（2026-07-07）
- [x] 地面纹理替换（已完成 2026-07-07）
- [x] 地面纹理管理改子文件夹结构（2026-07-08）：每个纹理一个子文件夹，文件夹名=纹理名。单文件→当整张贴图；多文件→分类 albedo/normal/roughness 等
- [x] 地面纹理平铺控制 UI（2026-07-08）：标签+数字输入框+滑条上下两行布局，默认 2.0 格。用 StyleBoxFlat 给滑条轨道和滑块做大圆点样式
- [x] ModeGate 权限闸（2026-07-08）：新增 autoload `scripts/mode_gate.gd` 持有编辑/运行唯一真值；main.gd 的 `_on_mode_changed` 拆成 `_apply_topbar/_apply_panel/_apply_camera/_apply_gizmo` 四个分派，确立"功能自报归属"规矩
- [x] Gizmo3D 运行态禁用手柄修复（2026-07-08）：根因是 gizmo3D `_process` 每帧重置 visible，单纯 visible=false 无效；改用 clear_selection + set_process(false) + visible=false 三连；用 `_building_to_gizmo` 泛型字典管理绑定，切回编辑态用 `_gizmo_selections_snapshot` 恢复选中（实现策略 B「玩完留下」的 gizmo 部分）
- [x] 运行态自由视角相机（2026-07-09）：mode_gate.gd 加 `EditSubMode {MAP,ORBIT}` 子模式 + `edit_sub_mode_changed` 信号；main.gd 删 `camera_angle/height/size` 改球坐标四量(yaw/pitch/dist/focus) + saved 四量(游玩视角权威) + `_map_size/_map_focus`(地图模式)。相机投影按子模式切正交/透视。输入:右键拖改 yaw/pitch、滚轮按子模式改 size/dist、中键拖按子模式平移 map_focus 或用相机 basis 投影平移 orbit_focus。删了 `_physics_process` 速度轮询(Input 文档说每 0.1s 才更新会卡顿)。顶栏加三按钮:子模式切换(两态)/保存视角(只编辑态)/恢复视角(只运行态)。依据:three.js OrbitControls 数学模型(见 LucaJunge/godot_orbit_controls,GPL 不兼容本仓 MIT 故只参考思路自实现)。API 经离线文档 4.7 核对:ProjectionType 枚举、event.relative、Input.is_mouse_button_pressed、look_at 每帧重调、pitch 须 clamp。**已 game_eval 实证验证**:开机地图模式(proj=1 正交,pos=(0,25,0)正上方)正确;切自由视角(proj=0 透视,pos=球坐标算出值)正确;改 yaw/pitch/dist/focus 后相机到焦点距离=设的 dist,look_at 对焦正确
- [ ] 物件系统（选中+属性面板骨架已落地 2026-07-09，仓库拖放 UI 待做）
- [~] 物件属性标记（schema + EntityProperties 组件 + 属性面板骨架已落地 2026-07-09，待手动实证闭环；可见层已接投屏 cull_mask）
- [x] 资产栏位结构定稿 + 可折叠（2026-07-09）：main.gd `_build_ui` 左栏顺序定为「场景(0)/Token(0)/地形(0)/地面纹理/墙体(0)/装饰(N)/交互物体(0)/光源(0)」。建筑栏并入装饰（4 个旧 FBX 暂留 `_building_list`，将来扫 `assets/props/` 往里加）。`_add_section` 改可折叠——返回一个 VBoxContainer 内容容器，标题做成 flat Button，点一下切内容容器 visible、标题前 ▼/▶ 标展开/收起态；原平铺挂总 vbox 的地面纹理控件/建筑按钮改挂到各 section 返回容器。API 全经离线文档 4.7 核对：Button.alignment/flat（gdd_0538 第 50/55 行）、CanvasItem.visible（gdd_0542 第 407 行，Control 第 15 行明说继承）、Button.pressed 信号、GDScript lambda 闭包。**本会话 godot-ai MCP 未连，未跑 game_eval 验证，仅逻辑自查无报错——待重连后或用户手动跑游戏确认折叠交互**
- [ ] 场景保存/加载（**存→读+切场景换树+纹理随场景存+脏标记+默认空场景+模型偏移从导入源头清 game_eval 闭环全通过 2026-07-13**：方案乙两层分离、纹理随场景、脏标记、默认空场景、post_import_center.gd 清模型自带位置。见问题表本场条目。仅"真人手点切场景+选中物件"待用户手动最终认）

### P2-P4
- [ ] Token 拖拽
- [ ] LOS 视线遮挡
- [ ] 墙体破坏（需装 Godot-Destruction）
- [ ] 特效触发
- [ ] 场景气氛
- [ ] 色块布局工具
- [ ] 多场景管理（**骨架落地 2026-07-09**：见 `docs/multi_scene_draft.md`。新增 5 个 scripts 文件立结构、未接入 main.gd 不破坏现行游戏：① `module_gate.gd`（class_name ModuleGate，当前模组/地点/session 全局真值+current_location_changed 信号，TODO 落地切幕写盘，拟 autoload 未注册）② `module_manifest.gd`（class_name ModuleManifest Resource，地点清单 locations:Array[LocationRef]+start_location+叙事占位 notes）③ `location_ref.gd`（class_name LocationRef Resource，display_name+canonical_path）④ `playthrough.gd`（class_name Playthrough Resource，带团存档 session_name+module_path+current_location+visited dict+叙事占位）⑤ `module_io.gd`（class_name ModuleIo，save_scene_tree/load_scene_tree/save_playthrough/load_manifest 静态方法，**正面修 owner 陷阱**：save 前调 _ensure_ownership 递归补 owner，依据 gdd_1006 第 31-45 行 pack 只打包有 owner 联结的节点）。@exporttyped Array[Resource子类] 写法依据 gdd_0306 第 474/481 行。划 4 个落地坑待正面解：owner 陷阱已收进 module_io、EntityProperties/PickProxy 序列化重连待 game_eval 实证、切地点主相机+投屏 CastView 重连、编辑态/运行态切地点语义按 ModeGate 分流）
- [ ] 层级切换
- [ ] 投屏模式

---

## 问题记录

| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-09 | **资源库框架搭建。** 用户确认物种类清单，在 assets/ 下新增 8 个子目录占位：walls(可破坏墙体)、terrain(地形)、props(装饰)、lights(光源物件)、interactables(可交互物件,火药桶/配电箱等主动触发型,用户拍板单列)、tokens(Token)、vfx(P3 特效预留)、environment(P3 气氛预留)。每目录写 README.md 说明放什么/格式/对应design.md哪条 + .gitkeep。依据 design.md 第77行物件种类(墙体/地形/装饰/光源/Token)+ 第78行属性标记(可交互是属性标签,用户决定在资源库层单列 interactables 而非贴标签,两者并存不冲突)。保留旧两模块 models/(4FBX建筑) + textures/ground/(地面纹理,main.gd扫描中)。发现 textures/buildings/ 与 models/textures/ 疑似同一批贴图存两份,本次未动待物件系统落地合并。根目录空骨架(entities/maps/objects/resources/ui/sandbox/gvtt/)未动待用户决定。architecture.md 文件结构图已更新(补漏写的 buildings + 新增8模块 + 空骨架标注) | ✅ |
| 2026-07-09 | architecture.md 文件结构图与磁盘不符：漏写 assets/textures/buildings/；未记空骨架目录。已更新补全 | ✅ |
| 2026-07-08 | Gizmo3D `_draw()` 三角化失败（gizmo3D.gd:338）——三点退化跳过不画已修 | ✅ 已修(加面积保护跳过退化三角形) |
| 2026-07-08 | `_building_to_gizmo` 字典只增不 erase，将来删建筑必须同步 erase 否则坏账 | 📌 潜伏债，已在代码注释提醒 |
| 2026-07-08 | `*.bak` 备份被 Git 跟踪——已加 .gitignore 并删 main.gd.bak | ✅ 已清 |
| 2026-07-08 | ModeGate 改造 + gizmo 运行态禁用 + 地面纹理结构改造 + 平铺 UI | ✅ |
| 2026-07-09 | **投屏窗口（玩家视角第三块）落地。** 架构定调：投屏窗口旁路于 ModeGate，是运行态的输出层，不是第三个 AppMode。新增 `scripts/cast_view.gd`：独立原生 `Window` + 只读 `Camera3D`，显式 `cast_window.world_3d = main_vp.world_3d` 共享同一 World3D 资源对象实现同步。main.gd 加顶栏"投屏⧉"按钮接 `_cast_view.open(self)/close()`，旁路 mode_changed 不订阅。每帧 `_sync_cast_camera` 把投屏相机姿态镜到主相机。API 全经离线文档 4.7 核对（Window/Viewport/Camera3D 三个类）。**game_eval 双轮实证**:open 后 is_open=true、cast_window_world3d_is_main=true（两窗口共享同一世界）、cast_cam_current + main_cam_current 都 true（两窗各一 active 相机不抢）。**踩坑:** 要让投屏窗变独立 OS 窗口（能拖第二屏/被腾讯会议单独共享），`Window.force_native` 实测在 `embed_subwindows=true`（项目默认）下被引擎强制保持 false、走不通；最终改全局 `display/window/subwindows/embed_subwindows=false` 解决，实测改后 is_embedded=false、cast_window_id=1≠main_window_id=0。代价：所有 Window 派生类（含将来对话框）都变独立 OS 窗，对 GM 桌面工具反而合适。design.md 三、3.1/3.2 与 architecture.md 3.6 已更新 | ✅ 已验证 |
| 2026-07-09 | 投屏 bug：GM 在地图（正交）模式缩放后，投屏窗看到的范围跟主窗不一致。根因 `_sync_cast_camera` 只复制了 position/rotation/projection/fov/near/far，漏了正交相机专属的 `size`（正交视野范围）。GM 滚轮改 `_map_size→main.camera.size`，投屏相机 size 一直停在默认 1。修：正交模式下加 `_cast_camera.size = _main_camera.size`。game_eval 实证修后 main_size=25 == cast_size=25 | ✅ 已修 |
| 2026-07-09 | **降画质预案留框架（默认关闭）。** 担心 GM 机双窗口双倍 GPU 绘制卡。cast_view.gd 加 `_low_quality` 开关 + `set_low_quality(bool)` + `_apply_low_quality()`。开时关投屏窗的 `positional_shadow_atlas_size=0`(实时阴影)、msaa/use_taa 关、`mesh_lod_threshold=2.0` 粗 LOD；GM 主窗不受影响。API 全经 gdd_0774 核对（第 809/835/955/1104/231-242 行）。**但有实测要求**：原生 Window 节点上调这些 Viewport 属性是否真生效无文档明示（类比 force_native 坑），日后拨开关跑游戏验证阴影确实掉才算坐实；不生效则退回 SubViewport 方案（gdd_0296 第 173-185 行）。当前默认 false 不影响体验。ARCHITECTURE.md 3.6 + cast_view.gd 已记 | 📌 留框架待实测 |
| 2026-07-09 | 运行态自由视角相机改造（mode_gate.gd 加子模式 + main.gd 球坐标相机 + 三按钮） | 🔄 代码已写入、编辑器无报错加载，等重连 godot-ai MCP 后跑游戏验证 |
| 2026-07-09 | 编辑器 GDScript 脏缓存：逐块 script_patch 改 main.gd 时，编辑器报"Cannot call non-static is_edit() on ModeGate"等错，行号与磁盘代码对不上。根因是 GDScript 脚本缓存层脏，非代码错。重启 Godot 后缓存清、干净运行(recent_errors 全空、helper live) | ✅ 重启 Godot 解决 |
| 2026-07-09 | godot-ai MCP 在本会话未加载（工具列表无 `mcp__godot-ai__*`），无法直接跑游戏验证。需重连 MCP 或新开会话 | ⏳ 待重连 |
| 2026-07-09 | **教训：不准用断链手段"冲"编辑器缓存报错。** 上一会话误用 editor_reload_plugin 想清脏缓存报错，结果报错没清(根因在脚本缓存)、MCP 连接反断、用户被迫重启 Godot。已写入 CLAUDE.md 禁断链规矩 | 📌 已立规矩 |
| 2026-07-09 | 保存视角 bug：保存视角按了但切运行态用的是编辑态当前视角。根因是 `_sync_orbit_to_saved_if_fresh()` 有 `_orbit_inited` 守门，首次切自由视角后就再不从 saved 套用，导致切运行态直接继承编辑态临场转动。修复：删 `_orbit_inited` 守门和 `_sync_to_saved_if_fresh`，改成每次切进自由视角都从 `_saved_orbit_*` 套用。GM 临场转动保护靠"运行态只改 _orbit_* 不动 saved"自然实现。已 game_eval 双闭环验证：保存→切运行态用 saved；恢复视角→回 saved | ✅ 已修 |
| 2026-07-09 | **物件属性标记 schema 落地。** 新增 gvtt_render_layers.gd / entity_properties.gd / pick_proxy.gd 三个 class_name 脚本。改 main.gd 加选中+属性面板，cast_view.gd 投屏相机接 cull_mask=CULL_MASK_PLAYER。schema 决策：①token 与战术物件两个独立 schema 不凑共通层(交集只名字)；②起源——penetrable 枚举原想加，经用户反问"什么叫 GM 脑子里记能不能穿"推翻——可穿透性是物件类型+破坏后状态的物理事实(玻璃型不进LOS、墙进),不是 GM 手标属性,据 design.md 第81-82行 LOS 定义最好自动算,故删字段；③cover_level 按赛博红掩体三定律只用 NONE/FULL 两值(用户引原话"没有部分掩体一说")；④可见层 visibility BOTH/GM_ONLY 接投屏 cull_mask，GM-only 物件投屏那头不渲染。选中方案据 godot-ai subagent 搜证：CollisionObject3D._input_event 要 collision_layer 有位(gdd_0554)，无实体光源靠 PickProxy 代理(Area3D+BoxShape3D 拾取层 monitoring=false) | 🔄 骨架落地 |
| 2026-07-09 | 编辑器脏缓存（同前几次）：scan 后 global_classes_registered_delta=0、main.gd 报"EntityProperties not found"一堆，但 find_symbols 能解析各新脚本、game_eval 里 EntityProperties.new()/GvttRenderLayers.CULL_MASK_PLAYER==524287/PickProxy Area3D collision_layer=524288 全通——确认编辑器报错纯脏缓存、游戏实跑脚本正常。按 CLAUDE.md 规矩承认"编辑器报错、游戏实跑正常"不重启 | ✅ 实证确认 |
| 2026-07-09 | godot-ai `filesystem_manage write_text` 把 gvtt_render_layers.gd 写坏(末尾追加一堆 NUL 字节，报"class_name can only be used once"假错)。改用 Write 工具重写解决。教训：写 GDScript 文件优先 Write 工具，godot-ai write_text 偶发写坏 | ✅ 已修 |
| 2026-07-09 | **选中点不到物件**（用户报"点了没反应"）+ **投屏编辑态还看见 gizmo 手柄**。两个真 bug/game_eval 实证定位：①PickProxy Area3D 我设了 monitoring=false 想省算力，实测 intersect_ray **不检测 monitoring=false 的 Area3D**(射线命中空)。印象"monitoring 只控信号不影响射线"是错的。改 monitoring=true，靠 collision_mask=0 兜底不被触。②gizmo 是场景 3D 节点属共享 World3D 投屏看得见，改 Gizmo3D.layers=1<<19 放 GM-only 渲染层，投屏 cull_mask 关第20层看不到手柄。game_eval 实证监测改后射线命中 PickProxyArea@pos(0,0.3,0)、_select_entity 流程面板可见+title="选中:物件甲"+各字段读回全对 | ✅ 已修 |
| 2026-07-09 | **属性面板改 CheckBox + 顺序 + 加可透光字段 + 默认值调**（用户拍板）。①"可当掩体"OptionButton→CheckBox(勾上=FULL/勾掉=NONE)；②"可见层"→"玩家可见"CheckBox(勾上=BOTH/勾掉=GM_ONLY)；③顺序改 名字→玩家可见→可透光→可破坏→可当掩体→最大生命(血量放最下)。④新增 `los_occluder` 字段(GM 手标挡视线,面板表"可透光"勾上=透光=不挡、勾掉=不透光=挡)。**战争迷雾接口**:entity_properties.gd 加 `signal los_occluder_changed(target, occluder)`+`set_los_occluder(root,bool)` 统一入口,将来 LOS/迷雾系统 connect 它重算、破坏系统砸毁物件调它设 false。⑤默认值调:max_hp 10→20、cover_level NONE→FULL、visibility BOTH、destructible false、los_occluder true(物件默认不透光)。**判定更正(推翻旧记录)**:旧草稿曾定性"是不是玻璃是物理事实不进 schema",2026-07-09 GM 反问点破"引擎无法从 mesh 分辨透不透光,只能 GM 手标"——正式推翻,los_occluder 进 schema。**game_eval 全实证**:面板顺序正确、6 字段默认值全对(20/fa­lse/FULL/BOTH/true)、勾选状态读回正确。schema 草稿 2.0 段+字段表更新,2.3 玻璃预留位删 | ✅ 已实证 |
| 2026-07-09 | **黄圈真因+修**：放房后物件脚下飘黄圈,根因=PickProxy 可视标记球(show_marker)原一概建且被同步缩成大球(从上俯看似圆圈趴脚底)。修:pick_proxy.gd 加 `@export var show_marker: bool = false`,_ready 里仅 show_marker=true 时建标记球。实体物件(墙/房有 mesh 自带外观)默认 false→不建、脚下干净;无实体物件(将来的光源/机关)显式设 true,GM 才有"这里有的点"视觉提示。game_eval 实证放房后 show_marker=false、无 PickProxyMarker 子节点 | ✅ 已实证 |
| 2026-07-09 | **【根因二+闭环】选中点不到物件真因=拾取盒写死 0.6 贴脚底原点**（用户报"点了没反应"，前一轮修 monitoring=true 仍点不中）。game_eval 实证：放出的物件根是空 Node3D，孩子是模型实例(缩放后约 10 大)+EntityProperties+PickProxy；PickProxy 的 Area3D 拾取盒 **写死 0.6 贴物件根原点(脚底一点)**，射线点房身必擦过命中空。修法：pick_proxy.gd 加 `_fit_from_target()`——_ready 里自扫 target_node 子树所有 GeometryInstance3D 的本空间 AABB(get_aabb())经 global_transform 换世界角点合并总盒，再用 PickProxy.global_transform.affine_inverse() 折回本空间，喂 fit_to_aabb 让 BoxShape3D.size=真实尺寸、Area3D.position=真实中心。API 经离线文档 4.7 核对(BoxShape3D.size/GeometryInstance3D.get_aabb/global_transform)。**game_eval 闭环三步实证**:①拾取盒从 0.6 变为真实尺寸(8.57×10.50×5.65、中心(0.31,4.75,0.0));②从物件中心投影屏幕再反推射线 → 命中 PickProxyArea;③调 _select_entity 后 gizmo.select 上+手动触发 _update_transform_gizmo→visible=true 手柄出、_prop_panel.visible=true。另证实 global_transform 在 add_child 同帧已同步(盒贴合准)。`_building_to_gizmo` 字典+`_gizmo_selections_snapshot` 废弃删除,改全场一套共享 gizmo(main._ready 建 `_gizmo`/SharedGizmo),_select_entity 里 `_gizmo.clear_selection()+select(target)`,_deselect 里 `clear_selection()`,_place_building 删掉每房 new gizmo。多选能力(Shift 加选)暂不做记债。**待用户手动实操最终认**(机器模拟射线通了,真实体感以你为准) | 🔄 待手动认 |
| 2026-07-07 | FBX 贴图路径问题——FBX 文件里写死 F:\download...，Godot 找不对贴图。以后模型导出必须勾"嵌入贴图"，旧四个 FBX 不修 | 📌 立素材标准 |
| 2026-07-07 | 设计更正：地面材质笔刷 → 地面纹理替换 | ✅ |
| 2026-07-07 | 设计更正：地面材质笔刷 → 地面纹理替换 | ✅ |
| 2026-07-07 | Godot AI 配置路径不匹配（Claude-3p） | ✅ |
| 2026-07-10 | **左栏老栏位消失真因坐实+修。** 现象:跑游戏左栏只剩"场景"格,Token/地形/地面纹理/墙体/装饰/交互物体/光源七栏完全不显示(完全空白,非折叠)。交接总结方向A(每帧节点暴涨)静态读码筛不到元凶(main.gd 无 `_process`、`_physics_process`空、cast_view/gizmo3D 每帧函数均不造节点);方向b(某段动态清老格子孩子)也筛不到。真凶=main.gd 第475/479行用 Godot 3.x 旧属性名 `hint_tooltip` 给 Button 赋字符串——Godot 4.7 已改名 `tooltip_text`(离线文档 gdd_0565_Control 第103/1311行:`String tooltip_text`,setter `set_tooltip_text`)。该赋值非法→`_build_ui` 在场景格(466行)建完后到475行中断→后面七栏没建。修:两行 `hint_tooltip`→`tooltip_text`。game_eval 实证修后左栏 vbox 孩子=25(=1工具标签+8栏×(1分隔线+1标题按钮+1内容容器)),八栏全回 | ✅ 已修 |
| 2026-07-10 | **godot-ai 探运行态全废的真因坐实。** 前几场 helper_live 恒 false、logs_read(source=game) 恒 0 行、game_eval 连不上——交接总结归因"节点暴涨卡死"_被推翻(游戏明明活着能滚轮)。真因=僵尸 Godot 进程占着 6006(调试适配器)/6005(GDScript语言服务)端口,Godot 启动报 `Failed to start Debug adapter server on port 6006: Already in use` + `port 6005: Already in use`。交接总结"netstat 查无输出=端口非根因"_被推翻(端口就是工具链根因)。交接总结怀疑 `embed_subwindows=false` 把游戏赶独立窗断调试通道_也被推翻(独立窗照样 helper_live=true,embed_subwindows 跟调试通道无关)。解法:让用户重启电脑清掉僵尸进程(对零基础最省事)或任务管理器结束残留 Godot 进程。重启后 project_run 立即 helper_live=true/status=live/game_eval 通。已写 memory gvtt_debug_channel_root_cause | ✅ 已解 |
| 2026-07-10 | **game_eval 代码缩进必须用 tab。** 连续3次 EVAL_COMPILE_ERROR,报错 `Mixed use of tabs and spaces for indentation`。根因:game_eval 包装器把用户代码包进 execute() 协程、每行前加一个 tab 做外层缩进;若我的代码内层用空格→拼成 tab+空格混合→GDScript 解析报错。改纯 tab 缩进即通。已写 memory gvtt_game_eval_tab_indent。教训:写 game_eval 的 code 参数缩进一律 tab(JSON 里写成 `\t`) | ✅ 已知 |
| 2026-07-07 | gdstyle cargo 编译失败 | ✅ 改用预编译 zip |
| 2026-07-07 | 两个 project.godot 不同步 | ✅ |
| 2026-07-07 | 离线文档冗余（2.3GB→15MB） | ✅ |
| 2026-07-14 | **网格改 shader 方案(屏幕恒定宽，对标 Godot/Blender)。** 用户问"近粗远细、屏幕恒定宽"怎么实现，并问 Blender/Godot 怎么做的。查证讲清原理：编辑器/Blender 网格都是 shader 在屏幕空间画的(非画3D线段调粗细——GL 线段恒1像素无厚度属性)；核心是片段着色器里对地面坐标取模算到最近线距离 + fwidth() 算每像素覆盖米数，线宽=fwidth 倍数→屏幕恒定。用户提"搞两个地面不就没事了"——采纳：第二层 PlaneMesh 盖在纹理地面上挂网格 shader，shader 不画线处 alpha=0 透出下层纹理，换纹理只动下层 Ground、网格不受影响。**查证 shader API 依据**(离线文档 gdd_0384_Spatial_shaders)：render_mode unshaded/depth_test_disabled/blend_mix(第30/22/13行)、片段内置 in vec2 UV(第264行)、fwidth 是 GLSL 标准、MODEL/VIEW_MATRIX 等。GridMap(gdd_0619)查证是摆方块非画线、EditorNode3DGizmo 编辑器专用打包不存在——坐实"无现成可移植网格"。**实现**：①新增 shaders/grid_shader.gdshader——spatial shader，uniform grid_size/minor_step/major_step/各级颜色(辅灰0.45/主偏白0.9/X红/Z蓝)/line_px(屏幕像素宽1.5)；片段用 UV*grid_size 得米坐标，grid_line() 取模算距离场，smoothstep 转线强度，轴线用 coord-grid_size/2 算以原点为中心的坐标判断|cz|/|cx|；合成按优先级 if 覆盖(辅→主→X→Z)。②main.gd _draw_grid 整块重写：删旧 _build_grid_layer/_build_grid_axes/_axis_mat 三个函数+四级 ImmediateMesh 节点方案，改成建一个 GridOverlay MeshInstance3D(PlaneMesh 100×100)挂 ShaderMaterial，set_shader_parameter 传 grid_size，y0.02。③_adopt_scene_content reparent 改回只认 GridOverlay(不再认 Major/Axes/AxesZ)。**踩坑**：首跑 shader 编译失败 `Unknown identifier 'm'`(grid_shader.gdshader:67)——改合成逻辑时删了用 m/M 的旧段但新段仍引用 m/M 未补定义，补 `float m=max(minor_x,minor_z); float M=max(major_x,major_z);` 后通过。**game_eval 验证通过**(零报错)：GridOverlay 在/visible/y0.02/mesh100×100/材质是 ShaderMaterial/shader_path=res://shaders/grid_shader.gdshader/grid_size参数=100/shader代码3119字符可取=编译成功。⚠shader 视觉效果(线宽屏幕恒定/近粗远细/红蓝轴位)game_eval 看不到画面，待用户手动看体感 | ✅ game_eval 验证通过(机器层)+待用户体感 |
| 2026-07-14 | **新 UV 图设默认地面 + 网格线改三级(辅线/主线/XZ轴线)。** 用户需求三件：①用桌面新 UV 图替换旧的、②设为默认地面、③网格线加回来且换纹理时网格一直在。**查证**：原 UV 图在 assets/textures/ground/uv_checker/UV-3-790x790.jpg(790²)，默认地面 DEFAULT_GROUND_TEX_BASE=""(裸色无纹理)。GridOverlay 节点 game_eval 实测**在**(_scene_root 下、visible=true、参数全对)，用户看不见的根因=线太淡太密：alpha 仅 0.3、地面放大到 100 后 100 条线挤屏幕糊成一片，不是节点丢了。换纹理不会冲网格(_apply_ground_texture 只改 Ground 材质不碰 GridOverlay 节点)。**改动**：①桌面新图 UV_Checker_4096x4096.png(4096²) 复制进项目——旧图 rm 被拦(Operation not permitted)、allow_cowork_file_delete 工具不认路径，改用单独新文件夹 assets/textures/ground/uv_checker_4096/ 放新图(避免多图同组 _classify_texture 按扫目录顺序不确定哪张生效)，旧 uv_checker 文件夹留旧图不碍事；②main.gd 第31行 DEFAULT_GROUND_TEX_BASE "" → "uv_checker_4096"(纹理组标识=_base=文件夹名，_scan_texture_folder 第759行坐实)。**网格三级(本轮从两级升级)**：第一版做两级(辅线alpha0.25+主线alpha0.9)用户反馈"只有粗线、跟gd不一样、gd有XY轴专门的线"。查证 Godot 无现成可移植网格——GridMap(gdd_0619)是摆方块的不是画线的、EditorNode3DGizmo 类编辑器专用打包不存在、编辑器网格是 C++ 引擎层画的无脚本可抄，诚实告知用户只能自己画。改三级：_draw_grid 建4个 MeshInstance3D——辅线 GridOverlay(每1米,alpha0.45调亮,灰,y0.02)、主线 GridOverlayMajor(每5米,alpha0.9,偏白,y0.03)、X轴 GridOverlayAxes(穿过原点沿X,红(0.95,0.35,0.35),alpha1.0,y0.04)、Z轴 GridOverlayAxesZ(穿过原点沿Z,蓝(0.35,0.45,0.95),alpha1.0,y0.04)；逐层抬高y避免z-fighting；不做距离淡出(投屏要恒定可见)。_build_grid_axes 两条轴各一节点各一色材质(避免同材质无法红蓝分开)，辅以 _axis_mat 工厂方法。_adopt_scene_content reparent 按名认列表加 GridOverlayAxes/GridOverlayAxesZ。中途一次 _build_grid_axes 写成"建了又queue_free再调未定义函数"的垃圾代码,自查发现后重写干净。**game_eval 全闭环验证**：ground_has_texture=true、tex_size=[4096,4096]、active_ground_ts_base=uv_checker_4096；四层网格全在——辅线(visible/100×100/alpha0.45/灰/y0.02)、主线(visible/100×100/alpha0.9/偏白/y0.03)、X轴(visible/aabb100×0×0沿X/alpha1.0/红/y0.04)、Z轴(visible/aabb0×0×100沿Z/alpha1.0/蓝/y0.04)。⚠待用户手动看三级网格+UV默认地面体感 | ✅ game_eval 验证通过 |
| 2026-07-14 | **拿掉模型强制归一化 + 默认场景地面 50×50 改 100×100 + 地图模式初始视野缩到 10。** 起因：用户导 1.7m 行者与 1.4m 汽车，放场景后大小差距反常（人显得比车大）。读码定位元凶=main.gd `_place_model` 第1804-1807行强制归一化：取模型三轴最大边长(maxf(x,y,z))统一缩放到 target_size=10。行者最大边长 1.703→放大 5.87 倍到 10；汽车最大边长 4.70(车长)→只放大 2.13 倍到 10。归一化把真实比例抹平，且取"最大边长"而非"高度"使扁平车按长度算、瘦高人按高度算，基准不一致。**改动前先 game_eval 实测坐实链路**（不靠猜）：调 LibraryManager.load_model_runtime 把两 glb 读进来、不经过归一化直接量原始 AABB——网行者test.glb=0.51×1.703×0.76、破损汽车3d模型.glb=4.70×1.465×2.08，证明 Blender→glb→Godot 单位即真实米（1单位=1米），无需换算，用户"对接 Blender 尺寸标准用 glb"的直觉对。**改动**：①删 main.gd 1802-1807 归一化四行（target_size/max_extent/scale_factor/instance.scale），换说明注释记依据；②顺改 1831-1833 行 force_update_transform 注释（原写"instance.scale 刚设"已不设 scale）；③grid_size 默认 50→100（地面 PlaneMesh.size 与网格 half 都读它，自动跟着变）；④_map_size 默认 25→10（用户要地图模式初始显示范围小一点，物件显大好摆；滚轮缩放范围 5-80 不变够拉远看全 100 地面）。`_calc_instance_aabb` 函数成死代码（仅自递归无外部调用），暂留不删避免扩大改动。**game_eval 全闭环验证**（停游戏重跑让新代码生效，MCP stop 未断连）：grid_size=100、Ground PlaneMesh=100×100、_place_model 摆行者后 inst_scale=[1,1,1]（未缩放）、真实世界 AABB=0.51×1.703×0.76（与 glb 原始值一致，未被归一化成 10）、函数跑到底无报错、proxy.fit_from_target_synced 照常调；_map_size=10、camera.size=10、projection=1(正交)。⚠用户已手动摆模型认真实比例体感=对 | ✅ game_eval 验证通过 + 用户体感确认 |
| 2026-07-09 | **代码体检+真坑修复+多场景骨架落地。** 体检五脚本按 CLAUDE.md"所有 Godot API 须有离线文档依据"规矩，逐行对离线文档 4.7 实读核对。**真坑**：①`flags_unshaded` 在 Godot 4.7 已废弃（grep gdd_0864_BaseMaterial3D 零命中，4.x 改名 `shading_mode`，取 `ShadingMode.SHADING_MODE_UNSHADED`=0，文档第 112/317/1670 行）——main.gd 第 300 行网格线材质、pick_proxy.gd 第 172 行标记球材质两处都用着废弃 API。②`flags_no_depth_test` 也属 3.x 旧名，4.7 改 `no_depth_test`（文档第 90/1462 行，property+set_flag/get_flag）。③main.gd `_place_building` 第 977 行 add_child 未设 owner——pack 场景存盘会漏物件（gdd_1006 第 31-45 行原文），即多场景草案坑1，本会话收进 module_io._ensure_ownership。**已修**：①② 两处 API 改对（main.gd/pick_proxy.gd 各一处材质 flag 修复），行为不变仅用对 4.7 API 名。③ 暂不在 main.gd 修（不影响现行游戏），改收进 module_io 存盘时统一补 owner。**用户拍板"理顺分寸"**：主线是结构,顺手真坑修,孤立单脚本能跑的不动。**骨架落地 5 文件**（用途见功能进度那条），全留 TODO、未接 main.gd、未注册 autoload、不改 project.godot 不改 main.gd 行为，现行游戏不受影响。architecture.md 文件结构图已补这 5 文件标注"骨架占位"。**未做**：未 game_eval 验证骨架方法体（未调用无副作用，待接入时验）；未跑 gdstyle lint；project.godot autoloading 未动需 GM 下次会话决定是否注册 ModuleGate | 🔄 骨架立待接 |
| 2026-07-07 | 项目启动前自查 8 项 | ✅ 全部完成 |
| 2026-07-10 | **多场景系统第一段接入+class_name 遮蔽坑。** 用户拍板：开机默认一个"测试模组"（临时硬编码名待"导入/新建模组"UI 移除），场景存进它；场景加时自动起名场景N+1；保存语义=左栏点哪个选中、保存覆盖那个；场景文件内容=相机+地面纹理+网格+灯物+物件（不含 gizmo/投屏/UI 这些 GM 工具），用户点破"做关卡当然存相机"。**实现**：①main.gd 加 `_scene_root`(Node3D) 容器，相机/方向光/WorldEnvironment/CameraPivot/Ground/GridOverlay 在 `_adopt_scene_content` 里 reparent(依据 gdd_0512 Node.reparent 第142/1668行)进它+set_owner=它；`_place_building` 物件进它+set_owner=它，**正面修了 owner 陷阱**（gdd_0512 第691行 pack 只存 owner=根的节点）。UI/gizmo/cast_view 留 Main 不设 owner→pack 不收。②左栏"场景"节加"新建"+"保存此场景"按钮+场景列表订阅 ModuleGate.scene_list_changed 刷新。③module_gate.gd 加默认模组开机建+add_scene/save_current_scene/list_scene_names/set_current_location。④project.godot 注册 ModuleGate autoload。**真坑(2026-07-10 定性)**：module_gate.gd 同时声明 `class_name ModuleGate` **和** autoload 单例名 `ModuleGate` 重名 → Godot 解析 main.gd 时把 ModuleGate 当"脚本类"非 autoload 实例 → 报"Cannot call non-static function on class ModuleGate directly, make an instance"，连带第125行"Cannot find member scene_list_changed in base ModuleGate"。**修法**：删掉 module_gate.gd 的 `class_name ModuleGate` 行——autoload 单例名本身即全局访问名，不需要 class_name（依据 gdd_0374 Singletons）。script_patch 触发 main.gd 重解析后 diagnostics=none 确认文件层已干净。**但跑游戏仍报同样 parse error**——根因是编辑器脚本缓存脏：用户今早重启 Godot 时 module_gate.gd 还带 class_name，Godot 启动时把 ModuleGate 注册成脚本类；本会话删 class_name 后 Godot 未重启、缓存未刷新。**待用户重启 Godot 一次**让编辑器重读 module_gate.gd、认到无 class_name，跑游戏才能起。重启后做 game_eval 实测存→读（PickProxy.target_node 节点引用重连那个最大未知点）。未跑 gdstyle lint。+ ⚠ **2026-07-10 续会话证伪：上面那个"待重启 Godot"定性不对。** 重启 Godot（磁盘 module_gate.gd 已干净无 class_name、autoload list 实测 ModuleGate 在）后跑游戏，现象跟重启前**完全一样**——helper 始终 not_live、game_eval 连不上。证明 class_name 脏缓存**不是**游戏起不来的根因，是从上一份交接总结继承的错误假说，已推翻。详见 `docs/session_handoff_2026-07-10_round2.md`。真正的卡点见下一条 | 🔄 待查真正根因 |
| 2026-07-10 | **【续会话】游戏僵死卡顿循环 + MCP 重连规律 + 左栏坏体验初查。** 详见 `docs/session_handoff_2026-07-10_round2.md`。摘要：①MCP 断连**优先重启 Cowork 客户端(Claude Desktop)而非 Godot**——服务端通常还活只掉会话，重启客户端拿新会话即连（用户原话"以后别让我重启 gd，重启你就行"，已存 memory `gvtt_mcp_reconnect_shortcut`）。②跑游戏触发的"僵死卡顿循环"实测链：游戏窗弹出、`is_playing=true` 但 `game_status.status` 自相矛盾(stopped/not_live)、helper_live 恒 false、右上角播放键变刷新按钮关不掉、Debugger Errors 面板空、netstat 查 6006/6005 端口**未占**、调 `project_manage(op=stop)` 反触发 MCP 断链。helper 不通报活的根因**未坐实**（源码第63-90行/654-681行读过：助手靠 EngineDebugger 调试通道发 mcp:hello，编辑器收到才记 live；hello 跟 MCP 8000 端口是两套线）。runtime monitors 实测 object/count 84333、render 2700 物件/帧——某处造巨量物件，`_draw_grid`(第414-440行)只调一次已排除非元凶，元凶疑在 `_process` 反复 new()+add_child 不撤旧，**下次查证方向 A**。③`editor_reload_plugin` 不准用（断链）已写 CLAUDE.md，**本次新增：`project_manage(op=stop)` 也不准用来停僵死游戏**（已证明触发断链），停游戏优先让用户手动在 Godot 操作。④左栏坏体验初查（用户报"左边只剩场景格、点场景1弹更多场景1"）：磁盘代码第870-874行坐实——左栏整条 `_left_panel` 受 ModeGate 控制、运行态整条藏；场景格也属 `_left_panel`(第466行)按理该一起藏，用户却见场景格孤在，**疑似运行态异常未坐实**。点场景1增场景的根**磁盘代码查不出**（grep 实测 add_scene 只在开机第109行+"新建"按钮第183行调、`_on_scene_selected` 第170-177行不调），要 game_eval 看运行态真值。⑤用户拍板"先修左栏坏体验"未做完，因为要 game_eval 才能坐实、game_eval 要先解卡顿，两条线交缠。⑥用户提大问题"这项目跟 gd 多少关系、是不是很多该多依托 gd"——本次回应：main.tscn 几乎空骨架(6节点)、相机/光照/地面/网格/UI 全靠 main.gd 运行时 new() 挂(第96-483行)，是逆 Godot 常规做法，灵活但反噬(难调难查、节点暴涨难追)。辩证判断：静态部分(相机/光照/地面/UI)可考虑回 .tscn、GM 工具层(投屏/拾取/ModeGate/ModuleGate)Godot 没现成须自造。已存 memory `gvtt_all_code_scene_arch`/`gvtt_game_freeze_symptom`。本次会话教训：违反过"不准堆英文"规矩被批评、凭交接总结假说一路查到底浪费用户时间、EVAL_GAME_NOT_READY 时 Glob/Read（直接读磁盘文件）能用（参考路径见上）；任何会话因工具节制思路卡顿**不要硬挤乱字符输出，停手让用户给一句话再动** | 🔄 待查真正根因 |
| 2026-07-09 | **多场景/关卡系统架构草案。** 起因用户提出"跑团一幕一幕，参照剧情关卡/游乐园类项目结构把大逻辑理顺"。经多轮辩证+确认：①丢弃"线性关卡推进"参照（跑团是 GM 任意跳，非通关顺序），取"游乐园式任意选项目进场"模型——但更进一步用户反驳"主区"概念不成立，一场跑团会走很多不同地点，最终定地点=场景文件、模组=一场跑团装所有地点、一幕=地点+当前进度组合（不分主区，A 跨地点切与 B 时段推进天然都支持）。②两套存档=模组底本（备团成果出厂布置）+带团存档（一次实际跑团快照能接续），用户确认都要。③自动保存=切幕那一刻写盘+手动按钮兜底（不走每步实时盘写，理由：磁盘IO卡顿违反维度④+实时覆盖等同无撤销保护）。④叙事文本暂不做UI但留 `notes/historical_notes` 字段占位（Resource 加 String 字段近零成本，将来加 UI 只是挂 TextEdit）。⑤新增全局真值建议 autoload `ModuleGate`（持有当前模组/地点/session，广播 current_location_changed），对齐 ModeGate"功能自报归属"规矩，不塞进 ModeGate 混职责。依据：design.md 第③维度"GM 管理一个完整冒险非孤立地图"+Godot 4.7 离线文档 gdd_1006_PackedScene(pack/instantiate 第129/135行、pack owner陷阱第31-45行)、gdd_1477_ResourceSaver、gdd_1476_ResourceLoader。揭示未落地地基坑：①pack 只打包有 owner 的子节点，main.gd `_place_building` 放物件未设 owner 存盘会漏（须正面修不许绕）；②EntityProperties/PickProxy 含 NodePath 引用，序列化加载后须重连验证；③切地点主相机/投屏 CastView 共享 World3D 须重连（architecture 3.6）；④编辑态切地点=换舞台备团 vs 运行态切地点=带团走到新地点（触发切幕写盘）须按 ModeGate 分流。依赖关系确认正确：多场景(P4)须盖在 P1 单场景存读盘成熟之上。**网页搜索工具本会话多次无结果返回**，"游乐园类/剧情关卡现成项目结构参考"无外部依据拿到，草案主体基于官方 API+项目自身设计决策，不装懂；待查点已标进草案第10节。本次未动任何代码，仅写 `docs/multi_scene_draft.md` 草案 + 更新 DEVLOG，待用户批阅后下次会话动手 | ✅ 草案立 |
| 2026-07-10 | **【存→读闭环实测坐实 + PickProxy.target_node 加 @export 修复】** 接 session_handoff_2026-07-10_round3 开场白做优先级1（存→读闭环）。**通道**：新会话不假设通，project_run 后 helper_live=true/status=live（僵尸进程未复发，通道通）。**静态读码**：module_io.gd save_scene_tree（_ensure_ownership 补 owner + PackedScene.pack + ResourceSaver.save）/load_scene_tree（ResourceLoader.load CACHE_MODE_IGNORE + instantiate）；module_gate.gd save_current_scene/add_scene/list_scene_names；main.gd _scene_root/_adopt_scene_content（相机/光/WorldEnv/CameraPivot/Ground/GridOverlay reparent+set_owner）/_place_building（root+instance+props+proxy 四个都 set_owner(_scene_root)）/三个场景按钮回调。**离线文档核对**（gdd_1006_PackedScene 第31-50行 pack 只存 owner 节点+第135行 pack 签名+第129行 instantiate、gdd_1477_ResourceSaver 第19/90行 save+第98行运行时不存UID、gdd_1476_ResourceLoader 第165行 load+第63行 CACHE_MODE_IGNORE、gdd_0306_exported_properties **第519行关键**:普通 var 不存进文件+第308行 @export Node 合法+第314-319行 NodePath 老办法）。**实测6步闭环**（game_eval 缩进用 tab）：①造物件查基线 ②save_current_scene 存盘 ③load_scene_tree 读回不挂树查结构 ④查 target_node 读回值 ⑤清树挂回 ⑥查挂回后状态。**第一轮（空 Node3D 测试物件）结果**：存盘✅(5467字节落盘)、owner陷阱处理✅(节点没漏)、EntityProperties @export字段✅(6字段全对)、**PickProxy.target_node❌读回丢成null**（根因坐实:第21行 `var target_node` 普通var没@export,gdd_0306第519行明文不存文件）、挂回后拾取盒退回0.6针孔(因target丢→_fit_from_target没跑)。**修法**:用户选路线A(加@export最小改动)→pick_proxy.gd 第21行改 `@export var target_node: Node3D = null`+补注释。**第二轮（重启游戏加载新脚本后，用带真FBX模型的物件重测）结果**:存盘✅(5703字节)、读回挂回后 target_node✅重连(target_name=TestEntity)、模型GeometryInstance3D✅(1个没丢)、**拾取盒✅贴合(9.53×10×5.72 与存盘前一致没退化)**、EntityProperties✅(真物件乙/30全对)。**结论:路线A成立,不用走路线B(NodePath)**。⚠未验:真人点鼠标选中(game_eval没法真点,拾取盒尺寸对+target重连是必要条件,最终待用户手动跑游戏点一下认体感)。⚠暴露的架构点:存盘pack的是_scene_root本身,读回得到一个新SceneRoot,挂回时套两层(Main/SceneRoot/SceneRoot/TestEntity)—"怎么挂回去"是切场景换树(switch_location)要解的问题,本轮未展开。⚠game_eval坑:长闭环代码触发包装器"Standalone lambdas cannot be accessed"Parser Error致游戏卡break,改拆小步短代码即避。改文件用Write工具(DEVLOG记过godot-ai write_text偶发写坏) | ✅ 存读闭环通 |
| 2026-07-10 | **【切场景换树真实现】** 用户实测踩到"新建场景2后还看到场景1东西/点切换无效果"——坐实交接文档优先级2没做(_on_scene_selected只挪指针不换树、_on_new_scene_pressed不清舞台,代码注释自承认)。**架构决策(方案乙,用户拍板)**:两层分离——骨架层(相机/方向光/WorldEnvironment/CameraPivot/Ground/GridOverlay)所有场景共用**不存盘**;内容层(_content_root Node3D)装建筑物件,**存盘只pack这一棵**。理由:相机/光/地面是GM看场景的眼睛不是场景内容,切场景时骨架不动→相机/投屏/gizmo引用全不用重连,连带影响最小。推翻上一场"pack整个_scene_root含骨架"的存读(旧场景1/2/3.scn旧格式含骨架被删)。**切场景动作设计(用户拍板:切时弹窗三选一)**:平时操作不存盘(防卡,符合维度④);点切场景→弹窗"保存后切换/不保存直接切换/取消切换";选存或不存后才真换舞台。新场景没存过=空内容层(用户拍板"清空成空舞台")。地面纹理第一版不随场景存(只换建筑)。**代码改动**:①main.gd加`_content_root`(_scene_root下,owner=_scene_root),`_place_building`物件改挂_content_root+owner=_content_root,`_on_save_scene_pressed`传_content_root;②`_switch_to_scene(target)`:清_content_root孩子+queue_free→_deselect→ResourceLoader.exists判存过则load_scene_tree读回把**孩子搬进当前_content_root**(不套两层)+`_ensure_owner_recursive`重设owner→更新_current_scene_name+ModuleGate.set_current_location+_sync_scene_list;③`_on_scene_selected`改弹窗(_pending_switch_to记目标);④`_on_new_scene_pressed`新建后走切换;⑤`_show_switch_dialog`+三个回调(_on_switch_dialog_save/custom/cancel)。弹窗API:gdd_0513 AcceptDialog ok_button_text/add_cancel_button(canceled信号)/add_button(custom_action信号)/popup_centered(gdd_0786第1400行)。**坑**:旧 场景1/2/3.scn 是改架构前pack整个_scene_root存的(含骨架),新代码读会把相机/光/地面当物件塞进_content层=骨架重复。用户批准删3个旧文件,新格式只存物件(场景1新存1706字节 vs 旧1.87MB)。game_eval坑:`break`在for循环里触发包装器"Expected end of statement, found break"Parser Error致卡break,改拼字符串路径不循环即避。**game_eval闭环全通**:场景1放带FBX模型物件+存盘(新格式)→切到新场景2(内容层清0、无骨架残留)→切回场景1(物件读回、target_node重连、拾取盒9.53×10×5.72贴合、EntityProperties属性对)。⚠未验:真人手点切场景认体感(game_eval只直调_switch_to_scene,没手动操作弹窗UI);切场景后投屏窗CastView么同窗重显未验(骨架没动理论上不影响)。下一步:用户手动跑游戏实操认体感,再优先级3切场景提示UI优化/4重命名删除场景/5模组UI | 🔄 代码通待手认 |
| 2026-07-10 | **【修两 bug：地面纹理随场景存 + 脏标记】** 用户实测报两个 bug。**bug1 地面纹理不随场景存**(所有场景按最后一套纹理):根因纹理状态在 Ground 骨架层不存盘。→ 新建 scene_props.gd(class_name SceneProps,@export ground_tex_base/ground_tile)挂 _content_root(set_script),换纹理/改平铺写进它,存盘 pack _content_root 时随场景序列化,切场景读回按它重建 Ground 材质(_apply_ground_texture_for_scene)。**bug2 存过了切场景还问要不要存**:加 _scene_dirty 脏标记(放物件/换纹理/改平铺置脏;存盘成功/切场景完成清脏;切场景只 dirty 时弹窗)。game_eval 双验通过:场景1 stone_floor/场景2 uv_checker 各自独立切回不变;存盘后切直接切不弹窗。**踩坑**:改完代码编辑器缓存脏报"_apply_ground_texture_for_scene not found"行号偏移→重启 Godot 编辑器清(不断 MCP) | ✅ 两 bug 修 |
| 2026-07-10 | **【默认空场景专门记录 + 开机不扫盘】** 用户报 bug1"新建场景2不是默认空白、是之前保存的场景、保存过再打开程序不清空"+ bug2"新建场景3跟一开始空场景不一样、默认场景该有专门记录"。bug1 根因:add_scene 起名"场景N"可能撞磁盘旧 .scn 文件名,撞上就读到旧内容。bug2 根因同 bug1(撞名)+用户点破"默认场景该有专门记录"。**修法(用户拍板"做新模组从干净开始、要用旧模组靠将来导入模组")**:①开机不扫磁盘、建全新空模组(ModuleGate._ready 已是建空 manifest,确认不改);②add_scene 起名跳过清单已用名(防撞);③main.gd 加 DEFAULT_GROUND_TEX_BASE/TILE 常量集中记默认场景长相(纯空舞台=无物件+默认纹理/裸色+默认平铺),_apply_default_scene() 统一入口(开机/新建/切到没存过场景都走它,将来改默认只改这处)。删了上几轮残留 场景1/2/3/4.scn。game_eval 实测:开机场景1纯空(0物件/默认纹理)→新建场景2纯空→新建场景3纯空→清单名不撞递增→磁盘有场景3.scn但新建场景4空(没读旧内容)→切回场景3读到物件+target重连。**踩坑**:改完代码又缓存脏报"_apply_default_scene not found"→重启 Godot 编辑器清(第二次同坑)。⚠未验:真人重启游戏认"保存过再打开程序新建是空白"(game_eval 不能重启程序,但代码+实测双证:开机不扫盘+add_scene 防撞) | ✅ 默认场景修 |
| 2026-07-13 | **【bug3 模型偏移从导入源头清 + 复盘为何修这么久】** 用户报"保存场景切回来模型偏移"。**根因坐实**:FBX 模型 mesh 子节点自带 position(实测 CP Building_001 的 Front_Building_01B position=-95),_reset_all_transforms 清成0、存盘存0,但 Godot pack/instantiate 读回时变回模型原值-95,几何飘 -95×scale=-19(实测 diff=-19.04 X轴)。模型 AABB 原点也偏(-36,-0,-14.4),几何中心不在 mesh 原点。**修法(用户从一开始就给的正解)**:从导入源头清模型自带位置信息——新建 scripts/post_import_center.gd(@tool extends EditorScenePostImport,API 依据 gdd_1276 _post_import(scene) 拿根节点改后 return):导入 FBX 后自动 ①_置所有子节点 position/rotation=0(scale 保留) ②算整棵合并 AABB 中心(_walk 用 local transform 累加,不用 global_transform——post-import 时节点没进场景树 global_transform 报 !is_inside_tree)给根节点设 position=-(中心) 让几何居中到原点。挂给四个 FBX:改 .import 的 import_script/path=res://scripts/post_import_center.gd + filesystem_manage(op=reimport) 触发。重导后 mesh 子节点 position=0、根节点带居中位移(12.22,-24.98,0.17),game_eval 存读闭环 diff=0 不偏。**为何修这么久(逐步复盘,不朦胧)**:①方向偏——用户说"软件根本不认模型自带位置信息、原点归0"是设计指令,我当猜测去查 _switch_to_scene 读回逻辑,机器读 root.position 没变就说没复现,绕几轮;②加 @export 修 PickProxy 拾取盒(_box_size/_box_center)治标不治本(手柄偏≠模型几何偏,混着改);③加抵消位移(算 AABB 中心设 instance.position=-(中心×scale))治标——脏在 mesh 子节点不在顶层,且子节点 position 存0读回变-95 存不住;④BuildingData+读回重建(不存模型实例只存数据)造屎山,重建跟残留叠加多出一份模型;⑤查"Allow Geometry Helper Nodes"导入选项判断错——它本就 false(查 .import 第44行);⑥post-import 第一版用 global_transform 但节点没进树报错;⑦改脚本后编辑器缓存脏、重导还跑旧脚本,重启 Godot 才重读。**总教训**:用户给的设计方向优先于我查的技术细节;简单事别绕成跟引擎存读搏斗;post-import 脚本改了要重启 Godot 重读。回退了屎山(BuildingData/抵消位移删除,building_data.gd 文件删),保留合理改动(PickProxy @export 拾取盒、post_import_center.gd、.import 挂脚本) | ✅ bug3 修 |
| 2026-07-12 | **审阅吸收 UnorthodoxHacks。** 品鉴 GitHub 项目 [Muigoochen/UnorthodoxHacks](https://github.com/Muigoochen/UnorthodoxHacks)——一个 Godot 4 工具函数库，封装 FileAccess/DirAccess/ConfigFile 的静态方法集。评价：写得扎实（静态类型全覆盖、防御性编程到位、备份轮转机制完整、跨平台路径处理细致），但项目和 Gvtt 不是同一层面产物（它是工具库，Gvtt 是完整产品）。吸收三处进开发文档：①备份+轮转策略写入 `docs/multi_scene_draft.md` 第 4.1 节（后缀 `.bak`、保留 5 份、copy vs rename 权衡）；②顺序命名空缺编号算法记入同一节；③`#region` 分区习惯 + 防御性编程纪律写入 `docs/architecture.md` 第 7 节。不采纳其全部：工具函数以 static func 直调为中心，不认 ModeGate/ModuleGate 权限约束，不适合作为依赖引入。DEVLOG.md 此条记毕 | ✅ 已吸收进文档 |
| 2026-07-13 | **【bug4 地面纹理导入法线图被当颜色图显示】** 用户报"导入 2K_Gravel01 文件夹后以法线贴图样子展示，不是把法线当贴图"。测试文件夹 3 文件：gravel_diffuse_xtm.jpg（颜色/diffuse）、gravel_displace_xtm.jpg（位移）、gravel_normal_xtm.jpg（法线）。**根因坐实（game_eval）**：原分类逻辑用"后缀结尾匹配"（ends_with），只认 _diffuse/_normal 这种类型词在文件名**结尾**的；但这批素材类型词在**中间**（结尾是 _xtm），三个文件全匹配不上→全走"认不出默认当 albedo"→字典 albedo 键被连续覆盖，字母顺序最后的 gravel_normal_xtm 赢→法线图被存成颜色图。**修法（用户拍板"搜关键词"）**：library_manager.gd _classify_one_texture + main.gd _classify_texture 两处都从"后缀结尾匹配"改成"关键词子串搜索"（find>=0），文件名里出现 normal 就当法线、diffuse/albedo/basecolor/color 就当颜色图，不管词在哪个位置。关键词按长度降序排（basecolor 比 color 长先匹配）避免短词误吃长词。另修覆盖 bug：_scan_one_ground_folder + _scan_texture_folder 多张同类型图加"只认第一个不覆盖"保护（if not group.has(type)）。game_eval 实测修后：2K_Gravel01 分类成 albedo=gravel_diffuse_xtm.jpg + normal=gravel_normal_xtm.jpg（displace 被默认当 albedo 但已被 diffuse 占→忽略，合理位移图不当贴图），_apply_texture_set 贴上 albedo_tex=true + normal_on=true 正常。displace（位移图）分类规则未收录，默认当 albedo 再被忽略——日后要支持位移图再单独加规则 | ✅ bug4 修 |
| 2026-07-13 | **【右键删除素材功能】** 用户需求"左栏栏位里右键弹出删除"。**用户拍板**：①只删导入的（user:// 下），自带素材（res:// 打包后只读 gdd_0372 第60-63行）右键"删除"灰掉提示"自带素材打包后只读删不掉"——推翻用户反问"有必要分自带导入吗"，辩证说明：打包后自带素材物理只读，不分就会给打包后失灵的按钮，带 📥 标记导入素材一眼可辨，UI 无需额外做识别；②点"删除"即删不额外弹窗确认（右键这一步当确认）。**实现**：查实 API——Button 继承 Control.gui_input 信号捕获 InputEventMouseButton 右键、PopupMenu（gdd_0707）add_item(label,id)+id_pressed 信号+set_item_disabled 灰显+set_item_tooltip+popup(Rect2) 弹鼠标位置。LibraryManager 加 delete_model（删 user://library/<cat>/<文件>，DirAccess.remove_absolute）+ delete_ground_texture（删整文件夹：先逐文件删再删空文件夹）。main.gd _btn_model + _btn_ground 各加 gui_input 连右键回调 _on_model_btn_gui_input/_on_ground_btn_gui_input：建一次性 PopupMenu add_item"删除"→导入的可点+自带的 set_item_disabled 灰掉+tooltip 说明→id_pressed 回调 _delete_model_item/_delete_ground_item 删文件+重建列表+menu.close_requested queue_free 释放。地面纹理 _rebuild_ground_buttons 给 set 加 source 标记（builtin/imported）供右键判能否删；_delete_ground_item 若当前地面正用这套纹理则清选中+藏平铺控件避免指向已删文件。**game_eval 实测**：delete_ground_texture("2K_Gravel01") before=1 deleted=true after=0；delete_model("decor","网行者test.glb") before=1 deleted=true after=0。删除方法闭环通。⚠未验：真人右键点按钮弹菜单选删除（game_eval 不能真点鼠标右键，PopupMenu UI 交互待你手动实操认），用的全是查实 API | ✅ 删除功能加 |
| 2026-07-14 | **【右键删除菜单 bug：绕四轮终于修通+复盘】** 用户需求"左栏素材按钮右键弹删除菜单"。**最终方案**：_input 最开头判"右键按下+鼠标在左栏(_left_panel 全局矩形)"→调 _handle_right_click_menu 坐标命中检测(遍历 _model_panels 各栏 container + _ground_list_container 的按钮，鼠标坐标落在哪个按钮 get_global_rect 里就弹那个的菜单)+set_input_as_handled+return(不转相机)；菜单弹在 DisplayServer.mouse_get_position()（屏幕坐标，因 embed_subwindows=false PopupMenu 是独立 OS 窗要屏幕坐标，用 get_viewport().get_mouse_position() 窗口内坐标会偏到窗外——用户实测"菜单飞到游戏窗口外"坐实）。自带素材"删除"set_item_disabled 灰掉+tooltip"自带素材打包后只读删不掉"。按钮靠 set_meta("kind"/"category"/"index" 或 "group"/"source")存身份，右键时读 meta 知道删哪个。**绕四轮的复盘(教训)**：①第一轮用按钮 gui_input 信号连右键回调——game_eval print 实测 gui_input 只收 InputEventMouseMotion、收不到 InputEventMouseButton(项目里所有 MouseButton 都被上层截走，左键能用是走 _unhandled_input 不靠 gui_input)，方向错；②第二轮改用 _unhandled_input + gui_get_hovered_control 找按钮——print 实测 gui_get_hovered_control 返回 null(疑 embed_subwindows=false 致 Viewport 错位)，方向又错；③第三轮改 _unhandled_input + 坐标命中检测——print 实测右键到不了 _unhandled_input(只有 pressed=false 松开到，pressed=true 按下被 _input 抢去转相机)，_input 里"左栏判断"用 event.position(相对坐标)跟 _left_panel.get_global_rect()(全局矩形)比，坐标系不一致判断永远不成立；④第四轮才对：直接在 _input 最开头处理右键菜单(_input 本来就收得到右键按下，它一直在抢就是证据)，在转相机逻辑之前，set_input_as_handled 标记已处理。**总教训**：①用户说"走了歪路"是对的——没先搜现成方案(CLAUDE.md 规矩)就自己推理绕四轮；②`_input` 抢走事件时，在 `_input` 里处理是正解，别绕到下游 _unhandled_input/gui_input；③embed_subwindows=false 下独立窗口的 popup 位置要屏幕坐标(DisplayServer.mouse_get_position)，不是窗口内坐标；④坐标比较要统一坐标系(event.position 相对 vs get_global_rect 全局)；⑤加 print 探针时别读键盘事件的 position(InputEventKey 无 position 会崩把游戏搞进 break)。LibraryManager 加 delete_model/delete_ground_texture 两方法已 game_eval 验过(删前1删后0)。⚠未验：真人右键弹菜单+点删除(菜单位置这次改屏幕坐标应贴鼠标，但用户关对话前未确认弹对位置，待下次手动认)。代码已清干净 debug print | ✅ 右键菜单修通(位置待手认) |

| 2026-07-14 | **【shader 网格"近粗远细"无效果诊断+待修】** 接前几场 shader 网格工作。用户报"网格没跟随相机/地面远近变粗细"。**已验证**：shader 挂在 GridOverlay（运行态 /root/Main/SceneRoot/GridOverlay），grid_size=100 参数对；两次截图（cam.size=5 拉近 / cam.size=40 拉远）都能看到网格（辅线灰/主线白/红蓝轴线）+UV 纹理。**根因坐实（读 shader 代码）**：`shaders/grid_shader.gdshader` 第20行 `uniform float world_line = 0.04`（4厘米）太细——拉近看10米地面时线才约3像素粗，拉远掉到保底1.5像素，3→1.5像素变化肉眼基本无感。正交相机（地图模式）单帧无透视变化，粗细只在"拉远近动作"时变，这点设计本身对。**待修（一行）**：world_line 从 0.04 改 0.15（15厘米）→预期拉近约10像素/拉远1.5像素，变化明显。⚠未做：值没改、没 game_eval 验证改后效果（用户要开新对话，留给下一场）。game_eval 缩进必须 tab；场景修改合并一个 batch_execute；禁断链 MCP | 🔄 待改 world_line |

---

## 十大未解之谜 🕵️

> 留案待查。记的不是已修好的 bug，是**没坐实根因就自己好了/偶发的怪现象**。再犯时回来翻这里，能省一堆瞎查。破一个就标 ✅ 挂日期，凑齐十个看会不会召唤神龙。

### 谜 #1：右键删除"打开不拖就不弹，拖一下窗口就好，后来又自己好了"（2026-07-14）

**现象：** 用户报右键不出删除菜单。发现"拖动一下窗口"就恢复正常能删。再后来用户说"现在又好了，打开不拖也能删了"——啥都没改自己好了。

**当时查到的：**
- 右键菜单代码完整没被弄掉（_input 第1446-1450行 + _handle_right_click_menu + _popup_delete_menu_model/ground 都在）。
- game_eval 查初始状态：窗口1280×720、左栏矩形(0,10,200,710)、按钮矩形正常、content_scale_factor=1，看着都对。
- game_eval 喂模拟右键事件到按钮中心坐标，菜单没弹出（popup_count=0）——但发现 _input 判"鼠标在左栏"用的是 `get_viewport().get_mouse_position()`（真实鼠标位置），不是事件自带坐标，所以模拟喂事件验不出来（game_eval 改不了真实鼠标）。

**最强嫌疑（未坐实）：** 窗口记忆功能（_ready 里设 win.size/win.position）启动时设了窗口位置，但 Godot 内部"窗口屏幕位置/内容尺寸状态"没立刻同步 → 弹菜单用的 DisplayServer.mouse_get_position()（屏幕坐标）算出错误位置 → 菜单弹飞到看不见的地方（看着像"没反应"）。拖窗口强制重同步 → 菜单位置对了 → "恢复"。

**"自己又好了"的一个可能解释：** 复盘发现我在一次 game_eval 里设过 `win.content_scale_size = Vector2i(1280, 720)`，设这个属性可能触发了 Godot 重新同步窗口/布局状态（等价于拖窗口的效果）。但用户记不清"又好了"是哪次跑游戏，无法坐实是这个动作治好的还是偶发。

**为什么没改代码：** 根因没坐实 + 功能自己好了 + game_eval 没法终验（改不了真实鼠标、看不到菜单弹哪）。没复现就改=瞎改，违反"不绕远"规矩。

**再犯时怎么查：** ①第一时间问用户"游戏窗口弹在屏幕什么位置"（飞偏了=屏幕坐标没同步嫌疑大）；②在 _popup_delete_menu_model 临时加 print 打印 DisplayServer.mouse_get_position() 和 get_window().position + get_viewport().get_mouse_position()，对比三个坐标差，看屏幕坐标是不是算飞了；③若坐实是 content_scale_size 同步问题，预防性修法=_ready 设完窗口后主动设 content_scale_size 跟窗口尺寸一致（一行，低风险）。

**状态：** 🕵️ 待再犯抓现行

---

## 2026-07-15 修 main.gd 被截断 + 场景宽×高改造收尾

### 起因
用户报"昨天搞坏了，问题可能在 main.gd / grid_manager.gd / scene_props.gd 三个文件里"。

### 查证根因（editor logs_read source=editor 实拿 parse error，非缓存猜测）
编辑器报 3 个 parse error（main.gd）：
1. 第386行 `set_grid_size()` 调用只传1参，函数要2参。
2. 第1893行 调 `_reset_all_transforms()` 但该函数在 main.gd 里不存在。
3. 第1934行 用 `_model_panels`（少个 s），声明的变量是 `_model_panelss`。

**根因**：上一场把"场景尺寸"从单一 `scene_size` 改造成宽×高（`scene_width`/`scene_height`，长方形场地），但 **main.gd 只改了一半就断了**：grid_manager.gd 的 `set_grid_size` 已改成 `(width,height)` 两参、scene_props.gd 已加 `scene_width`/`scene_height` 字段，但 main.gd 还全程用旧 `scene_size` 单值（`set_grid_size(size)` 只传1参→报错1）、`_content_root.scene_size=xxx` 赋不存在的字段；且 `_place_model` 写到一半**文件被截断**，`_reset_all_transforms` 定义整个丢了、末尾留半截 `_model_panels`（报错2、3）。git HEAD 无 main.gd（从未提交），main.gd.bak 大小同当前坏版（救不了），三条还原路全断，只能据上下文补。

### 用户拍板方向
问用户"回退到单一尺寸 vs 改造到底（宽≠高）"，用户选**改造到底**。

### 改动（main.gd）
1. 常量 `DEFAULT_SCENE_SIZE` → `DEFAULT_SCENE_WIDTH`/`DEFAULT_SCENE_HEIGHT`。
2. 成员 `_scene_size_input`（单 SpinBox）→ `_scene_width_input`/`_scene_height_input`（两个）。
3. `_on_scene_size_changed(new_size)` → `_on_scene_width_changed(new_w)` + `_on_scene_height_changed(new_h)` 两个回调，各自只改自己那一维；加 `_current_scene_width()`/`_current_scene_height()` 取另一维真值（读 _content_root SceneProps，避免回调里读输入框旧值互相覆盖）。
4. `_apply_scene_size(size)` → `_apply_scene_size(width,height)`：地面 PlaneMesh 用 `Vector2(w,h)`、`set_grid_size(w,h)` 传两参、UV 平铺按宽高各算、`grid_size` 取 `maxf(w,h)` 兼容旧 @export。
5. `_apply_default_scene` / `_switch_to_scene` 所有 `scene_size` 单值改 `scene_width`/`scene_height`；`_switch_to_scene` 读回加**老存档兼容**：有 `scene_width` 读新字段，没有则退回 `scene_size` 当正方形（宽=高=老值），老存档不坏。
6. 左栏输入框 UI 从单个"场景大小"改成"宽"+"高"两个 SpinBox（5–500，步进5）。
7. 补全 `_place_model` 被截断的尾巴：`_scene_dirty=true` + `_clear_all_model_selections()` + 工具提示。
8. 补回 `func _reset_all_transforms(node)` 定义：递归把子树 Node3D 的 position/rotation 清0、scale 设 ONE（不缩放，保留 glb 真实尺寸，2026-07-14 改的延续）。

### 踩坑（写文件两次末尾被截断）
- 第一次用 Python 补 `_place_model` 尾巴 + `_reset_all_transforms`，写回报告 93196 字节，但之后文件末尾又停在半截（`_tool_label.add_theme_color_override("font_co`），定义又丢了。疑 `filesystem_manage(op=reimport)` 重扫时把文件末尾搞截。
- 第二次同样手法补，落盘 94349 字节完整。
- **教训**：写 GDScript 大文件后必须 `tail -c 20 | xxd` 验末尾完整 + `grep func 定义` 验关键函数在 + utf-8 合法性，不能信写回报告的字节数。

### 验真（game_eval 实证，非靠编辑器无报错）
- `script_manage(op=find_symbols)` 返回完整 90 函数符号表（含 `_on_scene_width_changed`/`_on_scene_height_changed`/`_apply_scene_size`/`_place_model`/`_reset_all_transforms`）→ 编辑器对新版解析通过。
- `project_run` 跑游戏：helper_live=true/status=live；`recent_errors_may_predate_run=true` 标明那 4 条 parse error 是**跑前留存的旧错**。
- `game_manage(op=get_scene_tree)` 运行态树：SceneRoot/ContentRoot/Camera3D/Ground/GridManager/GridOverlay/SharedGizmo/UI_Layer/ItemPanel/PropPanel 全在 → **main.gd _ready 完整跑到底**（脚本加载失败这些节点一个不会建）。
- `game_eval` 实测真值：`ground_size=(100.0,100.0)`、`has_w_input=true`/`has_h_input=true`、`w_val=100`/`h_val=100`、`scene_width_prop=100`/`scene_height_prop=100`、`grid_w=100`/`grid_h=100` → **宽高改造全链路运行态跑通**。

### 编辑器脏缓存残留（认"编辑器报错、实跑正常"）
- `logs_read(source=editor)` 仍显示那 4 条旧 parse error（行号386/1893/1934 对应旧版内容），但同一批日志里 main.gd 929/1097/1524 行报的是 **warning**（UNUSED_PARAMETER/SHADOWED_VARIABLE，新版本行号）→ 编辑器同时在 parse 旧缓存实例（报 parse error）和新磁盘脚本（只报 warning，通过）。
- `filesystem_manage(op=scan)` + `script_patch` 触发 reload 都没清掉旧缓存实例的报错。
- 按 CLAUDE.md 规矩：温和办法试过 + 不准断链（editor_reload_plugin），认"编辑器报错、实跑正常"，**留待用户下次重启 Godot 编辑器清缓存**（关掉重开 Godot，不断 MCP）。

### 未做 / 待用户确认
- ⚠️ 未让用户手动实操认体感：左栏宽/高两个输入框改值后地面/网格是否真跟着变长方形（game_eval 只验了默认100×100，没验改值）。
- ⚠️ 编辑器 Errors 面板仍显示旧 parse error 红字（脏缓存），实跑无影响，待重启 Godot 编辑器清。
- 未跑 gdstyle lint。


## 2026-07-15 默认贴图铺满拉伸 + 换默认贴图

### 需求
用户：默认贴图要一直占满整个场景，不管场景是不是长方形、大小怎么变，贴图都跟着拉伸铺满（不重复）；顺便换一张默认贴图（用户放桌面 Gvtt 文件夹里了）。

### 换默认贴图
- 用户桌面 `C:\Users\Admin\Desktop\Gvtt\UV_Checker_4096x4096 (2).png`（4096×4096 RGBA）。AskUserQuestion 确认候选三张（UV检测图(2)/汽车生成图/砾石PBR）后用户选 UV 检测图(2)。
- 复制进 `assets/textures/ground/uv_checker_4096_v2/uv_checker_4096_v2.png`（按项目规矩一个纹理一个子文件夹、英文名避免括号空格）。`_scan_texture_folder` 单文件当 albedo 整张贴图。
- 常量 `DEFAULT_GROUND_TEX_BASE` 从 `uv_checker_4096` → `uv_checker_4096_v2`。

### 铺满拉伸模式（核心改动）
**旧问题**：UV 算 `1.0/ground_tile_size*尺寸`，ground_tile_size=一张图覆盖多少米。场景 100m+tile=100 正好一张铺满；但场景变 150m 时 UV=1.5，贴图**重复 1.5 次**不是拉伸铺满。
**用户要的**：默认贴图永远一张铺满整个地面，场景变长方形/改大小贴图跟着拉伸。
**设计取舍**：只给默认贴图开"铺满模式"，其他纹理（砾石 PBR 等）保持按 ground_tile_size 格数重复铺——因为真实材质按真实尺寸重复才有意义，硬拉伸成一张铺满 100m 会糊。
**实现**：
- 新增 `_ground_uv_scale(base,w,h,tile)`：base==DEFAULT_GROUND_TEX_BASE 时返回 `Vector3(w,h,1)`（一张图=整个地面）；否则 `Vector3(1/tile*w,1/tile*h,1)`（按格数重复）。依据 gdd_0407 StandardMaterial3D.uv1_scale（UV 坐标乘数，scale=尺寸时整张贴图映射到 [0,尺寸]=整个 PlaneMesh）。
- `_apply_scene_size` 和 `_apply_ground_texture` 两处 UV 都改调 `_ground_uv_scale`（统一逻辑，改尺寸/换纹理两条路径都不打架）。`_apply_ground_texture` 原来用 grid_size 整数算 UV，改从 `_current_scene_width/height()` 读真实宽高（铺满模式要真实尺寸）。
- `_on_ground_clicked`：点默认贴图时判 `base==DEFAULT_GROUND_TEX_BASE`（不再写死 "uv_checker_4096"），铺满模式 ground_tile_size 存 0 占位、**平铺控件藏掉**（铺满模式调平铺没意义）；其他纹理 tile=5、显示平铺控件。
- `_apply_ground_texture_for_scene`：平铺控件可见性改 `(base != "" and base != DEFAULT_GROUND_TEX_BASE)`（默认贴图也藏）。
- `_apply_default_scene`：默认场景存 ground_tile=0（占位，铺满模式不参与 UV）。

### 老存档兼容
老存档 ground_tex_base 可能是旧 `uv_checker_4096`，读回后 base != 新 DEFAULT，走重复模式（tile=100 时 1/100*100=1 正好一张铺满 100m，视觉等同铺满），不破坏。新场景才用新默认贴图铺满模式。

### 验真（game_eval 实测）
- 新贴图扫到：`ground_bases=[stone_floor,uv_checker,uv_checker_4096,uv_checker_4096_v2]`、`has_v2=true`、`active_base=uv_checker_4096_v2`、`active_has_albedo=true`。
- 铺满模式默认：`uv_scale=(100,100,1)` + `ground_mesh_size=(100,100)` → UV=场景尺寸，一张铺满。
- `sp_base=uv_checker_4096_v2`/`sp_tile=0`/`sp_w=100`/`sp_h=100`、`tile_ctrl_visible=false`（平铺控件藏）。
- **改尺寸拉伸验真（第一版，结论错误，见下条订正）**：`call("_apply_scene_size",150,60)` 后 `uv_after=(150,60,1)`，当时误判为"铺满"。实际是重复——见下条。

### 未做 / 待用户确认
- ⚠️ 未让用户手动实操认体感：肉眼看默认贴图是否真铺满（game_eval 只验了 UV 数值=场景尺寸，没法看画面）；改宽高输入框后贴图拉伸的视觉效果待用户跑游戏认。
- 编辑器脏缓存旧 parse error 残留仍在（同上条，实跑无影响，待重启 Godot 编辑器清）。

### 2026-07-15 订正：铺满模式 UV 方向搞反了（重复→铺满）
**用户反馈**："没有做到啊，现在是重复不是拉伸"。用户对。
**真根因**：`_ground_uv_scale` 铺满模式返回 `Vector3(w,h,1)` 是**反的**。查离线文档 gdd_0864 BaseMaterial3D.uv1_scale 原文："How much to scale the UV coordinates. This is multiplied by UV"——是 UV 坐标的**乘数**。PlaneMesh 默认 UV 范围 [0,1]（整张贴图映射整个平面）。`uv1_scale=(100,100)` → UV 变 [0,100] → 贴图在 0..1 区间**重复 100 次**，不是铺满一张。我上一版凭感觉写成 (w,h) 把方向搞反了，game_eval 看到 uv=(150,60) 误判"铺满"，实际是重复 150×60 次。
**正确逻辑**：一张铺满 = `uv1_scale=(1,1,1)`，UV 保持 [0,1]，整张贴图映射整个 PlaneMesh。PlaneMesh 的 size 改了但 UV 范围仍是 [0,1] 映射整个 mesh，所以**贴图自动跟着 PlaneMesh 拉伸铺满，UV 缩放恒为 (1,1) 不用动场景尺寸**。重复模式（其他纹理）不变，仍是 `1/tile*size`。
**修法**：`_ground_uv_scale` 铺满分支 `return Vector3(w,h,1.0)` → `return Vector3(1.0,1.0,1.0)`，加注释记文档依据和"此前搞反"教训。
**验真（game_eval 重跑新代码）**：默认 100×100 `uv1_scale=(1,1,1)`；改 150×60 后 `mesh_after=(150,60)`、`uv_after=(1,1,1)`、贴图仍 4096×4096 整张 → 一张贴图映射整个 150×60 PlaneMesh，跟着拉伸铺满，不重复。✅
**教训**：①uv1_scale 是 UV 乘数不是"贴图覆盖米数"，UV=(1,1) 才是一张铺满；②game_eval 只看数值不看画面，UV=(150,60) 我没核对语义就判"铺满"是错的，数值对但理解错——下次改 UV/材质参数必须先查文档确认语义再判结果。


