# 游戏计划书｜同频之城｜跨对话交接入口

> **交接快照：2026-11-17（Asia/Singapore）**  
> **总体状态：开发候选 V0.18；未正式交付，视觉/真实试玩验收未完成。**  
> 本页是历史快照，不是持续自动更新的实时状态。开始任何新一轮开发前，必须依照下方链接重新查询 GitHub。

## 1. 项目定位

- 游戏：**同频之城（LifeSim）**，现实世界时间同步的 3D 人生模拟。玩家可游览街区、进入公寓及商店、兼职打工、收支消费、发展生活活动、保存状态。
- 技术方向：**Godot 4.7.2** 的 3D 开发候选；另保留最初 HTML/WebGL 可玩入口的独立监督契约。
- 仓库：[`ruabie/moci-cet4`](https://github.com/ruabie/moci-cet4)；项目目录：`lifesim/`。
- 不改动 `wordride/`、`kotoba/` 等其他项目；不新增任何付费 API/服务器/订阅/Runner，不自动合并、自动发布或替用户花钱。修复候选最多两轮，须保留失败证据。

## 2. 主分支与开发候选必须区分

| 位置 | 本次核实的真实状态 | 能否当成交付 |
| --- | --- | --- |
| `main:lifesim/project.json` | `sourceState=not_connected`；HTML 专用 S0–S5 均 `pending` | **不能** |
| `main:lifesim/index.html` | GitHub 读取为 404 | **不能** |
| [V0.18 草稿 PR #32](https://github.com/ruabie/moci-cet4/pull/32) | `open`、`draft`、`merged=false`；`lifesim-v018-humanoid-art-pass`，head `c288af7b7cd75fd8baa9d3369610d9f8b178b0dc` | **开发候选** |
| PR #32 的 base | `lifesim-v017-refrigeration-art`（V0.17），属于逐级叠加的开发分支链 | **不是主分支版本** |

V0.18 对玩家及六名 NPC 的外观/骨骼兼容性进行了候选改动；仓库确有 `lifesim/godot/project.godot` 与运行 QA 脚本。**这只证实代码及候选描述存在，不意味着游戏操作手感、最终画面或 Windows 性能已通过。**

相关工作：
- [Issue #10：HTML 首版及监工契约](https://github.com/ruabie/moci-cet4/issues/10) — `open`
- [Issue #12：Godot G0 验证](https://github.com/ruabie/moci-cet4/issues/12) — `open`，历史引擎 CI 有通过记录
- [Issue #18：美术与体验阻断](https://github.com/ruabie/moci-cet4/issues/18) — `open`，不可仅凭旧版引擎 CI 关闭
- [V0.17 草稿 PR #31](https://github.com/ruabie/moci-cet4/pull/31) — V0.18 的上游候选

## 3. 接下来应执行的工作（先核实，后修改）

1. **查证最新版本**：重新读取 `main` 的 `project.json`、最新 LifeSim PR、Issue #18、候选分支提交 SHA、CI 运行记录；不能假设 V0.18 永远最新。
2. **视觉优先**：查看当前实际截图/录屏，核验人物步态、骨骼变形、面向、场景比例、建筑拼接感、店铺/公寓是否空洞、相机/建筑遮挡；没有视觉证据就标记未验收。
3. **功能复测**：Godot 4.7.2 引擎中验证现实时间、角色移动、进入室内、工作/薪资一次性结算、余额/购买、存档恢复、错误存档。
4. **浏览器与实机**：验证 Web 预览当前链接是否真正可玩；另行在 Windows RTX 3060 设备测 FPS、延迟、摄像机和交互。Linux CI 的软件渲染不能替代实机。
5. **按证据推进**：独立草稿 PR、保留回归证据；QA 未完成时不得宣称视觉达标或已正式发布。

## 4. 新对话如何继续

将下方内容发给新 ChatGPT 对话即可（不需要复制整个旧对话）：

> 继续“游戏计划书 / 同频之城”项目。请用 GitHub 连接器读取 `ruabie/moci-cet4` 的 `lifesim/HANDOFF.md`、`lifesim/HANDOFF_STATE.json`、`lifesim/HANDOFF_PROTOCOL.md`；然后独立核对 `lifesim/project.json`、最新 LifeSim PR/Issue/CI 和候选分支真实源码。先更新交接状态，再继续下一项尚未通过的开发/验收任务。保持零新增费用、独立草稿 PR、不自动合并或发布，不用其他项目替代，不将代码存在等同于可玩或美术验收通过。

## 5. 每次交接必须同步

- **人类可读摘要**：本文件 `HANDOFF.md`
- **机器可读快照**：`HANDOFF_STATE.json`
- **更新及验收规则**：`HANDOFF_PROTOCOL.md`

任何对话在完成重要 PR、CI、Bug 修复、里程碑验收或准备切换窗口时，都先依据最新 GitHub 证据更新本页和 JSON，再在最终回复中列出更新的文件链接、提交 SHA、已验证/未验证项。不得覆盖未核实的历史状态。

> **监工集成已确认（2026-11-17）**：原有「游戏计划书监工」每 6 小时任务已增加交接快照的**只读核对**。发现重大变化时会连同 PR/SHA、已验收与阻断项报告；遵守原任务的静默通知规则。**不会自动改写主分支交接文件、合并草稿 PR 或宣称已自主编码。**
