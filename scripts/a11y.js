#!/usr/bin/env node

'use strict';

const fs = require('fs');
const path = require('path');
const { AxeBuilder } = require('@axe-core/playwright');
const { chromium } = require('playwright-core');

const root = path.resolve(__dirname, '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'a11y.config.json'), 'utf8'));
const writeJson = process.argv.includes('--json');

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
    throw new Error(
      'Chrome or Chromium was not found. Set CHROME_PATH to the browser executable.'
    );
  }
  return executablePath;
}

function printViolations(url, violations) {
  const nodeCount = violations.reduce((total, violation) => total + violation.nodes.length, 0);
  console.log(` > ${url} - ${nodeCount} errors`);

  violations.forEach(violation => {
    console.error(`   ${violation.id} (${violation.impact || 'unknown'}): ${violation.help}`);
    console.error(`   ${violation.helpUrl}`);
    violation.nodes.forEach(node => {
      console.error(`     ${node.target.join(' ')}`);
      if (node.failureSummary) console.error(`     ${node.failureSummary.replace(/\n/g, '\n     ')}`);
    });
  });

  return nodeCount;
}

async function run() {
  const browser = await chromium.launch({
    executablePath: findBrowser(),
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage']
  });
  const context = await browser.newContext({ viewport: config.viewport });
  const reports = [];
  let errorCount = 0;

  try {
    console.log(`Running Axe on ${config.urls.length} URLs:`);
    for (const url of config.urls) {
      const page = await context.newPage();
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: config.timeout });
        if (config.wait) await page.waitForTimeout(config.wait);

        const result = await new AxeBuilder({ page })
          .withTags(config.tags)
          .analyze();
        reports.push({ url, violations: result.violations });
        errorCount += printViolations(url, result.violations);
      } catch (error) {
        errorCount += 1;
        reports.push({ url, error: error.message });
        console.error(` > ${url} - audit failed: ${error.message}`);
      } finally {
        await page.close();
      }
    }
  } finally {
    await context.close();
    await browser.close();
  }

  if (writeJson) {
    fs.writeFileSync(
      path.join(root, 'a11y-results.json'),
      `${JSON.stringify({ generatedAt: new Date().toISOString(), reports }, null, 2)}\n`
    );
  }

  if (errorCount > 0) {
    console.error(`\nAccessibility audit failed with ${errorCount} errors.`);
    process.exitCode = 1;
  } else {
    console.log(`\n✔ ${config.urls.length}/${config.urls.length} URLs passed`);
  }
}

run().catch(error => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
