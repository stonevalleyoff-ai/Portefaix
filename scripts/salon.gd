extends Node
# Portefaix — le salon en ligne (scripts/salon.gd)
# On ouvre un salon, il donne un code de cinq lettres ; les autres entrent avec ce code. Il faut être connecté à son compte.
# Supabase ne porte que le salon (supabase.sql) : qui y est, et les messages de mise en relation. La partie, elle, passe
# directement d'un joueur à l'autre, par WebRTC : chaque invité se relie à l'hôte, qui fait foi comme en réseau local. Le reste du jeu
# ne voit pas la différence : ce sont les mêmes appels d'un joueur à l'autre.
# WebRTC est dans tous les navigateurs ; sur un ordinateur, Godot demande une extension (webrtc-native) que le projet ne porte pas.

const R = preload("res://scripts/regles.gd")

signal change

var principal
var compte
var code := ""
var numero := 0
var membres: Array = []           # [{numero, pseudo}], l'hôte porte le numéro 1
var occupe := false
var _rtc: WebRTCMultiplayerPeer
var _pairs := {}                  # le numéro d'un membre → sa liaison
var _apres := 0                   # le dernier message de mise en relation lu
var _file: Array = []             # les messages à envoyer, dans l'ordre
var _envoie := false
var _sonde := false
var _t := 0.0

const ERREURS := {
	"introuvable": "Ce code ne mène à aucun salon.",
	"parti": "Dans ce salon, la nuit a déjà commencé.",
	"complet": "Ce salon est plein : six porteurs.",
	"plein": "Trop de salons sont ouverts. Réessaie dans un moment.",
	"connexion": "Ta connexion a expiré : reconnecte-toi.",
	"reseau": "Le service des salons ne répond pas. Vérifie ta connexion.",
	"dehors": "Le salon a fermé.",
}


static func disponible() -> bool:
	return OS.has_feature("web") or ClassDB.class_exists("WebRTCLibPeerConnection")


func hote() -> bool:
	return numero == 1


static func dire(erreur: String) -> String:
	return ERREURS.get(erreur, "Le salon a refusé (%s)." % erreur)


func pseudo_de(n: int) -> String:
	for m in membres:
		if int(m.get("numero", 0)) == n:
			return str(m.get("pseudo", "Porteur"))
	return "Porteur"


# ouvrir un salon : rend "" si c'est fait, sinon ce qui n'a pas marché
func creer() -> String:
	return await _entrer("pf_salon_creer", {"p_pseudo": compte.nom()})


func rejoindre(c: String) -> String:
	c = c.strip_edges().to_upper()
	if c.length() != 5:
		return "Un code de salon fait cinq lettres ou chiffres."
	return await _entrer("pf_salon_rejoindre", {"p_code": c, "p_pseudo": compte.nom()})


func _entrer(fonction: String, params: Dictionary) -> String:
	if occupe:
		return ""
	occupe = true
	change.emit()
	var r: Dictionary = await compte.fonction(fonction, params)
	occupe = false
	if r.has("erreur") or not r.has("code"):
		change.emit()
		return dire(str(r.get("erreur", "reseau")))
	principal.debrancher()                 # (ferme ce qui était ouvert avant)
	code = str(r.code)
	numero = int(r.numero)
	membres = [{"numero": numero, "pseudo": compte.nom()}]
	_apres = 0
	_rtc = WebRTCMultiplayerPeer.new()
	var err := _rtc.create_server() if hote() else _rtc.create_client(numero)
	if err != OK:
		fermer()
		return "Ce navigateur ne sait pas relier deux joueurs (WebRTC)."
	principal.brancher(_rtc, hote())
	if not hote():                         # l'invité fait le premier pas vers l'hôte
		var liaison := _lier(1)
		if liaison == null or liaison.create_offer() != OK:
			quitter()
			return "Ce navigateur ne sait pas relier deux joueurs (WebRTC)."
	_t = 0.0
	change.emit()
	return ""


# une liaison vers un membre : ce qu'elle a à lui dire part par le salon
func _lier(n: int) -> WebRTCPeerConnection:
	var l := WebRTCPeerConnection.new()
	if l.initialize({"iceServers": [{"urls": R.STUN}]}) != OK:
		return null
	l.session_description_created.connect(func(type: String, sdp: String):
		l.set_local_description(type, sdp)
		_signaler(n, {"type": type, "sdp": sdp}))
	l.ice_candidate_created.connect(func(media: String, index: int, nom: String):
		_signaler(n, {"type": "ice", "media": media, "index": index, "nom": nom}))
	if _rtc.add_peer(l, n) != OK:
		return null
	_pairs[n] = l
	return l


func _signaler(vers: int, donnees: Dictionary) -> void:
	_file.append([vers, donnees])
	if _envoie:
		return
	_envoie = true
	while not _file.is_empty() and code != "":
		var m: Array = _file.pop_front()
		await compte.fonction("pf_salon_signal", {"p_code": code, "p_vers": m[0], "p_donnees": m[1]})
	_envoie = false


func _recu(de: int, d) -> void:
	if not (d is Dictionary):
		return
	var type := str(d.get("type", ""))
	var l: WebRTCPeerConnection = _pairs.get(de)
	if l == null:
		if not hote() or type != "offer":       # seul l'hôte ouvre une liaison à la demande, et seulement sur une offre
			return
		l = _lier(de)
		if l == null:
			return
	if type == "offer" or type == "answer":
		l.set_remote_description(type, str(d.get("sdp", "")))
	elif type == "ice":
		l.add_ice_candidate(str(d.get("media", "")), int(d.get("index", 0)), str(d.get("nom", "")))


# l'hôte lance la nuit : plus personne n'entre
func partir() -> void:
	if code != "" and hote():
		compte.fonction("pf_salon_partir", {"p_code": code})


func quitter() -> void:
	if code != "":
		compte.fonction("pf_salon_quitter", {"p_code": code})
	fermer()


# oublier le salon, ici seulement
func fermer() -> void:
	for l in _pairs.values():
		l.close()
	_pairs.clear()
	_file.clear()
	_rtc = null
	var avait := code != ""
	code = ""
	numero = 0
	membres = []
	if avait:
		change.emit()


# tant qu'on attend au salon : une fois par seconde, qui est là, et ce qu'on m'a laissé
func _process(dt: float) -> void:
	if code == "" or _sonde or principal.etat != principal.SALON:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	_sonde = true
	var c := code
	var r: Dictionary = await compte.fonction("pf_salon_etat", {"p_code": c, "p_apres": _apres})
	_sonde = false
	if code != c:
		return
	if r.has("erreur"):
		if str(r.erreur) == "dehors":        # l'hôte est parti : le salon n'est plus
			principal.retour_menu(dire("dehors"))
		return
	if r.get("membres") is Array:
		membres = r.membres
	if r.get("signaux") is Array:
		for s in r.signaux:
			if s is Dictionary:
				_apres = maxi(_apres, int(s.get("id", 0)))
				_recu(int(s.get("de", 0)), s.get("donnees"))
	change.emit()
