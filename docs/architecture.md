# Gvtt 项目架构与代码导引

> 写给下一个对话的 Claude 或开发者：读完这个文件再动代码。
> 更新时间：2026-07-09（补术语表一节）

---

## 一、项目定位

- 不是游戏，是用 Godot 引擎做的桌面地图工具——开源 3D 俯视交互地图引擎
- 首要场景：线下跑团，GM 电脑操作，投屏给所有人看
- 单 exe，GM 一人操作
- 核心卖点：实时光照 + LOS(视线遮挡)、可破坏地形、法术特效、3D 俯视
- 不做：联网同步、骰子系统、规则系统、模组市场、玩家端、账号

详见 `docs/design.md`

---

## 术语表（Glossary）

> 这是"活的"术语表——不一次性定死，边做边补。每个名词后面标出处（哪个文件/哪一节），保证可核对、不凭记忆。
> 目的：让 GM、你、下一个对话的 Claude 对同一个东西用同一套词，避免一个概念被叫三个名导致代码和沟通错位（业界叫 Ubiquitous Language，通用语言）。
> 命名规则不在本表，见 `.claude/CLAUDE.md` 的"命名规范"一节（文件名 snake_case、节点名 PascalCase、私有成员加 `_` 前缀等已定死）。
> 同一概念的中文叫法和英文代号在表里固定下来后，代码与沟通过程中应全程统一使用，不准临时换叫法。

### A. 角色 / 产品定位

| 中文名 | 英文代号 | 一句话 | 出处 |
|---|---|---|---|
| 游戏主持人 | GM（Game Master） | 跑团里控场、操作本软件的人，本工具唯一操作者 | design.md 五维度受众；eco 一节 |
| 虚拟桌游平台 | VTT（Virtual Tabletop） | 跑团地图工具的统称，多为 2D，本工具做 3D | design.md 1.1 |
| 标记 | Token | 场上角色/怪物的代理物件，2D 告示板默认、3D 模型可选 | assets/tokens/；design 四 |
| 视线遮挡 | LOS（Line of Sight） | GM 控制玩家能看到场上哪些区域，本工具核心卖点之一 | architecture 第 13 行 |

### B. 引擎 / 架构概念

| 中文名 | 英文代号 | 一句话 | 出处 |
|---|---|---|---|
| 全局单例 | autoload | Godot 项目启动时自动加载、全脚本可按名访问的全局节点 | project.godot；scripts/mode_gate.gd |
| 权限闸 | ModeGate | 编辑/运行两态的全局唯一权限闸（autoload），持有当前态真值 | architecture 3.1 |
| 应用模式 | AppMode{EDIT, RUN} | ModeGate 持有的枚举，两态权限档 | architecture 3.1 |
| 运行时手柄 | Gizmo3D | 选中物件后显示移动/旋转/缩放三轴的运行时插件 | addons/Gizmo3DScript；3.4 |
| 告示板渲染 | Billboard | 2D 贴图始终面向镜头的画法，Token 默认用 | design 四；assets/tokens |
| 投屏窗口 | CastView | 运行态的输出层，第二块原生窗口给玩家/会议软件看，旁路于 ModeGate | architecture 3.6；scripts/cast_view.gd |
| 3D 世界 | World3D | Godot 里承载 3D 场景的世界资源，主窗与投屏窗显式共享同一份 | architecture 3.6 |
| 可见层掩码 | cull_mask | 相机渲染哪些层的开关，将来用于藏 GM-only 信息不让玩家看 | architecture 3.6 后续 |
| 嵌入贴图 | Embed Textures | 模型导出时把贴图打进文件，避免写死作者本机路径的坑 | architecture 3.5 |

### C. 物件分类（assets/ 之下）

| 中文名 | 英文目录名 | 含义 | 出处 |
|---|---|---|---|
| 可破坏墙体 | walls | 边缘/带厚度、可破坏的墙 | assets/walls |
| 地形物件 | terrain | 土丘/斜坡/岩石/台阶 | assets/terrain |
| 装饰物件 | props | 树/灌木/纯视觉摆件 | assets/props |
| 光源物件 | lights | 火把/篝火/魔法光，Mesh+OmniLight3D 组合件 | assets/lights |
| 可交互物件 | interactables | 火药桶/配电箱等主动触发后果件（用户拍板单列） | assets/interactables |
| 法术特效预设 | vfx | 法术特效预设（P3 预留） | assets/vfx |
| 场景气氛预设 | environment | Environment 资源预设（P3 预留） | assets/environment |

