// Portefaix — L'ESSAI EN LIGNE (outils/essai-en-ligne.js)
// Trois navigateurs sur cette machine, trois comptes, un salon : Ada l'ouvre, Bob et Cléo y entrent par son code, Ada lance la nuit, et les
// trois se voient bouger. Les comptes et le salon passent par le faux service (outils/faux-service.js) ; la partie, elle, passe pour de
// bon d'un navigateur à l'autre, par WebRTC. Les clics vont où le jeu dit que sont ses boutons (window.portefaix.reperes).
// Il faut l'export web du jeu, et Playwright avec son Chromium :
//   outils/construire.sh
//   node outils/essai-en-ligne.js site [dossier où poser des images]
// Il sort avec le code 0 si tout passe.
'use strict';
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const { creer } = require('./faux-service.js');
const WEB = process.argv[2], IMAGES = process.argv[3] || null, PORT_JEU = 8127, PORT_SERVICE = 8126;
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.pck': 'application/octet-stream', '.png': 'image/png' };
let ok = true, n = 0;
const verif = (c, m) => { n++; ok = ok && !!c; console.log((c ? '  ✓ ' : '  ✗ ') + m); };

(async () => {
  if (!WEB || !fs.existsSync(path.join(WEB, 'index.wasm'))) { console.error('il faut le dossier de l\'export web (index.html, index.wasm, index.pck)'); process.exit(2); }
  const service = creer();
  await new Promise(f => service.serveur.listen(PORT_SERVICE, '127.0.0.1', f));
  // l'export, servi tel quel ; sa page lance le jeu avec « --service=… », pour qu'il parle au faux service
  const page = fs.readFileSync(path.join(WEB, 'index.html'), 'utf8').replace('"args":[]', `"args":["--service=http://127.0.0.1:${PORT_SERVICE}"]`);
  const jeu = http.createServer((req, res) => {
    const nom = req.url.split('?')[0] === '/' ? '/index.html' : req.url.split('?')[0], f = path.join(WEB, path.normalize(nom));
    if (!f.startsWith(WEB) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' });
    res.end(nom === '/index.html' ? page : fs.readFileSync(f));
  });
  await new Promise(f => jeu.listen(PORT_JEU, '127.0.0.1', f));
  verif(page.includes('--service='), 'la page lance le jeu sur le faux service');

  const nav = await chromium.launch({ channel: process.env.NAVIGATEUR || undefined, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist',
    '--disable-features=WebRtcHideLocalIpsWithMdns', '--autoplay-policy=no-user-gesture-required'] });
  const joueur = async nom => {
    const ctx = await nav.newContext({ viewport: { width: 640, height: 360 } }), p = await ctx.newPage();
    const erreurs = [];
    p.on('pageerror', e => erreurs.push(e.message));
    await p.goto(`http://127.0.0.1:${PORT_JEU}/`);
    const etat = () => p.evaluate(() => window.portefaix || null);
    const attendre = async (quoi, test, ms = 30000) => { const t0 = Date.now(); let e;
      while (Date.now() - t0 < ms) { e = await etat(); if (e && test(e)) return e; await p.waitForTimeout(200); }
      return null; };
    const cliquer = async repere => { const e = await attendre(repere, x => x.reperes[repere]); if (!e) throw new Error(`${nom} : pas de « ${repere} » à l'écran`);
      await p.mouse.click(e.reperes[repere][0], e.reperes[repere][1]); await p.waitForTimeout(150); };
    const ecrire = async (repere, texte) => { await cliquer(repere); await p.keyboard.type(texte, { delay: 15 }); await p.waitForTimeout(150); };
    const photo = async quoi => { if (IMAGES) await p.screenshot({ path: path.join(IMAGES, `${quoi}-${nom}.png`), timeout: 20000 }).catch(() => {}); };
    return { nom, p, etat, attendre, cliquer, ecrire, photo, erreurs };
  };
  console.log('0. Créer un compte, mot de passe oublié');
  {
    const dan = await joueur('dan');
    verif(await dan.attendre('la page de connexion', e => e.etat === 'menu' && e.reperes.vers_creer && e.reperes.vers_oubli, 60000), 'la page de connexion propose de créer un compte, et « Mot de passe oublié ? »');
    // créer un compte
    await dan.cliquer('vers_creer');
    await dan.ecrire('c_pseudo', 'Eve'); await dan.ecrire('c_email', 'eve@exemple.fr'); await dan.ecrire('c_mdp', 'court'); await dan.cliquer('c_creer');
    verif(await dan.attendre('le refus', e => /6 caractères/.test(e.erreur_compte)) && !service.comptes['eve@exemple.fr'], 'un mot de passe trop court : refusé, rien n\'est créé');
    await dan.cliquer('c_mdp'); await dan.p.keyboard.press('Control+A'); await dan.p.keyboard.type('motdepasse', { delay: 15 }); await dan.cliquer('c_creer');
    verif(await dan.attendre('la confirmation', e => /confirmation/.test(e.avis_compte) && /eve@exemple\.fr/.test(e.avis_compte) && !e.connecte), 'un bon : le compte est créé, la page dit d\'aller confirmer par e-mail');
    verif(service.comptes['eve@exemple.fr'] && service.comptes['eve@exemple.fr'].choisi === 'Eve' && service.courrier.some(c => c.genre === 'confirmation' && c.email === 'eve@exemple.fr'),
      'le service a le compte, son pseudo, et un e-mail de confirmation à envoyer');
    // mot de passe oublié
    await dan.cliquer('c_retour'); await dan.cliquer('vers_oubli');
    await dan.ecrire('o_email', 'dan@exemple.fr'); await dan.cliquer('o_envoyer');
    verif(await dan.attendre('le lien', e => /e-mail vient de partir/.test(e.avis_compte)) && service.courrier.some(c => c.genre === 'mot de passe' && c.email === 'dan@exemple.fr'),
      '« Mot de passe oublié ? » : le lien est demandé pour cette adresse, la page dit d\'aller voir ses e-mails');
    // le lien de l'e-mail ramène à la page du jeu, avec de quoi entrer dans son adresse : expiré, puis bon
    await dan.p.goto(`http://127.0.0.1:${PORT_JEU}/#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired`);
    await dan.p.reload();
    verif(await dan.attendre('le lien expiré', e => /expiré/.test(e.erreur_compte) && !e.connecte, 60000) && await dan.p.evaluate(() => location.hash === ''), 'un lien expiré : c\'est dit, et l\'adresse de la page est nettoyée');
    await dan.p.goto(`http://127.0.0.1:${PORT_JEU}/#access_token=${encodeURIComponent('jeton:dan@exemple.fr:9')}&refresh_token=${encodeURIComponent('reprise:dan@exemple.fr:9')}&expires_in=3600&token_type=bearer&type=recovery`);
    await dan.p.reload();
    verif(await dan.attendre('le nouveau mot de passe', e => e.a_changer && e.connecte && e.reperes.n_mdp && e.reperes.n_valider, 60000) && await dan.p.evaluate(() => location.hash === ''),
      'le bon lien : la page « Nouveau mot de passe » s\'ouvre, et le jeton n\'est plus dans l\'adresse');
    await dan.ecrire('n_mdp', 'tout-neuf'); await dan.ecrire('n_encore', 'tout-neuf'); await dan.cliquer('n_valider');
    verif(await dan.attendre('le menu', e => !e.a_changer && e.connecte && e.pseudo === 'Dan' && e.reperes.seul) && service.comptes['dan@exemple.fr'].mdp === 'tout-neuf',
      'le nouveau mot de passe est enregistré : dan est connecté, au menu');
    verif(!dan.erreurs.length, 'aucune erreur dans la page' + (dan.erreurs.length ? ' ; ' + dan.erreurs.slice(0, 2).join(' | ') : ''));
    await dan.p.context().close();
  }

  const [ada, bob, cleo] = await Promise.all(['ada', 'bob', 'cleo'].map(joueur));
  const tous = [ada, bob, cleo];

  console.log('1. Se connecter');
  for (const j of tous) verif(await j.attendre('la page de connexion', e => e.etat === 'menu' && e.reperes.email, 60000), `${j.nom} : le jeu se charge sur la page de connexion`);
  await ada.photo('1-connexion');
  await bob.ecrire('email', 'bob@exemple.fr'); await bob.ecrire('mdp', 'faux'); await bob.cliquer('connecter');
  verif(await bob.attendre('le refus', e => e.refus === 'E-mail ou mot de passe incorrect.' && !e.connecte), 'bob, un mauvais mot de passe : refusé, et c\'est dit');
  await bob.cliquer('mdp'); await bob.p.keyboard.press('Control+A'); await bob.p.keyboard.type('bon', { delay: 15 }); await bob.cliquer('connecter');
  await ada.ecrire('email', 'ada@exemple.fr'); await ada.ecrire('mdp', 'bon'); await ada.p.keyboard.press('Enter');
  await cleo.ecrire('email', 'cleo@exemple.fr'); await cleo.ecrire('mdp', 'bon'); await cleo.cliquer('connecter');
  const noms = { ada: 'Ada', bob: 'Bob', cleo: 'Porteur' };
  for (const j of tous) verif(await j.attendre('le menu', e => e.connecte && e.pseudo === noms[j.nom] && e.reperes.ouvrir && e.reperes.code),
    `${j.nom} : connecté (« ${noms[j.nom]} »), le menu propose d'ouvrir un salon ou d'entrer par un code`);

  console.log('2. Le salon et son code');
  await ada.cliquer('ouvrir');
  const a = await ada.attendre('le salon', e => e.etat === 'salon' && /^[A-Z2-9]{5}$/.test(e.code) && e.hote && e.reperes.commencer);
  verif(a && a.numero === 1, `ada ouvre un salon : le code ${a && a.code}`);
  const code = a.code;
  await bob.ecrire('code', 'zzzzz'); await bob.cliquer('entrer');
  verif(await bob.attendre('le refus', e => e.etat === 'menu' && e.avis === 'Ce code ne mène à aucun salon.'), 'bob tape un mauvais code : c\'est dit, il reste au menu');
  await bob.cliquer('code'); await bob.p.keyboard.press('Control+A'); await bob.p.keyboard.type(code.toLowerCase(), { delay: 15 }); await bob.cliquer('entrer');
  verif(await bob.attendre('le salon', e => e.etat === 'salon' && e.code === code && e.numero === 2 && !e.hote && !e.reperes.commencer), 'bob tape le bon (en minuscules) : il entre, numéro 2, sans le bouton de l\'hôte');
  const ada2 = await joueur('ada2');
  await ada2.attendre('la page', e => e.etat === 'menu' && e.reperes.email, 120000);
  await ada2.ecrire('email', 'ada@exemple.fr'); await ada2.ecrire('mdp', 'bon'); await ada2.cliquer('connecter');
  await ada2.attendre('le menu', e => e.connecte && e.reperes.code, 30000);
  await ada2.ecrire('code', code); await ada2.p.keyboard.press('Enter');
  verif(await ada2.attendre('le refus', e => e.etat === 'menu' && /ton propre salon/.test(e.avis), 20000) && service.salons.get(code).membres.length === 2,
    'ada, dans un second onglet avec le même compte, tape son propre code : refusé, avec l\'explication (il faut un compte par joueur)');
  await ada2.p.close();
  await cleo.ecrire('code', code); await cleo.p.keyboard.press('Enter');
  verif(await cleo.attendre('le salon', e => e.etat === 'salon' && e.numero === 3), 'cléo aussi, numéro 3');
  // l'hôte veut partir trop tôt : cléo vient d'entrer, sa liaison n'est pas faite. Le salon le retient.
  const tot = await ada.etat();
  if (tot.relies.length < 2) {
    await ada.cliquer('commencer');
    await ada.p.waitForTimeout(1500);
    const retenu = await ada.etat(), chezCleo = await cleo.etat();
    verif(retenu.etat === 'salon' && chezCleo.etat === 'salon' && service.salons.get(code).etat === 'ouvert', 'ada veut lancer la nuit avant que cléo soit reliée : le salon la retient, personne n\'est laissé dehors');
  } else console.log('    (cléo était déjà reliée : le départ trop tôt n\'a pas pu être essayé)');
  const lesTrois = await ada.attendre('les trois', e => e.membres.length === 3 && e.membres.map(m => m.pseudo).join() === 'Ada,Bob,Porteur');
  if (!lesTrois) { const e = await ada.etat(); console.log('    (chez ada : ' + JSON.stringify({ etat: e.etat, code: e.code, numero: e.numero, membres: e.membres, relies: e.relies, avis: e.avis, hote: e.hote }) + ' ; au service : ' + JSON.stringify(service.salons.get(code)).slice(0, 300) + ')'); }
  verif(lesTrois, 'ada voit les trois pseudos au salon');
  verif(await ada.attendre('les liaisons', e => e.relies.length === 2 && e.relies.includes(2) && e.relies.includes(3), 45000), 'les navigateurs de bob et de cléo se relient à celui d\'ada (WebRTC)');
  for (const j of [bob, cleo]) verif(await j.attendre('la liaison', e => e.relies.includes(1), 20000), `${j.nom} : relié à l'hôte`);
  await ada.photo('2-salon'); await bob.photo('2-salon');
  verif(service.journal.filter(l => l.includes('pf_salon_signal')).length >= 4, 'la mise en relation est passée par le salon (' + service.journal.filter(l => l.includes('pf_salon_signal')).length + ' messages)');

  console.log('3. La nuit, à trois');
  await ada.cliquer('commencer');
  for (const j of tous) verif(await j.attendre('la partie', e => e.etat === 'partie' && Object.keys(e.joueurs).length === 3 && e.meubles >= 40 && e.pieces >= 6, 90000),
    `${j.nom} : la nuit commence, trois porteurs, une maison meublée`);
  const [ea, eb, ec] = await Promise.all(tous.map(j => j.etat()));
  verif(ea.quota === eb.quota && eb.quota === ec.quota && ea.quota > 0 && ea.meubles === eb.meubles && eb.meubles === ec.meubles && ea.pieces === ec.pieces,
    `la même maison chez tous : ${ea.pieces} pièces, ${ea.meubles} objets, le même quota (${ea.quota} €)`);
  verif(['1', '2', '3'].every(i => ea.pseudos[i] === eb.pseudos[i] && eb.pseudos[i] === ec.pseudos[i]) && ea.pseudos['1'] === 'Ada' && ea.pseudos['2'] === 'Bob', 'les mêmes pseudos sur les mêmes porteurs');
  verif(service.salons.get(code).etat === 'parti', 'le salon est fermé aux nouveaux venus');
  // bob avance : les deux autres le voient bouger
  const avant = (await ada.etat()).joueurs['2'];
  await bob.p.mouse.click(320, 180); await bob.p.keyboard.down('KeyS');      // (il marche jusqu'à avoir fait deux mètres : trois jeux à la fois, la machine est lente)
  await bob.attendre('son mètre et demi', e => Math.hypot(e.joueurs['2'][0] - avant[0], e.joueurs['2'][1] - avant[1]) > 1.0, 40000);      // (à reculons, vers la rampe du camion ; quatre jeux à la fois, la machine est lente)
  await bob.p.keyboard.up('KeyS');
  let chezBob = (await bob.etat()).joueurs['2'];           // (on attend qu'il soit arrêté pour de bon)
  for (let i = 0; i < 40; i++) { await bob.p.waitForTimeout(500); const p2 = (await bob.etat()).joueurs['2']; const arrete = Math.hypot(p2[0] - chezBob[0], p2[1] - chezBob[1]) < 0.02; chezBob = p2; if (arrete) break; }
  const vu = await ada.attendre('bob qui bouge', e => Math.hypot(e.joueurs['2'][0] - chezBob[0], e.joueurs['2'][1] - chezBob[1]) < 0.5, 40000);
  if (!vu) console.log('    (chez bob : ' + chezBob + ' ; chez ada : ' + (await ada.etat()).joueurs['2'] + ')');
  verif(Math.hypot(chezBob[0] - avant[0], chezBob[1] - avant[1]) > 1.0 && vu, `bob marche ${Math.hypot(chezBob[0] - avant[0], chezBob[1] - avant[1]).toFixed(1)} m : ada le voit au même endroit`);
  verif(await cleo.attendre('bob qui bouge', e => Math.hypot(e.joueurs['2'][0] - chezBob[0], e.joueurs['2'][1] - chezBob[1]) < 0.5, 40000), 'cléo aussi (par l\'hôte)');
  await ada.photo('3-partie'); await cleo.photo('3-partie');

  console.log('4. Partir');
  await cleo.p.close();
  verif(await ada.attendre('le départ', e => e.relies.length === 1 && e.relies[0] === 2, 20000), 'cléo ferme sa page : ada ne la compte plus');
  await ada.p.close();
  verif(await bob.attendre('le retour au menu', e => e.etat === 'menu' && e.avis !== '', 20000), 'l\'hôte ferme la sienne : bob revient au menu, avec l\'explication');
  verif(tous.every(j => !j.erreurs.length), 'aucune erreur dans les pages' + (tous.some(j => j.erreurs.length) ? ' ; ' + tous.flatMap(j => j.erreurs).slice(0, 3).join(' | ') : ''));

  console.log(`\n${ok ? 'Tout passe' : 'ÉCHEC'} : ${n} vérifications`);
  await nav.close(); jeu.close(); service.serveur.close();
  process.exit(ok ? 0 : 1);
})().catch(e => { console.error('ÉCHEC :', e.message); process.exit(1); });
