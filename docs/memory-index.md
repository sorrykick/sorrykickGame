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

- `scripts/main.lua`：Yoga UI 入口，包含登录界面、读档/存档更新、离线收益结算、游戏主界面，并接入秘境战斗场景切换、勇者编队页面、背包页面、勇者养成页面、勇者技能培养页面和英雄图鉴页面切换；主界面勇者序列帧默认使用 `image/npcClip/0001/`。
- `scripts/Formation/FormationScene.lua`：独立勇者 NPC 上阵编队页面，包含三套阵容 TAB、实时总战力、勇者列表排序、9 格三排站位、上阵/替换/下阵、单格锁定、全阵容锁定、一键上阵、一键清空、保存阵容、推荐开关与羁绊展示。
- `scripts/Hero/HeroGrowthScene.lua`：独立勇者养成页面，使用与背包/阵型一致的 Yoga UI 棕色/米黄风格，聚焦勇者列表选择、等级提升、升星和属性展示；右侧详情区展示勇者概览、扩展属性（生命/攻击/防御/移动/暴击/抗暴/增伤/减伤/暴伤）、升级和升星，不再放置技能培养入口或技能学习/升级明细；勇者列表只在页面打开时创建/重置，选择勇者和养成操作只局部替换右侧详情区并更新左侧卡片选中态/等级/战力/星级文本，避免滚动列表焦点被刷新。
- `scripts/Hero/HeroSkillScene.lua`：独立勇者技能培养页面，复用顶部 HUD 与项目棕色/米黄风格，由主界面底部“技能”导航入口进入，支持选择勇者、查看技能槽、按 NPC 配置顺序学习技能、查看技能详情并升级已学习技能；学习消耗蓝钻，升级消耗金币，变更后通过 `SaveManager.MarkFieldsDirty()` + `SaveGameSnapshot()` 保存 `heroes` 与资源字段；技能等级存储在 `hero.skillLevels`。
- `scripts/Battle/GridBattleScene.lua`：20×20 网格自动战斗，管理格子、单位占位、双方自动寻敌、战斗 HUD 和返回主界面；背景资源为 `image/BattleRes/1.png`；战斗网格逻辑保留但显示层已隐藏；战斗单位读取 NPC 配置的扩展属性、主动技能、被动技能与 `ai` 行为配置，按目标优先级、移动策略、技能策略和低血量反应执行自动行动；技能支持单体、十字、直线、3×3、全屏等范围，基础接入攻击、治疗、增益、控制、护盾、减速、眩晕、流血/中毒/灼烧持续伤害，被动支持命中、受击、移动、击杀、施放技能和周期触发；伤害公式使用攻击、防御、暴击、抗暴、增伤、减伤、暴伤等扩展属性；勇者和敌方都会按状态播放待机 01-04、移动 06-09、攻击 10-14 序列帧，敌方水平反转并保留红色 tint。
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
- 创建参考图风格的游戏主界面，并已从临时整屏参考图升级为分层图片资源 + Yoga UI 叠加：`main_bg_blur.png`、`stage_forest_bg.png`、资源图标、顶部功能图标、挑战徽章、收益条、秘境按钮、功能按钮、底部导航等均已接入；顶部 HUD 的 `time` 按 24 小时制显示当前时间，`coinValue`/`diamondValue`/`crystalValue` 绑定玩家金币、蓝钻、白钻并在数据变化、页面切换或页面内部刷新后同步更新；顶部“设置”按钮临时接入清档功能，点击后删除云存档所有 key 并回到登录界面重新进游戏；“秘境挑战”按钮已接入秘境挑战界面，顶部和底部背景与背包页一致：根节点使用 `image/page_background.png`，顶部复用主界面/背包页同款时间、金币、蓝钻、白钻 HUD，底部返回按钮使用 `image/BT-返回.png`，左侧展示当前章节关卡列表和首通掉落，右侧使用与阵型页一致的 3×3 九宫格站位展示选中关卡敌方阵型，并显示关卡总战力、首通奖励或已通关扫荡奖励。
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
- 已新增 `scripts/Inventory/InventoryScene.lua`，实现与阵型页一致的 Yoga UI 棕色/米黄风格背包系统：分类 TAB、5 列物品格、详情面板、使用/整理/扩充/关闭按钮；主界面底部“背包”入口已接入；存档新增 `inventory` 字段并纳入增量 dirty 上传，默认 36 格和 6 个示例物品；小袋金币可使用并同时保存 `coin` 与 `inventory`。最近按 Inspector 同步背包布局：背景显式 720×1280，页面标题改为“背包”且容量文本上移；物品列表删除“物品列表”标题，内容父级 `backBag` 调整为 `left=13/top=122/right=29/height=994`，列表面板调整到 `left=2/top=5/height=69.6%` 且圆角清零，分类 TAB 调整到 `left=-3/top=2`，ScrollView 为 `left=2/top=-44/flexBasis=684`，滚动内容容器为 `top=74`；详情底板调整为 `left=-5/top=710/height=25.6%/backgroundColor={255,255,255,0}` 且圆角清零，空详情状态文本为 `left=292/top=-23`，选中详情标题、图标、名称、品质、数量、状态、描述框重新排布，选中详情状态文本调整为 `left=415/top=23`；底部操作按钮组调整为 `left=49/top=1120/width=87.1%`，整理/扩充按钮分别定位到 `left=240/top=3` 与 `left=478/top=2`。
- 勇者序列帧已接入主界面森林关卡区，默认使用 `assets/image/npcClip/0001/` 做 UI 序列帧动画：主界面 `Hanginglist` 最多显示 5 个玩家已拥有勇者，拥有不足 5 个时只显示实际拥有数量；每个显示位使用对应勇者 `clipDir` 的 06-09 移动帧做原地移动动作，每 3-5 秒在候选充足时替换其中一个当前显示位；左侧挑战徽章仍可触发攻击，右侧成长徽章触发移动。
- 已新增 `scripts/UI/NormalizedSprite.lua`，按每张 `npcClip` 帧图的透明像素包围盒做归一化缩放/居中，已接入主界面 `Hanginglist`、阵型页勇者卡/站位预览、战斗页单位精灵，解决同界面不同勇者或不同动作因画布留白不同导致视觉大小不一致；当前已增加缺失 NPC 序列帧兜底，主界面、编队页、战斗页和 `NormalizedSprite` 在 `image/npcClip/0171/01.png` 等帧资源不存在时会回退到 `image/npcClip/0001/`，并使用 `cache:Exists()` 做无报错存在性检查。
- NPC/勇者数据已从 `docs/setting/npcdata.json` 全量同步到运行配置：`assets/Config/npc.json` 保留 112 个 NPC 的扩展 `stats`（生命、攻击、防御、移动、暴击、抗暴、增伤、减伤、暴伤）、`activeSkill`、`passiveSkills`、`ai`、字母品质、阵营、职业、故事等完整信息，并补充运行字段 `qualityRank/power/role/clipDir/Skill`；`assets/Config/skill.json` 生成 560 个技能条目（每个 NPC 1 个主动 + 4 个被动）。`SaveSchema` 登录规范化会按新 NPC 配置刷新旧存档英雄的静态信息，保留等级/星级/战力等成长数据；阵型、图鉴、养成页通过 `Config.QualityUtil` 统一处理 D/C/B/A/S/SS/L 品质。
- 关卡系统已接入 `docs/setting/level_design.json`：配置复制到 `assets/Config/level_design.json`，新增 `LevelManager` 读取 67 个章节/小关/BOSS/敌人配置；存档新增 `stageProgress`，主界面标题和关卡摘要显示当前章节小关，战斗场景按当前小关生成敌方单位并使用 `sceneImage` 切换 `BattleRes` 背景，胜利后推进关卡进度并保存。

