# Memory Index

## 项目摘要

- 类型：2D 纯竖屏移动端休闲游戏。
- 核心体验：全天候离线挂机，上线领取收益，下线持续成长。
- 核心表达对象：伙伴。后续架构、系统命名、UI 文案统一使用“伙伴”，不使用“宠物”作为主术语。
- 操作方式：适配手机单手操作。
- 技术方向：UrhoX Lua，用户代码应放在 `scripts/`。

## 不可变规则

1. 所有玩家数据登录游戏时请求存档。
2. 游戏中改变了玩家存档数据时请求更新存档。
3. 纯竖版适配，不支持横屏，UI、场景、战斗视角全部为竖屏定制。

## 当前结构

- `scripts/main.lua`：Yoga UI 入口，包含登录界面、读档/存档更新、离线收益结算、游戏主界面，并接入秘境战斗场景切换和勇者编队页面切换；主界面勇者序列帧默认使用 `image/npcClip/0001/`。
- `scripts/Formation/FormationScene.lua`：独立勇者 NPC 上阵编队页面，包含三套阵容 TAB、实时总战力、勇者列表排序、9 格三排站位、上阵/替换/下阵、单格锁定、全阵容锁定、一键上阵、一键清空、保存阵容、推荐开关与羁绊展示。
- `scripts/Battle/GridBattleScene.lua`：20×20 网格自动战斗原型，管理格子、单位占位、双方自动寻敌、身前 1 格攻击、战斗 HUD 和返回主界面；背景资源为 `image/BattleRes/1.png`；战斗网格逻辑保留但显示层已隐藏；寻敌优先选择同列敌方，同列无目标时再选择最近敌方；勇者和敌方都会按状态播放待机 01-04、移动 06-09、攻击 10-14 序列帧，敌方水平反转并保留红色 tint。
- `assets/image/login_background.png`：登录背景图资源，运行时路径 `image/login_background.png`。
- `assets/image/`：登录背景、主界面背景、森林关卡、资源图标、顶部功能图标、挑战徽章、收益条、秘境按钮、功能按钮、底部导航等 UI 图片资源。
- `assets/image/npcClip/0001/` 等：NPC 序列帧动作资源，01-04 为待机、06-09 为移动、10-14 为攻击。
- `scripts/Level/LevelManager.lua`：关卡数据管理器，读取 `Config/level_design.json`，提供当前章节/小关标题摘要、关卡敌人生成、敌方站位映射和胜利推进逻辑。
- `assets/Config/level_design.json`：由 `docs/setting/level_design.json` 复制的关卡配置，共 67 个章节，包含场景名、场景图编号、难度、小关、敌人、BOSS 信息。
- `.project/`：构建后由工具生成。
- `docs/`：记忆系统目录。

## 已完成

