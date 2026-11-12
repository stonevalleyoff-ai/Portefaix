// Portefaix — LE FAUX SERVICE (outils/faux-service.js)
// Répond comme le Supabase de Stone Valley pour ce dont le jeu se sert : les comptes (se connecter, rester connecté, le pseudo) et
// les salons en ligne (les six fonctions de supabase.sql, avec les mêmes règles), le tout en mémoire.
// Il sert aux essais dans un navigateur (outils/essai-en-ligne.js), sans toucher aux vrais comptes ni à la vraie base.
//   node outils/faux-service.js [port]      (8126 par défaut)
// Comptes : ada@exemple.fr, bob@exemple.fr, cleo@exemple.fr, dan@exemple.fr ; mot de passe « bon ». On peut en créer d'autres, et
// changer un mot de passe (par un jeton, comme en porte le lien d'un e-mail) ; aucun e-mail ne part : les demandes sont notées.
'use strict';
const http = require('http');
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function creer() {
  const COMPTES = { 'ada@exemple.fr': { id: 'u-ada', pseudo: 'Ada' }, 'bob@exemple.fr': { id: 'u-bob', pseudo: 'Bob' }, 'cleo@exemple.fr': { id: 'u-cleo', pseudo: '' },
    'dan@exemple.fr': { id: 'u-dan', pseudo: 'Dan' } };
  const courrier = [];             // les e-mails qui seraient partis : { genre, email }
  const salons = new Map();        // code → { hote, etat, membres: [{ uid, numero, pseudo }], signaux: [{ id, de, vers, donnees }] }
  let suite = 0;
  const journal = [];
  const pseudo = p => (String(p || '').replace(/[\u0000-\u001f<>]/g, '').trim().slice(0, 16).trim()) || 'Porteur';
  const sortir = uid => { for (const [c, s] of salons) { if (s.hote === uid) salons.delete(c); else s.membres = s.membres.filter(m => m.uid !== uid); } };
  const fonctions = {
    pf_salon_creer(uid, p) {
      sortir(uid);
      let c; do { c = Array.from({ length: 5 }, () => ALPHABET[Math.floor(Math.random() * 32)]).join(''); } while (salons.has(c));
      salons.set(c, { hote: uid, etat: 'ouvert', membres: [{ uid, numero: 1, pseudo: pseudo(p.p_pseudo) }], signaux: [] });
      return { code: c, numero: 1 };
    },
    pf_salon_rejoindre(uid, p) {
      const c = String(p.p_code || '').trim().toUpperCase(), s = salons.get(c);
      if (!s) return { erreur: 'introuvable' };
      const deja = s.membres.find(m => m.uid === uid);
      if (deja) { deja.pseudo = pseudo(p.p_pseudo); return { code: c, numero: deja.numero }; }
      if (s.etat !== 'ouvert') return { erreur: 'parti' };
      if (s.membres.length >= 6) return { erreur: 'complet' };
      sortir(uid);
      const n = Math.max(...s.membres.map(m => m.numero)) + 1;
      s.membres.push({ uid, numero: n, pseudo: pseudo(p.p_pseudo) });
      return { code: c, numero: n };
    },
    pf_salon_etat(uid, p) {
      const c = String(p.p_code || '').trim().toUpperCase(), s = salons.get(c), moi = s && s.membres.find(m => m.uid === uid);
      if (!moi) return { erreur: 'dehors' };
      return { code: c, etat: s.etat, numero: moi.numero, membres: s.membres.map(m => ({ numero: m.numero, pseudo: m.pseudo })).sort((a, b) => a.numero - b.numero),
        signaux: s.signaux.filter(x => x.vers === moi.numero && x.id > (p.p_apres || 0)).map(x => ({ id: x.id, de: x.de, donnees: x.donnees })) };
    },
    pf_salon_signal(uid, p) {
      const c = String(p.p_code || '').trim().toUpperCase(), s = salons.get(c), moi = s && s.membres.find(m => m.uid === uid);
      if (!moi) return { erreur: 'dehors' };
      if (p.p_donnees == null || JSON.stringify(p.p_donnees).length > 8000 || s.signaux.length >= 800) return { erreur: 'trop' };
      if (p.p_vers === moi.numero || !s.membres.some(m => m.numero === p.p_vers)) return { erreur: 'destinataire' };
      s.signaux.push({ id: ++suite, de: moi.numero, vers: p.p_vers, donnees: p.p_donnees });
      return { ok: true };
    },
    pf_salon_partir(uid, p) {
      const s = salons.get(String(p.p_code || '').trim().toUpperCase());
      if (!s || s.hote !== uid) return { ok: false };
      s.etat = 'parti'; return { ok: true };
    },
    pf_salon_quitter(uid, p) {
      const c = String(p.p_code || '').trim().toUpperCase(), s = salons.get(c);
      if (!s) return { ok: false };
      if (s.hote === uid) { salons.delete(c); return { ok: true }; }
      const moi = s.membres.find(m => m.uid === uid);
      if (!moi) return { ok: false };
      s.membres = s.membres.filter(m => m !== moi); s.signaux = s.signaux.filter(x => x.de !== moi.numero && x.vers !== moi.numero);
      return { ok: true };
    },
  };
  const session = (email, n) => ({ access_token: `jeton:${email}:${n}`, refresh_token: `reprise:${email}:${n}`, expires_in: 3600,
    user: { id: COMPTES[email].id, email, user_metadata: COMPTES[email].choisi ? { pseudo: COMPTES[email].choisi } : {} } });
  const serveur = http.createServer((req, res) => {
    let corps = '';
    req.on('data', d => { corps += d; });
    req.on('end', () => {
      const rendre = (code, objet) => { res.writeHead(code, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'apikey, authorization, content-type', 'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS' }); res.end(JSON.stringify(objet)); };
      if (req.method === 'OPTIONS') return rendre(200, {});
      let j = {}; try { j = corps ? JSON.parse(corps) : {}; } catch (e) { return rendre(400, {}); }
      const porteur = /^Bearer jeton:([^:]+):/.exec(req.headers.authorization || ''), email = porteur && COMPTES[porteur[1]] ? porteur[1] : null;
      journal.push(`${req.method} ${req.url}`);
      if (!req.headers.apikey) return rendre(401, { message: 'pas de clé' });
      if (req.url.startsWith('/auth/v1/token?grant_type=password')) {
        const c = COMPTES[j.email];
        if (!c || j.password !== (c.mdp || 'bon')) return rendre(400, { code: 400, error_code: 'invalid_credentials' });
        return c.a_confirmer ? rendre(400, { code: 400, error_code: 'email_not_confirmed' }) : rendre(200, session(j.email, 1));
      }
      if (req.url.startsWith('/auth/v1/signup')) {
        if (!/redirect_to=http/.test(req.url)) return rendre(400, { code: 400, error_code: 'validation_failed' });
        if (String(j.password || '').length < 6) return rendre(422, { code: 422, error_code: 'weak_password' });
        if (COMPTES[j.email]) return rendre(200, { id: 'u-faux', email: j.email, identities: [] });       // (comme le vrai service, pour une adresse déjà prise)
        COMPTES[j.email] = { id: 'u-' + Object.keys(COMPTES).length, pseudo: '', choisi: String((j.data || {}).pseudo || ''), mdp: j.password, a_confirmer: true };
        courrier.push({ genre: 'confirmation', email: j.email });
        return rendre(200, { id: COMPTES[j.email].id, email: j.email, identities: [{ provider: 'email' }], confirmation_sent_at: new Date().toISOString() });
      }
      if (req.url.startsWith('/auth/v1/recover')) {
        if (!/redirect_to=http/.test(req.url)) return rendre(400, { code: 400, error_code: 'validation_failed' });
        courrier.push({ genre: 'mot de passe', email: j.email });
        return rendre(200, {});
      }
      if (req.url.startsWith('/auth/v1/token?grant_type=refresh_token')) {
        const m = /^reprise:([^:]+):(\d+)$/.exec(j.refresh_token || '');
        return m && COMPTES[m[1]] ? rendre(200, session(m[1], +m[2] + 1)) : rendre(400, { code: 400, error_code: 'refresh_token_not_found' });
      }
      if (!email) return rendre(401, { message: 'pas de jeton' });
      if (req.url.startsWith('/rest/v1/vp_comptes')) return rendre(200, [{ pseudo: COMPTES[email].pseudo || null }]);
      if (req.url.startsWith('/auth/v1/user') && req.method === 'GET') { COMPTES[email].a_confirmer = false; return rendre(200, session(email, 1).user); }
      if (req.url.startsWith('/auth/v1/user') && req.method === 'PUT') {
        if (j.password != null) { if (String(j.password).length < 6) return rendre(422, { code: 422, error_code: 'weak_password' }); COMPTES[email].mdp = String(j.password); }
        if (j.data) COMPTES[email].choisi = String(j.data.pseudo || '');
        return rendre(200, { id: COMPTES[email].id });
      }
      if (req.url.startsWith('/auth/v1/logout')) return rendre(204, {});
      const f = /^\/rest\/v1\/rpc\/(\w+)/.exec(req.url);
      if (f && fonctions[f[1]]) return rendre(200, fonctions[f[1]](COMPTES[email].id, j));
      rendre(404, {});
    });
  });
  return { serveur, salons, journal, comptes: COMPTES, courrier };
}

module.exports = { creer };
if (require.main === module) {
  const port = +process.argv[2] || 8126, s = creer();
  s.serveur.listen(port, '127.0.0.1', () => console.log(`faux service de comptes et de salons : http://127.0.0.1:${port}`));
}
