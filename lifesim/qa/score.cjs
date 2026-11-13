'use strict';
// Do not call a partial LifeSim MVP "complete" because two smoke tests are green.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..', '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'lifesim/project.json'), 'utf8'));
const input = path.join(__dirname, 'test-results/browser-results.json');
const json = JSON.parse(fs.readFileSync(input, 'utf8'));

function collect(suites, out = []) {
  for (const suite of suites || []) {
    for (const spec of suite.specs || []) {
      for (const result of spec.tests || []) {
        out.push({title: spec.title, project: result.projectName, status: result.status});
      }
    }
    collect(suite.suites, out);
  }
  return out;
}
function inventory(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const item of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, item.name);
    if (item.isDirectory()) inventory(full, out);
    else out.push(full);
  }
  return out;
}
const cases = collect(json.suites);
const passed = cases.filter(x => x.status === 'expected');
const skipped = cases.filter(x => x.status === 'skipped');
const failed = cases.filter(x => x.status !== 'expected' && x.status !== 'skipped');
const reasons = [];
if (failed.length) reasons.push(failed.length + ' failed or indeterminate browser tests');
for (const device of ['desktop','mobile']) {
  for (const title of [
    'real standalone 3D game starts without external engine downloads',
    'desktop and mobile real scene screenshots are retained for review'
  ]) {
    if (!passed.some(x => x.project === device && x.title === title)) {
      reasons.push(device + ' core browser proof missing: ' + title);
    }
  }
}
const pending = manifest.milestones.filter(m => m.status !== 'done').map(m => m.id);
const active = manifest.milestones.filter(m => m.status === 'done').map(m => m.id);
const mapping = {
  S1: 'clock follows actual local wall time across foreground and return',
  S2: 'player moves in the actual world rather than a decorative canvas',
  S3: 'shop job credits wallet once per completed task',
  S4: 'purchases and saves conserve balance across reloads'
};
for (const id of active) {
  if (!mapping[id]) continue;
  for (const device of ['desktop','mobile']) {
    if (!passed.some(x => x.project === device && x.title === mapping[id])) {
      reasons.push('Claimed ' + id + ' milestone not accepted on ' + device);
    }
  }
}
const pngs = inventory(path.join(__dirname, 'test-results')).filter(f => f.endsWith('.png'));
if (pngs.length < 4) reasons.push('Missing screenshots from desktop/mobile real gameplay');

let headSha = process.env.GITHUB_SHA || null;
try {
  const e = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  if (e.pull_request && e.pull_request.head && e.pull_request.head.sha) headSha = e.pull_request.head.sha;
} catch (_) {}

const report = {
  project: 'lifesim', testedEntry: 'lifesim/index.html',
  sourceHeadSha: headSha,
  sourceBranch: process.env.GITHUB_HEAD_REF || process.env.GITHUB_REF_NAME || null,
  status: reasons.length ? 'blocked'
    : pending.length ? 'technical_partial_milestones_pending'
    : 'technical_pass_visual_pending',
  counts: {passed: passed.length, failed: failed.length, skipped: skipped.length},
  activeMilestones: active, pendingMilestones: pending,
  screenshotCount: pngs.length, blockers: reasons,
  visualApproved: false, targetDeviceFpsVerified: false, paidApiUsed: false
};
fs.mkdirSync(path.join(__dirname, 'test-results'), {recursive: true});
fs.writeFileSync(path.join(__dirname, 'test-results/acceptance-report.json'), JSON.stringify(report, null, 2) + '\n');
const summary = [
  '# LifeSim actual-browser supervisor',
  '',
  '**Status: ' + report.status + '**',
  'Game source: lifesim/index.html',
  'Passed: ' + passed.length + ' | Failed: ' + failed.length + ' | Skipped: ' + skipped.length,
  'Pending milestones: ' + (pending.join(', ') || 'none'),
  'Screenshots: ' + pngs.length,
  '',
  '## Blockers',
  ...(reasons.length ? reasons.map(x => '- ' + x) : ['None in current test stage']),
  '',
  'WARNING: a static screenshot and CI software WebGL renderer cannot prove final aesthetics or real GPU FPS.',
  ''
].join('\n');
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary);
console.log(summary);
if (reasons.length) process.exitCode = 1;
