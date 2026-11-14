# 同频之城 · 青川町 V0.3 Godot 开发工程

**状态：可编辑的原始 Godot 4 工程。** V0.3 标准是迁移工程底座和验证系统接口；不是完整 3D 商业游戏，也不是与 HTML V0.2 功能等价的发布版。

## 怎样运行（Windows）

1. 从 https://godotengine.org/download/windows/ 下载 **Godot 4.7.2 Standard (非 .NET)**，解压。
2. 解压本项目 ZIP，在 Godot 项目管理器点击「导入」，选择 `project.godot`。
3. 首次等待资源导入完成后，点击右上角 **运行项目（F6/F5）**。Godot 从 `scenes/main.tscn` 加载整个世界。
4. 角色从青川町街区道路中央出生，`WASD` 移动、鼠标转镜头、`Shift` 跑步、滚轮缩放、`Esc` 释放鼠标。
5. 靠近指定地点按 `E`，便利店按 `J` 进行短时兼职，咖啡馆/生活商店按 `B` 购买；靠近公寓按 `E` 回家，再按 `Q/E` 返回。

**如果控制台提示 GDScript 解析错误，请将完整错误和行号发回；目前没有把通过引擎运行的结果当作已验证。**

## V0.3 已编写的模块

| 模块 | 文件 | 功能 |
|---|---|---|
| 时间 | `scripts/world_clock.gd` | 系统本地日期/时间，白天/夜间光照过渡与恢复时同步 |
| 街区 | `scripts/city_builder.gd` | 8 栋带门面/窗户/空调的建筑、十字路口、人行道、路灯、树木、NPC 背景移动 |
| 人物 | `scripts/player.gd` | CharacterBody3D、第三人称追随相机、镜头避障、四肢程序动画 |
| 存档 | `scripts/game_state.gd` | `user://` JSON，版本检查、备份、坏档回退、余额非负与重复工作结算防护 |
| 游戏流程 | `scripts/main.gd` | HUD、地点交互、便利店兼职、购买、家具、公寓进出、自动保存 |
| 引擎测试 | `tests/qa_headless.gd` | 时钟、经济幂等、结构、场景加载的引擎内自动测试（尚未执行） |

**已知限制：** 当前 V0.3 的地形、建筑、人物是原生网格/程序化场景，仅用于验证 Godot 项目底座；完整 GLB 建模、骨骼动画、室内装饰、天气/交通系统与完整职业小游戏尚未实现。现实时间依赖设备时钟，离线 NPC 目前不执行持久化世界模拟。V0.2 的旧 HTML 存档不能自动迁移到 Godot。

## 测试指令

在 Godot 可执行文件目录或 PATH 下：

```bash
# Linux / macOS（根据系统调整可执行名称）
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/qa_headless.gd
python tests/check_structure.py
```

Windows PowerShell：

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --headless --editor --path . --quit
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/qa_headless.gd
```

## 后续验收门槛

V0.4 才引入明确许可的 GLB 角色/建筑资源、PBR 材质、可复用建筑组件、角色骨骼动画和较完整的街道光照；一切视觉工作先通过截图与实机帧率验证。GitHub 的 `lifesim/` S0–S5 浏览器监督与本 Godot 工程分开，不直接宣称其验收通过。
