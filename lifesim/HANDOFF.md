# 游戏计划书｜同频之城｜跨对话交接入口

> **交接快照：2026-11-17（Asia/Singapore）**  
> **最新开发候选：V0.24 草稿 PR #38（骨骼修改器读取时机诊断；未合并、未发布）。Godot 4.7.2 同 SHA 技术测试已证实真实玩家 IK 在 modification_processed 信号内求解成功；人物自然度、实机及 Web 验收仍阻断。**  
> 这是一次有证据的历史快照，不是实时仪表板。每次接班仍需独立查最新 GitHub PR/SHA/CI/Issue。

## 最新一轮：V0.24 澄清原生双腿 IK 测试误判（2026-11-17）

- 已独立确认 [V0.24 草稿 PR #38](https://github.com/ruabie/moci-cet4/pull/38)：head `5ed2a6db7a96c757dc35c2176befa4c22efc259e`；base V0.23 分支；**open / draft / 未合并、未发布**。源代码修改仅限诊断测试与 Actions；**没有替换正式 `CityPlayer` 的 V0.20 动作**。
- 依据 [Godot 4.7 SkeletonModifier3D 官方说明](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html)，修改器实际骨骼姿态应在 `modification_processed` 信号**触发瞬间**读取。原 V0.23 错在等 `process_frame` 后用 `get_bone_global_pose()` 读取，错过求解后姿态。因此此前“原生 IK 根本无法修改真实人物骨骼”的推论被新证据**推翻**；但 V0.23 当时的 CI 失败记录仍然有效，不能删除历史。
- 新增不依赖游戏资产的 `tests/diagnostic_v24_minimal_ik.gd`，以真实官方 Godot 4.7.2 建三根骨骼、1 套原生 TwoBoneIK3D，手动 `Skeleton3D.advance()` 并在 `modification_processed` 内测实际脚踝：修改器触发 **4 次**，原本误差 **0.44m**，信号内 **0m**，信号外恢复 **0.44m**。短流程 [CI #44089439638](https://github.com/ruabie/moci-cet4/actions/runs/44089439638) **success**。
- 又新增 `tests/diagnostic_v24_city_ik.gd`：**真实 LifeSim 原有 CC0 玩家模型**，沿用 V0.23 `TwoBoneIK3D` 左右腿设置及 UAL1 Walk/Jog 片段，在同一个场景里同时比较修改器前、信号内部与信号外三种读数。实际 **10 次修改器信号**；10 组 Walk/Jog 采样，7 个支撑脚样本，其中 **5 个显著改善**；支撑脚目标平均误差从 **0.248m**（动作原始姿态）降为信号内 **0m**，但后续读取仍为 **0.248m**。
- 与 V0.24 同 SHA 的 [完整 PR Godot CI #44089439985](https://github.com/ruabie/moci-cet4/actions/runs/44089439985)、[完整 Push Godot CI #44089426494](https://github.com/ruabie/moci-cet4/actions/runs/44089426494)、[独立最小 IK CI #44089439638](https://github.com/ruabie/moci-cet4/actions/runs/44089439638) 及 [监督 CI #44089439690](https://github.com/ruabie/moci-cet4/actions/runs/44089439690) **均 completed/success**。已下载并独立读取 [同 SHA 的 GitHub 原始运行工件 #14331276265](https://github.com/ruabie/moci-cet4/actions/runs/44089439985/artifacts/14331276265)，确认 `v24_city_ik_metrics.json` 对应上述实测数字。
- 在 V0.24 的完整 CI 中，**保留执行原 V0.23 失败脚本作为明确预期失败的反例对照**，并验证是已知“读取过晚”的失败原因；随后 V0.24 必须通过信号内测量的新独立门槛。没有隐藏旧错误或把反例当作功能成功。
- **已通过的范围：** 官方 Godot 4.7.2 的原生求解器确实在**实际游戏人物骨架**上改变了脚踝位置，确认此前 V0.23 诊断误判。**未通过：** 蒙皮鞋底真实落地、膝盖/摆臂美观、连续实际输入、脚滑、走跑切换、Chrome WebGL、Windows RTX3060 和正式发布；不应从 `0m` 信号内误差推导美术和游戏体验合格。
- 下一独立 V0.25 的首要工作：**在骨骼修改器已经生效的时刻捕获实际蒙皮角色渲染证据**，检验膝盖是否反折、鞋底是否穿地、手臂和重心是否自然，再判断是否值得研究接入正式控制。严格零新增费用，不合并、不发布、不推送仍有自动发布风险的 V0.18 旧分支。

---

## 历史里程碑：V0.23 Godot 原生双腿 IK 的实际失败证据（2026-11-17）

- 新建 [V0.23 草稿 PR #37](https://github.com/ruabie/moci-cet4/pull/37)，base `lifesim-v022-rest-foot-contact-pilot`，最终 head SHA `7dc7d47add4ad62c95d610504725c70523bbbd9b`，**open / draft / merged=false；未发布、未替换正式玩家动作**。
- 根据 [Godot 4.7 的 TwoBoneIK3D 原生接口](https://docs.godotengine.org/en/4.7/classes/class_twoboneik3d.html) 提交 `scripts/native_foot_ik_v23.gd`：显式 `SkeletonProfileHumanoid`/`BoneMap` 人形语义映射，左右腿各一套 `UpperLeg → LowerLeg → Foot`、世界地面射线目标与膝盖 pole；独立测试中根节点固定在 idle 校准值。还提交 `tests/visual_v23_native_ik.gd`、`tools/assemble_v23_native_ik.py` 及 CI 验收步骤。
- **首次失败：** SHA `f55fc47adb9fb86ed14372ab8a855c71bb347637`、[PR CI #44085960249](https://github.com/ruabie/moci-cet4/actions/runs/44085960249)，错误调用了不存在的 `SkeletonProfileHumanoid.get_bone_count()`，应使用官方 `get_bone_size()`；已经修复但没有放宽后续测试门槛。
- **第二轮实证仍失败：** SHA `7dc7d47add4ad62c95d610504725c70523bbbd9b`；[PR CI #44086627399](https://github.com/ruabie/moci-cet4/actions/runs/44086627399)、[Push CI #44086618495](https://github.com/ruabie/moci-cet4/actions/runs/44086618495) **均 completed/failure，失败于新原生 IK 验收**。此前 Godot 导入、经济/存档、V0.19–V0.22 动作截图测试均通过，不能以这些旧项通过代替新项。
- 实际下载并审查 [该 SHA 失败工件 #14329447830](https://github.com/ruabie/moci-cet4/actions/runs/44086627399/artifacts/14329447830)：`v23_native_ik_metrics.json`、真实 Godot **Walk/Jog 各 8 张 PNG**、完整运行日志。成功创建了标准人形映射 **20 根骨骼**和两套 IK 目标；真实脚踝目标误差的 **12 次支撑脚采样中改善 0 次**，平均误差 **求解前 0.249m、求解后仍 0.249m**。**这是信号外的错误测量时机造成的假阴性**，不能证明 IK 求解器本身没有工作；V0.24 同一模型的新测试已证明信号内真实脚踝被求解到目标。保留旧 CI 测试失败这一事实，但废弃当时的错误归因。
- 固定预览角色根节点 `-0.276m`，记录的根节点波动为 0 是**预览脚本设定**，并不证明实际游玩中身体自然平稳。截图仍显示手臂不自然、跑步腾空、街道重复低精度；真实鞋底蒙皮接触、连续操作视频、Chrome 和 RTX3060 性能均未验收。
- **历史判定：V0.23 原始测量门槛 FAIL，人物视觉门槛 FAIL；V0.24 已纠正原始门槛的测量方法，并确认 IK 求解生效。** 本轮最多两次有界修复已用完；保留草稿 PR 和失败证据，**不合并、不发布、不把测试模块接入 CityPlayer**。
- **下一独立 V0.24 应先做根因诊断**，用最小 Godot Skeleton3D 测试 `SkeletonModifier3D.modification_processed` 是否触发，检查两条 `TwoBoneIK3D` 的 target/pole NodePath、`active`、动画更新时序以及 `Skeleton3D.advance()`，以实际脚踝骨骼前后坐标验证求解器是否运行；没有实证前禁止声称 IK 已落地。后续才是足部踩地、膝盖形态、动作混合与真实设备连续录屏。
- **安全与交付边界不变：** V0.18 旧分支 push-to-main 的自动发布风险未解除，禁止直接推送该旧分支；主分支 HTML S0–S5 仍待验收，Chrome 实际试玩和 Windows RTX3060 FPS 未通过，#15/#18 继续开放。零新增付费服务。

---

## 历史里程碑：V0.22 静止姿态旋转轴及鞋底接地（2026-11-17）

**候选：** [V0.22 草稿 PR #36](https://github.com/ruabie/moci-cet4/pull/36)，head `dd1203044e911707f3f91581dac023c3bf9dd68c`，base V0.21 分支，**open / draft / merged=false**；零新增费用、无自动合并、无公开发布、未修改游戏正式玩家动作。

- 按 [Godot 4 官方骨架重定向说明](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html)，Bone Pose 包括 Bone Rest，不可因骨骼名称一致就直接复用旋转。因此新增 `animation_retarget_v22.gd`：从源骨骼静止旋转提取动作增量，再通过源/目标**全局骨骼静止轴**变换动作增量，最后应用到目标骨骼静止姿态；与 V0.21 源脚本分离，不影响现有游戏。
- 新增 `foot_contact_v22.gd`：读取实际玩家模型鞋部网格**静止状态包围盒**和 Foot.L/Foot.R 脚踝位置，射线碰撞实际街道路面，**仅在 QA 预览**调整渲染角色根高度。此法每个采样只保证最低脚踝对应的鞋底代理落地，**不等于真实鞋面蒙皮接触检测或独立两脚 IK**。
- 第一轮提交 `5624c2f6611297ae769954aa5b14863bacc11401` 完成六张真实 Godot 渲染 PNG 和地面代理指标：脚踝与鞋底静止偏移约 0.0234m；根节点需下降约 0.21–0.51m。**人工画质复核：** V0.21 明显悬空已得到视觉改善，但手臂和跑步姿态不自然，不能交付。
- 第二次有界修正提交 `dd1203044e911707f3f91581dac023c3bf9dd68c`：在拍照前冻结动画采样姿态，新增 `visual_v22_sequence.gd`，分别对真实 CC0 Walk 与 Jog 动作片段生成 18 帧采样 PNG、GIF、逐帧对照和精确 JSON。动作片段采样不等于真实设备中连续输入或 60FPS 游戏录屏。
- **实际相位高度指标：** Walk 片段长 1.333s，18 帧根节点高度修正范围 **0.067m**、相邻采样最大跳变 **0.031m**；Jog 片段长 0.933s，18 帧范围 **0.122m**、相邻采样最大跳变 **0.095m**。走跑切换预期还存在约 0.25m 的根节点高度差。这些数字暴露出新的严重动画质量风险，不能只凭鞋底代理高度归零来声称已消除脚滑。
- 对**准确 SHA**的 [PR Godot CI #44083259830](https://github.com/ruabie/moci-cet4/actions/runs/44083259830)、[Push CI #44083250185](https://github.com/ruabie/moci-cet4/actions/runs/44083250185) 和 [监工 CI #44083259710](https://github.com/ruabie/moci-cet4/actions/runs/44083259710) 均为 `completed/success`；已下载并查看 [36 帧真实动作/指标工件 #14327039681](https://github.com/ruabie/moci-cet4/actions/runs/44083250185/artifacts/14327039681)。
- **判定：技术 QA 通过；视觉/足部 IK/实际游玩验收失败。** 双脚尚未独立锁定地面、跑步手臂像出拳、身体上下跳动过大；禁止进入正式玩家控制。两次有界尝试已经结束，下一独立工作包应使用 Godot `SkeletonProfileHumanoid` / BoneMap 正规骨骼静止轴映射、真正的足部 IK、平滑 root motion、连续真实输入视频和 Windows RTX3060 实机测评。
- **保持原有风险边界：** V0.18 旧分支仍有 push-to-main 自动发布工作流，禁止对旧分支直接 push；当前高版本草稿无自动发布；main 的 `lifesim/index.html` 仍不存在，HTML S0–S5 `pending`，Chrome 浏览器试玩与 Windows FPS 均未验收，#15/#18 仍开放。

---

## 历史里程碑：V0.21 有版权证据的真实动画库接入与失败可复现（2026-11-17）

- [草稿 PR #35](https://github.com/ruabie/moci-cet4/pull/35)，head `753f2dd577c161df486960d7a892c332b4184d15`，base `lifesim-v020-grounded-gait-review`。**open / draft / merged=false，原 V0.20 正式操控与经济/存档实现没有替换。**
- 真实接入 Quaternius 的 **Universal Animation Library 1**，许可 CC0-1.0（[原作者官方下载页](https://quaternius.itch.io/universal-animation-library)）。使用只读、固定 Git commit 的可再分发镜像 `Barbatos6669/elderforge@bb2ce469f0ab2ccfc487faef55550ba07fae2483`：`UAL1_Standard.glb`，Git blob SHA `473e59080288428d0b6da826ba19324d07b191f0`，SHA256 `69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997`，7,618,436 字节，43 个动作片段。
- 已提交 `tools/acquire_ual_v21.py`（构建时获取，验证文件 SHA/尺寸/真实动画/骨骼并生成 manifest）、`scripts/animation_retarget_v21.gd`（骨骼语义映射和 BoneRest 增量旋转）、`tests/visual_v21_retarget.gd`（在现有玩家模型上真实渲染待机/走/跑六帧）与 CI 工作流及来源证据。**运行时不请求网络**；但纯 git checkout 仍需先执行构建时下载脚本才能导入此资源，不能称已离线自带资源。
- **第一轮失败证据：** 初版 `801e3f9f...` [CI #44078406302](https://github.com/ruabie/moci-cet4/actions/runs/44078406302) 失败于骨骼匹配仅 1 根，因动作库采用 `pelvis / spine_01 / thigh_l` 命名，现有人物是 `Hips / Abdomen / UpperLeg.L`。不是引擎/经济测试故障。
- **第二轮真实结果：** 添加明确语义映射；[PR Godot CI #44079086818](https://github.com/ruabie/moci-cet4/actions/runs/44079086818) 和 [Push Godot CI #44079074579](https://github.com/ruabie/moci-cet4/actions/runs/44079074579) 在同一 SHA 全部 **success**。读取 [真实运行图/日志工件 #14326357015](https://github.com/ruabie/moci-cet4/actions/runs/44079074579/artifacts/14326357015)：语义骨骼匹配 49 根；`Idle / Walk / Jog_Fwd` 每项映射 47 条旋转轨道，玩家左大腿姿态变化依次为 0.044 / 0.407 / 0.759 rad。
- **独立视觉判定：FAILED。** 六张实际截图均显示人物脚底远离地面/悬空，手臂姿态不自然，跑动像在空中跳跃。轨道驱动成功**不等于动作、脚部贴地、角色方向、真实操作手感合格**。两次有界尝试结束，QA 试验脚本不能并入正式操控。Issues #15/#18 保持开放。
- **下一步单一最优先任务：** 独立 V0.22 项目重校准 source/target BoneRest、人物 root height 与鞋底地面位置，使用 Godot 官方 `SkeletonProfileHumanoid`、BoneMap / 适当足部 IK 或可量化接触约束；先消除 V0.21 悬空/畸形，再以完整实际录屏复验。**禁止第三轮只调摆臂数值的无界返工**。
- 主分支 `lifesim/index.html` 仍 404、S0–S5 均 `pending`；Windows RTX3060 FPS、Chrome WebGL 真实输入和发布验收仍未完成。V0.18 上游工作流仍可能在推送时向 main 自动发布；**不要向旧分支 push**，在其独立禁用自动发布后才考虑继续。

---

## 历史里程碑：V0.20 动态步态与脚部贴地（2026-11-17）

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

1. **V0.25 真实蒙皮视觉审核**：V0.24 已在实际 CC0 模型上证明 TwoBoneIK3D 信号内脚踝误差从 24.8cm 降为 0；下一独立小版本必须捕获求解后真正用于绘制的蒙皮网格，逐帧审查足部接地、膝盖形态、手臂、角色重心，不能凭骨骼目标为 0 就宣布美术合格。
2. 只有视觉通过后才进行实际输入驱动的连续走跑停/转身、双脚锁定地面、渲染时序和真实 Windows 录屏；禁止直接覆盖生产 CityPlayer。
3. 不向 V0.18 旧分支直接 push，它仍含自动发布到 main 的工作流。高版本草稿只交付构建工件，不发布。
4. 保持主分支 HTML S0–S5 独立验收，并实测 Chrome WebGL/指针锁/商店与存档、Windows RTX3060 的 1080p FPS 和输入延迟。

## 5. 下次新聊天直接复制

> 继续《游戏计划书／同频之城》项目。先读取 GitHub `ruabie/moci-cet4` 的 `lifesim/HANDOFF.md`、`HANDOFF_STATE.json`、`HANDOFF_PROTOCOL.md` 并独立核实最新 PR/SHA/CI/Issue。当前最新 V0.24 草稿 PR #38，head `5ed2a6db7a96c757dc35c2176befa4c22efc259e`，引擎 CI 与独立最小 IK 测试成功；**更正 V0.23 的错误归因**：真实游戏人物的原生 IK 在 `modification_processed` 信号内将支撑脚平均目标误差从 24.8cm 降至 0，旧脚本信号外读数仍为 24.8cm。历史失败对照已保留，不要误称旧版测试通过。下一独立 V0.25 先获取原生 IK 生效后的蒙皮截图/连续证据，人工核查脚底与膝盖、手臂/跑步自然度；在美术/真实设备验收通过前绝不接入正式操控或发布。保持零费用、不自动合并或发布、不推送旧 V0.18 危险分支。结束时更新两份交接文件及真实提交 SHA。

## 6. 交接文件和监工

- 人类入口：[`lifesim/HANDOFF.md`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF.md)
- 机器快照：[`lifesim/HANDOFF_STATE.json`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF_STATE.json)
- 约束协议：[`lifesim/HANDOFF_PROTOCOL.md`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF_PROTOCOL.md)

已有「游戏计划书监工」每 6 小时的任务仅负责**只读核对和必要报告**，不会自动修改 main 的交接、合并 PR 或称自己完成了真实编码。接班必须再读仓库，按证据更新。
