// Portefaix — LE BANC (outils/banc.js)
// Ce qui se vérifie sans Godot, à chaque envoi :
//  1. le projet : chaque fichier qu'il nomme (res://…) existe ; la scène de départ ; des scripts indentés aux tabulations ; l'export web en
//     application installable, avec ses icônes ; le compte (aucune clé secrète) ; le salon en ligne (le schéma, le jeu et le faux service d'accord) ;
//  2. la maison (scripts/maison.gd) : un plan rectangulaire, clos de murs, où tout le sol se rejoint depuis la porte d'entrée ;
//  3. les règles (scripts/regles.gd) : chaque meuble de la maison est au catalogue ; seul, on peut faire le quota sans soulever ce qui se porte à deux.
// Ce que seul Godot vérifie (que le jeu tourne) : outils/godot.sh --headless --path . -- --essai (puis --essai-reseau, --essai-compte)
//   node outils/banc.js
'use strict';
const fs = require('fs'), path = require('path');
const JEU = path.join(__dirname, '..');
let ok = true; const verif = (c, m) => { ok = ok && !!c; console.log((c ? '  ✓ ' : '  ✗ ') + m); };
const lire = f => fs.readFileSync(path.join(JEU, f), 'utf8');
const fichiers = d => fs.readdirSync(path.join(JEU, d)).filter(f => !f.startsWith('.')).map(f => path.join(d, f));

console.log('1. Le projet');
const projet = lire('project.godot'), sources = ['project.godot', 'export_presets.cfg', ...fichiers('scenes'), ...fichiers('scripts')];
const noms = new Set(sources.flatMap(f => [...lire(f).matchAll(/res:\/\/([A-Za-zÀ-ÿ0-9_\-./]+)/g)].map(m => m[1])).filter(n => /\.[a-z]+$/.test(n)));
const manquent = [...noms].filter(n => !fs.existsSync(path.join(JEU, n)));
verif(noms.size >= 10 && !manquent.length, `les ${noms.size} fichiers que nomme le projet existent` + (manquent.length ? ` ; manquent : ${manquent.join(', ')}` : ''));
verif(/run\/main_scene="res:\/\/scenes\/principal\.tscn"/.test(projet) && /gl_compatibility/.test(projet) && /driver\/enable_input=true/.test(projet),
  'la scène de départ, le rendu Compatibility, le micro ouvert');
const preset = lire('export_presets.cfg');
verif(/platform="Web"/.test(preset) && /variant\/thread_support=false/.test(preset) && fs.existsSync(path.join(JEU, 'scripts/tactile.gd')),
  'un export pour le navigateur, sans fils d\'exécution (celui que lit n\'importe quel navigateur), et de quoi jouer du doigt');
const icones = [...preset.matchAll(/progressive_web_app\/icon_\w+="res:\/\/([^"]+)"/g)].map(m => m[1]);
verif(/progressive_web_app\/enabled=true/.test(preset) && icones.length === 3 && icones.every(i => fs.existsSync(path.join(JEU, i))) && fs.existsSync(path.join(JEU, 'outils/pwa.js')),
  `une application installable : ses ${icones.length} icônes sont là, et de quoi finir le service worker`);
const gd = fichiers('scripts').filter(f => f.endsWith('.gd'));
const espaces = gd.filter(f => lire(f).split('\n').some(l => /^ +\S/.test(l)));
verif(!espaces.length, `${gd.length} scripts, indentés aux tabulations, comme Godot le veut` + (espaces.length ? ` ; avec des espaces : ${espaces.join(', ')}` : ''));

const compte = lire('scripts/compte.gd'), secrets = gd.filter(f => /service_role|sb_secret_|eyJhbGciOi/.test(lire(f)));
verif(/const CLE := "sb_publishable_/.test(compte) && /const SUPABASE := "https:\/\//.test(compte) && !secrets.length,
  'le compte : le service et sa clé publique, et aucune clé secrète dans les scripts' + (secrets.length ? ` ; à retirer de : ${secrets.join(', ')}` : ''));