- 主界面 `Hanginglist` 点击任一显示勇者会进入勇者养成页；四个圆形入口中的“勇者”入口也会进入默认第一个勇者的养成页；子控件点击使用 `event:StopPropagation()`，避免触发父级 `Hanginglist` 动作切换；主界面底部第 3 个导航已改为“技能”，点击进入独立勇者技能培养页面。
- `scripts/Hero/HeroGrowthScene.lua` 页面使用 `image/page_background.png`、`image/BT-返回.png`、品质/星级图标与 `NormalizedSprite` 展示勇者；左侧滚动列表选择勇者，右侧聚焦等级、星级、战力、扩展属性、升级和升星，不再提供技能培养入口；升级消耗金币并增加等级/战力，升星消耗白钻并提升战力和成长上限；每次变更都标记对应 dirty 字段并上传存档。
- `scripts/Hero/HeroSkillScene.lua` 承接独立技能学习和升级：从主界面底部“技能”导航进入，返回时回主界面，支持按 `npc.Skill` 顺序学习技能、展示已学/未学/未开放技能槽、查看技能类型/触发/目标/效果说明，并将已学技能升级到最高 10 级；学习消耗蓝钻，升级消耗金币，技能等级保存到 `hero.skillLevels`，`SaveSchema` 登录规范化会补齐并裁剪技能等级。
- 勇者养成页和英雄图鉴页的属性面板已扩展为 9 项：生命、攻击、防御、移动、暴击、抗暴、增伤、减伤、暴伤；`GridBattleScene` 已按 `docs/design_doc.md` 的战斗思路接入 NPC 行为 AI 与技能执行，包含目标选择、移动策略、主动技能、被动效果、低 HP 逻辑、Buff/Debuff、护盾、持续伤害和扩展伤害公式。
- LSP 诊断 0 Error，官方构建成功。

