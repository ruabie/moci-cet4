# V0.5 QA 状态（候选包）

静态检查：本地 `python3 tests/check_regressions.py`、`check_delimiters.py`、`check_authored_assets.py`；游戏引擎侧 `tests/qa_headless.gd` 新增 rig 验证。

**不宣称通过 Godot 引擎测试**：当前容器中没有 Godot 可执行文件；必须通过 CI 真实导入和实例化 GLB，截图人工评估后才能升级验收状态。

重点阻断：如果 Skeleton3D 缺少命名骨骼，或街道没有显示新模型，停止交付；如 Godot 导入警告，修复而不是关闭检查。