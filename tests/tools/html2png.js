// usage: node html2png.js IN.html OUT.png  — screenshot the page body with the installed Chromium
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [inp, out] = process.argv.slice(2);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1800, height: 400 }, deviceScaleFactor: 1 });
  await p.setContent(fs.readFileSync(inp, 'utf8'));
  await p.waitForTimeout(500);
  await p.locator('body').screenshot({ path: out });
  await b.close();
  console.log(out);
})();