- 记录项目定位与核心硬性规则。
- 部署最小项目记忆文件。
- 统一核心表达对象为“伙伴”。
- 创建 720×1280 竖屏 Yoga UI 登录主界面，背景图为 `image/login_background.png`，中央按钮为“登录”。
- 登录按钮已接入“请求存档 → 读取玩家数据 → 离线收益结算 → 请求更新存档 → 跳转主界面”流程。
- 创建参考图风格的游戏主界面，并已从临时整屏参考图升级为分层图片资源 + Yoga UI 叠加：`main_bg_blur.png`、`stage_forest_bg.png`、资源图标、顶部功能图标、挑战徽章、收益条、秘境按钮、功能按钮、底部导航等均已接入。
- 底部导航已按 Inspector 调整：隐藏文字标签，导航图标放大到 96×96，并调整底部导航项父级布局宽高与偏移。
- 顶部功能图标和四个圆形功能图标已按 Inspector 调整：删除文字标签，仅保留图片。
- 按 Inspector 删除主界面森林关卡下方的模式徽章横排 Panel（原位于 `scripts/main.lua` 的 `homeScreen` 第 5 个子项，视觉位置 x=5,y=514,w=712,h=110）。
- 收益条、领取按钮、离线收益文案、四个圆形功能入口、秘境挑战按钮、章节标题条已按 Inspector 调整；章节标题条使用 `image/P-标题-上.png`。
- 按 Inspector 同步主界面 4 个控件：收益条上移到 top=530 且圆角清零；勇者容器调整为 720×148、left=0/top=159；勇者图缩小为 150×120 并移动到 left=-283/top=36；删除“勇者1 · 待机”动作文字 Label。
- 按要求删除主界面 `stageSummaryLabel` 组件，并清理对应缓存变量、查找和更新逻辑。
- 按 Inspector 将勇者容器标记为 `id="Hanginglist"`，并将勇者图 `top` 从 36 调整为 0。
- 森林关卡背景 `stage_forest_bg.png` 确认为 1024×309，并改为两个图层横向无缝滚动。
- 主界面上半区已按 Inspector 调整：顶部功能区图标 96×96，资源条移除“金/蓝/晶”短标签，右上角数字移除，标题条、章节文字、模式行和挑战徽章位置尺寸更新。
- 存档系统已模块化：`scripts/Save/SaveSchema.lua`、`SaveValidator.lua`、`RuntimeSave.lua`、`SaveManager.lua`；`main.lua` 通过 `SaveManager.LoginSyncPlayerSave()` 登录读档，通过 `SaveManager.GetSaveData()` 读取运行时副本，通过 `SaveManager.CollectIdleReward()` 领取收益；登录/上传流程已按 `docs/login.md` 优化为字段级 dirty、版本递增、字段校验和、增量上传、下载/上传 3 次重试和旧整包存档兼容迁移。
- 勇者序列帧已接入主界面森林关卡区，默认使用 `assets/image/npcClip/0001/` 做 UI 序列帧动画：主界面 `Hanginglist` 会从玩家已拥有 `heroes` 中随机选择一个勇者，使用该勇者 `clipDir` 的 06-09 移动帧做原地移动动作，每 3-5 秒随机切换到另一个当前未显示的勇者；左侧挑战徽章仍可触发攻击，右侧成长徽章触发移动。
- 已新增 `scripts/UI/NormalizedSprite.lua`，按每张 `npcClip` 帧图的透明像素包围盒做归一化缩放/居中，已接入主界面 `Hanginglist`、阵型页勇者卡/站位预览、战斗页单位精灵，解决同界面不同勇者或不同动作因画布留白不同导致视觉大小不一致。
- NPC/勇者数据已从 `docs/setting/npcdata.json` 生成到 `assets/Config/npc.json`，共 112 条。`SaveSchema` 通过 `ConfigManager` 读取 NPC 配置生成默认勇者列表，字段包括 `npcId/configId/name/quality/star/power/job/profession/faction/role/story/clipDir/skills`；旧存档若仍是占位勇者，会在 Normalize 时切换为配置生成的 NPC 勇者并重建默认阵容；阵型页和战斗场景均使用 `hero.clipDir` 显示对应 NPC 序列帧。
- 关卡系统已接入 `docs/setting/level_design.json`：配置复制到 `assets/Config/level_design.json`，新增 `LevelManager` 读取 67 个章节/小关/BOSS/敌人配置；存档新增 `stageProgress`，主界面标题和关卡摘要显示当前章节小关，战斗场景按当前小关生成敌方单位并使用 `sceneImage` 切换 `BattleRes` 背景，胜利后推进关卡进度并保存。

## 下一步候选

- 将主界面参考图拆分为正式 UI 资源与可交互模块。
- 完善主界面的背包、阵型、冒险、任务、图鉴等入口。
- 设计玩家数据模型：资源、伙伴成长进度、上次离线时间、收益结算状态。
- 继续完善数据变更保存、收益领取、伙伴成长逻辑。
- 将勇者1动画逻辑抽成可复用伙伴动画组件，并接入伙伴配置与战斗状态。
- 在 `GridBattleScene` 上继续实现寻路、技能范围、敌方 AI、攻击表现、胜负结算和战斗结果存档。

## POST 日志

- 2026-07-03：修正 GitHub 同步地址并成功推送：`origin` 改为 `https://github.com/sorrykick/sorrykickGame.git`，确认 PAT 对该仓库有 `push` 权限；通过本地-only `.git/hooks/post-commit` 使用 `x-access-token` Basic header 方式自动推送，当前 `master` 已推送到 `origin/master`。注意：hook 内含本地 token，仅存在 `.git/hooks/`，不会进入仓库。

