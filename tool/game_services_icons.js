// Renders Play Games / Game Center icons for 99 Numbers' leaderboards and
// achievements. Usage: node icons.js <outDir>
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const outDir = process.argv[2];
const FONT = "'Arial Black','Segoe UI Black',Arial,sans-serif";

const text = (s, y, size, fill, extra = '') =>
  `<text x="512" y="${y}" font-family="${FONT}" font-size="${size}" font-weight="900" fill="${fill}" text-anchor="middle" dominant-baseline="central" ${extra}>${s}</text>`;

const rays = (n = 16) => {
  let r = '';
  for (let i = 0; i < n; i++) {
    const a1 = (i / n) * Math.PI * 2, a2 = a1 + Math.PI / n;
    const p = (a) => `${512 + Math.cos(a) * 900},${512 + Math.sin(a) * 900}`;
    r += `<polygon points="512,512 ${p(a1)} ${p(a2)}" fill="#fff" opacity="0.07"/>`;
  }
  return r;
};

let bgId = 0;
const bg = (light, dark) => { const id = "bg" + (++bgId); return `
  <defs><radialGradient id="${id}" cx="50%" cy="38%" r="80%">
    <stop offset="0" stop-color="${light}"/><stop offset="1" stop-color="${dark}"/>
  </radialGradient></defs>
  <rect width="1024" height="1024" fill="url(#${id})"/>${rays()}`; };

