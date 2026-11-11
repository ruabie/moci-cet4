# WordRide 自动监工 · QA V0.1

这个目录是 **WordRide V2.1 的浏览器自动验收试点**，不修改游戏页面，也不会自动发布、合并 PR 或调用收费 AI API。

## 自动执行内容

- 用 Chromium 的真实浏览器打开 `wordride/v2.1.html`，在桌面 1280×720 与手机 390×844 两种视口检查 WebGL2 初始化
- 模拟开始、暂停/恢复、画质切换、天气切换和提示操作
- 捕获开始界面及运行界面截图，异常时保留视频、trace 和 HTML 报告
- 记录动画帧间隔分布与近似 rAF 帧率，**不把 GitHub 共享机器上的 rAF 帧率冒充用户实际设备的 GPU 性能**
- 出现 WebGL 加载失败、操作失效或脚本异常时使 CI 失败

## 如何运行

提交修改后打开仓库的 **Actions → WordRide browser QA pilot**，或在 PR 的 Checks 选项卡查看结果。
下载 `wordride-qa-...` artifact，可以看到截图、报告及 `frame-pacing.json`。

本地（有 Node.js 24、Python 3 和浏览器安装权限的环境）：

```bash
cd wordride/qa
npm install
npx playwright install chromium
npm test
```

## 重要边界

- 本版是 **自动收集证据与基础功能门禁**，不是“AI 已确认画面美观”。
- GitHub Actions 软件渲染环境可能与 Windows 独显、iPhone 的表现不同；性能验收必须追加目标设备实测。
- 截图尚未建立经审核的视觉基准，后续可以将批准过的关键帧作为回归对比基准；不同 GPU/驱动可能造成像素级误差。
- 当前不会自动返工。自动返工需增加一个带权限边界的开发 Agent、可控 API 费用、最多重试次数，并保留人工发布许可。
- `OPENAI_API_KEY` 之类的密钥只能放进 GitHub Repository Secrets，禁止写进代码或 PR。先跑通不需要密钥的 QA，再引入自动代码修复。
