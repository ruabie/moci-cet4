'use strict';

// Deterministic QA summarizer; no AI key or network required.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname);
const resultsDir = path.join(root, 'test-results');
const input = path.join(resultsDir, 'qa-results.json');

function collectTests(suites, entries = []) {
  for (const suite of suites || []) {
    for (const spec of suite.specs || []) {
      for (const test of spec.tests || []) {
        entries.push({
          title: spec.title,
          project: test.projectName || 'unknown',
          outcome: test.status || test.outcome || 'unknown',
          results: (test.results || []).map(r => ({
            status: r.status,
            durationMs: r.duration,
            errors: (r.errors || []).map(e => String(e.message || e.value || '').slice(0, 700))
          }))
        });
      }
    }
    collectTests(suite.suites, entries);
  }
  return entries;
}

function inventory(dir, base = dir, output = []) {
  if (!fs.existsSync(dir)) return output;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) inventory(full, base, output);
    else if (entry.isFile()) output.push(path.relative(base, full).replace(/\\/g, '/'));
  }
  return output;
}

function writeReport(result, text) {
  fs.mkdirSync(resultsDir, { recursive: true });
  fs.writeFileSync(path.join(resultsDir, 'supervisor-report.json'), JSON.stringify(result, null, 2) + '\n');
  fs.writeFileSync(path.join(resultsDir, 'supervisor-report.md'), text);
  if (process.env.GITHUB_STEP_SUMMARY) {
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
  }
}

let json;
try {
  json = JSON.parse(fs.readFileSync(input, 'utf8'));
} catch (error) {
  const reason = 'Playwright JSON report unavailable: ' + String(error.message);
  writeReport({ status: 'blocked', reasons: [reason] },
    '# WordRide 自动监工\n\n**无法验收**：' + reason + '\n');
  process.exit(1);
}

const tests = collectTests(json.suites);
const counts = { passed: 0, failed: 0, flaky: 0, skipped: 0, other: 0 };
for (const test of tests) {
  if (test.outcome === 'expected') counts.passed++;
  else if (test.outcome === 'unexpected') counts.failed++;
  else if (test.outcome === 'flaky') counts.flaky++;
  else if (test.outcome === 'skipped') counts.skipped++;
  else counts.other++;
}
const files = inventory(resultsDir);
const evidence = {
  desktopPlaying: files.some(f => /playing\.png$/i.test(f) && f.includes('desktop')),
  mobilePlaying: files.some(f => /playing\.png$/i.test(f) && f.includes('mobile')),
  desktopRoad: files.some(f => /desktop-road-visible\.png$/i.test(f)),
  frameMetrics: files.filter(f => /frame-pacing\.json$/i.test(f)).length,
  screenshots: files.filter(f => /\.png$/i.test(f)).length,
};
// Bind reports to the exact PR head, not just a generic passing CI run.
let sourceHeadSha = process.env.GITHUB_SHA || null;
try {
  const ev = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  if (ev.pull_request && ev.pull_request.head && ev.pull_request.head.sha) {
    sourceHeadSha = ev.pull_request.head.sha;
  }
} catch (_) { /* Local runs may not have a GitHub event file. */ }
const sourceBranch = process.env.GITHUB_HEAD_REF || process.env.GITHUB_REF_NAME || null;
const blockers = [];
if (counts.failed || counts.other) blockers.push('Failed or indeterminate browser tests');
if (counts.passed < 10) blockers.push('Fewer than ten accepted live-entry smoke tests');
if (!evidence.desktopPlaying || !evidence.mobilePlaying || !evidence.desktopRoad) {
  blockers.push('Missing desktop/mobile road-scene screenshot evidence');
}
if (evidence.frameMetrics < 2) blockers.push('Missing frame pacing samples');
for (const required of [
  'current published entry is the version under test',
  'desktop camera never starts inside the near-right building row',
  'motion signals advance together when riding, not while paused'
]) {
  if (!tests.some(t => t.title === required && t.outcome === 'expected')) {
    blockers.push('Required live-entry QA missing or failing: ' + required);
  }
}
const warnings = [];
if (counts.flaky) warnings.push('Flaky browser cases require investigation');
warnings.push('Visual aesthetics are NOT automatically approved');
warnings.push('SwiftShader performance is NOT representative of Windows GPU or iPhone');
const status = blockers.length ? 'blocked' : 'technical-pass';
const report = {
  status, sourceBranch, sourceHeadSha, targetPath: 'wordride/index.html',
  counts,
  evidence,
  blockers,
  warnings,
  testResults: tests,
  source: 'Playwright Chromium software renderer'
};
const rows = tests.map(t => '| ' + t.project + ' | ' + t.title.replace(/\|/g, '/') + ' | ' + t.outcome + ' |').join('\n');
const md = [
  '# WordRide 自动监工验收报告',
  '',
  '**自动技术门禁：' + (blockers.length ? '未通过' : '通过') + '**。画面美学和目标设备性能仍待独立审核。',
  '',
  '| 通过 | 失败 | 不稳定 | 跳过 |',
  '|---:|---:|---:|---:|',
  '| ' + counts.passed + ' | ' + counts.failed + ' | ' + counts.flaky + ' | ' + counts.skipped + ' |',
  '',
  '## 证据',
  '- 桌面运行截图：' + (evidence.desktopPlaying ? '有' : '缺失'),
  '- 手机运行截图：' + (evidence.mobilePlaying ? '有' : '缺失'),
  '- 桌面道路截图：' + (evidence.desktopRoad ? '有' : '缺失'),
  '- 动画帧时间文件：' + evidence.frameMetrics,
  '',
  '## 阻断问题',
  blockers.length ? blockers.map(x => '- ' + x).join('\n') : '无自动技术阻断项。',
  '',
  '## 验收边界',
  warnings.map(x => '- ' + x).join('\n'),
  '',
  '## 测试明细',
  '| 平台 | 测试 | 结果 |',
  '|---|---|---|',
  rows || '| - | 没有测试记录 | blocked |',
  ''
].join('\n');
writeReport(report, md);
console.log('[WordRide supervisor] ' + status + ' | ' + counts.passed + ' passed, ' + counts.failed + ' failed');
if (blockers.length) process.exitCode = 1;
