# 游戏计划书｜同频之城｜跨对话交接入口

> **最新 V0.39 草稿 [PR #53](https://github.com/ruabie/moci-cet4/pull/53)**，确切 head `0925394389eedacf4c1ce1c028922182ed60e5b1`、base V0.38 #52，open/draft/unmerged/unpublished。2026-11-22（Asia/Singapore）[真实 Godot 摄像机专项 Push #45025977376](https://github.com/ruabie/moci-cet4/actions/runs/45025977376)、[PR #45025983015](https://github.com/ruabie/moci-cet4/actions/runs/45025983015) 均已 `completed/success`。真实场景与真实 `CityPlayer.ThirdPersonCamera` 对店铺后墙发生 **42 次正向避障收缩 / 相机碰撞球与实体墙重叠 0 次**，离墙回到 4.70m。**重大负面视觉发现：相机贴墙退到仅 0.098m，真人物头发几乎遮住整张画面，摄像机可用性 FAIL**。中文 HUD 缺字/原始 CJK 字体缺席、室内粗糙、美术、Web/Windows 均未验收。同 SHA 完整 Godot 引擎 CI #45025983134 最后复核时仍 `in_progress`，不可提前写成完成。main HTML S0–S5 `pending`，只有隔离 V0.18 Web 导出核实存在。
> **交接是 SHA 快照不是实时仪表板；新轮仍需实际读取最新 GitHub PR/CI/源码/Issue。**

## 最新一轮：V0.39 实体后墙摄像机防穿墙与观感审查（2026-11-22）

- **实际新候选：** 从 V0.38 #52 派生 [V0.39 草稿 PR #53](https://github.com/ruabie/moci-cet4/pull/53)，最终确切 head `0925394389eedacf4c1ce1c028922182ed60e5b1`。新增 `tests/visual_v39_real_camera_occlusion.gd`、`tools/audit_v39_real_camera.py`、独立免费 `.github/workflows/lifesim-v039-camera-occlusion-qa.yml`，在**同一个游戏原始主场景、真实北区地块和正式 `CityPlayer` 摄像机**上走 W 进店、以 QA 姿态让镜头明确朝向真实后墙、验证物理防穿墙、改回方向后镜头恢复，S 走出；5 张真实角色第三人称相机视角原始 `1280×720` PNG。只有**镜头角度**由诊断设置，不冒充人手鼠标输入；初始 QA 角色位置后无传送/坐标赋值。
- **先失败、后定位：** 最初 `96ab7b5a...` 在 [专项 Push #45025521030](https://github.com/ruabie/moci-cet4/actions/runs/45025521030)、PR #45025542096 **FAIL**，虽然目标相机位置被原有球体扫掠避障，但旧代码从历史相机位置**插值平滑到目标时没有复测中间位置**，有真实帧与实体墙产生碰撞球重叠。[失败原始工件 #14755194459](https://github.com/ruabie/moci-cet4/actions/runs/45025521030/artifacts/14755194459) 保留。
- **受限修复 1/2 `d091df0a`：** 修改 `scripts/player.gd` 中 `CityPlayer._update_camera`：在原本受保护的目标镜头计算**之后**，再对**实际平滑后的最终位置**沿角色 pivot 执行带半径的碰撞扫掠，必要时留出缓冲并回缩，保证过渡帧不穿墙；没有删场景碰撞，也不修改角色行走物理。该版真实 Godot 已输出 42 次避障、零重叠、5 张 PNG，但 Python 审核因错误要求 `wall_distance_m>0.35` 失败，而真实距离为 **0.3393297m**，属于不恰当的检测下限，不是游戏物理缺陷。该失败保留于 [Push #45025756124](https://github.com/ruabie/moci-cet4/actions/runs/45025756124) / [工件 #14755638448](https://github.com/ruabie/moci-cet4/actions/runs/45025756124/artifacts/14755638448)。
- **受限修复 2/2 `09253943...`：** 仅将上述无关安全的审核下限从 `0.35m` 修正为 `0.20m`；**原有真实墙名、阳性遮挡、镜头必须回缩、碰撞球逐帧 0 重叠、解除遮挡后恢复、5 PNG 渲染检查全部保留**。修复额用尽，不允许在该轮不断盲改。
- **同最终 SHA 真实性能之外的真实渲染技术 PASS：** [Push CI #45025977376](https://github.com/ruabie/moci-cet4/actions/runs/45025977376) 和 [PR CI #45025983015](https://github.com/ruabie/moci-cet4/actions/runs/45025983015) 均 `completed/success`，已下载并人工打开 [原始 Godot 工件 #14756015186](https://github.com/ruabie/moci-cet4/actions/runs/45025977376/artifacts/14756015186)：真实 collider `Solid_rear_retail_wall` 距 pivot **0.3393297m**；不避障目标镜头半径 4.69815m；**42 次**真实避障触发，28 帧监测 **0 次摄像机碰撞球重叠**，最短镜头 pivot 半径 **0.0983215m**；撤开障碍后回复到 **4.696666m**。原 `CityPlayer` 物理 W 键约 **124 帧**进入原店，S 键实际行走退出，仍保持 V0.32 11 地块和 V0.37 实体店铺碰撞。5 张原始 `1280×720` PNG，室内无遮挡 vs 有墙镜头变动像素 **52.4137%**，该数并非美术质量评分。同 SHA 完整引擎 #45025983134 最后复核尚 `in_progress`，必须另查，不能将 focused CI 冒充全部 CI。
- **独立视觉审核强制 FAIL：** 真正贴墙时相机接近 pivot 仅 0.10 米，**原始 PNG 中角色头部和头发巨大遮挡店内视野**；虽物理不穿墙但游戏镜头不能用。打开门口、回到街上时视野正常，关店/直接传送等旁路均未使用。原始 UI 画面里中文有**方块乱码**；仓库树无 `art/fonts/NotoSansCJKsc-Regular.otf` 实体，`main.gd` 只能退回 Linux 系统字体，缺字源头待实际字体资源/授权检查与截图复验。店内陈设仍薄弱，住宅立面暗色与城市整体不一致。没有 V0.39 专用真实鼠标硬件、头部透明处理、鞋底 IK、Windows RTX3060 FPS、Chrome WebGL、工作/购物/存档闭环，也没有发布。
- **下一唯一优先任务：** V0.40 针对**相机回缩小于约 0.7m 时的角色头部遮挡**设计有美术合理性的近景过渡模式（如仅针对本机头发/头部暂时淡出，避免隐藏整个身体或第一人称硬跳），同时保留并重新证明实体球体 0 穿墙；用原视角和真实移动连续截图/视频验收，再对中文字体做独立许可核验与可复现字体打包。技术安全并不等于可用性，不能宣布“已解决镜头体验”。继续零新增费用、不自动合并/发布，不扩大低精度街区，#10/#12/#15/#18 开放，旧 V0.18 Web 自动推送分支禁止操作。

---

## 最新一轮：V0.38 真实游戏人物 WASD 店铺往返（2026-11-22）

- **实际代码：** 从 V0.37 #51 分支建立 [V0.38 草稿 PR #52](https://github.com/ruabie/moci-cet4/pull/52)，最终候选 head `3ebd8acea9616be295cb8ef56ebb2f9f8a73ab86`。仅在 `application/config/v38_real_player_route_qa` 开关开启时，正式 `CityPlayer` 初始生成于现有北区住宅底商门前；常规的保存/初始位置规则不改。新增 `tests/visual_v38_real_cityplayer_route.gd` 通过原始 `Input.parse_input_event(InputEventKey)` 发出物理 W/A/D/S 键，到游戏本来的 `InputMap`、`CityPlayer._physics_process` 和 `move_and_slide`；不再用上轮虚浮的代理，且生成场景后**无角色位置写入/传送**。还增加严格 JSON/原始 PNG 核查脚本 `tools/audit_v38_real_cityplayer.py` 和零费独立 CI `.github/workflows/lifesim-v038-real-player-qa.yml`。
- **第一次真实失败很关键：** 首稿 `ff042c1f...` 的 [Godot Push #45022580037](https://github.com/ruabie/moci-cet4/actions/runs/45022580037) 和 PR #45022602439 均实际 FAIL：W 键输入正常，真实人物走 175 物理帧却卡在 **x=-17.036**（起点 -13.750），未进入店内。[原始失败工件 #14754248663](https://github.com/ruabie/moci-cet4/actions/runs/45022580037/artifacts/14754248663) 保留。证据定位是 V0.37 原有实心 **12cm 石门槛**及上抬地坪会阻挡接地胶囊角色；上一版悬空的胶囊代理完全漏报。
- **受限修复 1/2 `cf8c3218`：** 只把装饰石门槛改为无碰撞网格，实体地板调整至街道路面高度以下；**地板本身、柜台、货架、侧墙、后墙和上层依旧为真实碰撞**，绝非关闭全店碰撞。下一轮真实 Godot 成功进店并停住，但 D 键输入状态立即断言失败。**修复 2/2 `3ebd8acea...`** 仅在测试脚本中保证相反横向键 A 释放后经过完整物理帧，观察 D 真实按键事件 14 帧，无 `Input.action_press` 假替代，也不再修改游戏运动代码；两次修复已用完。
- **确切通过证据：** [同 SHA 专项 Push #45023100693](https://github.com/ruabie/moci-cet4/actions/runs/45023100693) / [专项 PR #45023106654](https://github.com/ruabie/moci-cet4/actions/runs/45023106654) 均 `completed/success`。已下载并人工打开 [真实 Godot Artifact #14754294365](https://github.com/ruabie/moci-cet4/actions/runs/45023100693/artifacts/14754294365)：**5 张来自角色自身 `ThirdPersonCamera` 的原始 1280×720 PNG**及 **14,879 字节真实位移/输入 JSON**、引擎和资源校验日志。W 持续 **123** 个物理帧，贴地 **123/123**，动画权重工作 **119** 帧，从 x=-13.750 到 -22.7962（进入约 **9.0463m**）；无输入停住；A 实际人物朝向改变 **1.30793 rad**，D 物理按键被捕获并记录 **0.75112m** 侧移；S 持续 **136** 物理帧重新到达外侧 x=-12.4131、z=117.0293。**共 616 帧真实人物物理处理**；原始脚踝相对 idle 高差峰值 ~**0.07037m**，不是鞋底/IK 完美接地证明。
- **与美术/性能隔离：** 同最终 SHA V0.34 #45023106644、V0.35 #45023106611、V0.36 #45023106626、V0.37 #45023106629、监督 #45023106656 均 `completed/success`。[完整 Godot 引擎 CI #45023106727](https://github.com/ruabie/moci-cet4/actions/runs/45023106727) 同 SHA 于 2026-11-22T12:40:52Z `completed/success`；整体引擎回归技术验收通过，**不代表美术、玩家真人键盘、Chrome 或 Windows GPU 已通过**。**实际 5 图人工质量审查 FAIL**：店内几乎空白墙、简单台架、日间街道与暗色门面不匹配，**中文 HUD 出现方块缺字**；本路线 `camera_collision_activations=0`，虽有 sphere-sweep 配置，却没有证明摄像机真正遇障后的回缩效果。没有 Windows RTX3060、Chrome WebGL、连续鞋底实测、真实人手操作、该店工作消费/保存闭环证据。
- **下一项优先开发：** 修复/实测**第三人称镜头室内贴墙和出口回缩**、中文 HUD 字体缺失；在不增加地图、不混淆真假美术的情况下提升同一店铺内外材质与货架真实感，再单店铺接入可重复验收的经营/消费。QA 开关默认关闭，V0.38 不可自动合并/发布；免费、#10/#12/#15/#18 开放，绝不推 V0.18 不安全自动发布旧分支。

---

## 最新一轮：V0.37 实体店铺门洞/街道连续通行 QA（2026-11-22）

- **实际提交：** [V0.37 草稿 PR #51](https://github.com/ruabie/moci-cet4/pull/51) 从 V0.36 #50 派生；最终实查 head `27c616a35e2cf515d02ddfd627f2f2cdd4b0e930`。新增 `scripts/walkable_shop_v37.gd`、`tests/visual_v37_walkable_shop.gd`、`tools/audit_v37_walkable_shop.py`、专门免费的 `.github/workflows/lifesim-v037-walkable-shop-qa.yml`；修改 `scripts/planned_district_v32.gd` 仅当 `application/config/v37_walkable_shop_preview` 显式启用且地块为 `west_homes_a` 时替换旧全实心建筑足迹碰撞。
- **实质问题解决：** 原 V0.36 商店门面实际前方有不间断整楼 `StaticBody3D`，**不能进入**。V0.37 在同一固定 20×22m 地块，保留原 11/11 地块、原路径、17 件原厂固定哈希/构建期转换的真实 Tevy GLB 外观，重新建上层实心和底层隔墙，提供宽 **2.9m**、净高 **2.75m** 的无实体遮挡门洞、约 **7.6×6m** 有收银台/货架、分区真实碰撞的零售小室，店铺内部没有假装接通真实货币、任务或 POI。
- **真实物理证据：** Godot 4.7.2 原场景 V0.36/V0.37 前后开关对照。旧版中心入口有实墙碰撞，新版中央入口水平射线无阻挡，边缘和店铺后墙保留碰撞；**3/3** 门前/店内地面射线通过；真实引擎 `CharacterBody3D.move_and_collide` 代理由世界 x=-14.0 向店内移动到 -23.000015，连续 **50 步 / 9.000015m，0 次阻挡**。这是对代理实体的真实物理测试，**不是正式 CityPlayer 输入连续性、腿部脚底接地或真人游玩**。
- **实际截图和精确数据：** [专项 Push Godot CI #45018764238](https://github.com/ruabie/moci-cet4/actions/runs/45018764238) 及 [PR CI #45018781050](https://github.com/ruabie/moci-cet4/actions/runs/45018781050) 同最终 SHA `completed/success`。已下载并检查 [Artifact #14752648713](https://github.com/ruabie/moci-cet4/actions/runs/45018764238/artifacts/14752648713)：**5 张实际 1280×720 PNG**（街景/门口前后及室内）、物理 JSON、图像 A/B；同机位像素变化 >25 RGB：街景 191,899 / 921,600 (**20.822%**)，门口 884,670 / 921,600 (**95.993%**)；这不是美学评分。**同 SHA 旧 V0.34 回归 #45018780975、V0.35 #45018781039、V0.36 #45018780992、免费监工 #45018781029 也 completed/success**；完整 Godot CI #45018780942 截至记录为 `in_progress`。
- **独立视觉审核：仍 FAIL。** 虽然原来封死的商铺门洞真的被打开且真实引擎代理可走进去，实际渲染室内货架、商品和照明依然廉价、空洞，楼上暗色赛博街面与周边偏浅城市不一致。真实 `CityPlayer` 无连续输入证据，生产购物/工作/存档未集成；Windows RTX3060 FPS、Chrome WebGL 与完整城市街区美术均未验收。这轮技术门槛 PASS 不等于美术/可玩交付。
- **下一最高优先级：** 在现有**同一条步行路径和同一房间**内，使用正式 `CityPlayer` 的真实输入、镜头/碰撞/脚底接地做连续街道→门洞→室内→退出运动证据（无传送），验证失败先修逻辑，再提升室内陈设和统一建筑色彩；不能复制 11 栋或宣称完成 Web 发布。零新增费用；不自动合并发布，不向含不安全自动发布工作流的 V0.18 旧分支推送。#10/#12/#15/#18 继续开放。
  
---

## 最新一轮：V0.36 真实授权现代住宅立面与 Godot 导入失败复核（2026-11-22）

- **本轮真实提交：** [草稿 PR #50](https://github.com/ruabie/moci-cet4/pull/50) 从 V0.35 实验分支继承。新增 `credits/TEVY_V36_SOURCE.json` 记录第三方 tevy 的 3 个源版本、许可声明 CC0-1.0、原文件字节数和 SHA256（共 **8,444,096 字节**），`tools/fetch_v36_cc0.py` 在 CI 拉取时必须逐个核查来源哈希、GLB 头和实际几何/材质；新 `scripts/urban_facade_v36.gd`、`tests/visual_v36_cc0_facade.gd`、`tools/audit_v36_facade.py`、专用免费 `.github/workflows/lifesim-v036-facade-art-qa.yml`。V0.32 `planned_district_v32.gd` 仅为 `west_homes_a` 地块接入 QA 开关 `application/config/v36_pinned_facade_preview`，**默认人物、经济、保存、旧 10 栋楼以及 V0.18 Web 均不变**。
- **第一轮失败证据：** 初始 head `8a6798c23b32cd6e6e62b078b9e2be551186938d` 的 [focused push #45017645155](https://github.com/ruabie/moci-cet4/actions/runs/45017645155) / [PR #45017672087](https://github.com/ruabie/moci-cet4/actions/runs/45017672087) 在真实 Godot 导入时报错：原 GLB 带 `EXT_meshopt_compression`、`KHR_mesh_quantization` 必需扩展，Godot 4.7.2 不支持，尽管**原文件哈希通过**。失败现场原始 artifact [#14752740753](https://github.com/ruabie/moci-cet4/actions/runs/45017645155/artifacts/14752740753) 保留，不掩盖为通过。
- **有限修正 1/2：** 精确诊断后 [`564164aa7ceb4093eeca13f3b2a944acee8758a7`](https://github.com/ruabie/moci-cet4/commit/564164aa7ceb4093eeca13f3b2a944acee8758a7) 仅在 CI **先对原始来源做 SHA-256 校验**，再通过固定版 `@gltf-transform/cli@4.5.0` 解压 Meshopt 与去量化，并二次检查 Godot 不支持的 `extensionsRequired` 已移除。**这是经过真实数据处理的转换，不是仅删扩展名、关闭哈希或用盒子代替模型；游戏运行时不需互联网。** 转换后的资源目前只在 CI 构建产物中，裸 Git checkout 未自带第三方大文件，且 CI 产物将到期。
- **同最终 SHA CI：** [V0.36 专项 Push #45017890677](https://github.com/ruabie/moci-cet4/actions/runs/45017890677)、[专项 PR #45017894727](https://github.com/ruabie/moci-cet4/actions/runs/45017894727)、[旧 V0.34 街景回归 #45017894735](https://github.com/ruabie/moci-cet4/actions/runs/45017894735)、[V0.35 住宅/图书馆回归 #45017894774](https://github.com/ruabie/moci-cet4/actions/runs/45017894774)、[免费监工 #45017894724](https://github.com/ruabie/moci-cet4/actions/runs/45017894724) 均为 `completed/success`。同 SHA **[完整 Godot 引擎 CI #45017894739](https://github.com/ruabie/moci-cet4/actions/runs/45017894739)** 已在 2026-11-22T11:38:21Z 复核为 `completed/success`；这仍然只是引擎/场景 QA，并不解除美术、Chrome 或 Windows 真实性能阻断。
- **原始 Godot 截图和数值：** 已从 [专项 Push artifact #14752462358](https://github.com/ruabie/moci-cet4/actions/runs/45017890677/artifacts/14752462358) 下载并实际查看 4 张 `1280×720` PNG、实测 JSON。住宅原有固体碰撞和门前步行路网保留；**3/3** 外部公共入口地面采样通过；11 个原规划地块保留。单栋住宅采用 3 种原始 CC0 GLB 共 **18 个真实实例**，附着 6 层、18m 立面，开窗/空调/阳台/底商有显著建模细节；同机位 RGB 差值 >25 像素比例：正面 **56.894%**，斜视 **16.786%**。注意这仅证明渲染变化，不代表画质优良。
- **人工审核：美术 FAIL。** 相较 V0.35 盒子，真实窗户、阳台、外置空调及底商纹理明显变得丰富，但模型为偏暗、霓虹、赛博朋克感住宅，**与整体偏浅、低精度、空旷的日间街道明显割裂**；住宅后墙无细节、店铺无法进入（保留 V0.32 建筑足迹碰撞）、未验证连续玩家实走、真实 Chrome WebGL / Windows RTX3060 性能。不可按此版本批量替换城市建筑，更不可宣称用户期待的开放世界已可交付。
- **下一唯一优先开发项：** 先**确定整条可步行街段统一的现代生活建筑风格与材质曝光基线**，选择授权明确且能组成正立面/侧立面/背立面/真实门槛的同一系列模型，组成 1–2 个相邻地块而非单个暗色贴面；结合合法的 PBR 表面材质及店铺室内/真正通行入口，先用真实双机位及连续输入证据复核，再考虑扩地图、LOD、批量替换。另需解决 Quaternius Base 模型目前依赖即将过期旧 CI 工件的问题。坚持零新增费用、不自动合并发布，不动危险的 V0.18 自动推送分支。

---

## 最新一轮：V0.35 两种建筑类型的真实替换及视觉复核（2026-11-22）

- **[草稿 PR #49](https://github.com/ruabie/moci-cet4/pull/49)**：从未合并的 V0.34 #48 派生新隔离分支 `lifesim-v035-architecture-slice-qa`；最新实查 head `0e4d2066b5541ee52cbe28f6bcb61209fd74eb13`。增加 `scripts/architectural_slice_v35.gd`、`tests/visual_v35_architecture.gd`、`tools/audit_architecture_v35.py`、独立免费工作流 `.github/workflows/lifesim-v035-architecture-qa.yml`；`planned_district_v32.gd` 仅在 **`application/config/v35_architecture_preview` QA 开关**开启时切换指定 2 栋楼。旧 9 栋、原地块碰撞/入口路径、正常人物/经济/存档/Web 均未改。 
- **真实新样板：** `west_homes_a` 原盒状住宅替换为有退台、10 处阳台、侧立面窗的住宅组合（81 个可渲染网格）；`east_library` 替换为明显横向的阅览建筑形体，含 7 道竖向外遮阳、15 组窗口构件（49 个可渲染网格）。二者仍**仅为外立面**，未声称有可进入的室内，原 11/11 规划地块仍存在；两个入口步行位置真实物理射线检查通过。
- **[同 SHA 专项 PR CI #45016938846](https://github.com/ruabie/moci-cet4/actions/runs/45016938846) 与 [Push CI #45016923394](https://github.com/ruabie/moci-cet4/actions/runs/45016923394)** 都已 `completed/success`。从 [原始截图 Artifact #14752211518](https://github.com/ruabie/moci-cet4/actions/runs/45016923394/artifacts/14752211518) 实际下载并查看住宅和图书馆的各一组前后 1280×720 Godot 4.7.2 Mesa OpenGL3 对照；与 V0.33 同机位比较，变化像素（RGB 单通道最大差 >25）住宅 456,224/921,600（49.503%），图书馆 275,330/921,600（29.875%）。这些只是画面变化，不是精细度和 FPS 评分。
- **[旧 V0.34 focused QA 回归 #45016938799](https://github.com/ruabie/moci-cet4/actions/runs/45016938799) 与 [免费监工 #45016938797](https://github.com/ruabie/moci-cet4/actions/runs/45016938797) 均同 SHA `completed/success`。**完整 Godot CI #45016938779** 截至本轮记录仍在运行中，未升格通过；Chrome WebGL、Windows RTX3060、连续走停转输入均未执行。
- **人工美术验收仍 FAIL：** 住宅具有区分度但阳台重复、材质平、建筑缺少真实细部；图书馆轮廓改善但远看仍像简单组合模型。城市仍大范围低密度，街面没有可用室内与真实生活组织。**本轮证明可测试的两种形体方向，不代表已经解决用户提出的地图精细度或设施合理性问题。** 不在这一步推广 11 栋相同复制品。
- **下一唯一优先项：** 为连续街面 **1–2 个地块**导入/创作真正具备许可核验的现代建筑模块（包括有真实比例的底商、墙窗立面、入口退让、门槛与交通动线），完成足够完整的美术样板，并用原始同机位真实截图重新由人审视；通过视觉门槛后再做可步行室内及真实输入连续验收。继续禁止扩大低精度面积，保持零新增费用、不合并、不发布；#10/#12/#15/#18 开放，绝不向旧 V0.18 自动部署分支推送。

---

## 最新一轮：V0.32–V0.34 真实扩展地图、设施布局及城市美术复核（2026-11-22）

- 用户反馈：地图太小、精细度差、设施布局不合理。实际核查 `city_builder.gd`：旧版可碰撞地面 **180×180m**，只有两条十字主干路，外围相当数量建筑是无碰撞的远景背景；住宅/便利店/咖啡馆和公交设施分散硬编码，缺少统一规划。**扩图不是同义词：不能复制低精度盒子冒充新城市。**
- **V0.32 [草稿 PR #46](https://github.com/ruabie/moci-cet4/pull/46)**，最终 head `7906f65b3eede2b3974b9fe74c50a88d87bbd435`：新增仅在 `application/config/v32_spatial_preview` QA 开关下启用的 **178×191m / 33,998m²** 北部地面，与原主干道真实接缝相连（总地面约 66,398m²，未减去接缝）。`data/v32_north_district.json` 单一规划包含 **11 栋分住宅、诊所、图书馆、零售等不同用途的建筑外观**、公园、公交车站、共享单车点、两个步行联络通道及过街标线；不是可进入的新室内。`audit_north_district_v32.py` 实查建筑最小间距 **16.5m**、**11/11** 入口通道；实际 Godot **20/20** 道路碰撞光线采样、**407** 处窗细节、**14** 棵建模树、五视角真实 PNG。移除进入新步行范围的旧无碰撞“幽灵背景”。[Godot PR CI #44754432959](https://github.com/ruabie/moci-cet4/actions/runs/44754432959)、[Push #44754419556](https://github.com/ruabie/moci-cet4/actions/runs/44754419556)、[监工 #44754432914](https://github.com/ruabie/moci-cet4/actions/runs/44754432914) 均同 head 完成 success；**美术仍 FAIL**：街区虽变大却依然大块盒体、空地和曝光泛白。
- **V0.33 [草稿 PR #47](https://github.com/ruabie/moci-cet4/pull/47)**，最终 head `24eaa7ed6fb7097cddc1424d20325c0c642aa579`：在独立 `v33_streetscape_preview` QA 开关下，为 11 栋底层加上有区别的门面、遮棚、围墙及 **24 件真实 Kenney CC0 花箱/垃圾设施 GLB**，并试验降低过曝。构建时发现原先镜像仓库 `Barbatos6669/elderforge` 已 404；UAL 原始库改从 `WaviestSun/atelier-packs` `characters-1` 发布资源获得，**原始 7,618,436 字节、Git Blob SHA1 `473e5908…` 与 SHA256 `69591853…` 全部复核通过**。原角色基础模型暂从本项目过往已验收 [run #44754419556](https://github.com/ruabie/moci-cet4/actions/runs/44754419556) 的 artifact 恢复，校验原始 1,085,752 字节及双 SHA；**该 CI 工件会过期，不能作为长期稳定素材来源**。V0.33 [完整 CI #45013127444](https://github.com/ruabie/moci-cet4/actions/runs/45013127444) 完成旧版引擎及动作回归，但新 A/B 预览脚本错误地按名称取 `WorldEnvironment` 而非 `main.gd` 的 `ambient_env`，因此没有可认证的 V0.33 A/B 图片，测试 FAIL；两轮受限修正后不继续盲改。
- **V0.34 [草稿 PR #48](https://github.com/ruabie/moci-cet4/pull/48)**，head `361e269805dc00e7d12510f66fe507eb585c6b6f`：只修复上述场景对象的**真实成员引用**，新增独立免费的真实 Godot 4.7.2 OpenGL3 四机位 A/B 检验。已重新下载并人工打开 [集中截图证据 artifact #14751206543](https://github.com/ruabie/moci-cet4/actions/runs/45013555198/artifacts/14751206543) 的 8 张原始 PNG：主道路、十字路口、公园、商铺临街面。**同机位真实渲染 Push CI #45013555198 与 PR CI #45013578930 均成功**，监工 #45013578896 成功；完整历史 Godot PR [#45013578952](https://github.com/ruabie/moci-cet4/actions/runs/45013578952) 也已 `completed/success`；四条同 SHA CI 均成功，但这不是最终城市美术/浏览器/实机验收。
- 四视角**地面/地块高亮像素（平均 RGB >222）比例**，旧 V0.32 → V0.34：道路 `33.33%→14.22%`，路口 `14.04%→6.66%`，公园 `37.06%→4.78%`，门面 `21.90%→1.84%`。新设施实际可见，11 个临街面、24 件固定来源 GLB 符合最低技术门槛，旧公共道路 14 点碰撞保留。**数字只证明亮部及图像差异，不等于城市建筑美术好看。**
- **人工美术审核 FAIL：** 现有建筑体量/窗墙关系仍明显近似方盒子，空地过大，街面底商缺乏真正完整的建筑细节/室内，缺少车行、行人空间及生活密度。下一任务应**先替换建筑资产与街面结构设计方法，在 1–2 个建筑地块做高质量切片并验证**，不再继续复制面积或堆砌低价值花箱。
- 安全边界：所有 V0.32/33/34 城市扩展仍 QA-only，默认 `CityPlayer`、存档、经济、旧 V0.18 网页没有改变；PR 链 draft/open/unmerged，**无真实 Chrome/WebGL 试玩、用户 Windows RTX3060 性能或连续长距离漫游证据**。原始 main `lifesim/index.html` 仍未接入且 HTML S0–S5 未验收。#10/#12/#15/#18 继续开放，零新增费用，不合并或发布，不推送旧 V0.18 危险 auto-deploy 分支。

---

## 历史里程碑：V0.30–V0.31 模块服装真实蒙皮试验与现有 Web 体验核对（2026-11-20）

- **最新候选：** [V0.31 草稿 PR #45](https://github.com/ruabie/moci-cet4/pull/45)，head `5af61bc80df3633292b6077e2fa62aa32ea7f2db`，base V0.30；open/draft/未合并、未发布。原主角 `CityPlayer`、玩法和网页构建未修改。
- 用户要求查看网页版后已再次查询 **main**：`lifesim/index.html` **404**，`lifesim/project.json` 的 HTML S0–S5 仍 pending/sourceState=not_connected。唯一确认存在的隔离版是 [`lifesim/play-v18/`](https://github.com/ruabie/moci-cet4/tree/main/lifesim/play-v18)，真实 `build-info.json` 记载 **V0.18**、源 commit `c288af7b7cd75fd8baa9d3369610d9f8b178b0dc`。已从 [Web Actions #43909332249](https://github.com/ruabie/moci-cet4/actions/runs/43909332249) 下载 artifact `#14245624663`，核实 index.html/index.js/index.pck/index.wasm 均齐全，并在该聊天中另制作 Windows 本地 PowerShell localhost 一键启动 ZIP（仅会话文件，未写入仓库），但 **无法确认 GitHub Pages 网址真实在线可玩或 Windows 浏览器已经通过测试**。V0.31 未发布到网页。
- V0.30 [草稿 PR #44](https://github.com/ruabie/moci-cet4/pull/44) 做 Quaternius CC0 服装来源接入，但**两轮素材清单 SHA 抄写错误**先后将 `Male_Peasant_Feet.bin`、`T_Peasant_ORM.png` 的真实来源误拒绝，在渲染前失败。两次受限修复用完，保留失败证据，没有在旧 PR 无上限修补。
- V0.31 采用作者 Quaternius [Modular Character Outfits – Fantasy](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html)，原始许可 CC0-1.0，源文件来自固定只读镜像 `agentkaerf/FreeModels@db3df04d1e4714298a09510b26fb6de6645138a2`。构建时严格比对 9 个 glTF/.bin/贴图 Git Blob SHA 与字节数；**上衣 Body、裤装 Legs、鞋 Foot** 三份独立蒙皮 GLTF 各自 **65 根骨骼、65 个父子对应关系均与 Universal Base Character 相同**，沿用 V0.29 正确处理的 55 条动画旋转+1 条 pelvis 平移。
- 真正的 Godot 4.7.2 OpenGL3 画面：待机×1、步行×2、跑步×2，共 **5 组同相位穿衣开关对照 / 10 张 1280×720 PNG**。真实 RGB 像素变化计数 **15,182 / 15,399 / 12,085 / 10,844 / 11,116**；原始截图、`v30_outfit_audit.json`、`v30_outfit_render.json`、`v30_outfit_pixel_gate.json` 与 5×2 对照 JPG 已从 [focused Push CI artifact #14633412999](https://github.com/ruabie/moci-cet4/actions/runs/44747428071/artifacts/14633412999) 下载并人工打开核查。
- **同最终 SHA 五条 CI 都 completed/success：** [Focused PR #44747482726](https://github.com/ruabie/moci-cet4/actions/runs/44747482726)、[Focused Push #44747428071](https://github.com/ruabie/moci-cet4/actions/runs/44747428071)、[完整 Godot PR #44747482752](https://github.com/ruabie/moci-cet4/actions/runs/44747482752)、[完整 Godot Push #44747428072](https://github.com/ruabie/moci-cet4/actions/runs/44747428072)、[监工 #44747482682](https://github.com/ruabie/moci-cet4/actions/runs/44747482682)。
- **审核结论严格区分：** 许可/资源固定、三份服装骨骼层级、Godot 实际蒙皮动作、原有引擎玩法 QA **通过**；**最终美术 FAIL**：现有素材只是较朴素的奇幻乡村装扮，面部/头发不完整、衣服可能和基础人体穿插，绝不能作为现代都市市民直接集成。连续真实输入/鞋底接地/Chrome WebGL/Windows RTX3060 尚未验证。画面改变≠服装符合项目美术标准。
- **下一独立美术目标：** 暂停将 Peasant 服装作为生产候选，保留 65 骨骼/动画/服装蒙皮兼容技术，优先寻找或制作确实符合现代生活的 CC0 上衣、长裤、鞋、头发及面部细节；通过用户标准及连续走/停/转/跑之后，才考虑在封闭试玩中替换正式 `CityPlayer`。不合并、不自动发布、不增加费用，#10/#12/#15/#18 保留；旧 V0.18 分支仍含危险 push-to-main Web 自动发布工作流，禁止直接推送。

---

## 历史里程碑：V0.27–V0.29 导入修复、15 张真实同相位人物截图（2026-11-17）

- **最新候选：** [V0.29 草稿 PR #43](https://github.com/ruabie/moci-cet4/pull/43)，最终 head `d82fb76e649dbcf3d9c0c6787be755d3d75acfcc`，base `lifesim-v028-import-name-rest-proof`；**open / draft / merged=false**。当前只是验证美术方向，不合并、不自动发布、不替换生产 `CityPlayer`。
- V0.27 **独立诊断**发现问题并非源素材缺少脊柱动画：原始 Quaternius UAL1 GLB 的 `spine_01` 在 `Idle_Loop`、`Walk_Loop`、`Jog_Fwd_Loop` 整条轨道的旋转变化均约 **0°** 且完全等于源骨骼 rest；反面证据是同一 Walk 的 `upperarm_l` 振幅 **32.57°**、Jog **26.51°**，不允许丢弃这些真正运动的关节。真实 Godot 4.7.2 导入把 `Idle_Loop/Walk_Loop/Jog_Fwd_Loop` 分别改名 `Idle/Walk/Jog_Fwd`，并优化掉静止的 `spine_01`，保留每个动作 **55 条旋转+1 条 pelvis 平移**。新代码只允许带 pinned GLB Git blob 证据的缺失恒定轨道回退到目标 rest，其他动态关键骨骼仍为阻断项。
- 两个受限排错小版本保留真实失败证据：**PR #41 / V0.27** 最终 `d92f8e7238f723d3db303dedc499e436e8ff39ac`，先误用原始动作名、后在 source-rest JSON 中误用导入名，未出图；**PR #42 / V0.28** 最终 `782c7be2774c6f251570297e5bc5060139bd4b2b` 修复动作名映射，跳过之前的关键轨道阻断，但预览 GDScript `Array[float]` 条件赋值失败，仍未出图。历史失败不掩盖，也不对两者无限补丁。
- V0.29 第一轮 `b7777ee7559ba777a26e6f24a94c3a22f89eb4b5` 修复真正的 typed-array 脚本问题，已有**15 张真实 Godot OpenGL3 同相位截图**（待机一组；步行、慢跑各两组）；第二轮最终 `d82fb76e649dbcf3d9c0c6787be755d3d75acfcc` 仅改测试拍照时隐藏另外两个角色，防止同画面模型重叠。实际图片来自原始 UAL 黄色人偶、65 骨骼 CC0 Universal Base Character 和 49 骨骼旧市民，不是 AI 概念图。
- **四项同 head SHA CI 均 `completed/success`**：[专注源文件/轨道/实际三方渲染 #44106195024](https://github.com/ruabie/moci-cet4/actions/runs/44106195024)、[完整 Godot PR CI #44106195075](https://github.com/ruabie/moci-cet4/actions/runs/44106195075)、[完整 Godot Push CI #44106180691](https://github.com/ruabie/moci-cet4/actions/runs/44106180691)、[监工 CI #44106195051](https://github.com/ruabie/moci-cet4/actions/runs/44106195051)。已下载、人工打开并核对 [原始证据工件 #14338513188](https://github.com/ruabie/moci-cet4/actions/runs/44106195024/artifacts/14338513188)，含 **15 张 1280×720 PNG**、真实轨道清单、来源及动作指标、只含单一人物的 5×3 JPG 对照图。
- **实际画面判断：** 官方 UAL 原生动画人偶与 Quaternius 65 骨骼兼容基础人物的全身步行/跑步比旧 49 骨骼有衣市民更协调，旧人物手臂异常抬高、类似出拳。新人物的臂腿运动接近原始动作库，这是**比较意义上的实质改善**；但新人物目前只是未换装的基础人体，并非真实城市生活服装，不能作为正式玩家；实际游戏街道、鞋底接触、脚滑、膝盖/脚尖滚动、从跑到停/转身的输入驱动连贯性均未证明。
- **数值边界：** 最新静止/步行/跑步帧最低踝骨 Y（米）原始/兼容/旧市民分别为待机 `0.069/0.069/0.156`；步行两相位 `0.069–0.075 / 0.072–0.078 / 0.102–0.147`；跑步两相位 `0.108–0.186 / 0.141–0.219 / 0.330–0.372`。这是骨骼高度代理，**不是鞋底物理离地距离或扎实落地证据**。
- **下一独立里程碑 V0.30：** 为兼容的 65 骨骼基础人物寻找/制作**许可证允许、与现代城市相符的衣服、鞋、头发**，保持现已验证的全身骨骼层级与 `pelvis` 平移；实际 Godot 蒙皮外观达到普通年轻人可接受的标准后，再将其接入封闭的玩家漫游试点，提供连续真实输入证据和 Windows/Chrome 测试。旧 V0.18 分支仍含危险的 push-to-main 自动发布，不推送它；Issues #10/#12/#15/#18 未关闭，main `lifesim/index.html` 缺失，HTML S0–S5 仍待验收。

---

## 历史里程碑：V0.26 CC0 原生兼容骨架与未完成的实际渲染（2026-11-17）

- **候选：** [草稿 PR #40](https://github.com/ruabie/moci-cet4/pull/40)，base V0.25，最终 head `87a5399cc7c4be920ca2d35e8b0ec5fd54403ff4`，**open / draft / merged=false**。没有自动合并、发布、收费，也没有替换正式 `CityPlayer`。
- 重新核实 Quaternius 官方 [Universal Base Characters](https://quaternius.itch.io/universal-base-characters) 和 [Universal Animation Library](https://quaternius.itch.io/universal-animation-library)，二者均为 **CC0 1.0**，官方明确提及互相兼容。新增 `tools/acquire_base_v26.py` 从只读固定镜像 `Barbatos6669/elderforge@bb2ce469f0ab2ccfc487faef55550ba07fae2483` 于 **CI 构建时**取得 `BaseCharacter.glb`；验证 Git blob `59c4044d5146146170f1c6d5e765985a73bc7875`、SHA256 `2d6792e77f337cf6fac3a81e1caf92798b898401140485b55307c9f14785ec25`、大小 1,085,752B、真实蒙皮与骨骼。裸 git checkout **不内含该二进制**，不能声称完全离线直接启动；运行时游戏也不请求网络。
- 新增 `tools/audit_rigs_v26.py` 和免费 CI `.github/workflows/lifesim-rig-v26.yml`，真实解析 3 份 GLB 二进制：动画库原生人偶 **65 根骨骼**，配套候选基础人物 **65 根骨骼**，**65 个名称和 65 个父子层级全部一致**；对应静止局部旋转差异中位数 **2.16°**，髋部约 **1.91°**、左肩锁骨约 **11.92°**。现有 V0.18 旧市民模型 49 根骨骼，与 UAL 同名者仅 **1 根**。候选在结构上明显比旧市民更匹配，但并不意味着最终游戏美术已通过。
- 在真实动画库原始 GLB 中还核实到 Walk/Jog 的 `pelvis` 平移：Walk 局部 Z 变化约 **0.05264m**，Jog 约 **0.24482m**。V0.21–V0.25 旧重定向只复制旋转轨道，没有保留这段髋部平移，**可能**导致步态失真，具体对画质影响未验证。
- **同最终 SHA 的独立骨架审核 CI** [#44098933766](https://github.com/ruabie/moci-cet4/actions/runs/44098933766) 为 `completed/success`，工件中有原始来源、许可核对及 JSON 指标。随后新增 `scripts/compatible_anim_v26.gd`（候选角色保留全身骨骼旋转+髋部平移）与 `tests/visual_v26_rig_compare.gd`（原生动画人偶、配套基础人物、旧市民同相位同机位对照），期待得到真实 Godot 截图，但**两次有界测试均在渲染前置检查处被阻断**：
  1. 第一轮 SHA `31888015b7c0d04e70d65ddbbfff6af0bf479f0d`，[全量 Godot CI #44097738717](https://github.com/ruabie/moci-cet4/actions/runs/44097738717) **FAILED**：Godot 实际读取了 **55 条可映射旋转轨道+1 条 pelvis 平移**，测试要求 `>=60`，与真实导入数量不一致。
  2. 第二轮 / 最终 SHA `87a5399cc7c4be920ca2d35e8b0ec5fd54403ff4`，修改为 `>=50` 且检查躯干、双臂双腿的必要轨道，但 [PR Godot CI #44098933886](https://github.com/ruabie/moci-cet4/actions/runs/44098933886) 与 [Push #44098911548](https://github.com/ruabie/moci-cet4/actions/runs/44098911548) 均 `completed/failure`：原始 GLB 虽包含 `spine_01` 动画通道，Godot 已导入的动作里缺少这一要求的旋转轨道；究竟是常量轨道被过滤还是路径映射不同，**还未核实**。
- **重要区分：骨骼结构和授权来源审核 PASS；V0.26 三方人物动作应用与截图未完成；美术质量未知且发布继续 BLOCKED。** 没有任何可诚实呈现的 V0.26 三方对照 PNG，禁止用 V0.25 图片代替或称“新的全身动作已通过”。原有旧人物 V0.25 美术仍 FAIL。原玩法经济/存档/旧场景回归测试通过，但不能替代新环节。
- **下一独立 V0.27：** 对照 GLB 源动画频道与 Godot 导入 `AnimationPlayer` 的实际 TrackType/NodePath，先查清 `spine_01` 为什么缺失；针对确认为静止不动的关节允许使用源骨架 rest-pose，真正有运动的骨骼必须保留；然后才能重新输出三方同相位真实截图，人工检查膝盖、摆臂、鞋底及生活风格适配。V0.26 已用满两轮有界修正，禁止第三次盲改。
- 严格保留现有边界：V0.18 旧分支仍有推送自动发布 main 的高风险工作流，禁止 push；Issues #15/#18 继续开放，主分支 `lifesim/index.html` 缺失、S0–S5 未验收；Chrome/WebGL 与 Windows RTX3060 尚未实测。

---

## 历史里程碑：V0.25 真实蒙皮 IK 对照图与美术阻断（2026-11-17）

- **当前候选**：[草稿 PR #39](https://github.com/ruabie/moci-cet4/pull/39)，base `lifesim-v024-ik-signal-diagnostics`，最终 head `fbfc0a184f46de88a1aec9e080d9cee36d2baf7d`；**open / draft / merged=false**。零新增费用，未自动合并/发布，正式 `CityPlayer` 动作未替换。
- 在 V0.24 已证明 IK 修改器信号内真能改变玩家脚踝后，本轮新增 `lifesim/godot/tests/visual_v25_ik_render.gd` 和 `tools/analyze_v25_ik_render.py`：对实际 CC0 LifeSim 玩家、真实 Quaternius UAL1 Walk/Jog 两个动作、四个相位各拍摄 **IK OFF vs IK ON 的成对 Godot OpenGL3 原始 PNG**。每对同一相位、同一镜头、同一游戏场景，1280×720 共 16 张，不以代码想象或 AI 生图替代实际渲染。分析脚本读取 PNG 原图做 RGB 像素差分并生成并排 JPG。
- **两轮有界测试：** 第一轮 `9efee4e75006ac976014adabbde52482cd01a6d4` 的新测试在同一引擎帧里连续做 OFF 截图、ON 手动 advance，未收到第二次 `modification_processed`，CI 失败。第二轮 `fbfc0a184f46de88a1aec9e080d9cee36d2baf7d` 把 ON 求解移至下一个引擎帧，保留原始严格像素门槛。
- **可复核的技术结果：** [PR Godot CI #44092482728](https://github.com/ruabie/moci-cet4/actions/runs/44092482728)、[Push Godot CI #44092475366](https://github.com/ruabie/moci-cet4/actions/runs/44092475366)、[监工 CI #44092482766](https://github.com/ruabie/moci-cet4/actions/runs/44092482766) 针对同 SHA 均 `completed/success`。已下载 [实际渲染与日志工件 #14332003288](https://github.com/ruabie/moci-cet4/actions/runs/44092482728/artifacts/14332003288)，独立读取 `v25_ik_render_metrics.json`、`v25_ik_render_comparison.json`、两幅 4×2 对照图并人工检视。
- **量化结果：** 8 组真实 IK OFF/ON 图中 **8/8 均有真实可见渲染差异**。RGB 最大通道变化阈值 >20 的像素数按相位为 **13,434 / 16,418 / 10,277 / 17,648（Walk）**，**12,497 / 10,373 / 12,311 / 14,509（Jog）**，大约每张 1.1%–1.9% 图像像素，且在真实人物腿部可见。因此**不只是修改器回调数值，Godot 实际蒙皮角色也受到 IK 影响**。
- **独立美术复核：FAIL。** 实际渲染发现腿部支撑与膝盖仍不自然且部分姿态过直，跑步多帧仍显著腾空，手臂如出拳/格斗而非自然跑步；不能证明鞋底蒙皮触地、脚滑为零、转身/停走连续。街道仍是低精度重复建筑与宽阔马路。**像素差异≠美术通过**，禁止接入正式玩家动作。
- **下一独立方向：V0.26 以整个角色的动作适配为目标**：重新核对 UAL 动作源与当前 Quaternius 人物的上半身、肩膀、髋部、脚踝与膝盖的静止骨架取向，判断是否应直接改用骨架天然兼容的 CC0 人物与运动动画，避免继续在不兼容的全身动作上反复调 IK 或根节点高度。先交付对比和真实漫游姿态后再决定融合；仍需 Chrome/WebGL 真机与 Windows RTX3060 实测。
- 费用、安全和发布边界不变：高版本为独立草稿，V0.18 原始分支包含危险的 push-to-main Web 自动发布任务，不向它直接推送；#15/#18 未关闭；主分支 `lifesim/index.html` 仍不存在，HTML S0–S5 `pending`，用户实际游玩未验收。

---

## 历史里程碑：V0.24 澄清原生双腿 IK 测试误判（2026-11-17）

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

1. **V0.35 应先做高质量现实都市建筑/街面“切片”，不要再扩大城域面积。** 选择有明确 CC0/兼容授权的现代建筑/门面及地面材料（或者制作真实透视比例、分层屋顶与底商的原创模块），先仅在原 V0.32 已连接的 1–2 个地块替换盒状外墙。要求可辨识的底层门廊与真正对应的门、窗台/屋檐、转角/背面、合理机动车与步行动线；取得同镜头原始 Godot PNG、空间碰撞和人眼审美检验，假高精度/空室内不得交付。
2. **保留 V0.32 可碰撞的两倍地面和 V0.34 四视角技术证据，但不要将草稿当正式可玩地图。** 要实现玩家连续步行、进出新门面和动态 LOD/绘制开销验证，且在 Windows RTX3060 1080p FPS 合格后才考虑集成/扩围。
3. **修素材可持续获取：** 原 Elderforge 镜像 404，UAL1 已有 SHA 双校验发布源；65 骨骼 Base 目前靠自身过往 CI 工件暂存，工件过期后会失效，应建立合法稳定的离线/版本固定资源备份。不可关闭 SHA 检查绕过。
4. 人物质量仍有单独阻断：Quaternius 动画与 65 骨骼适配技术 PASS，但都市衣物、鞋底接地、连续互动未通过。网页只有真实存档的 V0.18 Web 导出；在线 Chrome/Windows 未验收，main HTML S0–S5 仍 pending。所有新 PR 继续 draft，无付费、无自动合并发布，#10/#12/#15/#18 保持开放，不触碰旧 V0.18 自动部署分支。

## 5. 下次新聊天直接复制

> 继续《游戏计划书／同频之城》。先从连接的 GitHub 仓库 `ruabie/moci-cet4` main 读取 `lifesim/HANDOFF.md`、`HANDOFF_STATE.json`、`HANDOFF_PROTOCOL.md` 并独立核实最新 PR/head/CI/Issue/main HTML。最新 V0.34 草稿 PR #48 head `361e269805dc00e7d12510f66fe507eb585c6b6f`，base V0.33 PR #47，未合并未发布。V0.32 仅 QA 开关的北区 33,998 m² 新地面、11 栋不同规划建筑、20/20 地面碰撞点通过，原地面 32,400 m²；V0.34 新增 11 处临街细节和 24 件 Kenney CC0 实际 GLB，用 4 个相同相机拍 8 张真实 Godot 截图，降低道路与公园过曝，focused push #45013555198、PR #45013578930、supervisor #45013578896 PASS，但建筑仍非常方盒子，人工美术 FAIL。完整 Godot PR #45013578952 已完成 SUCCESS，四条同 SHA CI 均通过；但人物、城市专业美术和 Chrome/Windows 实机仍 FAIL/UNVERIFIED。先做 1–2 个街区“建筑资产升级+底层真实门店结构”审美切片，不再无脑扩图或堆小装饰。原 elderforge 模型镜像 404；UAL1 已移至带 SHA256 的 live release，Base 仍从 CI 工件恢复，工件会过期。现有 V0.18 Web 导出没有这些改造，Chrome/Windows 实机未通过；保持零新增费用、不合并发布、不推动危险旧 V0.18 分支或其他项目。完成后更新两份 main 交接及真实 SHA。

## 6. 交接文件和监工

- 人类入口：[`lifesim/HANDOFF.md`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF.md)
- 机器快照：[`lifesim/HANDOFF_STATE.json`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF_STATE.json)
- 约束协议：[`lifesim/HANDOFF_PROTOCOL.md`](https://github.com/ruabie/moci-cet4/blob/main/lifesim/HANDOFF_PROTOCOL.md)

已有「游戏计划书监工」每 6 小时的任务仅负责**只读核对和必要报告**，不会自动修改 main 的交接、合并 PR 或称自己完成了真实编码。接班必须再读仓库，按证据更新。