### D. 渲染相关

| 中文名 | 英文代号 | 一句话 | 出处 |
|---|---|---|---|
| 全局光照 | GI（Global Illumination） | 光线弹射产生的间接光，本工具后期加，先做直接光+阴影 | design 四 |
| 细节层级 | LOD（Level of Detail） | 远处物件用更粗网格省性能 | architecture 3.6 降画质 |
| 多采样抗锯齿 | MSAA | 空间域抗锯齿，可在投屏窗关掉省性能 | architecture 3.6 |
| 时间抗锯齿 | TAA | 基于前后帧的抗锯齿，可在投屏窗关掉省性能 | architecture 3.6 |

### 维护规矩

- 新引入一个核心名词（类、模块、概念）时，在此表加一行，标出处。
- 同一概念若发现自己/旧代码里用了别的叫法，以本表为准统一，删掉旧叫法。
- 本表只记"会反复出现、不统一就会出错"的核心名词；一次性出现的临时名不必入表。

---

## 二、文件结构（只看重要目录和文件）

```
gvtt/                           ← Godot 项目根目录，在 C:\Users\Admin\Claude\Projects\Gvtt
├── project.godot               ← 项目配置（autoload、input map、渲染设置）
├── scripts/
│   ├── main.gd                 ← 主场景脚本（~400 行），承担所有功能逻辑
│   ├── mode_gate.gd            ← autoload 全局权限闸（编辑/运行两态）
│   ├── cast_view.gd            ← 投屏窗口（运行态输出层，旁路 ModeGate）
│   ├── entity_properties.gd    ← 物件属性组件（EntityProperties：战术物件 schema）
│   ├── pick_proxy.gd           ← 无实体物件的拾取代理（PickProxy）
│   ├── gvtt_render_layers.gd   ← 渲染层/拾取层 常量归口（GvttRenderLayers）
│   ├── module_gate.gd          ← 【2026-07-09 立骨架占位】跨场景全局真值闸（当前模组/地点/session），拟 autoload 未注册，main.gd 未订阅，见 docs/multi_scene_draft.md
│   ├── module_manifest.gd      ← 【2026-07-09 立骨架占位】模组清单 Resource（地点清单+开场地点+叙事占位）
│   ├── location_ref.gd         ← 【2026-07-09 立骨架占位】清单里一个地点的引用 Resource
│   ├── playthrough.gd          ← 【2026-07-09 立骨架占位】带团存档 Resource（一次实际跑团快照+visited 状态表）
│   ├── module_io.gd            ← 【2026-07-09 立骨架占位】存读盘封装（pack/instantiate/save/load + owner 陷阱处理），未接入调用
│   └── .gitkeep
├── scenes/
│   └── main.tscn               ← 唯一场景文件，根节点 Node3D
├── assets/
│   ├── models/                 ← 3D 建筑模型 (FBX)，现 4 个建筑
│   │   └── textures/           ← 模型的贴图文件（70+ 个 .png）
│   ├── textures/
│   │   ├── ground/             ← 地面纹理，按材质分子文件夹（main.gd 扫描中）：
│   │   │   ├── stone_floor/    ← 三张图(底色+光泽+法线)
│   │   │   └── uv_checker/     ← 一张方格图（诊断 UV 用）
│   │   └── buildings/           ← 建筑贴图（与 models/textures/ 疑似重复，待物件系统落地时合并去重）
│   ├── walls/                  ← 可破坏墙体（2026-07-09 建占位，物件系统 P1）
│   ├── terrain/                ← 地形物件（土丘/斜坡/岩石/台阶）
│   ├── props/                  ← 装饰物件（树/灌木/纯视觉摆件）
│   ├── lights/                 ← 光源物件（火把/篝火/魔法光，Mesh+OmniLight3D 组合件）
│   ├── interactables/          ← 可交互物件（火药桶/配电箱等主动触发后果件，用户拍板单列）
│   ├── tokens/                 ← Token（角色/怪物，2D BillBoard 默认 + 3D 可选）
│   ├── vfx/                    ← 法术特效预设（P3 预留）
│   └── environment/            ← 场景气氛预设 Environment（P3 预留）
├── entities/                   ← 空骨架（2026-07-07，未启用，待清理决定）
├── maps/                       ← 空骨架（同上）
├── objects/ (gitkeep)          ← 空骨架（同上）
├── resources/ (gitkeep)        ← 空骨架（同上）
├── ui/                         ← 空骨架（同上）
├── sandbox/ (gitkeep)          ← 空目录，Gvtt 专放
├── gvtt/                       ← 早期 Godot 项目残留（疑似旧主项目），待清理决定
├── addons/
│   ├── Gizmo3DScript/          ← 运行时手柄插件（已修三角化 bug）
│   └── gdUnit4/                ← 测试框架（未启用）
├── docs/
│   ├── design.md               ← 策划文档 5 维度+功能优先级
│   └── CCxGodot.md             ← Claude↔Godot 工具栈参考
├── devlog/
│   └── DEVLOG.md               ← 实时开发状态（每次会话结束前更新）
└── .claude/
    └── CLAUDE.md               ← 项目提示词（核心协作规则）
```

