# LifeSim 免费 Foreman

源于 WordRide 的免费协调器，**已隔离成 LifeSim 专用**：`TARGET=lifesim/index.html`，状态目录为 `.lifesim-foreman-state/`，不使用 WordRide 的游戏代码或验收结果。

## 核心限制

- 每个任务有独立 Git worktree 和状态 JSON。
- 必须以源代码中只出现一次的 10–200 字符片段为锚点；AI 只能提议局部 JSON 精确替换。
- 只允许修改 `lifesim/index.html`，单任务最多两轮返工。
- `run` 没有 `--execute` 时仅预览，不调用模型。
- `submit` 没有 `--execute` 时不推送；执行后也只生成草稿 PR，不自动合并。
- `review` 仅接受属于同一 Git 分支与提交的 QA JSON，技术通过不等于美术最终交付。
- 可以选择本机 Ollama，或者 Antigravity CLI 免费额度；后者的 Windows 具体命令和权限尚未在你的电脑上验证，不应直接放入无人值守系统。
- 没有操作系统沙盒时，不能让第三方 AI CLI 访问重要私密文件或 SSH/账户凭据，优先在隔离的低权限用户环境测试。

## 使用前提

先将真实 LifeSim 原型提交为 `lifesim/index.html`；目前还没有源代码，所以现在不能生成有效的锚点修复任务。源代码接入后：

```powershell
python lifesim\foreman\foreman.py new --goal "修复现实时间在切后台后未同步的问题，不能改变游戏内的金币收入" --anchor "这里替换成游戏源码中唯一存在的具体片段"
python lifesim\foreman\foreman.py status --id 任务ID
python lifesim\foreman\foreman.py run --id 任务ID --backend ollama
```

最后一条是预览；真正启动模型和提交候选前，需要在本机安装测试并确认权限限制。不能从这份文档推断 Ollama/Antigravity 已经在用户电脑上运行成功。

## 离线测试

```powershell
python -m unittest discover -s lifesim/foreman/tests -v
```

使用临时 Git 仓库和模拟模型，不需要 API Key 或云端调用。