// ---- glyphs (drawn in `c`, on a white medal) --------------------------------
const glyph = {
  grid: (c) => {
    let g = '';
    for (let r = 0; r < 3; r++) for (let k = 0; k < 3; k++) {
      const x = 317 + k * 135, y = 317 + r * 135;
      g += `<rect x="${x}" y="${y}" width="120" height="120" rx="18" fill="${c}"/>
        <path d="M${x + 30} ${y + 62} l22 22 l40 -44" stroke="#fff" stroke-width="16" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
    }
    return g;
  },
  level: (n) => (c) => `
    <path d="M512 270 l70 80 h-45 v40 h-50 v-40 h-45 z" fill="${c}"/>
    ${text('LV', 445, 90, c)}${text(n, 600, 230, c)}`,
  eye: (c) => `
    <path d="M262 512 Q512 262 762 512 Q512 762 262 512 Z" fill="${c}"/>
    <circle cx="512" cy="512" r="118" fill="#fff"/>
    <circle cx="512" cy="512" r="82" fill="${c}"/>
    ${text('7', 516, 110, '#fff')}`,
  trophy: (c) => `
    <path d="M392 300 C300 300 300 440 410 460" stroke="${c}" stroke-width="34" fill="none"/>
    <path d="M632 300 C724 300 724 440 614 460" stroke="${c}" stroke-width="34" fill="none"/>
    <path d="M372 280 H652 V430 Q652 590 512 600 Q372 590 372 430 Z" fill="${c}"/>
    <rect x="482" y="596" width="60" height="80" fill="${c}"/>
    <rect x="402" y="670" width="220" height="62" rx="14" fill="${c}"/>
    ${text('11', 430, 120, '#fff')}`,
  flame: (c) => `
    <path d="M512 250 C610 350 700 420 668 570 C645 690 570 750 512 750 C430 750 352 690 352 580 C352 500 405 465 428 392 C458 440 478 462 500 466 C482 380 470 318 512 250 Z" fill="${c}"/>
    ${text('x10', 610, 120, '#fff')}`,
  calendar: (n, tc = '#fff') => (c) => `
    <rect x="312" y="300" width="400" height="420" rx="46" fill="${c}"/>
    <rect x="312" y="300" width="400" height="100" rx="46" fill="#000" opacity="0.18"/>
    <rect x="392" y="268" width="36" height="80" rx="18" fill="${c}" stroke="#fff" stroke-width="10"/>
    <rect x="596" y="268" width="36" height="80" rx="18" fill="${c}" stroke="#fff" stroke-width="10"/>
    ${text(n, 572, n.length > 1 ? 190 : 230, tc)}`,
  stopwatch: (n, tc = '#fff') => (c) => `
    <rect x="472" y="262" width="80" height="54" rx="12" fill="${c}"/>
    <rect x="497" y="300" width="30" height="50" fill="${c}"/>
    <rect x="660" y="330" width="40" height="70" rx="12" fill="${c}" transform="rotate(40 680 365)"/>
    <circle cx="512" cy="550" r="200" fill="${c}"/>
    <circle cx="512" cy="550" r="168" fill="none" stroke="${tc}" stroke-width="12" opacity="0.5"/>
    ${text(n, 556, 170, tc)}`,
  zen: (c) => `
    ${text('ZEN', 360, 90, c)}
    ${text('3:00', 505, 180, c)}
    <path d="M392 670 Q452 630 512 670 Q572 710 632 670" stroke="${c}" stroke-width="22" fill="none" stroke-linecap="round"/>`,
  games: (c) => `
    ${text('100', 470, 210, c)}
    <rect x="352" y="590" width="320" height="130" rx="65" fill="${c}"/>
    <rect x="404" y="643" width="70" height="24" rx="8" fill="#fff"/>
    <rect x="427" y="620" width="24" height="70" rx="8" fill="#fff"/>
    <circle cx="590" cy="636" r="18" fill="#fff"/><circle cx="628" cy="674" r="18" fill="#fff"/>`,
};

// Achievement: full-bleed colored square + white medal (circle-safe for
// Game Center's round mask).
const medal = (light, dark, g) => `
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
    ${bg(light, dark)}
    <circle cx="512" cy="530" r="378" fill="#000" opacity="0.18"/>
    <circle cx="512" cy="512" r="378" fill="#fff"/>
    <circle cx="512" cy="512" r="352" fill="none" stroke="${dark}" stroke-width="14" opacity="0.35"/>
    ${g(dark)}
  </svg>`;

// Leaderboard: bigger white glyph + caption, no medal.
const board = (light, dark, inner, caption) => `
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
    ${bg(light, dark)}
    ${inner(dark)}
    ${text(caption, 830, caption.length > 8 ? 84 : 104, '#fff', 'letter-spacing="4"')}
  </svg>`;

const boardGlyph = {
  classic: (d) => `
    <rect x="292" y="190" width="440" height="440" rx="70" fill="#000" opacity="0.2" transform="translate(0 16)"/>
    <rect x="292" y="190" width="440" height="440" rx="70" fill="#fff" stroke="#1B5E20" stroke-width="26"/>
    ${text('99', 418, 240, '#D81B60')}`,
  daily: (d) => `<g transform="translate(0 -110)">${glyph.calendar('99', d)('#fff')}</g>`,
  zen: (d) => `${text('1→99', 400, 220, '#fff')}
    <path d="M332 560 Q422 500 512 560 Q602 620 692 560" stroke="#fff" stroke-width="30" fill="none" stroke-linecap="round"/>`,
  timeAttack: (d) => `<g transform="translate(0 -110)">${glyph.stopwatch('60', d)('#fff')}</g>`,
};

const leaderboards = {
  lb_classic: board('#66BB6A', '#2E7D32', boardGlyph.classic, 'CLASSIC'),
  lb_daily: board('#FFA726', '#E65100', boardGlyph.daily, 'DAILY'),
  lb_zen: board('#26A69A', '#00695C', boardGlyph.zen, 'ZEN'),
  lb_time_attack: board('#EF5350', '#B71C1C', boardGlyph.timeAttack, 'TIME ATTACK'),
};

const achievements = {
  first_clear: medal('#64B5F6', '#1565C0', glyph.grid),
  level_4: medal('#81C784', '#2E7D32', glyph.level('4')),
  level_7: medal('#4DD0E1', '#00838F', glyph.eye),
  champion: medal('#FFD54F', '#F57F17', glyph.trophy),
  combo_10: medal('#FF8A65', '#D84315', glyph.flame),
  streak_3: medal('#FFB74D', '#EF6C00', glyph.calendar('3')),
  streak_7: medal('#F48FB1', '#AD1457', glyph.calendar('7')),
  zen_180: medal('#4DB6AC', '#00695C', glyph.zen),
  time_attack_40: medal('#E57373', '#C62828', glyph.stopwatch('40')),
  games_100: medal('#9575CD', '#4527A0', glyph.games),
};

(async () => {
  const exe = 'C:/Users/Hi/AppData/Local/ms-playwright/chromium_headless_shell-1248/chrome-headless-shell-win64/chrome-headless-shell.exe';
  const browser = await chromium.launch({ executablePath: exe });
  const all = { ...leaderboards, ...achievements };
  for (const size of [512, 1024]) {
    const dir = path.join(outDir, size === 512 ? 'play_512' : 'gamecenter_1024');
    fs.mkdirSync(dir, { recursive: true });
    const page = await browser.newPage({ viewport: { width: size, height: size } });
    for (const [name, svg] of Object.entries(all)) {
      const sized = svg.replace('<svg ', `<svg width="${size}" height="${size}" `);
      await page.setContent(`<html><body style="margin:0">${sized}</body></html>`);
      await page.screenshot({ path: path.join(dir, name + '.png'), omitBackground: false });
    }
    await page.close();
  }
  // Contact sheet for review, with Game Center's circular mask previewed.
  const page = await browser.newPage({ viewport: { width: 1100, height: 900 } });
  const cells = Object.entries(all).map(([n, s]) =>
    `<div style="text-align:center;font:12px sans-serif"><div style="width:200px;height:200px;${n.startsWith('lb_') ? '' : 'border-radius:50%;'}overflow:hidden">${s.replace('<svg ', '<svg width="200" height="200" ')}</div>${n}</div>`).join('');
  await page.setContent(`<body style="margin:10px;display:grid;grid-template-columns:repeat(5,210px);gap:10px">${cells}</body>`);
  await page.screenshot({ path: path.join(outDir, '..', 'icons_preview.png'), fullPage: true });
  await browser.close();
})();
