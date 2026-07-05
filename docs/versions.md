# Versions

| 日期 | 版本/阶段 | 说明 |
|---|---|---|
| 2026-07-05 | hero-codex-quality-display-fix | 修复英雄图鉴按品质分页后的显示问题：根据 `npc.json` 实际存在品质动态生成分页，避免 L/D 空页；品质标题改为 D/C/B/A/S/SS/L；同品质英雄过多时左侧列表改为可滚动；详情默认选中当前品质页第一个英雄；LSP 0 Error，官方构建成功。 |
| 2026-07-05 | hero-codex-quality-pages | 英雄图鉴分页改为按品质分组：使用 L、SS、S、A、B、C、D 的品质顺序翻页，每页只显示对应品质英雄，页标题显示品质名和数量；保留此前分页和普通图标渲染以降低 WebGL 资源压力；LSP 0 Error，官方构建成功。 |
| 2026-07-05 | hero-codex-webgl-resource-fix | 修复图鉴页 WebGL `glGenSamplers` 相关资源异常风险：英雄列表由一次性渲染 112 个 `NormalizedSprite` 改为分页显示（每页 24 个），列表头像改用普通 `UI.Panel backgroundImage`，仅右侧详情保留单个归一化大图，降低进入页面时的图片 pattern/sampler 瞬时创建压力；LSP 服务不可连接，官方构建成功。 |
| 2026-07-05 | hero-codex-system | 新增英雄图鉴系统：`HeroCodexScene` 展示 `npc.json` 中 112 个英雄，底部“图鉴”入口接入；点击英雄图标可查看属性、技能、品质、职业、阵营、站位、战力；获得英雄后可领取图鉴激活蓝钻，升星达到 2/3/4/5/6 星可领取星级蓝钻；`SaveSchema` 新增 `codex` 字段并纳入 dirty 增量上传；LSP 服务不可连接，官方构建成功。 |
| 2026-07-05 | inventory-remove-footer-close | 按 Inspector 删除背包页底部操作区的“关闭”按钮，仅保留使用、整理、扩充按钮和父级布局；LSP 0 Error，官方构建成功。 |
| 2026-07-05 | formation-hero-status-label-top | 按 Inspector 将阵型页勇者列表卡片中的出战/待机状态 Label 下移：`top` 从 40 调整为 70，仅修改目标 Label；LSP 0 Error，官方构建成功。 |
| 2026-07-05 | secret-realm-remove-footer-close | 按 Inspector 删除秘境挑战底部操作区的“关闭”按钮，仅保留提示文本和挑战/扫荡按钮；LSP 0 Error，官方构建成功。 |
| 2026-07-05 | hero-growth-scene | 新增勇者养成界面：主界面 `Hanginglist` 勇者图和“勇者”圆形入口可进入 `HeroGrowthScene`，页面复用背包/阵型风格，支持勇者列表选择、等级提升、升星和按配置学习技能；升级消耗金币，升星消耗白钻，学习技能消耗蓝钻，并通过 dirty 字段保存 `heroes/coin/crystal/diamond`；`SaveSchema` 新增并规范化 `hero.level`；LSP 0 Error，官方构建成功。 |
| 2026-07-05 | secret-realm-formation-board-sync | 秘境挑战界面的“关卡阵型信息”改为与阵型页一致的 3×3 九宫格站位样式：复用 98×104 站位格、前/中/后三排顺序、米黄底板和品质边框，并使用 `NormalizedSprite` 展示敌方头像与战力；LSP 0 Error，官方构建成功。 |
| 2026-07-04 | secret-realm-top-hud | 秘境挑战界面接入与主界面/背包页一致的顶部 HUD：通过 `createTopResourceRow` 复用时间、金币、蓝钻、白钻资源栏，打开秘境和切换关卡刷新时重新绑定 `time/coinValue/diamondValue/crystalValue`；LSP 0 Error，官方构建成功。 |
| 2026-07-04 | secret-realm-inventory-background-sync | 秘境挑战界面顶部和底部背景改为与背包页一致：根节点使用 `image/page_background.png` 全屏背景，标题/章节信息直接挂在顶部背景上，底部返回按钮使用 `image/BT-返回.png`，底部操作区对齐背包页按钮位置；LSP 0 Error，官方构建成功。 |
| 2026-07-04 | npc-clip-missing-resource-fallback | 修复关卡配置引用未打包 NPC 序列帧时报错：NPC 帧路径存在性检查统一改为 `cache:Exists()`，缺失时回退到 `image/npcClip/0001`；主界面、编队页、战斗页和 `NormalizedSprite` 均增加兜底，避免 `image/npcClip/0171/01.png` 等缺失资源错误；LSP 0 Error，官方构建成功。 |
| 2026-07-04 | secret-realm-challenge-dialog | 新增秘境挑战弹窗：点击主界面“秘境挑战”后打开背包/阵型同风格棕色米黄弹窗，左侧展示当前章节关卡列表和首通掉落，右侧展示关卡阵型、总战力、首通奖励，已通关关卡显示扫荡掉落；LSP 0 Error，官方构建成功。 |
| 2026-07-04 | hanginglist-max-five-owned-heroes | 主界面 `Hanginglist` 最多同时显示 5 个已拥有勇者；拥有不足 5 个时只显示实际拥有数量，其余槽位隐藏；候选充足时保留 3-5 秒随机替换显示位逻辑；LSP 0 Error，官方构建成功。 |
| 2026-07-04 | settings-clear-cloud-save | 主界面顶部“设置”按钮临时接入清档：删除当前玩家云存档 legacy/meta/字段级所有 key，成功后回到登录界面，重新登录会创建新存档；LSP 服务不可连接，官方构建成功。 |
| 2026-07-03 | top-hud-dynamic-time-resources | 顶部 HUD 的 `time` 改为 24 小时制当前时间，`coinValue`/`diamondValue`/`crystalValue` 绑定玩家金币、蓝钻、白钻；新增统一刷新和页面重建后重新绑定逻辑，资源变化后同步更新显示；LSP 0 Error，官方构建成功。 |
| 2026-07-03 | home-time-label-inspector-id | 按 Inspector 给主界面顶部时间 Label 增加 `id="time"`，便于后续运行时定位和动态更新时间；LSP 0 Error，官方构建成功。 |
| 2026-07-03 | inventory-inspector-layout-sync | 按 Inspector 同步背包页 4 个控件：内容父级宽度改 696，物品列表改为上方 693×76.8% 绝对布局，详情面板改到底部并使用 `image/IM-说明-底.png`，删除 Header 包装节点并将其子项上提到根节点；LSP 0 Error，官方构建成功。 |
| 2026-07-03 | github-sync-manual-only | 按用户偏好禁用本地 `post-commit` 自动推送 hook；后续只在用户明确要求同步 GitHub 时执行 `git push`，本地提交不自动上传。 |
| 2026-07-03 | inventory-system-yoga-formation-style | 新增背包系统：存档新增 `inventory` 并纳入增量 dirty；新增 `InventoryScene`，复用阵型页棕色/米黄 Yoga UI 风格，实现分类、物品格、详情、使用小袋金币、整理和扩充；主界面底部“背包”入口接入；LSP 服务不可连接，官方构建成功。 |
| 2026-07-03 | github-origin-sorrykick-sync-success | 修正 remote 为 `https://github.com/sorrykick/sorrykickGame.git`，确认 PAT 对该仓库有 push 权限，使用本地 hook 的 `x-access-token` Basic header 自动推送；`master` 已成功推送到 `origin/master`。 |
| 2026-07-03 | github-origin-auto-sync | 配置 `origin=https://github.com/HYsorrykick/sorrykickGame.git`，设置本地 Git HTTP/HTTPS 代理，并新增本地 `post-commit` hook 使每次提交后自动尝试推送；当前 GitHub 返回 401，需配置凭据后推送成功。 |
| 2026-07-03 | project-title-sorrykickGame1 | 修改 `.project/project.json` 的 `taptap_publish.title` 为 `sorrykickGame1`；JSON 校验通过，官方构建成功。 |
| 2026-07-03 | login-delta-cloud-save-flow | 按 `docs/login.md` 优化登录/云存档流程：新增字段级 dirty、字段校验和、本地版本首次变更递增、增量上传、下载/上传 3 次重试、上传失败强制退出、旧整包存档兼容迁移；编队/战斗保存显式标记 dirty，离线收益按钮移除固定发放占位值；LSP 服务不可连接，官方构建成功。 |
| 2026-07-02 | normalized-hero-sprite-size | 新增 `scripts/UI/NormalizedSprite.lua`，按 `npcClip` 帧图透明包围盒归一化绘制尺寸，并接入主界面、阵型页、战斗页，统一同界面勇者/动作视觉大小；LSP 0 Error，官方构建成功。 |
| 2026-07-02 | hanginglist-random-owned-heroes | 主界面 `Hanginglist` 从已拥有 `heroes` 随机选择勇者，按 `clipDir` 播放 06-09 原地移动帧，并每 3-5 秒切换到另一个当前未显示勇者；LSP 0 Error，官方构建成功。 |
| 2026-07-02 | inspector-hanginglist-id-top | 按 Inspector 将勇者容器增加 `id="Hanginglist"`，并将勇者图 `top` 从 36 调整为 0；LSP 0 Error，官方构建成功。 |
| 2026-07-02 | remove-stage-summary-label | 删除主界面 `stageSummaryLabel` 组件，并清理缓存变量、`FindById` 和 `UpdateHomeLabels` 更新逻辑；LSP 0 Error，官方构建成功。 |
| 2026-07-02 | inspector-home-hero-reward-layout | 按 Inspector 同步主界面 4 个控件：收益条上移并清零圆角，勇者容器改为 720×148，勇者图缩小并移动到左侧，删除“勇者1 · 待机”动作文字 Label；LSP 0 Error，官方构建成功。 |
| 2026-07-02 | inspector-home-remove-mode-badges | 按 Inspector 删除主界面森林关卡下方模式徽章横排 Panel（原 `homeScreen` 第 5 个子项）；LSP 服务不可连接，官方构建成功。 |
| 2026-07-02 | resource-preload-default | 排查大量 `<game>/assets/*.png` not found：源资源和 manifest 条目存在，启用 `.project/resources.json` 的 `preload_groups=["default"]`，避免启动阶段 UI/序列帧动态加载时资源尚未下载；LSP 0 Error，官方构建成功。 |
| 2026-07-02 | level-design-integration | 读取 `docs/setting/level_design.json` 接入 67 章关卡配置：新增 `LevelManager`，存档新增 `stageProgress`，主界面显示当前章节/小关，战斗按当前小关生成敌人并胜利推进关卡；LSP 客户端不可用，官方构建成功。 |
| 2026-07-01 | cleanup-unused-old-assets | 删除未调用旧资源：旧 `npcClip/1` 跟踪目录、非下划线品质图标、`BattleRes/2.png` 到 `67.png` 及重复 `docs/data/` 配置副本；官方构建成功。 |
| 2026-07-01 | npcdata-config-integration | 读取 `docs/setting/npcdata.json` 生成 112 条 NPC/勇者配置到 `assets/Config/npc.json`，存档默认勇者改为从配置生成，阵型页和战斗场景改用各 NPC 的 `clipDir` 序列帧；LSP 客户端不可用，官方构建成功。 |
| 2026-07-01 | formation-hero-card-inspector-8-controls | 按 Inspector 同步阵型页勇者卡片 8 个控件：头像扩大并贴左，品质图标移到左上，星级徽章加宽下移，星星图标和数字重新对齐，名称/职业阵营/战力整体微调；LSP 0 Error，官方构建成功。 |
| 2026-07-01 | formation-hero-card-polish | 优化阵型页勇者列表卡片规整度：头像增加统一底框，品质图标固定右上，星级徽章固定底部，名称/职业阵营/战力统一信息列左对齐；LSP 0 Error，官方构建成功。 |
| 2026-07-01 | formation-hero-card-inspector-6-controls | 按 Inspector 同步阵型页勇者卡片 6 个控件：头像放大并绝对定位，品质图标改 32×32，名称/职业阵营/战力文本移动到试调坐标，星级徽章内部高度与偏移同步；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-star-icon-number | 修正勇者卡片星级展示为 `星级.png` 图标 + 数字文本，1 星也显示数字 1，不再用多个星级图标重复表示；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-hero-quality-star-icons | 勇者卡片品质/星级改为图片展示：品质使用 `_D/_C/_B/_A/_S/_SS/_L.png`，星级使用 `星级.png` 按星级数量重复；默认勇者创建星级统一为 1 星，品质归一化上限扩到 7 档；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-hero-card-flatten | 按 Inspector 删除勇者卡片文字信息包装 Panel，将名称、品质星级、职业阵营、战力 Label 上提到卡片父级，并同步头像与品质星级偏移；LSP 服务不可用，官方构建成功。 |
| 2026-06-30 | formation-show-top-hud | 将主界面顶部资源栏抽为 `CreateTopResourceRow`，保留 `id="顶级"`，并在阵型页通过 `FormationScene` 回调复用显示；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | home-top-hud-id | 按 Inspector 给主界面顶部 HUD 第一行 Panel 增加 `id="顶级"`，便于后续运行时定位；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-inspector-17-controls | 按 Inspector 同步编队页 17 个控件：总战力、阵容 TAB、内容区、底部按钮组、智能推荐、全锁、返回按钮重排；勇者列表宽度改 307，9 个勇者卡片宽度改为 95%；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-inspector-7-controls | 按 Inspector 同步编队页 7 个控件：阵容 TAB 容器缩到 373 宽并移到 left=33/top=196；标题、总战力、全锁按钮、智能推荐同步试调坐标；删除底部操作外层透明 Panel，将提示文本和按钮组直接挂到 `background` 下；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-background-parenting | 按 Inspector 同步编队页背景父子结构：`CreateBackground` 增加 `id="background"`，背景位置改为 left=-1/top=-1/right=1/bottom=1，并将标题、顶部锁定按钮、总战力、智能推荐移动到背景节点下；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-inspector-layout | 按 Inspector 同步编队页 24 个控件布局：顶部/底部背景透明化、背景图不透明、返回按钮改用 `BT-返回.png`、内容区下移、站位标签删除、站位格固定尺寸、按钮偏移同步；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-page-background | 按 Inspector 修改编队页背景层：使用 `image/page_background.png`，同步黑色背景、0.56 透明度和 zIndex=0；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-clear-selection-after-assign | 编队上阵/替换完成后自动清除当前选择，避免连续误操作；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | formation-system-page | 新增独立勇者 NPC 上阵编队系统页面：扩展默认勇者与 3 套阵容存档，接入主界面“阵型”入口，支持总战力、排序、6 格站位、上阵/替换/下阵、锁定、一键上阵/清空、保存、推荐开关与羁绊展示；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | battle-target-same-column-first | 更新自动战斗寻敌策略：优先选择同列敌方，同列无目标时再回退到全局最近敌方；LSP 服务不可用，官方构建成功。 |
| 2026-06-30 | battle-target-same-row-first | 更新自动战斗寻敌策略：优先选择同行敌方，同行无目标时再回退到全局最近敌方；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | battle-unit-state-animations | 战斗单位接入待机/移动/攻击三状态序列帧：不移动不攻击时循环 01-04，移动时循环 06-09，攻击时播放 10-14 后回到待机；敌方水平反转并保留红色 tint；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | battle-enemy-move-animation | 敌方和勇者使用同一套移动动作设定，敌方移动时也按 8 FPS 循环播放 06-09 移动序列帧并保留红色 tint；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | battle-hero-move-animation | 战斗勇者移动时播放 06-09 移动序列帧：移动开始切换移动首帧，移动中按 8 FPS 循环，移动结束恢复 01 待机图；LSP 0 Error，官方构建成功。 |
| 2026-06-30 | battle-grid-hidden | 隐藏战斗网格显示层，将 `GridBattleScene` 的 `gridLayer.visible` 改为 `false`；战斗单位贴图、敌方红色 tint 与自动战斗逻辑保留；LSP 0 Error，官方构建成功。 |
| 2026-06-29 | battle-grid-model-units | 战斗网格下移并放大：`GRID_TOP=360`、`CELL_SIZE=32`、`GRID_LEFT=40`，网格重新显示；战斗单位从圆形色块改为已有 `image/npcClip/1/01.png` 模型图，敌方使用红色 tint 区分；LSP 0 Error，官方构建成功。 |
| 2026-06-29 | inspector-battle-layout | 按 Inspector 修改战斗布局：隐藏网格显示层并设置 `top=600`，自动战斗说明面板移动到 `left=37,right=27,bottom=832`；LSP 0 Error，官方构建成功。 |
| 2026-06-29 | inspector-battle-background | 按 Inspector 修改战斗场景背景 Panel：背景资源改为 `image/BattleRes/1.png`，同步 `borderRadius=0`、`zIndex=0`；LSP 0 Error，官方构建成功。 |
| 2026-06-29 | enemy-auto-battle-ai | 敌方接入与勇者相同的自动战斗逻辑：双方单位都会自动寻找最近敌对单位、按格靠近，并在敌方位于身前 1 格时攻击；LSP 0 Error，官方构建成功。 |
| 2026-06-29 | auto-grid-battle-20x20 | 将网格战斗改为 20×20 自动战斗：勇者无需玩家控制，自动寻找最近敌方、按格靠近，只有敌方位于身前 1 格时自动攻击并扣血；LSP 0 Error，官方构建成功。 |
| 2026-06-29 | grid-battle-scene-prototype | 新增 `scripts/Battle/GridBattleScene.lua`：30×30 网格战斗场景原型，单位占 1 格，移动按格子执行，支持点击空格移动、越界/占用校验、方向调试按钮和秘境挑战入口；LSP 0 Error，官方构建成功。 |
| 2026-06-29 | hero1-animation-size-normalization | 统一勇者1待机、移动、攻击动作显示高度；攻击动作使用更宽承载框避免攻击帧因素材宽度不同而视觉变小；LSP 0 Error，官方构建成功。 |
| 2026-06-29 | hero1-ui-frame-animation | 接入 `assets/image/npcClip/1/` 勇者1序列帧动画：待机 01-04、移动 06-09、攻击 10-14；主界面森林关卡区展示勇者1，并通过点击勇者/挑战徽章/成长徽章触发动作；LSP 服务不可用，官方构建成功。 |
| 2026-06-28 | save-manager-modularization | 将登录读档、云同步、运行时副本、基础合法性校验从 `main.lua` 拆分为 `SaveManager` / `SaveSchema` / `SaveValidator` / `RuntimeSave` 模块；LSP 服务不可用，官方构建成功。 |
| 2026-06-27 | inspector-top-home-layout | 落实 Inspector 主界面上半区修改：顶部功能区图标放大到 96×96、删除资源短标签和右上角数字、调整标题条/章节文字/模式行/挑战徽章布局，LSP 0 Error，构建成功。 |
| 2026-06-27 | stage-forest-scroll | 将 `stage_forest_bg.png` 按 1024×309 规格接入两个图层横向无缝滚动，LSP 0 Error，构建成功。 |
| 2026-06-27 | inspector-home-layout | 落实 Inspector 主界面布局修改：放大四个功能入口到 160×160、调整收益条/领取按钮/离线收益文案位置尺寸、补回秘境挑战文字、章节标题条改用 `P-标题-上.png`，LSP 0 Error，构建成功。 |
| 2026-06-27 | inspector-home-icons | 落实 Inspector 主界面修改：删除顶部功能图标文字、删除勇者/福利/召唤/宝物文字、移动秘境挑战按钮，LSP 0 Error，构建成功。 |
| 2026-06-27 | inspector-bottom-nav | 落实 Inspector 底部导航修改：隐藏文字标签、放大导航图标到 96×96、调整底部导航项布局，LSP 0 Error，构建成功。 |
| 2026-06-27 | home-ui-assets | 按新上传资源更新主界面，从整屏参考图切换为分层图片资源 + Yoga UI 叠加，LSP 0 Error，构建成功。 |
| 2026-06-27 | login-save-home | 接入登录读档、离线收益结算、存档更新和跳转主界面流程；新增参考图风格主界面，LSP 0 Error，构建成功。 |
| 2026-06-27 | login-ui | 新增 720×1280 竖屏 Yoga UI 登录主界面，背景图 `image/login_background.png`，中央“登录”按钮，构建成功。 |
| 2026-06-27 | terminology-partner | 将核心表达对象统一为“伙伴”，替代“宠物”术语。 |
| 2026-06-27 | memory-init | 初始化项目记忆，记录 2D 纯竖屏离线挂机游戏定位与存档硬性规则。 |
