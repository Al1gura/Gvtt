# CCxGodot — Claude Code + Godot 开发参考

> 搜自 GitHub / SkillsMP / 社区，2026年7月整理。
> 此文件为参考索引，不随项目设计演变修改。

---

## 一、Claude Code 官方内置插件和技能

### 1.1 code-reviewer（代码审查）
- **安装：** `/plugin install code-review@claude-plugins-official`
- **来源：** [Anthropic 官方 Code Review](https://claude.com/ja/blog/code-review)
- **功能：** 4-5 个并行审查代理同时检查代码：CLAUDE.md 规范、Bug 检测（只看 diff）、Git 历史上下文、PR 历史。信心评分 0-100，只报 ≥80 分的高可信问题。过滤掉：linter 已有问题、非本次变更引入的问题、假阳性。Anthropic 内部数据：有实质反馈从 16%→54%，误报 <1%，每次审查约 20 分钟。

### 1.2 frontend-design（前端设计）
- **安装：** 内置，自动触发
- **来源：** [Frontend Design Plugin DeepWiki](https://deepwiki.com/anthropics/claude-code/4.6-frontend-design-plugin)
- **功能：** 写 UI 前先确定美学方向——Purpose / Tone / Constraints / Differentiation。指导五大域：Typography（禁止 Inter/Roboto/Arial）、Color & Theme（禁止紫渐变白底）、Motion、Spatial Composition、Backgrounds & Visual Details。2026 新增工程规范：4px/8px 网格、Design Token 化、组件审计、WCAG 语义 HTML。

### 1.3 security-review（安全审查）
- **安装：** `/plugin install security-review@claude-plugins-official`
- **来源：** [Anthropic Security-Guidance](https://www.helpnetsecurity.com/2026/05/27/anthropic-claude-code-security-guidance-plugin/)
- **功能：** 三阶段——①文件编辑时：纯正则匹配 ~25 种高危漏洞（eval/硬编码密钥/SQL 注入/XSS/命令注入/不安全反序列化）②每轮模型后：分析 Git diff，检测逻辑漏洞（授权绕过/IDOR/SSRF/弱加密）③commit/push 时：Opus 级深度审查调用链。需要 Claude Code CLI v2.1.144+、Python 3.8+、Git。

### 1.4 deep-research（深度调研）
- **安装：** 无需安装，对话中自动触发
- **功能：** 多源搜索→逐源查证→交叉验证→写引用报告。策划/调研阶段使用。

### 1.5 consolidate-memory（记忆整理）
- **安装：** 无需安装，自动触发（距上次 24 小时 + 积累 5+ 次会话）
- **功能：** 扫描 memory 目录→提取信号→合并去重/消除矛盾/日期修正→保持 MEMORY.md 在 200 行以内。

### 1.6 schedule（定时任务）
- **安装：** 内置
- **功能：** 三种触发器——Cron 定时 / HTTP webhook / GitHub webhook。本地或云端运行。典型用途：每周简报、定时代码质量扫描、每日规划生成。

---

## 二、Godot SKILL.md 技能文件

`SKILL.md` 放进 `.claude/skills/` 后 Claude Code 自动发现。所有 Godot 技能目标引擎 **Godot 4.3+**，GDScript 2.0。

### 2.1 Godot-Skill（GDScript 规范）
- **来源：** https://github.com/shihabshahrier/Godot-Skill
- **内容：** 1 个主 `SKILL.md`（<500 行）+ 4 参考文件。强制静态类型、禁止 Godot 3 旧语法（`yield`/`TileMap`/`File`/`Directory`）、信号驱动+组件化、防止 AI 幻觉编造 API。

### 2.2 GodotPrompter（51 技能 + 9 代理，最全面）
- **来源：** https://github.com/jame581/GodotPrompter | v1.10.1（2026年6月）
- **安装：** `claude plugins marketplace add jame581/skillsmith` → `claude plugins install godot-prompter@skillsmith`

**完整 51 技能列表（13 大类）：**

| 类别 | 技能 |
|------|------|
| 核心/流程（6） | `godot-project-setup` `godot-brainstorming` `godot-code-review` `godot-debugging` `godot-testing` |
| 架构/模式（6） | `scene-organization` `state-machine` `event-bus` `component-system` `resource-pattern` `dependency-injection` |
| 物理/维度/XR（4） | `physics-system` `2d-essentials` `3d-essentials` `xr-development` |
| 玩法系统（13） | `player-controller` `input-handling` `animation-system` `tween-animation` `audio-system` `inventory-system` `dialogue-system` `save-load` `ai-navigation` `ability-system` `camera-system` `localization` `procedural-generation` |
| UI/UX（3） | `godot-ui` `responsive-ui` `hud-system` |
| 多人（3） | `multiplayer-basics` `multiplayer-sync` `dedicated-server` |
| 渲染/视觉（2） | `shader-basics` `particles-vfx` |
| 构建/部署（5） | `export-pipeline` `godot-optimization` `addon-development` `assets-pipeline` `mobile-development` |
| 脚本（4） | `gdscript-patterns` `gdscript-advanced` `csharp-godot` `csharp-signals` |
| 原生/性能（2） | `gdextension` `multithreading` |
| 数学（1） | `math-essentials` |
| 第三方（2） | `limboai` `beehave` |

**9 个专用代理：** `godot-game-architect` `godot-game-dev` `godot-code-reviewer` `godot-shader-author` `godot-performance-profiler` `godot-animator` `godot-csharp-engineer` `godot-ui-designer` `godot-tools-engineer`

### 2.3 awesome-gamedev-agent-skills（66 技能，跨引擎）
- **来源：** https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- **内容：** 66 个总技能，主路由器自动检测引擎。Godot 部分 15 个——`godot-gdscript` `godot-nodes-scenes` `godot-signals-groups` `godot-2d-movement` `godot-tilemap` `godot-physics` `godot-ui-control` `godot-animation` `godot-shaders` `godot-3d-essentials` `godot-resources` `godot-audio` `godot-multiplayer` `godot-export` `godot-csharp`
- **与 GodotPrompter：** 大部分重叠。

### 2.4 Claude-GDSkill（Godot 4.5 类参考）
- **来源：** https://github.com/Kothulhu94/Claude-GDSkill
- **内容：** Godot 4.5 全套 **1050+** 个类 API（压缩 2.5MB，解压 26MB）。只在查具体 API 时临时加载。

### 2.5 SkillsMP 上的 Godot 技能
- `godot-gdscript-patterns`（rmyndharis/wshobson/sickn33）— 架构模式/信号/状态机/优化
- `godot`（dmaynor v1.1.0）— 场景架构/物理/UI/着色器/常见踩坑
- `godot-api`（来自 Godogen）— 850+ 类 API 查找
- `godot-native-art`（merceralex397）— Polygon2D/ShaderMaterial/GPUParticles2D/TileMapLayer 零导入视觉

### 2.6 GodoMaster（18 模块，官方文档）
- **来源：** Aetik-yue/GodoMaster | 安装：`npm install -g godomaster-skill`
- **内容：** 项目管理/编辑器/GDScript/节点场景/2D/3D/物理/动画/UI/音频/输入/导出/性能/文件IO/着色器/网络/测试/架构

### 2.7 Godogen（自主生成）
- **来源：** https://github.com/htdt/godogen（2454+ stars）
- **功能：** 一句话→完整 Godot 4 项目。编排器 + 任务执行器 + Visual QA（截图→Gemini 分析→修复）。

### 2.8 godot-craft（6 阶段生成）
- **来源：** https://github.com/vp-k/godot-craft
- **功能：** 概念规划→脚手架→实现→Visual QA→打磨→验证。`claude plugin add vp-k/godot-craft`

---

## 三、MCP 工具（让 Claude 操控 Godot 编辑器）

### 3.1 Godot-MCP-Native（零依赖，155 工具）
- **来源：** https://github.com/yurineko73/Godot-MCP-Native | 免费
- **依赖：** 无（纯 GDScript+HTTP）。155 工具（30 核心 + 125 补充），含 68 个调试工具、C# 支持、场景审计。HTTP 端口 9080。

### 3.2 Godot AI（最成熟，120+ 操作）
- **来源：** https://github.com/hi-godot/godot-ai | 免费 | v2.8.1（74+ 版本）
- **依赖：** Python + uv。自动配置 16+ MCP 客户端。场景/节点/脚本/动画/UI/材质/粒子/相机/环境。

### 3.3 tugcantopaloglu/godot-mcp（149 工具，运行最完整）
- **来源：** https://github.com/tugcantopaloglu/godot-mcp | 免费
- **依赖：** TypeScript。149 工具含网络（HTTP/WebSocket/ENet/RPC）、3D Mesh 生成、**CSG**、**GridMap**、骨骼 IK、导航。`game_eval`（任意 GDScript 执行）。

### 3.4 Agent Tools（70 工具，Token 最省）
- **来源：** https://godotengine.org/asset-library/asset/5070 | 免费 MIT
- **依赖：** Godot 插件 + npm。无头运行+多帧截图+JSON dump、ClassDB 查询、Transform2D/3D 类型转换、GUT/GdUnit4 测试集成。

### 3.5 sterion66/godot-mcp-server（40 工具，安全沙箱）
- **来源：** https://github.com/sterion66/godot-mcp-server | 免费 | FastMCP Python
- **功能：** Asset Library 搜索/下载、GitHub 浏览、沙箱工作区、文件监听。

### 3.6 Godot-MCP-Pilot（npm 一键，35 工具）
- **来源：** https://github.com/Pushks18/Godot-MCP-Pilot | 免费 | `npx godot-mcp-pilot`
- **功能：** 编辑器启动/运行/场景节点脚本编辑/UID。支持 Claude Code/Cursor/Cline/Windsurf。

### 3.7 其他
- **Claude-GoDot-MCP**（PiMPStudios）— 170 工具，Python+WebSocket，运行时输入模拟+截图反馈+Profiler 快照
- **Ziva** — 原生 Godot 插件，多模型（Claude/GPT-5/Gemini/DeepSeek），内置 2D/3D 资产生成。免费层→$20/月
- **Summer Engine** — Godot 衍生独立引擎，44 MCP 工具，云端同步，免费 MIT

---

## 四、Godot 编辑器内 AI 插件

不同于 MCP——不需外部 Claude Code，直接在 Godot 编辑器里跑。从 Godot Asset Library 搜索安装。

| 插件 | 提供商 | 特点 |
|------|--------|------|
| **Golem-AI**（v1.5.5） | Ollama/LM Studio/OpenRouter/Kimi/MiniMax/OpenAI/Anthropic/Gemini/Cursor（9+） | 多步 agent 循环 + 编辑器工具（场景/脚本/节点/TileMap/空间映射）。网页搜索（Serper/Brave），可下载文件到项目。技能系统+@自动补全+/命令。API 密钥加密存储。测试于 4.6.x |
| **Godot AI**（mpxxv v0.1.0） | Claude/GPT/Gemini/Ollama | 流式聊天+实时答案。自动上下文注入（打开的脚本/场景树/项目文件）。AI 可创建节点、加脚本、运行场景。会话历史、快速操作（解释/重构/注释/找 bug）。导出聊天为 .md |
| **Ollama Assistant** | Ollama（本地） | 100% 本地免费离线用。重构/优化/解释/补全函数。代码直接应用到脚本。Godot 4.4+ |
| **Godo4NewbiAI**（v1.0.0） | Claude | 聊天+生成/运行 EditorScript。分享打开的脚本作上下文、粘贴报错获取修复。代码片段库。持久聊天历史 |
| **AlphaAgent**（v0.4） | — | 编辑器内嵌入式 AI 助手。Godot 4.5 |
| **Genesis Engine**（v1.0） | Gemini | 自然语言→完整游戏设计+执行。规划模式（GDD）、执行模式（创建场景/脚本/资源）、审查模式、Git 集成。需要 Python 3.10+。目前 2D 为主 |

---

## 五、GDScript 工具链

### 5.1 Linter + Formatter

| 工具 | 语言 | 规则数 | 特点 |
|------|------|--------|------|
| **gdstyle**（v0.1.4） | Rust | 54 规则 | 最快。单二进制，无需 Python/Godot。Linter+Formatter 合一。auto-fix（`--fix`/`--unsafe-fix`）。Godot 编辑器插件（点击诊断+保存时格式化）。pre-commit 集成。GitHub Actions |
| **GDScript Toolkit**（gdtoolkit v4.5.0） | Python | — | 行业标准。gdformat（格式化）+ gdlint（lint）+ gdradon（复杂度）。pip 安装 |
| **GDScript Linter**（v3.2.1） | GDScript | 17+ | 编辑器插件，编辑器内点击跳转。**Claude Code 集成**——扫描结果直接 AI 修复。导出 JSON/HTML/MD。CLI 模式+exit code 用于 CI/CD |
| **gdeye**（v0.1.3） | Rust/Tree-sitter | — | lint+format+LSP 三合一。auto-fix。TOML 配置 |
| **GDQuest Formatter** | Rust/Tree-sitter | — | 最快格式化（<100ms/1000行）。树-保姆解析器+Topiary |
| **GDShrapt.CLI** | .NET | — | .NET 全局工具。语义验证+类型推断+安全重命名+死代码检测+度量。CI 友好 JSON/SARIF |

### 5.2 测试框架

| 工具 | 语言 | 特点 |
|------|------|------|
| **GdUnit4** | GDScript+C# | 领先的嵌入式单元测试。场景测试+输入模拟+无头 CI+编辑器内检查器。~1000+ stars。有官方 GitHub Action |
| **GUT** | GDScript | 成熟测试框架，`godot-gut-ci` 用于 CI 集成 |
| **GoDotTest**（Chickensoft） | C# | C# 测试运行器。CLI 运行+代码覆盖率+VS Code 调试。~128k NuGet |
| **GoDotEnv**（Chickensoft） | C# | 集成测试+模拟输入+节点驱动+夹具。~62k NuGet |
| **PlayGodot** | Python | 游戏自动化框架（类似 Playwright for Godot）。E2E 测试+自动化游戏+远程调试协议外部控制。需要自定义 Godot 分支 |

---

## 六、项目模板参考

| 仓库 | 侧重 |
|------|------|
| [godot-project-template](https://github.com/SamuelAsherRivello/godot-project-template) | Godot 最佳实践 + C# 编码规范 |
| [Godot-Project-Structure-Template](https://github.com/Joshulties/Godot-Project-Structure-Template) | 标准化文件组织 |
| [godot-architecture-organization-advice](https://github.com/abmarnie/godot-architecture-organization-advice) | 架构和文件组织建议 |

---

## 七、CLAUDE.md 模板参考

- **[Godot + Claude Code 完全指南](https://gist.github.com/xbfool/af1cacc74b7e58364aa244770bf85752)** — 三层工具栈、CLAUDE.md 模板、GDScript 规则、踩坑
- **[godot-bevy CLAUDE.md](https://github.com/bytemeadow/godot-bevy/blob/v0.8.4/CLAUDE.md)** — Rust 桥接方案

---

## 八、安装方式

技能 = 文件夹 + `SKILL.md`，放到路径后 Claude Code 自动发现。

| 范围 | Windows 路径 |
|------|-------------|
| 项目级 | `.claude/skills/<skill名>/SKILL.md` |
| 全用户 | `C:\Users\<用户名>\.claude\skills\<skill名>\SKILL.md` |

```powershell
# 以 Godot-Skill 为例：
mkdir .claude\skills\godot-skill
# 打开 https://raw.githubusercontent.com/shihabshahrier/Godot-Skill/main/skills/godot/SKILL.md
# 全选复制 → 保存为 .claude\skills\godot-skill\SKILL.md
# 重启 Claude Code
```

`.claude/skills/` 在项目内，Git 自动追踪。