## 下一步候选

- 将主界面参考图拆分为正式 UI 资源与可交互模块。
- 完善主界面的背包、阵型、冒险、任务、图鉴等入口。
- 设计玩家数据模型：资源、伙伴成长进度、上次离线时间、收益结算状态。
- 继续完善数据变更保存、收益领取、伙伴成长逻辑。
- 将勇者1动画逻辑抽成可复用伙伴动画组件，并接入伙伴配置与战斗状态。
- 在 `GridBattleScene` 上继续实现寻路、技能范围、敌方 AI、攻击表现、胜负结算和战斗结果存档。

## POST 日志

- 2026-07-06：按 `docs/setting/npcdata.json` 与 `docs/design_doc.md` 更新 NPC 属性、行为 AI 与技能实现：重新同步 `assets/Config/npc.json` 的 112 个 NPC 扩展属性（生命/攻击/防御/移动/暴击/抗暴/增伤/减伤/暴伤）和 `assets/Config/skill.json` 的 560 个技能；勇者养成页与英雄图鉴页属性面板扩展为 9 项；`GridBattleScene` 改为读取 NPC `stats/activeSkill/passiveSkills/ai` 的数据驱动战斗，接入目标优先级、移动策略、技能释放、范围目标、被动触发、低血量反应、Buff/Debuff、护盾、持续伤害和扩展属性伤害公式。LSP 0 Error，官方构建成功。

- 2026-07-06：按需求迁移技能培养入口到主界面：`HeroGrowthScene` 移除“技能培养”面板、`onOpenSkill` 回调和相关技能入口文案，养成页只保留升级、升星和属性展示；主界面底部第 3 个导航改为“技能”，点击调用 `EnterHeroSkillScreen(GetDefaultHeroGrowthHeroId())` 进入独立技能页；`HeroSkillScene` 关闭后返回主界面。LSP 0 Error，官方构建成功。

- 2026-07-06：按 Inspector 运行时预览修改单同步主界面底部导航第 3 个图标：`main.lua` 中底部导航“冒险”图标从 `image/nav_adventure.png` 替换为新生成的 `image/edited_nav_skill_20260706082834.png`，用于显示“技能”文字图标；仅同步目标 Panel 的 `backgroundImage`，未调整父级和无关同级布局。LSP 0 Error，官方构建成功。

