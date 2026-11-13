'use strict';
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests-browser',
  timeout: 45_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [
    ['list'],
    ['json', { outputFile: 'test-results/browser-results.json' }],
    ['html', { open: 'never', outputFolder: 'playwright-report' }]
  ],
  outputDir: 'test-results',
  use: {
    baseURL: 'http://127.0.0.1:4174',
    browserName: 'chromium',
    headless: true,
    launchOptions: {
      // CI software WebGL only; DO NOT infer Windows/phone FPS from this.
      args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']
    },
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    { name: 'desktop', use: { viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 } },
    { name: 'mobile', use: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true } }
  ],
  webServer: {
    command: 'python3 -m http.server 4174 --bind 127.0.0.1 --directory ../..',
    url: 'http://127.0.0.1:4174/lifesim/index.html',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000
  }
});