---

## 三、核心架构：编辑↔运行两态系统（+ 投屏窗口旁路）

这是 2026-07-08 落地的根基设计，2026-07-09 补「投屏窗口」第三呈现块。

软件有三块呈现——编辑态、运行态、投屏窗口——但架构状态机只有**编辑/运行两档权限**（ModeGate.AppMode{EDIT,RUN}）。投屏窗口是运行态的**输出层**，旁路于 ModeGate，不是第三个 AppMode。理由见 design.md 第 3.1 节与下方 3.6。

### 3.1 ModeGate（权限闸）

- **文件：** `scripts/mode_gate.gd`
- **注册方式：** `project.godot` [autoload] → `ModeGate="*res://scripts/mode_gate.gd"`
- **角色：** 全局唯一（singleton），持有"当前是编辑态还是运行态"这个唯一真值

**暴露的 API：**

| 方法/信号 | 功能 |
|---|---|
| `ModeGate.switch_to(AppMode.RUN/EDIT)` | 切换状态，广播 `mode_changed` 信号 |
| `ModeGate.is_edit()` / `is_run()` | 查询当前态 |
| `ModeGate.current()` | 返回当前枚举值 |
| `signal mode_changed(mode)` | 各功能 connect 此信号，收到后自己开关 |

### 3.2 main.gd 的"功能自报归属"规矩

`_on_mode_changed(mode)` 只做协调，不堆开关逻辑：

```gdscript
func _on_mode_changed(mode):
    _apply_topbar_for_mode(mode)   # 右上角按钮文字
    _apply_panel_for_mode(mode)    # 左侧面板 visible
    _apply_camera_for_mode(mode)   # 正交↔透视
    _apply_gizmo_for_mode(mode)    # 手柄显隐
```

**新加跨态功能必须：**
1. 写一个 `_apply_xxx_for_mode(mode)`，只管自己
2. 在 `_on_mode_changed` 里加一行调用
3. 登记到 `docs/design.md` 第 44-53 行的权限表（目前还没有表，待补）

### 3.3 当前各功能的归属

| 功能 | 编辑态 | 运行态 | 实现位置 |
|---|---|---|---|
| 建筑放置（鼠标点地面） | 允许 | 禁止 | `_unhandled_input` 首行 ModeGate.is_edit() |
| Gizmo3D 手柄 | 显示可拖 | 隐藏不可交互 | `_apply_gizmo_for_mode` |
| 左侧物品面板 | 显示 | 隐藏 | `_apply_panel_for_mode` |
| 相机模式 | 正交俯视 | 透视倾斜 55° | `_apply_camera_for_mode` |
| 滚轮缩放 | 缩放正交 size | 拉近推远 | `_input` 按 ModeGate.is_edit() |
| 相机平移（中键） | 允许 | 允许 | `_physics_process` |

### 3.4 Gizmo3D 工程约束（踩坑记录）

- Gizmo3D 的 `_process` 每帧把 `visible` 重置为 `(selections>0)`——单纯 `gz.visible=false` 管不住
- **跨态关闭必须三连：** `clear_selection() + set_process(false) + visible=false`
- 恢复时：`set_process(true) + visible=true` + 用 `_gizmo_selections_snapshot` 逐个 `select` 回去
- 建筑↔gizmo 的绑定用 `_building_to_gizmo: Dictionary[Node3D, Gizmo3D]` 管理，不准访问 `gz._selections`
- 已知 bug(已修):gizmo3D.gd 第 338 行三角化失败——三点退化不画可跳过(已加面积保护)

### 3.5 潜伏债

- `_building_to_gizmo` 只增不 erase，实现删除建筑功能时必须同步 erase
- FBX 模型贴图路径不对(fbx 写死作者电脑路径 `F:\download\...`)
  - 方案：以后所有模型导出时勾"嵌入贴图"(Embed Textatures)
  - 旧四个 FBX 不改先，不计入代码债

