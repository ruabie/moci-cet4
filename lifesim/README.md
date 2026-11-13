# 游戏计划书 / LifeSim — 现实时间人生模拟

**状态：已建立独立监工与验收规范；当前尚未将可玩的游戏源码接入 GitHub。**

这个项目不是 WordRide 的分支玩法。前期使用现有已连接 GitHub 仓库内的 `lifesim/` 独立目录进行质量监控，以后可迁移至专用仓库。

## 游戏定位

3D 人生模拟：玩家能在街道中步行和探索、进入公寓、前往便利店工作、赚取和花费货币、保存角色状态。世界日期与时间基于设备的真实本地时间。

**关键设计取舍：** 同步现实时间 ≠ 要求玩家真的工作八个小时才能领取一次游戏内报酬。首版用较短、能操作的便利店工作任务，结算仍必须一致、可追踪、不能重复领薪。没有服务器就不承诺能防止玩家修改系统时间。

## 监督范围

| ID | 验收阶段 | 核心拒收条件 |
|---|---|---|
| S0 | 源码与真实 WebGL 首屏 | 不是实际可玩页面；依赖外部在线 3D 库；浏览器黑屏 |
| S1 | 现实时间 | 与设备本地时钟差距超过 90 秒；切后台/刷新不恢复 |
| S2 | 3D 移动和镜头 | 玩家不能移动、严重穿模、道路/建筑遮挡镜头 |
| S3 | 公寓、便利店打工 | 场景交互无效、工作任务无法结算、重复领薪 |
| S4 | 货币与存档 | 负余额支付、刷新丢失经济状态、存档损坏崩溃 |
| S5 | 视觉质量和体验 | 只有源码没有截图、未检查输入延迟、将 GitHub 软件渲染 FPS 当成实际性能 |

每个里程碑只在经过证据审核后，才能将 `project.json` 中的状态由 `pending` 改为 `done`。

## 现在有什么

- `project.json` — 项目目标、里程碑、禁止自动发布和免费运行约束。
- `qa/check_contract.py` — 审核是否找到**真实源码**，缺源时只输出 `waiting_for_source`，不冒充游戏通过。
- `qa/tests/` — 离线安全和状态测试。
- `qa/tests-browser/` — 用 Chromium 在桌面 1280×720、移动 390×844 验证实际游戏。
- `qa/score.cjs` — 区分 `blocked`、`technical_partial_milestones_pending`、`technical_pass_visual_pending`。
- `foreman/foreman.py` — 从 WordRide 安全机制迁移的独立协调器；只允许修改 `lifesim/index.html`，最多两轮修改，默认不运行模型、不推送、不合并。
- `.github/workflows/lifesim-supervisor.yml` — 对 `lifesim/` 的 PR 或主分支改动自动检查并记录报告。

## 接入先前开发的游戏原型

1. 将先前“游戏计划书”对话中完成的**实际**浏览器源码放到 `lifesim/index.html`；不要上传空白占位页充数。
2. 首版可以是单 HTML 自包含 WebGL 游戏，不应为显示 3D 而强制加载在线 CDN。
3. 将 `project.json` 的 `sourceState` 改为 `connected`。**不能擅自将未验收的里程碑设为 done。**
4. 页面提供 `data-testid="world-canvas"` 的真实 WebGL canvas、`data-testid="start-game"` 的启动按钮；在 `?qa=1` 时提供只读 `window.__LIFESIM_QA__.getState()`。返回字段详见 `qa/README.md`。
5. 提交后 GitHub Actions 自动跑真实游戏测试、存档检查并留截图。发生功能性失败时必须阻断交付；未完成事项保留 `pending`，不能宣称“全功能通过”。

当前未接入游戏源码，这是监工必须报告的**阻断项**，不是测试系统失效。

## 质量与安全

- 测试通过不代表画面审美已经满足用户；需要独立检查实际截图与可操作录屏。
- GitHub 的 SwiftShader 软件渲染 FPS 不代表用户 RTX 3060 或手机 FPS。
- 不启动付费 API，不创建公网可执行外部 PR 的本机自托管 Runner。
- 默认最多两轮修复，禁止自动合并主分支，提交只生成草稿 PR。
- 任何阶段缺少证据，都不能把项目标为交付完成。
