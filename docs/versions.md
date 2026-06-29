# Versions

| 日期 | 版本/阶段 | 说明 |
|---|---|---|
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