### 3.6 投屏窗口（玩家视图，2026-07-09 补）

**定位：** 运行态场景的同步呈现输出层，不是第三个 AppMode，旁路于 ModeGate。

**用户场景：** 线下跑团 GM 笔记本连电视/投影，或用腾讯会议「只共享投屏窗口」。GM 屏幕仍是编辑/运行态（有控件），第二屏是纯 3D 场景。

**实现要点（API 依据见下）：**
- `scripts/cast_view.gd`：创建一个独立原生 `Window` 节点，直接挂一颗只读 `Camera3D` 为其 active 相机。Window 本身继承自 Viewport，能直接渲染 3D 场景、有自己的 world_3d，**不需要**再套 SubViewportContainer/SubViewport（那层是为「画到纹理」用的，独立原生窗口用不上）
- 投屏窗口**不挂** main.gd 的 `_ui_layer`（那个 CanvasLayer 只属于主窗口），GM 控件天然不出现在玩家画面里
- 主相机与投屏相机各自在所属 Viewport 内 `current`，互不抢占（每个 Viewport 一个 active 相机）
- 投屏相机复用主场景的 World3D：**显式** `cast_window.world_3d = get_viewport().world_3d` 设同一 World3D 资源对象（跨原生 Window 祖先关系弱，不靠 `own_world_3d=false` 隐式继承，改用显式赋值，文档直接支持 `set_world_3d()`）
- open()/close() 接口由 main.gd 顶栏「投屏」按钮调用，不接入 ModeGate，两态都可开投屏

**API 依据（离线文档 4.7 核对，非猜测）：**
- Window 继承 Viewport（`Inherits: Viewport < Node < Object`），可创建原生系统窗口，运行时需手动处理 `close_requested` 信号 → `gdd_0786_Window.md` 第 3-14 行
- `world_3d` 属性可显式 set/get，跨 Viewport 共享同一 World3D 资源；`find_world_3d()` 返回自身或祖先第一个有效 World3D → `gdd_0774_Viewport.md` 第 1177-1196 行
- Camera3D 注册在最近父 Viewport；每 Viewport 仅一个 active 相机；`current` 控制是否被该 Viewport 使用；可设 `cull_mask` 限制渲染层 → `gdd_0540_Camera3D.md` 第 11、21-22、122-142 行；`gdd_0296_Using_Viewports.md` 第 55-73 行

**设计边界：** 投屏窗口 ≠ 玩家端。不联网、不需账号，是 GM 本机第二个本地窗口/共享窗给会议软件。与第 38 行「不做玩家端」无冲突。

**后续若要 GM 能看玩家看不到的隐藏信息：** 届时给每个物件/Token 标记「对玩家可见」布尔，投屏相机用 cull_mask 过滤掉 GM-only 层。这是比「当前纯藏 UI」更重的一档（见 design.md 3.1），目前不做，留接口。

**降画质预案（2026-07-09 留框架，默认关闭）：** 参数同步这条路代价是真双倍 GPU 绘制（CPU 场景逻辑只跑一遍、World3D 共享）。其中 3D 阴影随 Viewport 各自一套，是双倍里最贵的一块。预案做法：给 `cast_view.gd` 加 `_low_quality` 开关 + `set_low_quality(true)` + `_apply_low_quality()`，开关默认 false，GM 机实测卡了再拨开。拨开时只关投屏窗（Window 是 Viewport 子类，有自己的 Viewport 渲染属性）的贵特性，GM 主窗不受影响。当前实现关的是：

| 投屏窗属性 | 关闭/调值 | API 依据 |
|---|---|---|
| `positional_shadow_atlas_size` | 设 0（不渲染实时位置阴影） | `gdd_0774_Viewport.md` 第 955 行 |
| `msaa_3d` | `MSAA_DISABLED` | 第 835、231-242 行 |
| `use_taa` | false | 第 1104 行 |
| `mesh_lod_threshold` | 2.0（远物件用粗 LOD） | 第 809 行 |

有意没动的：方向光阴影属 WorldEnvironment/DirectionalLight3D，随 World3D 共享、不重复独立算；体积雾属 Environment，跨 Viewport 共享，没法只在投屏关——要关得给投屏窗配独立 Environment，架构改动较大，留作更重档。