- 2026-07-06：按需求将技能学习/升级从勇者养成页拆出：`HeroGrowthScene` 删除直接学习技能与技能槽明细，保留升级、升星、属性展示和“技能培养”入口；新增 `HeroSkillScene` 独立页面，支持选择勇者、按 `npc.Skill` 顺序学习技能、查看技能详情和升级已学技能；`main.lua` 新增 `EnterHeroSkillScreen()` 并从养成页跳转/返回同一勇者；`SaveSchema` 新增并规范化 `hero.skillLevels`，技能学习/升级沿用 dirty 字段保存 `heroes` 与资源变化。LSP 0 Error，官方构建成功。

- 2026-07-06：修复勇者养成页点击勇者后属性展示不完整：`HeroGrowthScene` 新增 `ATTRIBUTE_DEFS`、`GetHeroStats()`、`GetRawStatValue()` 和“具体属性”面板，右侧详情现在显示生命、攻击、防御、移动；同步压缩概览、升级、升星和技能区域高度，确保新增属性面板后仍完整显示。LSP 0 Error，官方构建成功。

- 2026-07-06：按 Inspector 运行时预览修改单同步背包选中详情状态 Label：`InventoryScene:CreateSelectedDetail()` 中 `self.statusText` 位置从 `left=496/top=25` 调整为 `left=415/top=23`。LSP 0 Error，官方构建成功。

- 2026-07-06：按 Inspector 运行时预览修改单同步背包页 4 个指定控件：物品列表 ScrollView 增加 `left=2`；分类 tabs 父级从 `left=0/top=147` 调整为 `left=-3/top=2`；列表面板高度从 `76.8%` 调整为 `69.6%`；详情底板从 `top=771/height=19.5%/backgroundColor={245,228,200,245}` 调整为 `top=710/height=25.6%/backgroundColor={255,255,255,0}`。LSP 0 Error，官方构建成功。

- 2026-07-06：按 Inspector 运行时预览修改单同步背包页 3 个指定控件：`backBag` 从 `top=164/height=951` 调整为 `top=122/height=994`；详情底板从 `top=657/height=31%` 调整为 `top=771/height=19.5%`；物品列表面板从 `left=4/top=-37` 调整为 `left=2/top=5`，并按说明将 tabs 子节点从 `top=-53` 下移 200 像素到 `top=147`。LSP 0 Error，官方构建成功。

- 2026-07-06：按 Inspector 运行时预览修改单同步背包页 2 个指定控件：内容父级 Panel 增加 `id="backBag"`，并从 `left=19/right=23/height=890` 调整为 `left=13/right=29/height=951`；底部操作按钮组从 `left=50/top=1109` 调整为 `left=49/top=1120`。LSP 服务不可连接，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步背包页 3 个指定控件：空详情状态文本位置从 `left=557/top=-18` 改为 `left=292/top=-23`；物品列表 ScrollView 从 `top=-56/flexBasis=644` 改为 `top=-44/flexBasis=684`；滚动内容容器 top 从 -2 改为 74。LSP 服务不可连接，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步背包页 18 个指定控件：背景改为显式 720×1280 且 right=0；标题从“伙伴背包”改为“背包”，容量文本 top 改为 69；物品列表面板 top 改为 -37、圆角清零，删除“物品列表”标题，分类 TAB 设置 `left=0/top=-53`，ScrollView 设置 `top=-56/flexBasis=644`；详情底板改为 `left=-5/top=657/height=31%/borderRadius=0`，选中详情标题、图标、名称、品质、数量、状态和描述框按 Inspector 位置重排；底部操作按钮组改为 `left=50/top=1109/width=87.1%`，整理/扩充按钮同步位置。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步背包空详情区 4 个指定控件：详情底板从 `left=-9/top=715/height=30.7%` 调整为 `left=-8/top=691/height=26.9%`；空详情标题增加 `left=24/top=23`；空状态文本移到 `left=557/top=-18`；空提示文案由“请选择左侧物品”改为“请选择背包物品”。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步背包页 13 个指定控件：`InventoryScene:CreateContent()` 父级位置改为 `left=19/top=164/right=23`；物品列表面板宽度改为 676，滚动网格宽度 94.6% 并偏移 `left=20/top=-2`；详情底板下移放大到 `left=-9/top=715/height=30.7%` 且 `backgroundFit="none"`；选中物品详情标题、图标、图标文字、名称、品质、数量、状态、描述框和底部按钮组同步 Inspector 试调布局。LSP 服务不可连接，官方构建成功。

