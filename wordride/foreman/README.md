# WordRide 免费监工 Foreman V0.1（本地试点）

此目录为 Python 标准库实现的轻量协调器；不需要 OpenAI API Key、付费云服务器或 GitHub Self-hosted Runner。

> **状态：核心协调器已实现，公开 CI 可验证离线故障注入；用户电脑上的 Ollama/Antigravity 登录与实际模型修复仍需本机运行测试。禁止把 CI 通过称作视觉最终验收。**

## 边界与授权

- **唯一目标文件**：`wordride/index.html`，当前正式页面 V2.2.1。存档 `v2.1.html`、日语词库和项目其他文件不允许修改。
- 每个任务在 `.foreman-state/worktrees/<task_id>` 创建独立 Git worktree；`.foreman-state/` 被 Git 忽略，不会提交任务目标、日志或私有记录。
- 默认命令不调用模型、不改游戏、不推送；只有显式 `run --execute` 才请求模型并应用限域提案。**AI 只返回 JSON 精确替换，不直接写源码或运行模型自选命令。**
- 修改必须位于用户选定的唯一源代码锚点附近；替换前逐字匹配且只出现一次。自动运行 JS 语法检查及 git diff 范围检查。
- 同一任务最多两轮有效修复。失败、额度不足或异常时保留状态，可检查原因；超过两次直接阻断。
- `submit --execute` 才通过你已登录的 GitHub CLI 提交独立分支并生成**草稿 PR**。不会合并主分支。
- `review` 会验证 QA 报告绑定到完全相同的分支与 Git 提交。技术成功状态为 `technical_pass_visual_pending`，并不是正式美术交付。
- **安全局限**：本工具不是操作系统沙盒；尤其 Windows 上第三方 CLI 的 `--sandbox` 可能因系统条件无效。需在独立低权限账户或隔离环境运行，且不要给此环境敏感密钥。慎用第三方 CLI 自动调用。

## 环境

- Windows 10/11，Python 3.10+、Node.js 22+、Git。
- 本地免费模型：安装 Ollama，执行 `ollama pull qwen3.5:4b`；需要模型兼容且硬件性能满足，可能有内存压力。
- 可选云端免费额度：安装并登录 Antigravity CLI `agy`。CLI 有额度和权限限制，不能保证长期免费无限使用。
- 可选 GitHub 送审：安装 GitHub CLI `gh` 并执行 `gh auth login`。不应把令牌粘贴给 AI。

## 一次实际任务

在 PowerShell 中切到仓库根目录：

```powershell
python wordride\foreman\foreman.py new --goal "确认桌面游戏镜头始终处于道路安全范围，并避免影响手机视角" --anchor "const eye=portrait?"
```

输出一个任务 ID。随后用该 ID 运行：

```powershell
python wordride\foreman\foreman.py status --id <任务ID>
python wordride\foreman\foreman.py run --id <任务ID> --backend ollama
```

第二条**只是预览**，不启动模型。只有明确允许代码候选时再执行：

```powershell
python wordride\foreman\foreman.py run --id <任务ID> --backend ollama --execute
```

如果模型返回 `no_change`，系统不会强行制造修改。要测试 Antigravity CLI，请先在隔离账户下确认权限与 CLI 版本，再改用 `--backend agy`。

检查 worktree 中的 diff、确认工作区未混入其他修改后，才考虑：

```powershell
python wordride\foreman\foreman.py submit --id <任务ID> --execute
```

GitHub 上 PR 的 WordRide QA 完成后，下载对应 `supervisor-report.json`，再执行：

```powershell
python wordride\foreman\foreman.py review --id <任务ID> --report "下载目录\supervisor-report.json"
```

如果报告属于其他 SHA/分支，程序将拒绝。若 QA 失败且尚有次数，可再次运行 `run --execute` 做下一轮；两轮结束自动停止。第三轮必须由人重新定义任务或修复验收规则，不能自动无限循环。

## 免费离线测试

```powershell
python -m unittest discover -s wordride/foreman/tests -v
```

这套测试会在临时 Git 仓库中注入可复现的模拟缺陷，用假模型验证边界、两轮限制与验收绑定，**不调用云端、不调用 Ollama、不修改当前正式网页**。GitHub Actions 会自动执行同样测试。

## 当前尚未完成的工作

1. 在用户电脑上测试 Ollama/Antigravity 实际返回 JSON 的成功率，记录日志与失败概率。
2. 将 PR 的截图证据自动关联到本地任务，并提供独立视觉审查后的人类最终确认。
3. RTX 3060 + Windows 浏览器真实性能与连续录屏测试；软件渲染的 rAF 不是设备 FPS。
4. 用至少 10 个真实或模拟可复现缺陷建立成功率、漏检、越权、人工耗时的评测基准。

不安装第三方模型也可以使用现有 GitHub Actions 自动测试；不需要也不应启动仓库中的付费 Codex 工作流。
