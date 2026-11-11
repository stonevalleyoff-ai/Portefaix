// Portefaix — L'ESSAI DE L'APPLICATION INSTALLABLE (outils/essai-pwa.js)
// Sert le dossier exporté sous /Portefaix/, comme GitHub Pages, et vérifie dans Chromium ce qui fait une application installable :
// un manifeste complet et ses icônes, un service worker qui s'installe et prend la page, et le jeu qui se relance et se joue seul
// **sans réseau**, une fois venu une première fois.
//   outils/construire.sh && node outils/essai-pwa.js site
// Il faut Playwright et son Chromium (ou NAVIGATEUR=chrome, pour le Chrome de la machine). Il sort avec le code 0 si tout passe.
'use strict';
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const SITE = path.resolve(process.argv[2] || 'site'), PORT = 8128, BASE = `http://127.0.0.1:${PORT}/Portefaix/`;
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png' };
let ok = true, n = 0;
const verif = (c, m) => { n++; ok = ok && !!c; console.log((c ? '  ✓ ' : '  ✗ ') + m); };

(async () => {
  let servis = 0;
  const serveur = http.createServer((req, res) => {
    const u = req.url.split('?')[0];
    if (!u.startsWith('/Portefaix/')) { res.writeHead(404); return res.end(); }
    const nom = u.slice('/Portefaix/'.length) || 'index.html', f = path.join(SITE, path.normalize(nom));
    if (!f.startsWith(SITE) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
    servis++;
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' });
    res.end(fs.readFileSync(f));
  });
  await new Promise(f => serveur.listen(PORT, '127.0.0.1', f));
  const nav = await chromium.launch({ channel: process.env.NAVIGATEUR || undefined, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await nav.newContext({ viewport: { width: 640, height: 360 } }), p = await ctx.newPage();
  const erreurs = [];
  p.on('pageerror', e => erreurs.push(e.message));
  const console_ = [];
  p.on('console', x => { console_.push(`${x.type()}: ${x.text()}`.slice(0, 300)); });
  const etat = () => p.evaluate(() => window.portefaix || null).catch(() => null);
  const attendre = async (test, ms = 60000) => { const t0 = Date.now(); while (Date.now() - t0 < ms) { const e = await etat(); if (e && test(e)) return e; await p.waitForTimeout(250); } return null; };
  const cliquer = async r => { const e = await attendre(x => x.reperes[r]); if (!e) throw new Error(`pas de « ${r} » à l'écran`); await p.mouse.click(e.reperes[r][0], e.reperes[r][1]); await p.waitForTimeout(200); };

  console.log('1. Le manifeste');
  await p.goto(BASE);
  const m = await p.evaluate(async () => { const l = document.querySelector('link[rel="manifest"]'); if (!l) return null; const r = await fetch(l.href); return { adresse: l.href, json: await r.json() }; });
  verif(m && m.json.name === 'Portefaix' && m.json.short_name && m.json.start_url === './' && m.json.scope === './' && m.json.lang === 'fr',
    'la page nomme son manifeste : Portefaix, en français, qui s\'ouvre et reste dans son dossier');
  verif(m && ['fullscreen', 'standalone'].includes(m.json.display) && m.json.orientation === 'landscape' && m.json.background_color && m.json.theme_color, 'plein écran, couché, aux couleurs de la nuit');
  const icones = m ? await p.evaluate(async ({ base, icones }) => Promise.all(icones.map(async i => { const r = await fetch(new URL(i.src, base)); const b = await createImageBitmap(await r.blob());
    return { tailles: i.sizes, usage: i.purpose, vu: `${b.width}x${b.height}` }; })), { base: m.adresse, icones: m.json.icons }) : [];
  verif(icones.length >= 4 && icones.every(i => i.tailles === i.vu) && icones.some(i => i.tailles === '512x512' && i.usage === 'maskable') && icones.some(i => i.tailles === '144x144'),
    `ses icônes se chargent à la taille dite (${[...new Set(icones.map(i => i.tailles))].join(', ')}), dont une qui se rogne en rond`);
  verif(await p.evaluate(() => document.documentElement.lang === 'fr' && !!document.querySelector('meta[name="theme-color"]') && !!document.querySelector('link[rel="apple-touch-icon"]')
    && !!document.querySelector('meta[name="apple-mobile-web-app-capable"]')), 'la page a ce qu\'il faut à un téléphone pour l\'ajouter à l\'écran d\'accueil');

  console.log('2. Le service worker');
  const charge = await attendre(e => e.etat === 'menu' && e.reperes.sans_compte, 90000);
  verif(charge, 'le jeu se charge, sur sa page de connexion');
  if (!charge) {       // sans le jeu, le reste ne dit rien : on dit ce que la page a vu, et on s'arrête là
    const webgl = await p.evaluate(() => { try { return !!document.createElement('canvas').getContext('webgl2'); } catch (e) { return String(e); } }).catch(e => String(e));
    console.log(`    WebGL 2 dans ce navigateur : ${webgl}`);
    for (const l of [...erreurs.map(e => 'erreur: ' + e), ...console_].slice(-15)) console.log('    ' + l);
    console.log(`\nÉCHEC : ${n} vérifications (le jeu ne s'est pas lancé dans ce navigateur)`);
    await nav.close(); serveur.close(); process.exit(1);
  }
  const sw = await p.evaluate(async () => { const r = await Promise.race([navigator.serviceWorker.ready, new Promise(f => setTimeout(() => f(null), 30000))]);
    return r && r.active ? { portee: r.scope, etat: r.active.state } : null; });
  verif(sw && sw.portee.endsWith('/Portefaix/') && ['activated', 'activating'].includes(sw.etat), 'le service worker s\'installe, pour le dossier du jeu');
  await p.reload();
  verif(await attendre(e => e.etat === 'menu') && await p.evaluate(() => !!navigator.serviceWorker.controller), 'à la visite suivante, c\'est lui qui sert la page');
  const garde = await p.evaluate(async () => { const noms = await caches.keys(); const f = []; for (const nm of noms) for (const r of await (await caches.open(nm)).keys()) f.push(r.url.split('/').pop()); return f; });
  verif(['index.html', 'index.js', 'index.wasm', 'index.pck', 'index.manifest.json'].every(f => garde.includes(f)), `il garde le jeu entier sur l'appareil (${garde.length} fichiers, dont le moteur et le paquet)`);

  console.log('3. Sans réseau');
  await ctx.setOffline(true);
  const avant = servis;
  await p.reload();
  verif(await attendre(e => e.etat === 'menu' && e.reperes.sans_compte) && servis === avant, 'réseau coupé, le jeu se relance quand même, sans rien demander au serveur');
  await cliquer('sans_compte'); await cliquer('seul');
  const partie = await attendre(e => e.etat === 'partie' && e.meubles >= 40, 30000);
  verif(partie && partie.quota > 0 && partie.pieces >= 6, `et l'on joue seul : la nuit commence, dans une maison de ${partie && partie.pieces} pièces et ${partie && partie.meubles} objets`);
  await ctx.setOffline(false);
  verif(!erreurs.length, 'aucune erreur dans la page' + (erreurs.length ? ' ; ' + erreurs.slice(0, 3).join(' | ') : ''));

  console.log(`\n${ok ? 'Tout passe' : 'ÉCHEC'} : ${n} vérifications`);
  await nav.close(); serveur.close();
  process.exit(ok ? 0 : 1);
})().catch(e => { console.error('ÉCHEC :', e.message); process.exit(1); });
