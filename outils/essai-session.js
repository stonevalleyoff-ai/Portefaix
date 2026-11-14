// Portefaix — L'ESSAI DE LA SESSION COMMUNE (outils/essai-session.js)
// Dans Chromium, sur l'export web, contre le faux service (outils/faux-service.js). Le portail et les jeux du site gardent la session
// sous une même clé du navigateur (« stonevalley:session ») : connecté au portail, on l'est ici en arrivant ; ce qu'on fait ici, le
// portail le voit. On pose donc la clé comme le portail le ferait, et l'on regarde ce que le jeu en fait.
//   node outils/essai-session.js <dossier de l'export web>
'use strict';
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const { creer } = require('./faux-service.js');
const WEB = process.argv[2], PORT_JEU = 8129, PORT_SERVICE = 8128, CLE = 'stonevalley:session';
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.pck': 'application/octet-stream', '.png': 'image/png' };
let ok = true, n = 0;
const verif = (c, m) => { n++; ok = ok && !!c; console.log((c ? '  ✓ ' : '  ✗ ') + m); };

(async () => {
  if (!WEB || !fs.existsSync(path.join(WEB, 'index.wasm'))) { console.error('il faut le dossier de l\'export web (index.html, index.wasm, index.pck)'); process.exit(2); }
  const service = creer();
  await new Promise(f => service.serveur.listen(PORT_SERVICE, '127.0.0.1', f));
  const page = fs.readFileSync(path.join(WEB, 'index.html'), 'utf8').replace('"args":[]', `"args":["--service=http://127.0.0.1:${PORT_SERVICE}"]`);
  const jeu = http.createServer((req, res) => {
    const nom = req.url.split('?')[0] === '/' ? '/index.html' : req.url.split('?')[0], f = path.join(WEB, path.normalize(nom));
    if (!f.startsWith(WEB) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' });
    res.end(nom === '/index.html' ? page : fs.readFileSync(f));
  });
  await new Promise(f => jeu.listen(PORT_JEU, '127.0.0.1', f));
  const nav = await chromium.launch({ channel: process.env.NAVIGATEUR || undefined, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const renouvellements = () => service.journal.filter(l => l.includes('grant_type=refresh_token')).length;
  // un joueur qui arrive, avec dans son navigateur la session que le portail y aurait laissée (ou rien)
  const arriver = async commune => {
    const ctx = await nav.newContext({ viewport: { width: 640, height: 360 }, serviceWorkers: 'block' }), p = await ctx.newPage();
    await ctx.addInitScript(([cle, s]) => { if (s && !sessionStorage.getItem('posee')) { sessionStorage.setItem('posee', '1'); localStorage.setItem(cle, JSON.stringify(s)); } }, [CLE, commune]);
    await p.goto(`http://127.0.0.1:${PORT_JEU}/`);
    const etat = () => p.evaluate(() => window.portefaix || null);
    const attendre = async (test, ms = 60000) => { const t0 = Date.now(); let e;
      while (Date.now() - t0 < ms) { e = await etat(); if (e && test(e)) return e; await p.waitForTimeout(200); }
      return null; };
    const cliquer = async repere => { const e = await attendre(x => x.reperes[repere]); if (!e) throw new Error(`pas de « ${repere} » à l'écran`);
      await p.mouse.click(e.reperes[repere][0], e.reperes[repere][1]); await p.waitForTimeout(150); };
    const ecrire = async (repere, texte) => { await cliquer(repere); await p.keyboard.type(texte, { delay: 15 }); await p.waitForTimeout(150); };
    const gardee = () => p.evaluate(cle => JSON.parse(localStorage.getItem(cle) || 'null'), CLE);
    return { ctx, p, attendre, cliquer, ecrire, gardee };
  };
  const duPortail = (email, uid, n, dure) => ({ jeton: `jeton:${email}:${n}`, refresh: `reprise:${email}:${n}`, exp: Date.now() + dure * 1000, uid, email, pseudo: '' });

  console.log('1. Connecté au portail, on arrive dans le jeu');
  let j = await arriver(duPortail('ada@exemple.fr', 'u-ada', 1, 3000));
  verif(await j.attendre(e => e.etat === 'menu' && e.connecte && e.pseudo === 'Ada' && e.reperes.seul), 'on est connecté en arrivant, au menu, sous son pseudo : pas de page de connexion');
  verif(renouvellements() === 0, 'le jeton du portail, encore bon, sert tel quel : il n\'est pas renouvelé');
  let g = await j.gardee();
  verif(g && g.jeton === 'jeton:ada@exemple.fr:1' && g.refresh === 'reprise:ada@exemple.fr:1' && g.uid === 'u-ada' && g.email === 'ada@exemple.fr' && Math.abs(g.exp - Date.now() - 3000e3) < 120e3, 'la session commune reste celle du portail, avec la même échéance');
  await j.ctx.close();

  console.log('2. La session du portail a vieilli');
  j = await arriver(duPortail('bob@exemple.fr', 'u-bob', 1, -10));
  verif(await j.attendre(e => e.etat === 'menu' && e.connecte && e.pseudo === 'Bob'), 'un jeton périmé : le jeu le renouvelle, et l\'on est connecté');
  g = await j.gardee();
  verif(renouvellements() === 1 && g && g.refresh === 'reprise:bob@exemple.fr:2' && g.jeton === 'jeton:bob@exemple.fr:2' && g.exp > Date.now() + 3000e3, 'le renouvellement est écrit dans la session commune : le portail le prendra');

  console.log('3. Se déconnecter dans le jeu');
  await j.cliquer('compte');
  verif(await j.attendre(e => !e.connecte) && await j.gardee() === null, 'déconnecté ici : la session commune est effacée, le portail ne l\'est plus non plus');

  console.log('4. Se connecter dans le jeu');
  await j.cliquer('compte');
  await j.ecrire('email', 'ada@exemple.fr'); await j.ecrire('mdp', 'bon'); await j.cliquer('connecter');
  verif(await j.attendre(e => e.connecte && e.pseudo === 'Ada'), 'connecté dans le jeu');
  g = await j.gardee();
  verif(g && /^jeton:ada@exemple\.fr:/.test(g.jeton) && g.refresh && g.uid === 'u-ada' && g.email === 'ada@exemple.fr' && g.pseudo === 'Ada' && g.exp > Date.now() + 3000e3, 'la session est écrite sous la clé commune, dans la forme que lit le portail : on y est connecté aussi');
  await j.ctx.close();

  console.log('5. Une session du portail qui ne vaut plus rien');
  j = await arriver({ jeton: 'jeton:personne@exemple.fr:1', refresh: 'perimee', exp: Date.now() - 10e3, uid: 'u-x', email: 'personne@exemple.fr', pseudo: '' });
  verif(await j.attendre(e => e.etat === 'menu' && !e.connecte && e.reperes.email && !e.refus) && await j.gardee() === null, 'pas connecté, la page de connexion, sans message d\'erreur ; la session morte est effacée');
  await j.ctx.close();

  await nav.close(); jeu.close(); service.serveur.close();
  console.log(ok ? `\nTout passe : ${n} vérifications` : `\nDes échecs (${n} vérifications)`);
  process.exit(ok ? 0 : 1);
})().catch(e => { console.error(e); process.exit(1); });
