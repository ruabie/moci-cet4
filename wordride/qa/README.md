# WordRide 自动监工 V0.2

## 当前已实现（不需要付费 API）

1. 每次改动 WordRide 后，在桌面 1280×720、手机 390×844 的 Chromium WebGL2 环境执行测试。
2. 记录桌面与手机运行截图、镜头安全范围、交互行为和帧时间诊断数据。
3. `.github/workflows/wordride-qa.yml` 自动调用 `supervisor.cjs` 汇总 Playwright JSON 结果，生成 `test-results/supervisor-report.md` 与 `.json`，并写入 GitHub Actions 工作摘要。
4. 证据丢失、重要测试失败或数量不符时，技术验收不能通过。
5. **技术通过不代表画面精美、骑行动作自然或真机性能达标。** 这些独立证据不足时不允许把它们标为合格。

## 已提交、默认不触发付费的 Codex 修复入口

工作流：`.github/workflows/wordride-codex-autofix.yml`。

激活自动修复需要仓库拥有者分别完成：
- 在 Settings → Secrets and variables → Actions → Secrets 中设置 `OPENAI_API_KEY`。**绝不将密钥提交到仓库或聊天。**
- 在同处 Variables 中创建 `WORDRIDE_AUTOFIX_ENABLED=true`。不设置变量时不会因 CI 失败自动触发付费 Agent。
- 在 Settings → Actions → General 中，确认 Workflow permissions 允许 GitHub Actions 创建 Pull Requests；若被策略禁止，自动发布 PR 会失败，但原代码不会被自动覆盖。
- 在 API 账户里设置预算/用量提醒（仓库工作流本身不强制 OpenAI 费用上限）。

自动流程：
1. 只有来自 `main` 分支 **push** 的 WordRide QA 失败，才会自动进入 Codex 生成任务。不信任来自 fork/PR 的触发源。
2. 单次运行只允许一次 Codex 修复尝试，没有无限重试，也不自动合并。
3. Codex 只允许修改 `wordride/v2.1.html`；日志中的任何指令均视为不可信数据。
4. 生成任务仅有 read 权限和受限 Codex 沙盒；修复结果作为 `codex.patch` artifact。
5. 独立发布任务没有 API 密钥，仅在补丁通过路径与 Git 检查后创建**草稿 PR**。
6. 发布任务显式触发 WordRide QA（使用 GitHub Token 创建的 PR 本身通常不会触发另一套 PR 工作流）。
7. 自动测试通过后仍需独立视觉审核与目标设备测试，最终决定是否合并。

可在 Actions → **WordRide bounded Codex repair** 手动运行；没有 API 密钥时只显示配置提示，不调用任何模型。

## 查看结果

- GitHub Actions → **WordRide browser QA pilot** → 运行记录 → **Summary** 看技术报告。
- 下载 `wordride-qa-<run-id>` artifact：包含 `supervisor-report.md`、截图、帧时间 JSON 与异常 Trace。
- 本地执行：`cd wordride/qa && npm install && npx playwright install chromium && npm test && node supervisor.cjs`。

## 剩余验收条件

- 在你的 Windows 独显设备和代表性手机上测帧时间、输入延迟、骑行动画方向。
- 建立经认可的关键帧参考图，随后才能独立评价真实的建筑遮挡、建模、材质与场景变化。
- 对每次 Codex 修改保留前后截图对比；任何测试不足、质量倒退或超出修改范围的补丁不得自动发布。

## 独立视觉审核（已提交代码，默认关闭）

新增工作流 `.github/workflows/wordride-visual-review.yml`，通过另外一个只读 Codex 任务接收 QA 实际生成的桌面/手机截图，输出 JSON 审核意见并在内部 PR 下留言。

- 将 GitHub Actions 变量 `WORDRIDE_VISUAL_REVIEW_ENABLED` 设为 `true` 才会调用付费图像审核；继续复用仓库 Secret `OPENAI_API_KEY`。
- 仅处理来自本仓库已成功的 WordRide QA；从主分支读取审核规则，截图为不可信数据。
- 审核 Agent 采用 `:read-only` 权限，不能自行改代码；与修复 Agent 隔离。
- 对看得见的建筑遮挡、画面异常、UI 可读性提出意见。**两张静态截图不能证明游戏帧率、动画方向、交互延迟或整体街景多样性合格。**
- 输出报告只作为独立的审核证据，不自动宣称项目完工，也不自动合并 PR。