**本预案的实测要求（重要）：** 在原生 `Window` 节点（非 SubViewport）上调这些 Viewport 属性是否会真生效，文档无明示示范，靠「Window 继承 Viewport」的推断（gdd_0786 第 3 行）。与 `force_native` 那个坑情况类似。**日后拨 `set_low_quality(true)` 跑游戏时必须验证**：投屏那头阴影确实消失、帧率确实起来才算坐实；若不生效，退回 SubViewport 方案（Window 内嵌 `SubViewportContainer → SubViewport`，给 SubViewport 设这些 Viewport 属性有官方明确支持，gdd_0296 第 173-185 行）再走一遍。框架已留，验证留给将来触发的那次会话。

---

## 四、地面纹理系统（2026-07-08 改造）

### 4.1 目录规则

```
assets/textures/ground/<纹理组名>/
    ├── albedo.png (或任意文件名，被扫到后按关键词分类)
    └── normal.png / roughness.jpg / ...
```

每个子文件夹 = 一个纹理组，文件夹名 = 显示在按钮上的名字。

### 4.2 按钮 UI 布局

```
┌─ 地面纹理 ──────────────────┐
│  平铺尺寸          [ 2.00 ▼] │  ← 标签+数字输入框
│  ═══════●══════════════════ │  ← 滑条（StyleBoxFlat 样式）
├─────────────────────────────┤
│  [Stone Floor]              │  ← 纹理选择按钮
│  [Uv Checker]              │
└─────────────────────────────┘
```

- 滑条+数字框双向同步
- 滑条范围 0.5-20，数字框范围 0.1-100
- 不选纹理时隐藏整个平铺控制区

### 4.3 代码关键函数

- `_scan_textures(dir)` → 扫子文件夹
- `_scan_texture_folder(folder_path, folder_name, out_arr)` → 读文件夹内文件
  - 单文件→当整张贴图(albedo)
  - 多文件→按 `_classify_texture` 关键词分类(albedo/normal/roughness 等)
- `_on_ground_clicked(ts)` → 点纹理按钮，调用 `_apply_ground_texture()`
- `_on_tile_changed(value)` → 滑条/数字框变化，同步+重设 UV 缩放
- `_apply_ground_texture()` → 新建材质+贴图+设 uv1_scale+挂到 Ground 节点

---

## 五、文件状态

- 文件编码：UTF-8 without BOM（已验证）
- Gitignore：已忽略 `*.uid`、`*.bak`、`sandbox/`
- 当前有未提交改动（2026-07-08 一整天的改造）

---

## 六、存档记忆（用于跨会话持久化）

在 `C:\Users\Admin\AppData\Local\Claude-3p\local-agent-mode-sessions\064f67ea\00000000\spaces\3c3518e6-ff6b-4f57-9c46-b724c3877573\memory\` 目录下有：
- `gvtt_mode_architecture.md`——ModeGate + Gizmo3D 架构记忆

每次改造完成后应更新此文件。

---

## 七、代码组织参考（2026-07-12 评 UnorthodoxHacks）

审阅 [Muigoochen/UnorthodoxHacks](https://github.com/Muigoochen/UnorthodoxHacks) 后，其代码组织水准有两点值得纳入开发习惯：

### 7.1 `#region` 分区

UnorthodoxHacks 每个 .gd 文件用 `#region 文件操作 / #region 路径工具` 将几十个方法按职责分组，折叠阅读。Gvtt 的 `main.gd` 现在上千行、函数平铺无分区，新读的人（包括你自己下次接）很难快速定位。推荐后续修改 `main.gd` 或其他长脚本时，按以下粒度加 `#region`：

```
#region --- UI 构建
#region --- 相机控制
#region --- 物件放置
#region --- 场景存读盘
#region --- 地面纹理
```

这不是必须补的债（不补不影响运行），但**修改到对应区段时顺手加上**，积少成多。

### 7.2 防御性编程习惯

UnorthodoxHacks 每个公开方法开头都做三件事：路径标准化、参数合法性检查、失败写警告/错误。我们自己代码多处直接相信传参——`_place_building` 未经 `@export_dir` 目录列表检查、`_apply_ground_texture` 没有 texture 错判保护。建议后续**新建方法时就带检查**，而不是回头改老的。

### 7.3 不适合照搬的部分

UnorthodoxHacks 的工具函数以 `static func` 直调为中心——不关心谁调的、是否需要权限。Gvtt 受 ModeGate 和 ModuleGate 约束，文件操作不是无条件可用。所以**不引入它的 FilesManager 作依赖**，只吸收其防御编程的纪律和 region 分区习惯。