- 2026-07-05：修复勇者养成页选择勇者或执行升级/升星/学习技能后左侧勇者列表被整页刷新导致焦点丢失的问题：`HeroGrowthScene` 现在只在打开页面或 fallback 时重建根节点，平时通过 `RefreshDetail()` 销毁并重建右侧详情养成区；左侧列表在创建时缓存卡片、等级、战力、星级 Label 引用，局部更新选中态与数值文本；保存成功/失败回调和校验失败状态也只刷新详情区并重绑定顶部资源栏。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步勇者养成页 12 个指定控件：内容区调整为 left=22/top=174/right=20/height=975；英雄概览姓名、职业阵营、星级徽章和等级/战力/技能信息行同步试调宽度与位置；状态文案改为左对齐顶部显示；底部操作父级 Panel 及“升级”“关闭”按钮删除，并将“当前培养”标签保留为根节点独立 Label，位置对齐到 x=25/y=124。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步勇者养成页 2 个指定控件：背景 Panel 显式设置 720×1280、left=1/top=1/right=0/bottom=-252、backgroundFit=none、borderRadius=0；删除顶部“金币/蓝钻/白钻”资源汇总 Label，保留页面标题和返回按钮。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步勇者养成页升级面板 3 个指定控件：升级面板高度从 102 调整为 125 且 padding 调整为 2；升级说明文本高度调整为 50、允许 normal 换行并顶部对齐；升级消耗金币 Label 下移到 top=91。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步勇者养成页 4 个指定控件布局：技能学习面板高度从 218 调整为 285；勇者升星面板高度从 102 调整为 129 且 padding 调整为 2；升星说明文本增高到 60、允许 normal 换行并最多 3 行；升星消耗白钻 Label 下移到 top=99。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 运行时预览修改单同步英雄图鉴页 10 个指定控件布局：左侧品质列表改为顶部 686×49.8% 绝对布局，右侧详情面板改为下方 693×54.1% 绝对布局；英雄概览高度缩为 176，并同步阵营/站位/星级/战力信息行、品质职业 Label 和“已获得”状态 Label 的运行时试调坐标。LSP 0 Error，官方构建成功。

- 2026-07-05：按 `docs/setting/npcdata.json` 全量更新游戏 NPC 信息：重新生成 `assets/Config/npc.json`，保留 112 个 NPC 的基础属性、主动技能、4 个被动技能、AI 行为、低血量逻辑、字母品质、故事、职业、阵营等源数据，并生成 `assets/Config/skill.json` 的 560 个技能条目；新增 `Config.QualityUtil` 统一 D/C/B/A/S/SS/L 品质映射；图鉴页改为展示源属性、真实主动/被动技能、背景与 AI 信息；存档规范化会按新配置刷新旧英雄静态信息并避免同 NPC 重复补齐。LSP 0 Error，官方构建成功。

- 2026-07-05：修复英雄图鉴按品质分页后的显示问题：根据 `npc.json` 实际存在的品质动态生成分页，避免进入不存在的 L/D 空页；品质标题改为与资源图标一致的 D/C/B/A/S/SS/L；同品质英雄数量较多时左侧列表使用 `UI.ScrollView` 滚动展示；详情默认选中当前品质页内第一个英雄，避免左侧品质页与右侧详情不一致。LSP 0 Error，官方构建成功。