- 2026-07-03：配置 GitHub 同步：初次将 `origin` 设置为 `https://github.com/HYsorrykick/sorrykickGame.git` 并配置 post-commit 自动推送，后续确认该地址 owner 错误，已更正为 `sorrykick/sorrykickGame`。

- 2026-07-03：将 `.project/project.json` 的 `taptap_publish.title` 修改为 `sorrykickGame1`，JSON 校验通过，官方构建成功。

- 2026-07-03：读取 `docs/login.md` 并优化登录/云存档流程：新增增量字段 key 和 meta key、`RuntimeSave` dirty 字段追踪/本地版本首次变更递增/字段校验和、`SaveManager.UpdatePlayerSave()` 增量上传、下载/上传 3 次重试、上传失败强制退出、旧整包存档兼容迁移；编队和战斗胜利保存前显式标记 `lineup`/`stageProgress` dirty；登录状态 UI 展示下载/上传进度；修正离线收益按钮不再固定发放 12.35 万。LSP 服务不可连接，官方构建成功。

- 2026-07-02：新增 `scripts/UI/NormalizedSprite.lua`，用每张 `npcClip` 帧图的透明像素包围盒归一化绘制尺寸，并替换主界面 `Hanginglist`、阵型页勇者卡/站位预览、战斗页单位精灵的显示组件，统一同界面内不同勇者和动作的视觉大小；LSP 0 Error，官方构建成功。

- 2026-07-02：实现主界面 `Hanginglist` 随机已拥有勇者展示：读取存档 `heroes`，按 `clipDir` 播放 06-09 原地移动帧，首次进入主界面随机选择，之后每 3-5 秒切换到另一个当前未显示勇者；LSP 0 Error，官方构建成功。

- 2026-07-02：按 Inspector 将勇者容器增加 `id="Hanginglist"`，并将勇者图 `top` 从 36 调整为 0；LSP 0 Error，官方构建成功。

- 2026-07-02：删除主界面 `stageSummaryLabel` 组件，同时清理 `stageSummaryLabel_` 缓存变量、`FindById` 和 `UpdateHomeLabels` 更新逻辑；LSP 0 Error，官方构建成功。

- 2026-07-02：按 Inspector 同步主界面 4 个控件：收益条上移到 top=530 并设置 borderRadius=0，勇者容器改为 720×148 且移动到 left=0/top=159，勇者图缩小为 150×120 并移动到 left=-283/top=36，删除“勇者1 · 待机”动作文字 Label；LSP 0 Error，官方构建成功。

- 2026-07-02：按 Inspector 删除主界面森林关卡下方模式徽章横排 Panel（原 `homeScreen` 第 5 个子项，含普通/精英/传说/剧情/奇遇/BOSS/地图徽章）；LSP 服务不可连接，官方构建成功。

- 2026-07-02：排查 TapTap Maker 大量 `<game>/assets/*.png` not found：报错 UUID 可反查到 `assets/image/npcClip/*/*.png.meta` 和 `assets/image/BattleRes/1.png.meta`，源资源和 manifest 条目存在；确认 `.project/resources.json` 为全量引用 `groups.default=["**"]`，进一步将 `preload_groups` 设置为 `["default"]`，避免启动阶段 UI/序列帧动态加载时资源尚未下载；LSP 0 Error，官方构建成功。

