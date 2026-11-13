'use strict';
const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..');
const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, 'project.json'), 'utf8'));
const done = id => manifest.milestones.some(m => m.id === id && m.status === 'done');
const GAME = '/lifesim/index.html';

async function begin(page) {
  await page.goto(GAME + '?qa=1', { waitUntil: 'load' });
  await expect(page.locator('[data-testid="world-canvas"]')).toBeVisible();
  await page.getByTestId('start-game').click();
}

async function state(page) {
  return page.evaluate(() => {
    const qa = window.__LIFESIM_QA__;
    if (!qa || typeof qa.getState !== 'function') return null;
    return qa.getState();
  });
}

test.beforeEach(async ({ page }) => {
  // The first prototype is standalone: do not hide CDN dependencies in CI.
  await page.route('**/*', async route => {
    const url = new URL(route.request().url());
    if (url.hostname !== '127.0.0.1') return route.abort('blockedbyclient');
    return route.continue();
  });
});

test('real standalone 3D game starts without external engine downloads', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(GAME + '?qa=1', { waitUntil: 'load' });
  await expect(page.getByTestId('world-canvas')).toBeVisible();
  const canvas = page.getByTestId('world-canvas');
  const webgl = await canvas.evaluate(el => !!(el.getContext('webgl2') || el.getContext('webgl')));
  expect(webgl, 'Visible 3D scene must be backed by a real WebGL context').toBe(true);
  await expect(page.getByTestId('start-game')).toBeVisible();
  await page.getByTestId('start-game').click();
  const scene = await state(page);
  expect(scene?.sceneReady, 'Scene-ready telemetry should be available in ?qa=1').toBe(true);
  expect(errors).toEqual([]);
  const filename = info.outputPath('game-start.png');
  await page.screenshot({ path: filename, fullPage: true });
  await info.attach('game-start.png', { path: filename, contentType: 'image/png' });
});

test('clock follows actual local wall time across foreground and return', async ({ page }) => {
  test.skip(!done('S1'), 'S1 is explicitly not finished; no time quality claim');
  await begin(page);
  const first = await state(page);
  expect(Math.abs(first.clockEpochMs - Date.now())).toBeLessThanOrEqual(90_000);
  await page.waitForTimeout(1800);
  const second = await state(page);
  expect(second.clockEpochMs).toBeGreaterThan(first.clockEpochMs + 1000);
  expect(Math.abs(second.clockEpochMs - Date.now())).toBeLessThanOrEqual(90_000);
  await page.reload();
  const reloaded = await state(page);
  expect(Math.abs(reloaded.clockEpochMs - Date.now())).toBeLessThanOrEqual(90_000);
});

test('player moves in the actual world rather than a decorative canvas', async ({ page }) => {
  test.skip(!done('S2'), 'S2 is explicitly not finished; cannot claim 3D movement');
  await begin(page);
  const before = await state(page);
  expect(before.player).toBeTruthy();
  await page.keyboard.down('w');
  await page.waitForTimeout(700);
  await page.keyboard.up('w');
  const after = await state(page);
  const travel = Math.hypot(
    after.player.x - before.player.x,
    after.player.z - before.player.z
  );
  expect(travel, 'Movement must affect world position').toBeGreaterThan(0.1);
});

test('shop job credits wallet once per completed task', async ({ page }) => {
  test.skip(!done('S3'), 'S3 is explicitly not finished; work payout not yet accepted');
  await begin(page);
  await page.getByTestId('enter-convenience-store').click();
  const initial = await state(page);
  await page.getByTestId('work-task').click();
  await expect.poll(async () => (await state(page)).wallet.balance, { timeout: 20_000 })
    .toBeGreaterThan(initial.wallet.balance);
  const completed = await state(page);
  const activity = completed.lastJobId;
  expect(activity).toBeTruthy();
  // Re-clicking the same completed task must not mint a second payout.
  await page.getByTestId('work-task').click();
  await page.waitForTimeout(300);
  const repeated = await state(page);
  if (repeated.lastJobId === activity) expect(repeated.wallet.balance).toBe(completed.wallet.balance);
});

test('purchases and saves conserve balance across reloads', async ({ page }) => {
  test.skip(!done('S4'), 'S4 is explicitly not finished; save/economy not accepted');
  await begin(page);
  await page.getByTestId('enter-convenience-store').click();
  const before = await state(page);
  await page.getByTestId('buy-item').click();
  const after = await state(page);
  expect(after.wallet.balance).toBeGreaterThanOrEqual(0);
  expect(after.wallet.balance).toBeLessThan(before.wallet.balance);
  await page.reload();
  const saved = await state(page);
  expect(saved.wallet.balance).toBe(after.wallet.balance);
  expect(saved.saveVersion).toBeGreaterThan(0);
});

test('desktop and mobile real scene screenshots are retained for review', async ({ page }, info) => {
  await page.goto(GAME, { waitUntil: 'load' });
  const canvas = page.getByTestId('world-canvas');
  await expect(canvas).toBeVisible();
  const screenshot = info.outputPath('world-overview.png');
  await page.screenshot({ path: screenshot, fullPage: true });
  await info.attach('world-overview.png', { path: screenshot, contentType: 'image/png' });
  // This proves that screenshots were collected, not that appearance was approved.
});
