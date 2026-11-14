# 同频之城 / 青川町 V0.4 视觉升级 Alpha

本工程基于 V0.3.2 Godot 4.7.2 可运行版本，属于**美术迭代候选**，不是成品城市或精致开放世界。

## 当前目标与取舍

- 保持真实设备时间的日期与昼夜同步；不改变收益结算和备份存档协议。
- 采用原创程序化贴图（`art/textures/`）和手工细化的商店、阳台、街具、远景构件；不使用外链 CDNs。
- 玩家从方块改为可动的关节式风格化人物（非骨骼蒙皮 GLB）；手臂与腿具有独立关节，镜头具有物理遮挡检测。
- 街景增加商店雨棚、阳台、花箱、自行车、铺装和远景。此阶段仍未制作完整室内场景和多职业体系。

## 开始运行

下载 Godot **4.7.2-stable**（当前项目固定稳定版本），在 Godot 项目管理器选择包含 `project.godot` 的文件夹，按 F5 运行。Windows 操作：WASD 移动，鼠标旋转，Shift 跑步，E 交互，J 便利店兼职，B 购买，Q 从公寓返回；Esc 释放鼠标。可在离线状态使用，不消耗付费模型 API。

## 质量验证

```
python tests/check_structure.py
python tests/check_delimiters.py
python tests/check_regressions.py
python tests/check_visual_upgrade.py
# 下列两步需要 Godot 4.7.2 引擎
Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --import --quit
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/qa_headless.gd
```

GitHub Actions 会执行 GDScript 导入和实际渲染截图，并保留构建日志；**CI 通过不等于画面审美通过，更不代表 RTX 3060 真机 60 FPS 已验证**。若 GH CI 尚未执行，状态保持待引擎验证。

## 素材归属和限制

纹理为本项目脚本算法生成的原创灰度图片，程序几何体和人物造型为本项目代码生成，不引用外部受限模型或影视角色。不存在正式 PBR 扫描建模、骨骼动画文件或高精度城市资产。V0.4 后续必须补真实尺度 GLB 素材与角色绑定，并且逐一检查来源许可、真机性能、脚滑问题。

## 无破坏性存档变更

延续 `SAVE_VERSION=1` 和 `user://same_time_city_v03.json`，已存在的 V0.3 玩家存档自动使用同一版本读取；首次游玩默认出生点位于便利店附近的人行道。测试使用临时路径，不修改真实玩家存档。