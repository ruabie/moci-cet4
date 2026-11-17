# 游戏计划书｜同频之城｜跨对话交接入口

> **交接快照：2026-11-17（Asia/Singapore）**  
> **最新开发候选：V0.19 草稿 PR #33（未合并、未交付）；上游 V0.18 的 Godot CI 通过，但实际试玩与美术验收未通过。**  
> 这是一次有证据的历史快照，不是实时仪表板。每次接班仍需独立查最新 GitHub PR/SHA/CI/Issue。

## 1. 项目与边界

- 游戏：**同频之城（LifeSim）**，本地真实时间同步的 3D 人生模拟，探索街区、公寓、便利店/咖啡馆生活与工作、收入消费和版本化存档。
- Godot 4.7.2 工程作为独立草稿分支链开发，`main:lifesim/project.json` 的 HTML/WebGL S0–S5 监督契约**独立存在**，不得用 Godot QA 冒充其通过。
- 仓库：[`ruabie/moci-cet4`](https://github.com/ruabie/moci-cet4)，目录：`lifesim/`。
- **零新增费用；不改动其他项目；不自动合并、发布或消费；最多两次有界返工，保留失败日志与截图。**

## 2. 已直接核实的当前仓库状态

| 对象 | 最新核实的状态与证据 | 验收判断 |
| --- | --- | --- |
| `main:lifesim/project.json` | `sourceState=not_connected`；HTML S0–S5 全部 `pending` | **未通过** |
| `main:lifesim/index.html` | GitHub Contents 404 | **不存在** |
| `main:lifesim/play-v18/` | `index.html` 与 `build-info.json` 确认存在；源 SHA 为 `c288af7b7cd75fd8baa9d3369610d9f8b178b0dc` | **仅证明隔离 Web 构建文件存在，Chrome 真正试玩未验证** |
| [上游 V0.18 草稿 PR #32](https://github.com/ruabie/moci-cet4/pull/32) | `open`/`draft`/`merged=false`，head `c288af7b7cd75fd8baa9d3369610d9f8b178b0dc` | 引擎功能候选；非主分支 |
| [V0.18 Godot CI](https://github.com/ruabie/moci-cet4/actions/runs/43909344105) | `success`，对应准确 SHA；导入、逻辑 QA、固定机位人物截图任务均完成 | **引擎 CI 通过，不代表实际动作/画质/Windows 通过** |
| [最新 V0.19 草稿 PR #33](https://github.com/ruabie/moci-cet4/pull/33) | `open`/`draft`/`merged=false`；head `31ba2aafb97784ac25133fe8df4bac85fa2b3fea`；base = V0.18 分支 | **新开发候选；未验收** |
| [V0.19 Godot CI #44071855686](https://github.com/ruabie/moci-cet4/actions/runs/44071855686) | 本轮最后查询时 `in_progress`；下次须重新读取结果与产物 | **不提前宣称成功** |

GitHub 开放阻断项：[Issue #10 浏览器原型](https://github.com/ruabie/moci-cet4/issues/10)、[Issue #12 Godot 实机验证](https://github.com/ruabie/moci-cet4/issues/12)、[Issue #15 美术重构](https://github.com/ruabie/moci-cet4/issues/15)、[Issue #18 画质/HUD/动作/FPS](https://github.com/ruabie/moci-cet4/issues/18)。除非证据变化，不要关闭。

## 3. 本轮执行：V0.19 动态人物证据与发布安全

已下载并**人工查看** [V0.18 run #43909344105 的截图工件](https://github.com/ruabie/moci-cet4/actions/runs/43909344105/artifacts/14246962551)：玩家仍有明显低多边形块面，街道在构图中占比过大、远景重复；六位居民合照中人物尺寸过小，难以确认关节细节。三张固定静态 PNG 不能证明行走、转身、停止或脚滑质量。美术与真实试玩状态继续 **blocked/pending**。

新创建的 V0.19 草稿 PR #33 在不修改游戏经济/世界源码的前提下，提交以下代码：
- `lifesim/godot/tests/visual_v19_motion.gd`：真实 `Input.action_press` 驱动两种走路相位、转身和停止；断言位移、骨骼姿态角变化、面向转动、停止速度与动画权重。
- `.github/workflows/lifesim-godot.yml`：在 Linux Mesa/Xvfb 的真实 Godot 渲染中生成四张 `v19_*.png` 与 `v19_motion_metrics.json` 并作为运行工件上传；CI 不通过则不得标记完成。
- `.github/workflows/lifesim-web.yml`：移除 `publish-isolated-path` 自动向 `main` 执行 `git push` 的任务，保留**只构建并上传人工审核工件**的流程。

**重要安全边界：** 上述自动发布修复目前只在 PR #33 的开发分支。V0.18 旧分支仍带有“推送即向 main 自动部署隔离目录”的旧工作流；在对旧分支继续 push 之前必须单独禁用或移除该任务，不能将 PR #33 的存在误当成全局已修复。历史 `play-v18` 文件已在 main，但**未独立验证浏览器实际可玩**。

本轮 PR #33 的机器测试状态、四张截图内容、Windows FPS 和输入手感需要下一轮重新查证。零新增费用，未执行自动合并/发布。

## 4. 下一步最优先任务

1. 重新读取 PR #33 head SHA 与 [Godot CI #44071855686](https://github.com/ruabie/moci-cet4/actions/runs/44071855686)；若失败最多两轮修复，并保留失败原始记录；若成功下载四张动态截图和 JSON，**人工判读走路方向、膝盖弯曲、步态、转身、脚滑/穿模**。
2. 确保所有后续开发分支均禁止未审核自动发布；尤其不要直接向 V0.18 旧分支 push 而触发旧发布任务。
3. 保持 `lifesim/index.html` 的浏览器 S0–S5 契约独立；核实现有隔离 Web 构建在真实 Chrome 的 WebGL/指针锁/输入/保存和加载表现。
4. 用 Windows RTX 3060 真机测 1080p 帧率、输入延迟、碰撞/相机、进出商店；达不到可用性与画质标准则继续阻断最终交付。

## 5. 下次新聊天直接复制

> 继续《游戏计划书／同频之城》开发。用 GitHub 连接器读取 `ruabie/moci-cet4` 的 `lifesim/HANDOFF.md`、`HANDOFF_STATE.json`、`HANDOFF_PROTOCOL.md`，重新核实最新 PR/SHA/Issue/CI 和主分支 HTML S0–S5（不将交接快照误当实时）。当前需优先复核草稿 PR #33 的 V0.19 真实输入驱动动作截图与 Godot 引擎运行证据；若未过关，保留失败证据，有界修复。严格禁止自动合并/自动发布/新增付费/修改其他项目；结束时同步两份交接记录与提交 SHA。

## 6. 交接文件和监工

- 人类入口：[`lifesim/HANDOFF.md`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF.md)
- 机器快照：[`lifesim/HANDOFF_STATE.json`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF_STATE.json)
- 约束协议：[`lifesim/HANDOFF_PROTOCOL.md`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF_PROTOCOL.md)

已有「游戏计划书监工」每 6 小时的任务仅负责**只读核对和必要报告**，不会自动修改 main 的交接、合并 PR 或称自己完成了真实编码。接班必须再读仓库，按证据更新。
