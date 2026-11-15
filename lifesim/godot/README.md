# 同频之城 · V0.5.1 角色骨骼、行人和原创建筑资产候选版

此包是 V0.4 Alpha 的工程升级版本，**已在 Godot 4.7.2 CI 完成首次导入与静态画面截图，但人物动作、Windows 帧率和视觉质量尚未通过最终验收**。不是正式游戏，也没有可证明的 Windows 60 FPS 数据。

## 启动

1. 使用 Godot 4.7.2 稳定版（GL Compatibility）导入 `project.godot`。
2. 聊天下载包已包含预生成 `.glb`，不需联网或 Python；GitHub 源码克隆后先在工程目录执行 `python3 tools/build_assets.py` 生成模型再导入 Godot。
3. 按 F5 运行；WASD 移动、鼠标控制视角、Shift 跑步、E 互动、J 打工、B 购买、Q 离开公寓。

## 本轮真正修改了什么

- `art/characters/commuter_rig.glb`：原创、可商用的 glTF 2.0 `skin` 资产，17 个命名关节，包含躯干、服装、面部、鞋子、背包等网格。`scripts/player.gd` 在 `Skeleton3D` 上按实际水平速度更新走跑/转向动画。
- `art/architecture/storefront.glb`：有门、橱窗、室内陈列、灯箱、棚架的可复用店面模型。
- `art/architecture/apartment_lobby.glb`：公寓入口、门、玻璃、信箱与花盆。暂不属于可进入真实大楼室内。
- `tools/build_assets.py`：纯 Python 标准库，能离线重建所有五个 GLB；资源均为原创，不依赖外部 API 或许可不明素材。
- `tests/check_authored_assets.py`：验证 glTF 结构、材质、命名骨骼和皮肤权重的静态检查；`tests/qa_headless.gd` 增加真正的 Skeleton3D 与建筑实例验收。

## 审核状态

| 项目 | 状态 |
|---|---|
| 独立 GLB 文件可生成并由第三方 glTF 解析器打开 | 已验证（本地） |
| 真实 glTF 皮肤权重和命名骨骼 | 已验证结构 |
| 游戏经济、存档静态回归 | 已通过 |
| Godot 4.7.2 骨骼导入/动画解析 | **CI 导入与场景测试已通过，Windows 实机待测** |
| Godot 实际视觉截图和性能 | **待验证** |
| 真人/高品质动画完整度 | **未达到** |

## 已知限制

- 人物是完整骨骼皮肤模型，但由原创程序化几何生成，离电影级角色建模还有显著差距。
- 玩家尚不能真正走入 AOI MART 店面，也尚无完整店内收银交互；沿用之前的兼职逻辑。
- 6 名 NPC 改用三套骨骼角色外观；仍采用简单日程与局部往返路线，而非完整社会模拟。
- V0.5 不会自动合并到主分支，验收缺口必须保留。