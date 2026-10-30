const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const mode = process.argv[2] || 'stills';
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto('file://' + process.cwd() + '/ad.html');
  const fontsOk = await p.evaluate(() => window.ready);
  console.log('fonts loaded:', fontsOk);
  const grab = async (t, file) => {
    const data = await p.evaluate(t => { window.renderAt(t); return document.getElementById('c').toDataURL('image/png'); }, t);
    fs.writeFileSync(file, Buffer.from(data.split(',')[1], 'base64'));
  };
  if (mode === 'stills') {
    for (const t of [1.4, 3.0, 5.6, 7.7, 9.7]) await grab(t, `still_${t}.png`);
  } else {
    fs.mkdirSync('frames', { recursive: true });
    for (let i = 0; i < 300; i++) await grab(i / 30, `frames/${String(i).padStart(4, '0')}.png`);
  }
  console.log('errors', errs); await b.close();
})();
