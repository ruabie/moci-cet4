# 同频之城 / LifeSim — Godot V0.3.1

> 状态：技术原型，等待真实引擎和视觉验收。

独立于原来的 HTML V0.2 版本。此目录承载真正的 Godot 4.7.2 项目，不依赖在线 CDN 3D 引擎。

## 打开方式

下载 [Godot 4.7.2 Standard](https://godotengine.org/download/)；在 Godot 项目管理器中选择「导入」，选中本目录的 `project.godot`，再按 `F5` 运行。

操作：`WASD` 行走、`Shift` 跑步、鼠标转镜头、滚轮缩放、`Esc` 释放鼠标；靠近地点按 `E`，便利店按 `J` 打工，商店按 `B` 购买，公寓内按 `Q/E` 返回。

## 功能模块

- `scripts/world_clock.gd`：真实设备时间与昼夜计算
- `scripts/city_builder.gd`：程序化街区、建筑、道路、基础 NPC
- `scripts/player.gd`：第三人称角色、相机避障
- `scripts/game_state.gd`：版本化存档、备份、消费、幂等工资
- `scripts/main.gd`：场景组装、交互、兼职、商店、公寓、HUD

## V0.3.1 修复

1. 消耗品支出与家具清单分离，防止咖啡无限积累到永久物品。
2. 工作与购物改为候选状态提交，存档失败不先确认收益。
3. 存储 `at_home` 状态，回到游戏时可以正确恢复公寓。
4. QA 使用隔离的临时文件和 `qa_mode`，避免覆盖玩家真实存档。

## 自动化验证

GitHub Actions 工作流在仓库根目录 `.github/workflows/lifesim-godot.yml`。

它应执行 Godot 4.7.2 引擎导入、GDScript 解析、场景创建及经济/存档契约测试，并保留日志。注意：静态 Python 测试通过并不能证明 Godot 工程能运行。

本目录由独立的 `lifesim/godot/` 验收，不更改旧版 `lifesim/project.json` 的 S0–S5 浏览器验收状态。

## 当前限制

使用原生简单网格的替身模型，**不满足正式画质门槛**。未实现正式骨骼动画、精细 GLB 建筑、真实 NPC 行为、完整多职业、多人联机。运行于 Windows RTX3060 的帧率仍需真机验证。

详见仓库 Issue #12。