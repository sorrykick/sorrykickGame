# Versions

| 日期 | 版本/阶段 | 说明 |
|---|---|---|
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