- 2026-07-05：按用户要求将英雄图鉴分页改为按品质分组：分页顺序为 L、SS、S、A、B、C、D，每页只显示对应品质英雄，并在页标题显示品质名称和英雄数量；保留此前分页降低 WebGL 资源压力的实现。LSP 0 Error，官方构建成功。

- 2026-07-05：修复图鉴页进入后 WebGL `glGenSamplers` 相关 `Invalid array length` 风险：图鉴列表从一次性渲染 112 个 `NormalizedSprite` 改为分页显示（每页 24 个英雄），列表头像改用普通 `UI.Panel backgroundImage`，仅详情页保留单个 `NormalizedSprite` 大图，降低图片 pattern/sampler 瞬时创建压力。LSP 服务不可连接，官方构建成功。

- 2026-07-05：新增英雄图鉴系统：`scripts/Hero/HeroCodexScene.lua` 展示 `npc.json` 中 112 个英雄，主界面底部“图鉴”入口接入；点击英雄图标查看属性、技能、品质、职业、阵营、站位和战力；获得英雄后图鉴激活，可领取激活蓝钻，升星达到 2/3/4/5/6 星可领取星级蓝钻；`SaveSchema` 新增 `codex` 字段并纳入 dirty 增量上传。LSP 服务不可连接，官方构建成功。

- 2026-07-05：按 Inspector 删除背包页底部操作区“关闭”按钮：仅修改 `InventoryScene:CreateBottomActions()` 中目标按钮，保留使用、整理、扩充按钮和父级布局不变。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 同步阵型页勇者列表卡片状态 Label：`FormationScene:CreateHeroCard()` 中“出战/待机”状态文本 `top` 从 40 调整为 70，仅修改目标 Label。LSP 0 Error，官方构建成功。

- 2026-07-05：按 Inspector 删除秘境挑战底部操作区“关闭”按钮：仅修改 `SecretRealmDialog:CreateFooter()` 中目标按钮，保留左侧提示文本和右侧挑战/扫荡按钮及父级布局不变。LSP 0 Error，官方构建成功。

- 2026-07-05：新增勇者养成界面：`scripts/Hero/HeroGrowthScene.lua` 复用背包/阵型棕色米黄全屏风格，支持勇者列表选择、升级、升星、按配置学习技能；主界面 `Hanginglist` 勇者图与“勇者”圆形入口接入该页面，点击子勇者时阻止事件冒泡避免同时切换动作；`SaveSchema` 新增并规范化 `hero.level`，升级/升星/学习技能分别保存 `heroes` 与资源字段 dirty。LSP 0 Error，官方构建成功。

- 2026-07-05：秘境挑战“关卡阵型信息”改为与阵型页一致的九宫格站位：`SecretRealmDialog` 引入 `NormalizedSprite`，复用 98×104 站位格、前/中/后三排顺序、米黄底板与品质边框，敌方槽位显示敌人名称、归一化头像和战力，空位显示站位标签。LSP 0 Error，官方构建成功。

- 2026-07-04：修复秘境挑战顶部 HUD 缺失：`SecretRealmDialog` 增加 `createTopResourceRow` 与 `onRootChanged` 回调，复用主界面/背包页的顶部时间、金币、蓝钻、白钻资源栏；打开秘境界面和切换关卡刷新时重新 `BindTopResourceLabels()`，保证 `time/coinValue/diamondValue/crystalValue` 正常显示和刷新。LSP 0 Error，官方构建成功。

- 2026-07-04：按背包页统一秘境挑战界面顶部/底部背景：`SecretRealmDialog` 根节点改为 720×1280 全屏页面，使用 `image/page_background.png` 背景；顶部标题和章节信息直接挂在背景上；底部返回按钮使用 `image/BT-返回.png` 并对齐背包页位置，底部关闭/挑战按钮对齐背包页操作区。LSP 0 Error，官方构建成功。