- 2026-07-02：读取 `docs/setting/level_design.json` 并接入关卡系统：复制配置到 `assets/Config/level_design.json`，新增 `scripts/Level/LevelManager.lua`，`ConfigManager` 读取关卡配置；存档新增 `stageProgress`；主界面标题/摘要显示当前章节小关；战斗场景按当前小关生成配置敌人，使用 `sceneImage` 选择战斗背景，胜利后推进关卡并保存；LSP 客户端不可用，官方构建成功。
- 2026-07-01：清理未调用旧资源：确认脚本和配置不再引用 `npcClip/1`、非下划线品质图标与 `BattleRes/2.png` 到 `67.png` 后，删除旧 `assets/image/npcClip/1/` 跟踪资源、`assets/image/品质/A/B/C/D/L/S/SS.png` 及 meta、`assets/image/BattleRes/2.png` 到 `67.png` 及 meta，并移除重复的 `docs/data/` 配置副本；官方构建成功。
- 2026-07-01：读取 `docs/setting/npcdata.json` 并生成 112 条 NPC/勇者配置到 `assets/Config/npc.json`；`SaveSchema` 默认勇者改为从 `ConfigManager` 读取 NPC 配置生成，并补充 `npcId/configId/profession/story/clipDir/skills` 字段；阵型页站位/列表和战斗场景改用每个 NPC 的 `clipDir` 序列帧；LSP 客户端不可用，官方构建成功。
- 2026-07-01：按 Inspector 同步阵型页勇者卡片 8 个控件：头像扩大到 106×97 并贴左，品质图标移到 left=11/top=2，星级徽章改为 71×22 并下移到 left=14/top=79，星星图标改 20×20 且数字改白色，名称/职业阵营/战力整体微调到 left=100；LSP 0 Error，官方构建成功。
- 2026-07-01：优化阵型页勇者列表卡片规整度：头像增加统一底框，品质图标固定在头像右上，星级徽章固定在头像底部，名称/职业阵营/战力统一左对齐到同一信息列，出战状态标签保持右侧独立显示；LSP 0 Error，官方构建成功。
- 2026-07-01：按 Inspector 同步阵型页勇者卡片 6 个控件：头像改为 80×90 并绝对定位到 left=7/top=10，品质图标改 32×32 并移动到 left=58/top=6，名称/职业阵营/战力文本移动到 Inspector 坐标，星级徽章内部高度改 34 并偏移 left=-105/top=-18；LSP 0 Error，官方构建成功。
- 2026-06-30：修正勇者卡片星级展示为 `星级.png` 图标 + 数字文本（即 1 星也显示数字 1），不再用多个星级图标重复表示；LSP 0 Error，官方构建成功。
- 2026-06-30：勇者卡片改为图片化品质/星级展示：品质映射到 `image/品质/_D.png`、`_C.png`、`_B.png`、`_A.png`、`_S.png`、`_SS.png`、`_L.png`，星级使用 `image/品质/星级.png` 按星级数量重复显示；默认勇者创建星级统一为 1 星，品质归一化上限扩到 7 档；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 调整阵型页勇者卡片内部结构：删除文字信息包装 Panel，将名称、品质星级、职业阵营、战力 Label 上提到卡片父级；同步头像 left=-2/top=-18 与品质星级 left=5/top=-1 的视觉偏移；LSP 服务不可用，官方构建成功。
- 2026-06-30：将主界面顶部资源栏抽为 `CreateTopResourceRow`，保留 `id="顶级"`，并通过 `FormationScene` 的 `createTopResourceRow` 回调在阵型页同样显示该顶部 HUD；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 给主界面顶部 HUD 第一行 Panel 增加 `id="顶级"`，用于后续 Inspector 定位；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页 17 个控件：总战力移动到 left=425/top=119；阵容 TAB 容器移动到 left=34/top=124；内容父级改为 width=678、left=16/top=170/right=26/bottom=327；底部按钮组移动到 left=25/top=1113；智能推荐移到 left=530/top=1070；全锁按钮移到 left=575/top=81；返回按钮移到底部 left=1/top=1183；勇者列表宽度改 307；9 个勇者卡片宽度改为 95%；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页 7 个控件：阵容 TAB 容器缩到 373 宽并移到 left=33/top=196；标题移到 left=19/top=66；总战力改宽 272 并移到 right/top 区；全锁按钮与智能推荐移到底部区域；删除底部操作外层透明 Panel，将提示文本和按钮组直接挂到 `background` 下并保持按钮组视觉位置；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页背景父子结构：`CreateBackground` 增加 `id="background"`，背景位置改为 left=-1/top=-1/right=1/bottom=1，并将“勇者编队”标题、顶部“锁定”按钮、“总战力”和“智能推荐”四个顶部控件移动到 `background` 节点下；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页返回按钮与背景底板：返回按钮移动到 left=2/top=2；删除 `CreateBackground` 中的 `_0002_底板.png` 子 Panel，仅保留页面背景图；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 继续整理编队页顶部结构：删除标题行和总战力行两个包装 Panel，将返回按钮、标题、锁定按钮、总战力、智能推荐直接上提到根节点；标题移动到 left=293/top=60，标签页容器移动到 left=25/top=201，并给“阵容1”按钮添加 left=1/top=-1 偏移；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页顶部与站位/操作布局：删除顶部包装 Panel 并将其 3 个子节点上提到根节点；标题行视觉位置同步到 x=15,y=99；站位九宫格容器改为 width=91.8%、left=15、top=-1；站位操作区状态文字绝对定位到 left=-1/top=56，按钮行移动到 left=0/top=130；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页底板和底部操作区：内容底板 `image/_0002_底板.png` 改为 721×1115、top=61、zIndex=1、backgroundFit=none；底部操作父级移到 left=14/right=-13/bottom=-17 并移除 padding；提示文本改棕色并下移，按钮组调整为 height=51、left=18、top=73；LSP 服务不可连接，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页内容底板资源：`FormationScene` 背景子面板改用 `image/_0002_底板.png`，背景色透明、边框宽度清零、圆角清零；LSP 服务不可连接，官方构建成功。
- 2026-06-30：出战位从 6 个扩展到 9 个：存档默认勇者补齐到 9 名，阵容槽位扩展为前/中/后三排 3×3；编队界面压缩站位卡尺寸显示 9 宫格；战斗场景读取当前激活阵容的出战槽位生成我方单位，并按相同槽位在右侧镜像生成敌方单位，生命/攻击按勇者战力换算；LSP 0 Error，官方构建成功。
- 2026-06-30：整理勇者编队页面显示：站位格不再显示“前排/后排”字样，已上阵站位显示勇者名和战力；勇者列表卡片增高并压缩图标/状态栏，文字拆成姓名、品质星级、职业阵营、战力四行，设置 flexShrink/flexBasis/overflow 避免超出父节点；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页底部按钮组为 95.2% 宽、66 高并统一四按钮顶端对齐；同时将 6 个站位格合并到同一父级 Panel 下，使用统一 105×138 规格和绝对坐标排成 3×2 阵列；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 将编队页底部“一键上阵、一键清空、保存阵容、推荐开关”四个按钮合并到同一父级 Panel，并同步试调后的绝对位置与推荐开关尺寸；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页 9 个控件布局：顶部栏高度缩为 150，返回按钮透明化并改为 164×58 cover，底部操作区缩为 196，并将一键上阵/一键清空/保存阵容/推荐开关按 Inspector 绝对位置落位；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 同步编队页 24 个控件布局：顶部/底部背景透明化、背景图不透明、返回按钮改用 `BT-返回.png`、内容区下移、站位标签删除、站位格固定尺寸、底部按钮偏移同步；LSP 0 Error，官方构建成功。
- 2026-06-30：按 Inspector 修改编队页背景层：背景资源改为 `image/page_background.png`，同步 `backgroundColor={0,0,0,255}`、`opacity=0.56`、`zIndex=0`；LSP 0 Error，官方构建成功。
- 2026-06-30：编队上阵/替换完成后自动清除当前选择，避免选中的勇者或站位在下一次点击中继续生效导致误操作；LSP 0 Error，官方构建成功。
- 2026-06-30：新增独立勇者 NPC 上阵编队系统页面：扩展默认勇者与 3 套阵容存档，接入主界面“阵型”入口，支持总战力、排序、6 格站位、上阵/替换/下阵、锁定、一键上阵/清空、保存、推荐开关与羁绊展示；LSP 0 Error，官方构建成功。
- 2026-06-30：自动战斗寻敌策略从优先同行调整为优先同列：先在同一 `gridX` 内选择最近敌方，同列没有敌方时再回退到全局最近敌方；LSP 服务不可用，官方构建成功。
- 2026-06-30：自动战斗寻敌策略调整为优先同行：先在同一 `gridY` 内选择最近敌方，同行没有敌方时再回退到全局最近敌方；LSP 0 Error，官方构建成功。
- 2026-06-30：战斗单位接入完整状态动画：待机循环 01-04，移动循环 06-09，攻击播放 10-14 后回到待机；敌方使用水平反转绘制并保留红色 tint；LSP 0 Error，官方构建成功。
- 2026-06-30：敌方移动动作与勇者保持一致，敌方移动时同样按 8 FPS 循环播放 `image/npcClip/1/06.png` 到 `09.png`，红色 tint 保留；LSP 0 Error，官方构建成功。
- 2026-06-30：战斗勇者移动时接入移动序列帧，移动开始切到 `image/npcClip/1/06.png`，移动中按 8 FPS 循环 06-09，移动结束恢复 `01.png`；LSP 0 Error，官方构建成功。
- 2026-06-30：按需求隐藏战斗网格显示层，将 `GridBattleScene` 的 `gridLayer.visible` 改为 `false`；战斗单位与自动战斗逻辑保留；LSP 0 Error，官方构建成功。
- 2026-06-29：战斗网格下移并放大：`GRID_TOP=360`、`CELL_SIZE=32`、`GRID_LEFT=40`，网格重新显示；战斗单位从圆形色块改为已有 `image/npcClip/1/01.png` 模型图，敌方使用红色 tint 区分；LSP 0 Error，官方构建成功。
- 2026-06-29：按 Inspector 修改战斗布局：网格显示层 `top=600` 且 `visible=false`，自动战斗说明面板调整为 `left=37,right=27,bottom=832`；LSP 0 Error，官方构建成功。
- 2026-06-29：按 Inspector 修改战斗场景背景 Panel：背景改为 `image/BattleRes/1.png`，同步 `borderRadius=0`、`zIndex=0`；LSP 0 Error，官方构建成功。
- 2026-06-29：敌方接入与勇者相同的自动战斗逻辑，双方单位都会自动寻找最近敌对单位、按格靠近，并在敌方位于身前 1 格时攻击；LSP 0 Error，官方构建成功。
- 2026-06-29：将网格战斗改为 20×20 自动战斗：移除勇者手动点击/方向控制，勇者自动寻找最近敌方、按格靠近，敌方在身前 1 格时攻击并扣血；LSP 0 Error，官方构建成功。
- 2026-06-29：新增 30×30 网格战斗场景原型 `scripts/Battle/GridBattleScene.lua`，支持单位占格、点击空格移动、越界/占用校验、调试方向按钮和主界面“秘境挑战”入口；LSP 0 Error，官方构建成功。
- 2026-06-29：统一勇者1待机/移动/攻击显示高度，攻击动作使用 360×240 承载框避免 300×200 攻击帧在 `contain` 缩放下人物变小；LSP 0 Error，官方构建成功。
- 2026-06-29：接入勇者1动作序列帧资源：待机 01-04、移动 06-09、攻击 10-14；主界面森林关卡区展示勇者1，点击勇者循环动作，挑战/成长徽章分别触发攻击/移动；LSP 服务不可用，官方构建成功。
- 2026-06-27：落实 Inspector 主界面布局修改：放大四个功能入口到 160×160、调整收益条/领取按钮/离线收益文案位置尺寸、补回秘境挑战文字、章节标题条改用 `P-标题-上.png`；LSP 0 Error，构建成功。
- 2026-06-27：落实 Inspector 主界面修改：删除顶部功能图标文字、删除勇者/福利/召唤/宝物文字、移动秘境挑战按钮；LSP 0 Error，构建成功。
- 2026-06-27：落实 Inspector 底部导航修改：隐藏文字标签、放大导航图标到 96×96、调整底部导航项布局；LSP 0 Error，构建成功。
- 2026-06-27：按新上传资源更新主界面，从整屏参考图切换为分层图片资源 + Yoga UI 叠加；LSP 0 Error，构建成功。
- 2026-06-27：接入登录读档、离线收益结算、存档更新和跳转主界面流程；新增参考图风格主界面；LSP 0 Error，构建成功。
- 2026-06-27：实现 720×1280 竖屏 Yoga UI 登录主界面，使用 `image/login_background.png` 背景和中央“登录”按钮；构建成功。
- 2026-06-27：初始化项目记忆，记录竖屏离线挂机游戏定位与存档硬性规则。
