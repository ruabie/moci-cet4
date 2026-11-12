'use strict';
const { test, expect } = require('@playwright/test');
const fs = require('node:fs');

const GAME = '/wordride/v2.1.html';

test.beforeEach(async ({ page }) => {
  await page.goto(GAME, { waitUntil: 'load' });
  await expect(page.locator('#loading')).toHaveClass(/hide/, { timeout: 30_000 });
  await expect(page.locator('#error')).not.toHaveClass(/show/);
});

test('scene initializes in a real WebGL2-capable browser', async ({ page }, testInfo) => {
  await expect(page.locator('#gl')).toBeVisible();
  await expect(page.locator('#start')).toBeVisible();
  const scene = await page.locator('#gl').evaluate((canvas) => ({
    width: canvas.width,
    height: canvas.height,
    webgl2: !!canvas.getContext('webgl2')
  }));
  const sceneFile = testInfo.outputPath('webgl-scene.json');
  fs.writeFileSync(sceneFile, JSON.stringify(scene, null, 2));
  await testInfo.attach('webgl-scene.json', {
    path: sceneFile, contentType: 'application/json'
  });
  expect(scene.webgl2, 'WebGL2 context must exist').toBe(true);
  expect(scene.width).toBeGreaterThan(0);
  expect(scene.height).toBeGreaterThan(0);
  await page.screenshot({ path: testInfo.outputPath('scene-before-start.png'), fullPage: true });
  await testInfo.attach('scene-before-start.png', {
    path: testInfo.outputPath('scene-before-start.png'), contentType: 'image/png'
  });
});

test('ride, pause, quality, rain and hint controls respond', async ({ page }, testInfo) => {
  const errors = [];
  page.on('pageerror', err => errors.push(err.message));
  await page.locator('#start').click();
  await expect(page.locator('#startOverlay')).toHaveClass(/hide/);
  await expect(page.locator('#tiles')).not.toBeEmpty();
  // Wide desktop intentionally hides the touch keyboard; physical keys remain supported.
  await expect(page.locator('#keyboard .key')).toHaveCount(26);
  if (testInfo.project.name === 'mobile') {
    await expect(page.locator('#keyboard .key').first()).toBeVisible();
  } else {
    await expect(page.locator('#keyboard .key').first()).toBeHidden();
  }

  await page.locator('#pause').click();
  await expect(page.locator('#pause')).toHaveText('▶');
  await page.locator('#pause').click();
  await expect(page.locator('#pause')).toHaveText('Ⅱ');

  const quality = page.locator('#qualityToggle');
  await quality.click();
  await expect(quality).toContainText('LOW');
  await quality.click();
  await expect(quality).toContainText('HIGH');
  await quality.click();
  await expect(quality).toContainText('AUTO');

  await page.locator('#rainBtn').click();
  await expect(page.locator('#rainBtn')).toContainText('OFF');
  await page.locator('#rainBtn').click();
  await expect(page.locator('#rainBtn')).toContainText('ON');

  await page.locator('#hint').click();
  await expect(page.locator('#explain')).toContainText(/提示|已使用提示/);
  await expect(page.locator('#error')).not.toHaveClass(/show/);
  expect(errors, 'Uncaught browser script errors').toEqual([]);

  // Screenshot is evidence, NOT an automatically approved visual baseline.
  await page.screenshot({ path: testInfo.outputPath('playing.png'), fullPage: true });
  await testInfo.attach('playing.png', {
    path: testInfo.outputPath('playing.png'), contentType: 'image/png'
  });
});

test('desktop camera never starts inside the near-right building row', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'Desktop camera regression only');
  await page.goto(GAME + '?qa=1', { waitUntil: 'load' });
  await expect(page.locator('#loading')).toHaveClass(/hide/, { timeout: 30_000 });
  await page.locator('#start').click();
  const canvas = page.locator('#gl');
  await expect(canvas).toHaveAttribute('data-camera-mode', 'landscape');
  await expect(canvas).toHaveAttribute('data-camera-x', /-?\d+\.\d+/);
  const x = Number(await canvas.getAttribute('data-camera-x'));
  expect(Number.isFinite(x)).toBe(true);
  // Street spans |x| < ~5.8; buildings' near faces start beyond |x| ~6.8.
  expect(x, 'The desktop eye must not be embedded in a building').toBeGreaterThan(-5.5);
  expect(x, 'The desktop eye must not be embedded in a building').toBeLessThan(5.5);
  await page.screenshot({ path: testInfo.outputPath('desktop-road-visible.png'), fullPage: true });
  await testInfo.attach('desktop-road-visible.png', {
    path: testInfo.outputPath('desktop-road-visible.png'), contentType: 'image/png'
  });
});

test('measure animation-frame pacing without claiming GPU-level FPS', async ({ page }, testInfo) => {
  await page.locator('#start').click();
  const metrics = await page.evaluate(() => new Promise((resolve) => {
    const marks = [];
    const began = performance.now();
    const fallback = setTimeout(() => resolve({ timedOut: true, frames: marks.length }), 6_000);
    const tick = (now) => {
      marks.push(now);
      if (now - began < 2_000) return requestAnimationFrame(tick);
      clearTimeout(fallback);
      const times = marks.slice(1).map((t, i) => t - marks[i]).sort((a, b) => a - b);
      const quantile = (p) => times.length ? times[Math.min(times.length - 1, Math.floor((times.length - 1) * p))] : null;
      resolve({
        timedOut: false,
        frames: marks.length,
        elapsedMs: Math.round(now - began),
        rafFpsApprox: Math.round(marks.length * 1000 / (now - began)),
        p95FrameGapMs: quantile(0.95),
        maxFrameGapMs: times[times.length - 1] || null,
        devicePixelRatio: devicePixelRatio
      });
    };
    requestAnimationFrame(tick);
  }));
  const metricsFile = testInfo.outputPath('frame-pacing.json');
  fs.writeFileSync(metricsFile, JSON.stringify(metrics, null, 2));
  await testInfo.attach('frame-pacing.json', {
    path: metricsFile, contentType: 'application/json'
  });
  // The GitHub-hosted SwiftShader renderer has no representative GPU. Record
  // stalled/slow rAF samples as evidence, rather than gate release on its speed.
  if (metrics.timedOut || metrics.frames < 10) {
    console.warn('CI software-rendering frame sample is slow/inconclusive:', JSON.stringify(metrics));
  }
  // Establish pass/fail performance limits using hardware representative of users.
});
