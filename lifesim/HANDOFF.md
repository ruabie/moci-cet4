# 游戏计划书｜同频之城｜跨对话交接入口

> **交接快照：2026-11-17（Asia/Singapore）**  
> **最新开发候选：V0.20 草稿 PR #34（第二轮有界步态修正；未合并、未交付）。V0.19 PR #33 是技术基线，不能以旧版 CI 代替最新候选验收。**  
> 这是一次有证据的历史快照，不是实时仪表板。每次接班仍需独立查最新 GitHub PR/SHA/CI/Issue。

## 最新一轮：V0.20 动态步态与脚部贴地（2026-11-17）

- 新建 [V0.20 草稿 PR #34](https://github.com/ruabie/moci-cet4/pull/34)，base 为 V0.19 PR #33；最新提交 `93fb2112d3a8a1c47014789f632dbf83893848db`。**未合并、未发布**。
- 更新 `scripts/player.gd`：以实际位移推进 2.30m/步态周期（旧版约 4.25m），改进交替膝盖屈伸和手臂摆动，增加小幅受限的角色视觉根节点高度补偿（不会修改玩家物理碰撞体）。
- 新增 `tests/visual_v20_gait.gd` 与 `tools/assemble_gait_v20.py`，Godot CI 采集真实物理运行的 20 张截图、动态 GIF、逐帧图和数值报告。必须记录采样时真正经过的物理帧数，不能把 Mesa 延迟造成的跳帧误称为正常实时视频。
- **第一轮实证：** V0.20 初版 SHA `07bf475e78f9efbbebdac620cc10da4972e55fd9`，PR CI [#44074055179](https://github.com/ruabie/moci-cet4/actions/runs/44074055179) 为 `success`；已下载并查看 [20 帧证据工件 #14323738171](https://github.com/ruabie/moci-cet4/actions/runs/44074055179/artifacts/14323738171)。发现脚踝基准相对闲置姿势最大抬升约 **0.110m**，视觉补偿未生效（0m）；截图横跨 **11.882m** 运动，采样间隔不严格。**技术 QA 通过，但画质/脚部贴地验收不通过。**
- **第二轮有界修正已验证：** SHA `93fb2112d3a8a1c47014789f632dbf83893848db`；[PR CI #44074870163](https://github.com/ruabie/moci-cet4/actions/runs/44074870163) 与 [Push CI #44074860982](https://github.com/ruabie/moci-cet4/actions/runs/44074860982) **均完成 success**。已下载并检查 [本提交 20 帧截图/GIF/JSON 工件 #14323684340](https://github.com/ruabie/moci-cet4/actions/runs/44074870163/artifacts/14323684340)：脚踝骨骼相对静止的高度代理最大值从约 **11cm 降至 7cm**；视觉根节点下移最多 **5.5cm**。每帧原拟相隔 3 物理 tick，实际最大间隔 **8 tick**，GIF 已基于真实 tick 间距编码。**引擎/玩法自动化测试 PASS，美术与真实步态未通过**：人物依旧僵硬，缺专业接触 IK；街景过于重复，无法凭 Mesa 截帧断言无脚滑、流畅或 Windows FPS 合格。
- 本轮两次有界尝试已经结束，技术证明已归档，但主观人物美术/运动质量仍**阻断**。下一独立里程碑需可验证许可证的完整走/跑/转向动画、骨骼重定向、足部接触约束及连续实机录屏；不继续无限微调现有摆腿公式。
- V0.18 旧分支仍带自动将 Web 构建 push 到 main 的工作流；仅 PR #33、#34 的候选分支移除此任务。**不要推送旧 V0.18 分支或自动发布**。主分支 HTML S0–S5、Chrome 真实试玩及 Windows RTX3060 FPS 均未通过。

---

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
| [V0.19 Godot CI #44071855686](https://github.com/ruabie/moci-cet4/actions/runs/44071855686) | 对应 V0.19 SHA 的 PR/Push 两次引擎 CI 均 `success`；四张动态 PNG 与 JSON 已实际下载复核 | **技术输入/动画运转通过；美术仍不达标** |

GitHub 开放阻断项：[Issue #10 浏览器原型](https://github.com/ruabie/moci-cet4/issues/10)、[Issue #12 Godot 实机验证](https://github.com/ruabie/moci-cet4/issues/12)、[Issue #15 美术重构](https://github.com/ruabie/moci-cet4/issues/15)、[Issue #18 画质/HUD/动作/FPS](https://github.com/ruabie/moci-cet4/issues/18)。除非证据变化，不要关闭。

## 3. 本轮执行：V0.19 动态人物证据与发布安全

已下载并**人工查看** [V0.18 run #43909344105 的截图工件](https://github.com/ruabie/moci-cet4/actions/runs/43909344105/artifacts/14246962551)：玩家仍有明显低多边形块面，街道在构图中占比过大、远景重复；六位居民合照中人物尺寸过小，难以确认关节细节。三张固定静态 PNG 不能证明行走、转身、停止或脚滑质量。美术与真实试玩状态继续 **blocked/pending**。

新创建的 V0.19 草稿 PR #33 在不修改游戏经济/世界源码的前提下，提交以下代码：
- `lifesim/godot/tests/visual_v19_motion.gd`：真实 `Input.action_press` 驱动两种走路相位、转身和停止；断言位移、骨骼姿态角变化、面向转动、停止速度与动画权重。
- `.github/workflows/lifesim-godot.yml`：在 Linux Mesa/Xvfb 的真实 Godot 渲染中生成四张 `v19_*.png` 与 `v19_motion_metrics.json` 并作为运行工件上传；CI 不通过则不得标记完成。
- `.github/workflows/lifesim-web.yml`：移除 `publish-isolated-path` 自动向 `main` 执行 `git push` 的任务，保留**只构建并上传人工审核工件**的流程。

**重要安全边界：** 上述自动发布修复目前只在 PR #33 的开发分支。V0.18 旧分支仍带有“推送即向 main 自动部署隔离目录”的旧工作流；在对旧分支继续 push 之前必须单独禁用或移除该任务，不能将 PR #33 的存在误当成全局已修复。历史 `play-v18` 文件已在 main，但**未独立验证浏览器实际可玩**。

本轮 V0.19 的 [PR CI #44071855686](https://github.com/ruabie/moci-cet4/actions/runs/44071855686) 及 [Push CI #44071812324](https://github.com/ruabie/moci-cet4/actions/runs/44071812324) 已针对**同一 SHA**验证成功。已下载并打开 [四张真实输入动作截图与指标工件 #14323676026](https://github.com/ruabie/moci-cet4/actions/runs/44071855686/artifacts/14323676026)：走路位移 **3.737 m**、左右相位的左大腿姿态角变化 **0.548 rad**、转向 **1.527 rad**、停止速度及动画权重均为 **0**。这证明脚本驱动角色产生了物理位移与骨骼/转向变化；但视觉复核显示角色仍较僵硬、手臂与腿部动作幅度不自然，脚部触地感存疑，远景建筑重复、空旷路面占比仍高。四张 PNG 无法证明连续脚滑或镜头无穿模。美术审美与真实试玩继续 **blocked/unverified**；零新增费用，未自动合并/发布。

## 4. 下一步最优先任务

1. **启动下一独立视觉里程碑（非 V0.20 第三轮盲改）**：寻找并核实可用于当前 Quaternius 人物骨骼的 CC0 或明确可再分发专业行走/跑步/转身动画，做重定向与足部接触约束，提交前后完整录屏和走/停/转实机证据。V0.20 当前仅技术 QA 通过。
2. 确保所有后续开发分支均禁止未审核自动发布；尤其不要直接向 V0.18 旧分支 push 而触发旧发布任务。
3. 保持 `lifesim/index.html` 的浏览器 S0–S5 契约独立；核实现有隔离 Web 构建在真实 Chrome 的 WebGL/指针锁/输入/保存和加载表现。
4. 用 Windows RTX 3060 真机测 1080p 帧率、输入延迟、碰撞/相机、进出商店；达不到可用性与画质标准则继续阻断最终交付。

## 5. 下次新聊天直接复制

> 继续《游戏计划书／同频之城》开发。用 GitHub 连接器读取 `ruabie/moci-cet4` 的 `lifesim/HANDOFF.md`、`HANDOFF_STATE.json`、`HANDOFF_PROTOCOL.md`，重新核实最新 PR/SHA/Issue/CI 和主分支 HTML S0–S5（不将交接快照误当实时）。当前最新草稿 PR #34（V0.20，head 93fb2112）已有同 SHA Godot CI 技术通过，但两轮受限修复后美术和步态仍未验收；继续下一独立动作资源重定向/足部 IK 里程碑，并取得视频和 Windows 实机证据。严格禁止自动合并/自动发布/新增付费/修改其他项目；结束时同步两份交接记录与提交 SHA。

## 6. 交接文件和监工

- 人类入口：[`lifesim/HANDOFF.md`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF.md)
- 机器快照：[`lifesim/HANDOFF_STATE.json`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF_STATE.json)
- 约束协议：[`lifesim/HANDOFF_PROTOCOL.md`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF_PROTOCOL.md)

已有「游戏计划书监工」每 6 小时的任务仅负责**只读核对和必要报告**，不会自动修改 main 的交接、合并 PR 或称自己完成了真实编码。接班必须再读仓库，按证据更新。
