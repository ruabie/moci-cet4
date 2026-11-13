# LifeSim 真实浏览器验收接口

**不复用 WordRide 的骑行指标。** 当前源代码尚未接入，只有监工框架在运行，不能声称游戏已经通过测试。

## 必要界面和测试入口

为了让 Playwright 检查**真实游戏**而不是只读 HTML 文案，游戏页面需要稳定的测试标识。

`data-testid="world-canvas"`：可见 WebGL / WebGL2 场景。  
`data-testid="start-game"`：开始游戏按钮。  
`data-testid="enter-convenience-store"`：进入便利店。  
`data-testid="work-task"`：完成便利店工作任务，结算一次收入。  
`data-testid="buy-item"`：购买商品，扣除余额。  

在 `?qa=1` 时，只读对象 `window.__LIFESIM_QA__.getState()` 返回示例：

```json
{
  "sceneReady": true,
  "clockEpochMs": 1794500000000,
  "player": {"x": 1, "y": 0, "z": 2},
  "wallet": {"balance": 100},
  "lastJobId": "job-1",
  "saveVersion": 1
}
```

以上数字**仅作接口格式示例**，不是游戏实际数据。正常玩家进入游戏时可以完全不注入 QA 对象，但不能由它发钱、改时钟或绕过经济规则。

## 自动测试

- 所有阶段：桌面/手机游戏启动、WebGL 可见、实际截图、控制台错误。
- S1 标记为 done 后：本地时间误差不大于 90 秒、刷新后仍与当前真实时间对齐。
- S2 标记为 done 后：实体按键移动后玩家世界坐标变化。
- S3 标记为 done 后：便利店工作结算、相同完成记录不能重复结算。
- S4 标记为 done 后：购买扣款、余额非负、刷新后货币和存档版本恢复。
- S5：保留每次截图及后续实机 FPS、输入延迟、视角与素材检查。静态截图**只能作为证据**，不能自动通过整体美术质量。

未完成的里程碑测试显示为 skipped 和 pending；**skipped 不计入通过**。真实功能有问题则 CI 失败。

游戏源码接入后，工作流自动在桌面和手机 Chromium 中运行；缺少游戏源码时工作流只执行监工自身测试并明确输出 `waiting_for_source`。

## 手动本地运行（有实际源码以后）

```powershell
cd lifesim\qa
npm install
npx playwright install chromium
npm test
node score.cjs
```

要求 Python 3、Node.js 24，以及 Chromium 的 WebGL 支持。测试中禁止对第三方 URL 发请求，防止通过在线 CDN 掩盖首版独立原型缺陷。
