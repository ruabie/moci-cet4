# LifeSim 跨对话交接协议（Handoff Protocol v1）

## 原则

1. **仓库为事实来源**：项目需求看 `lifesim/project.json`、开放 Issue、用户最近明确约束；候选成果看 PR 的真实 head/base SHA 和源码；是否通过看与该 SHA 一致的 CI 记录、截图、浏览器及实机证据。
2. **区分版本轨道**：`main` 上 HTML 的 `S0–S5` 与草稿分支 `lifesim/godot/` 的引擎开发不可相互替代。保留 upstream stacked PR 链，不因 PR 的版本号高就认为已合并、已发布。
3. **未知写未知**：`unverified`、`pending`、`blocked`、`passed`、`not_ready` 明确区分；静态脚本检查≠真实截图；CI 渲染≠Windows GPU 真机；用户反馈≠实际已修复。
4. **不擅自消除阻断**：验收状态只在有可复查的同一 SHA 证据后提升。PR/Issue 若已变化，重新核实再修改摘要，不猜测。
5. **费用与安全**：零新增费用；不调用付费 API、不添付费 Runner、不自动合并或公开发布、不修改其他项目；修复最多两轮并留证。

## 接班步骤（新聊天启动）

1. 读取 `HANDOFF.md`、`HANDOFF_STATE.json`、本协议。
2. 读取 `main:lifesim/project.json`；实查 `lifesim/index.html` 是否存在。
3. 查询最新 `LifeSim` PR，逐项检查最新候选的 `draft/state/head/base/head_sha`、代码、CI；检查 #10/#12/#18 的最新状态，及新阻断 Issue。
4. 对比快照是否过期：PR SHA 变化、问题关闭、验收状态有证据变化即视为旧快照，先更新；GitHub 不可访问时禁止将旧信息写成当前事实。
5. 选择**最优先未验收工作**，一次只推进一个可复验的改动，留截图/日志/运行结果及失败原因。
6. 完成该工作后更新人类可读交接、JSON、必要的 Issue/PR 记录；在回复中附链接与具体 SHA。

## 交班触发点

- 每次重要 PR 创建/更新、候选 SHA 更换或版本升级；
- 每次 CI、真实浏览器和实机验收状态发生实质变化；
- 每次用户提出持续有效的新约束、改变主要技术路线或验收标准；
- 当前聊天将切换、接近长度上限时；
- 监工检测到重大状态变化且**具备写入授权/权限**时。

未发生实质变化时无需重复生成提交。此协议不是异步执行器；如自动任务无法改写仓库，应记录通知，等有写权限的后续执行轮次更新。

## 更新数据规范

`HANDOFF_STATE.json`：
- `snapshotDate` 标记已核实的日期；
- `verifiedRepositoryFacts` 只放实际从 GitHub 查证的状态；
- `gates` 每项明确状态与理由；无证据严禁 `passed`；
- `nextActions` 是有顺序的待办，不是完成承诺；
- `handoff.monitorIntegration` 在没有读取并确认已有监工任务规则前保持 `not_verified`。

更新 `HANDOFF.md` 时同步修改对应 JSON 字段，至少包括：当前版本与 PR、最新候选 SHA、已完成证据、未完成/阻断、下一任务、日期。必要时保留快照历史在 GitHub commit history 中，无需不断复制历史全文。

## 结束一轮时的输出格式

- 当前可验证的最新候选：版本/PR/head SHA/是否草稿
- 本轮真实变更：文件/提交、测试证据链接
- 明确未通过/未执行：例如美术、Chrome WebGL、Windows FPS
- 下一步：一项最高优先级任务及其可判定的验收门槛
- 交接文件是否已同步：链接和提交 SHA；无法写入则明示失败

## 防止错误交付

永远不要因为交接文件写着“最新版本”，就跳过重新核对 GitHub。仅基于 `HANDOFF.md` 推断项目已达到用户要求的精美 3D 开放世界，视为交接失败。