- 2026-07-04：修复 `image/npcClip/0171/01.png` 缺失资源错误：确认 `0171` 来自 `assets/Config/level_design.json` 敌方 `npcId`，但当前 `assets/image/npcClip/` 无对应目录；将主界面、编队页、战斗页和 `LevelManager` 的 NPC 帧/战斗背景存在性检查从可能触发缺失资源日志的 `cache:GetFile()` 改为 `cache:Exists()`，并在 `NormalizedSprite` 增加组件级 NPC 帧兜底，缺失时统一回退到 `image/npcClip/0001/`。LSP 0 Error，官方构建成功。

- 2026-07-04：新增秘境挑战弹窗：`scripts/Level/SecretRealmDialog.lua` 使用 Yoga UI 实现与背包/阵型一致的棕色米黄弹窗；点击主界面“秘境挑战”后打开，左侧展示当前章节全部关卡与首通掉落，右侧展示选中关卡阵型信息、总战力、首通奖励，已通关关卡替换为扫荡掉落奖励；`LevelManager` 新增当前章节关卡列表、通关判断、敌方阵型/战力和奖励展示数据接口。LSP 0 Error，官方构建成功。

- 2026-07-04：主界面 `Hanginglist` 改为最多同时显示 5 个已拥有勇者：预创建 5 个显示槽位，从 `SaveManager.GetSaveData().heroes` 中随机选取最多 5 个有 `clipDir` 的勇者；拥有不足 5 个时其余槽位保持隐藏；候选充足时每 3-5 秒替换一个当前显示勇者。LSP 0 Error，官方构建成功。

- 2026-07-04：主界面顶部“设置”按钮接入清档功能：`SaveManager.ClearCloudSave()` 使用 `clientCloud:BatchSet():Delete()` 删除 `SaveSchema.GetAllCloudKeys()` 返回的 legacy/meta/字段级全部云存档 key，成功后重置运行时存档状态并返回登录界面，重新登录会创建新存档。LSP 服务不可连接，官方构建成功。

- 2026-07-03：顶部 HUD 动态显示接入：`time` 使用 `os.date("%H:%M")` 按 24 小时制显示当前时间；`coinValue`/`diamondValue`/`crystalValue` 绑定玩家金币、蓝钻、白钻；新增 `UpdateTopResourceLabels()` 和页面根节点重绑定逻辑，主界面、阵型页、背包页在数据变化或页面刷新后同步显示最新资源。LSP 0 Error，官方构建成功。

- 2026-07-03：按 Inspector 给主界面顶部时间 Label 增加 `id="time"`，仅同步该控件 id，不调整父级或同级布局。LSP 0 Error，官方构建成功。

- 2026-07-03：按 Inspector 同步背包页布局：内容父级宽度改为 696；物品列表面板改为上方绝对定位 left=4/top=4、width=693、height=76.8%，移除 padding；详情面板改为底部绝对定位 left=0/top=699、width=693、height=21.4%，使用 `image/IM-说明-底.png`；删除 Header 包装节点并将标题、容量、返回按钮上提到根节点。LSP 0 Error，官方构建成功。

- 2026-07-03：按用户偏好关闭 GitHub 自动同步：已禁用本地 `.git/hooks/post-commit` 自动推送 hook，后续仅在用户明确要求同步 GitHub 或推送时才执行 `git push`；该偏好已记录到项目记忆与随行记忆。

- 2026-07-03：新增背包系统：`SaveSchema` 新增并规范化 `inventory` 存档字段，纳入增量 dirty 上传；新增 `scripts/Inventory/InventoryScene.lua`，复用阵型页背景、棕色侧栏、米黄详情面板和底部操作按钮风格，实现分类 TAB、5 列物品格、详情展示、使用小袋金币、整理、扩充容量；主界面底部“背包”入口已接入。LSP 服务不可连接，官方构建成功。

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
