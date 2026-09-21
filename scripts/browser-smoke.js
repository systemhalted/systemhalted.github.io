#!/usr/bin/env node

'use strict';

const fs = require('fs');
const { chromium } = require('playwright-core');

function findBrowser() {
  const candidates = [
    process.env.CHROME_PATH,
    process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
    process.env.PUPPETEER_EXECUTABLE_PATH,
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser'
  ].filter(Boolean);

  const executablePath = candidates.find(candidate => fs.existsSync(candidate));
  if (!executablePath) {
    throw new Error('Chrome or Chromium was not found. Set CHROME_PATH to the browser executable.');
  }
  return executablePath;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function run() {
  const browser = await chromium.launch({
    executablePath: findBrowser(),
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage']
  });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    const siteUrl = process.env.SITE_URL || 'http://127.0.0.1:4002/';
    await page.goto(siteUrl, { waitUntil: 'domcontentloaded' });

    assert(await page.locator('#interactive-overlays').count() === 0,
      'Interactive template was not materialized.');
    assert(await page.locator('#search-overlay').count() === 1,
      'Search overlay is missing from the live document.');
    assert(await page.locator('#shortcuts-overlay').count() === 1,
      'Shortcut overlay is missing from the live document.');

    const searchToggle = page.locator('.search-toggle').first();
    await searchToggle.focus();
    await searchToggle.click();
    await page.waitForFunction(() => document.activeElement && document.activeElement.id === 'search-input');
    assert(await page.locator('#search-overlay').getAttribute('aria-hidden') === 'false',
      'Search overlay did not open.');

    await page.keyboard.press('Escape');
    assert(await page.locator('#search-overlay').getAttribute('aria-hidden') === 'true',
      'Search overlay did not close.');
    assert(await searchToggle.evaluate(node => document.activeElement === node),
      'Focus did not return to the search trigger.');

    await page.keyboard.press('?');
    await page.waitForFunction(() => document.activeElement && document.activeElement.id === 'shortcuts-close');
    assert(await page.locator('#shortcuts-overlay').getAttribute('aria-hidden') === 'false',
      'Shortcut overlay did not open.');
    await page.keyboard.press('Escape');
    assert(await page.locator('#shortcuts-overlay').getAttribute('aria-hidden') === 'true',
      'Shortcut overlay did not close.');
    assert(await searchToggle.evaluate(node => document.activeElement === node),
      'Focus did not return after closing shortcut help.');

    const originalClass = await page.locator('html').getAttribute('class');
    await page.keyboard.press('t');
    const updatedClass = await page.locator('html').getAttribute('class');
    assert(originalClass !== updatedClass, 'Theme shortcut did not change the active theme.');

    console.log('Browser interaction smoke checks passed');
  } finally {
    await context.close();
    await browser.close();
  }
}

run().catch(error => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
