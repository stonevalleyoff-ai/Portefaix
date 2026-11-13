// Portefaix — FINIR L'APPLICATION WEB (outils/pwa.js)
// Godot exporte le jeu en application web installable (PWA) : une page, un manifeste, un service worker qui garde le jeu sur l'appareil.
// Ce script passe derrière lui, sur le dossier exporté :
//  1. le service worker de Godot 4.3 veut garder « index.worker.js », qui n'existe pas dans un export sans fils d'exécution : un seul
//     fichier manquant fait échouer toute l'installation, et le jeu ne marcherait pas hors connexion. On ne lui laisse que ce qui existe.
//     Et il ne savait pas rouvrir le dossier du jeu (« ./ ») sans réseau : seulement « index.html ».
//  2. le manifeste : un nom court, une description, la langue, les couleurs, une icône qui se rogne bien en rond (maskable) ;
//  3. la page : la langue, la couleur de la barre du téléphone, ce qu'il faut à iOS pour l'ajouter à l'écran d'accueil ;
//  4. les icônes de la page (onglet, écran d'accueil d'iOS) : celles du jeu, à la place de celles de Godot.
//   node outils/pwa.js site
'use strict';
const fs = require('fs'), path = require('path');
const SITE = path.resolve(process.argv[2] || 'site'), ici = f => path.join(SITE, f), lire = f => fs.readFileSync(ici(f), 'utf8');
const NUIT = '#030408';
// la version : la date de la construction, et le commit s'il y en a un
let commit = '';
try { commit = require('child_process').execSync('git rev-parse --short HEAD', { cwd: __dirname, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch (e) { /* pas de dépôt */ }
const VERSION = new Date().toISOString().slice(0, 16).replace('T', ' ') + (commit ? ' · ' + commit : '');

// 1. le service worker
let sw = lire('index.service.worker.js');
const listes = [...sw.matchAll(/const (CACHED_FILES|CACHABLE_FILES) = (\[[^\]]*\]);/g)];
if (listes.length !== 2) { console.error('pwa.js : le service worker de Godot a changé de forme'); process.exit(1); }
for (const [tout, nom, liste] of listes) {
  const fichiers = JSON.parse(liste), presents = fichiers.filter(f => fs.existsSync(ici(f)));
  if (nom === 'CACHED_FILES') for (const f of ['index.manifest.json', 'index.144x144.png', 'index.180x180.png', 'index.512x512.png']) if (!presents.includes(f) && fs.existsSync(ici(f))) presents.push(f);
  sw = sw.replace(tout, `const ${nom} = ${JSON.stringify(presents)};`);
  console.log(`  ${nom} : ${presents.length} fichiers` + (fichiers.length > presents.filter(f => fichiers.includes(f)).length ? ` (retirés, car absents : ${fichiers.filter(f => !presents.includes(f)).join(', ')})` : ''));
}
// (l'application installée s'ouvre sur son dossier, « ./ », et non sur « index.html » : sans réseau, le service worker ne trouvait pas
// cette adresse dans ce qu'il garde, et rien ne s'ouvrait. Une visite du dossier, c'est la page.)
const cherche = 'let cached = await cache.match(event.request);';
if (!sw.includes(cherche)) { console.error('pwa.js : le service worker de Godot a changé de forme'); process.exit(1); }
sw = sw.replace(cherche, cherche + '\n\t\t\t\tif (cached == null && isNavigate) {\n\t\t\t\t\tcached = await cache.match(CACHED_FILES[0]);\n\t\t\t\t}');
// (une nouvelle version prend la place de l'ancienne tout de suite : sans cela, elle attendait que tous les onglets du jeu soient fermés,
// et l'on rejouait l'ancienne en croyant l'avoir rechargée)
const installe = "event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));", active = "return ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();";
if (!sw.includes(installe) || !sw.includes(active)) { console.error('pwa.js : le service worker de Godot a changé de forme'); process.exit(1); }
sw = sw.replace(installe, 'self.skipWaiting();\n\t' + installe).replace(active, active + '\n\t}).then(function () {\n\t\treturn self.clients.claim();');
fs.writeFileSync(ici('index.service.worker.js'), sw);

// 2. le manifeste
const m = JSON.parse(lire('index.manifest.json'));
Object.assign(m, { name: 'Portefaix', short_name: 'Portefaix', lang: 'fr', dir: 'ltr', id: './', start_url: './', scope: './',
  description: 'Videz une maison hantée avant l\'aube, seul ou à plusieurs. Ne réveillez pas ce qui y dort.',
  background_color: NUIT, theme_color: NUIT, display: 'fullscreen', display_override: ['fullscreen', 'standalone'], orientation: 'landscape', categories: ['games'] });
m.icons = m.icons.flatMap(i => i.sizes === '512x512' ? [{ ...i, purpose: 'any' }, { ...i, purpose: 'maskable' }] : [{ ...i, purpose: 'any' }]);
fs.writeFileSync(ici('index.manifest.json'), JSON.stringify(m, null, 1));

// 3. la page
let page = lire('index.html');
const avant = page;
page = page.replace('<html lang="en">', '<html lang="fr">').replace('</title>', `</title>
		<meta name="description" content="${m.description.replace(/"/g, '&quot;')}">
		<meta name="theme-color" content="${NUIT}">
		<meta name="mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
		<meta name="apple-mobile-web-app-title" content="Portefaix">
		<script>
// la version de cette construction, que le jeu affiche ; et la mise à jour : quand une nouvelle version prend la main, la page se
// recharge d'elle-même, une fois, pour la jouer
window.PORTEFAIX_VERSION = ${JSON.stringify(VERSION)};
if ('serviceWorker' in navigator) {
	const avait = !!navigator.serviceWorker.controller;
	let fait = false;
	navigator.serviceWorker.addEventListener('controllerchange', () => { if (avait && !fait) { fait = true; location.reload(); } });
	navigator.serviceWorker.getRegistration().then((r) => { if (r) r.update(); }).catch(() => {});
}
		</script>`);
if (page === avant || !page.includes('rel="manifest"')) { console.error('pwa.js : la page de Godot a changé de forme'); process.exit(1); }
fs.writeFileSync(ici('index.html'), page);

// 4. les icônes de la page
fs.copyFileSync(ici('index.180x180.png'), ici('index.apple-touch-icon.png'));
fs.copyFileSync(ici('index.144x144.png'), ici('index.icon.png'));
console.log('  manifeste, page et icônes : faits');