const ecrit = gd.filter(f => !f.endsWith('essai.gd') && /vp_sauver|vp_oublier|vp_supprimer|METHOD_(POST|PATCH|PUT|DELETE), "\/rest\/v1\/vp_/.test(lire(f)));
verif(/METHOD_GET, "\/rest\/v1\/vp_comptes/.test(compte) && !ecrit.length, 'il lit la sauvegarde de Stone Valley sans jamais y écrire' + (ecrit.length ? ` ; y écrit : ${ecrit.join(', ')}` : ''));

// le salon en ligne : ce que le jeu appelle existe dans le schéma, fermé comme il faut, et le faux service des essais répond aux mêmes noms
const sql = lire('supabase.sql'), salon = lire('scripts/salon.gd'), faux = lire('outils/faux-service.js');
const appelees = [...new Set([...salon.matchAll(/"(pf_\w+)"/g)].map(m => m[1]))], definies = [...sql.matchAll(/create function public\.(pf_salon_\w+)\(/g)].map(m => m[1]);
const absentes = appelees.filter(f => !definies.includes(f)), sansFaux = definies.filter(f => !new RegExp(f + '\\(uid').test(faux));
verif(appelees.length >= 5 && !absentes.length && !sansFaux.length, `le salon en ligne : ${definies.length} fonctions au schéma, ${appelees.length} appelées par le jeu, toutes imitées par le faux service`
  + (absentes.length ? ` ; absentes du schéma : ${absentes.join(', ')}` : '') + (sansFaux.length ? ` ; sans imitation : ${sansFaux.join(', ')}` : ''));
const tables = [...sql.matchAll(/create table public\.(pf_\w+)/g)].map(m => m[1]);
verif(tables.length === 3 && tables.every(t => sql.includes(`alter table public.${t} enable row level security`)) && !/create policy/.test(sql)
  && definies.every(f => new RegExp(`create function public\\.${f}\\([^)]*\\) returns jsonb\\s+language plpgsql security definer set search_path = ''`).test(sql))
  && /from public, anon;/.test(sql) && !/vp_/.test(sql.replace(/^--.*$/gm, '')),
  `${tables.length} tables fermées (accès par les fonctions seulement, réservées aux comptes connectés), rien de Stone Valley n'est touché`);

console.log('2. La maison');
const maison = lire('scripts/maison.gd');
const plan = [...maison.match(/const PLAN := \[([\s\S]*?)\n\]/)[1].matchAll(/"([#.DP]+)"/g)].map(m => m[1]);
const L = plan[0].length, H = plan.length, sol = (c, l) => l >= 0 && l < H && c >= 0 && c < L && plan[l][c] !== '#';
verif(H >= 8 && plan.every(l => l.length === L), `un plan de ${L} sur ${H} cases, rectangulaire`);
const bord = [];
for (let l = 0; l < H; l++) for (let c = 0; c < L; c++) if ((l === 0 || l === H - 1 || c === 0 || c === L - 1) && plan[l][c] !== '#') bord.push(plan[l][c]);
verif(bord.length > 0 && bord.every(x => x === 'P') && plan[H - 1].includes('P'), `clos de murs, avec une seule sortie : la porte d'entrée, côté cour (${bord.length} cases)`);
const vus = new Set(), pile = [[plan[H - 1].indexOf('P'), H - 1]];
while (pile.length) { const [c, l] = pile.pop(), k = c + ',' + l; if (!sol(c, l) || vus.has(k)) continue; vus.add(k); pile.push([c + 1, l], [c - 1, l], [c, l + 1], [c, l - 1]); }
const sols = plan.join('').replace(/#/g, '').length;
verif(vus.size === sols, `les ${sols} cases de sol se rejoignent toutes depuis l'entrée` + (vus.size === sols ? '' : ` ; ${sols - vus.size} sont enfermées`));
const pieces = [...maison.matchAll(/"rect": Rect2i\((\d+), (\d+), (\d+), (\d+)\)/g)].map(m => m.slice(1).map(Number));
const pleines = pieces.filter(([c, l, w, h]) => { for (let y = l; y < l + h; y++) for (let x = c; x < c + w; x++) if (plan[y]?.[x] !== '.') return false; return true; });
verif(pieces.length >= 4 && pleines.length === pieces.length, `${pieces.length} pièces à meubler, toutes sur du sol`);
const lampes = [...maison.match(/const LAMPES := \[([\s\S]*?)\]\n/)[1].matchAll(/Vector2\(([\d.]+), ([\d.]+)\)/g)].map(m => [+m[1], +m[2]]);
verif(lampes.length >= pieces.length && lampes.every(([x, z]) => sol(Math.floor(x), Math.floor(z))), `${lampes.length} lampes, toutes au-dessus du sol`);
verif(plan.join('').includes('DD') && plan.every(l => !/(^|[^D])D([^D]|$)/.test(l)), 'des portes de deux mètres, où passe un canapé');

console.log('3. Les règles');
const regles = lire('scripts/regles.gd');
const catalogue = {};
for (const m of regles.matchAll(/"(\w+)": \{"nom": "[^"]+", "taille": Vector3\(([\d.]+), ([\d.]+), ([\d.]+)\), "masse": ([\d.]+), "valeur": (\d+), "fragile": ([\d.]+)/g))
  catalogue[m[1]] = { taille: [+m[2], +m[3], +m[4]], masse: +m[5], valeur: +m[6], fragile: +m[7] };
const mobilier = [...regles.match(/const MOBILIER := \[([\s\S]*?)\]/)[1].matchAll(/"(\w+)"/g)].map(m => m[1]);
const nombre = n => +regles.match(new RegExp(`const ${n} := ([\\d.]+)`))[1];
const inconnus = mobilier.filter(t => !catalogue[t]);
verif(mobilier.length >= 15 && !inconnus.length, `${mobilier.length} meubles dans la maison, tous au catalogue (${Object.keys(catalogue).length} sortes)` + (inconnus.length ? ` ; inconnus : ${inconnus.join(', ')}` : ''));
const haut = nombre('HAUTEUR'), trop = Object.entries(catalogue).filter(([, o]) => o.taille[1] > 2.2 || o.taille[1] >= haut || o.fragile < 0 || o.fragile > 1);
verif(!trop.length, 'chacun passe sous une porte, debout, et sa fragilité est une part' + (trop.length ? ` ; pas : ${trop.map(x => x[0]).join(', ')}` : ''));
const force = nombre('FORCE_PORTEUR'), total = mobilier.reduce((s, t) => s + catalogue[t].valeur, 0);
const seul = mobilier.filter(t => catalogue[t].masse * 9.8 <= force).reduce((s, t) => s + catalogue[t].valeur, 0);
const quota = n => Math.round(total * Math.min(nombre('QUOTA') + nombre('QUOTA_PAR_JOUEUR') * (n - 1), nombre('QUOTA_MAX')) / 10) * 10;
verif(seul >= quota(1) * 1.3, `seul, on fait le quota (${quota(1)} € sur ${total}) avec ce qu'on soulève seul (${seul} €), de la casse comprise`);
verif(quota(6) > seul * 0.75, `à six, il faut aussi sortir les lourds (${quota(6)} €)`);
const sabotages = [...regles.match(/const SABOTAGES := \{([\s\S]*?)\n\}/)[1].matchAll(/"(\w+)": \{"nom"/g)].map(m => m[1]);
const principal = lire('scripts/principal.gd');
verif(sabotages.length >= 3 && sabotages.every(s => principal.includes(`"${s}"`)), `${sabotages.length} sabotages pour le chat, chacun joué par le jeu (${sabotages.join(', ')})`);
verif(nombre('CHOSE_CHASSE') > nombre('MARCHE') && nombre('CHOSE_CHASSE') < nombre('COURSE'), 'la chose va plus vite qu\'on ne marche, moins qu\'on ne court');

console.log(ok ? '\nTout passe.' : '\nÉCHEC.');
process.exit(ok ? 0 : 1);
