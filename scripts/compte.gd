extends Node
# Portefaix — le compte du joueur (scripts/compte.gd)
# On se connecte avec son compte Stone Valley : le même e-mail, le même mot de passe (les comptes du projet Supabase « Vallée de pierre »).
# Le jeu ne lit que qui l'on est et son pseudo ; il ne touche pas à la sauvegarde de Stone Valley (vp_comptes).
# Le mot de passe n'est jamais gardé : seul un jeton de reprise l'est, sur l'appareil, pour rester connecté d'une fois sur l'autre.
# Le pseudo : celui qu'on se choisit ici (gardé sur le compte), sinon celui de Stone Valley.

const SUPABASE := "https://ldazucyrnpewkqdneznc.supabase.co"
const CLE := "sb_publishable_qUrfgAsAUzc3jd_tiqkY9g_EVkkQRAs"      # la clé publique du projet : faite pour être dans le jeu
const PSEUDO_MAX := 16

signal change

var url := SUPABASE
var fichier := "user://compte.json"
var connecte := false
var occupe := false
var id := ""
var pseudo := ""
var erreur := ""
var jeton := ""                   # ce qui prouve qui l'on est, pour ce qui viendra (le jeu en ligne)
var _reprise := ""
var _jeton_le := 0                # quand le jeton a été reçu : il ne vaut qu'une heure


func nom() -> String:
	return pseudo if pseudo != "" else "Porteur"


static func propre(p: String) -> String:
	var t := ""
	for c in p.strip_edges():
		if c.unicode_at(0) >= 32 and c != "<" and c != ">":
			t += c
	return t.substr(0, PSEUDO_MAX).strip_edges()


func connecter(email: String, mot_de_passe: String) -> void:
	if occupe:
		return
	if email.strip_edges() == "" or mot_de_passe == "":
		erreur = "Il faut un e-mail et un mot de passe."
		change.emit()
		return
	_debut()
	var r := await _appel(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": email.strip_edges(), "password": mot_de_passe})
	await _recevoir(r)
	_fin()


# au lancement : si l'on était connecté la dernière fois, on le reste
func reprendre() -> void:
	if occupe or not FileAccess.file_exists(fichier):
		return
	var garde = JSON.parse_string(FileAccess.get_file_as_string(fichier))
	if not (garde is Dictionary) or str(garde.get("reprise", "")) == "":
		return
	_debut()
	var r := await _appel(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": str(garde.reprise)})
	if not await _recevoir(r):
		erreur = ""                       # (ce n'est pas une faute du joueur : il se reconnectera)
		if r.code >= 400:                 # le jeton ne vaut plus rien ; sans réseau, on le garde pour la prochaine fois
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	_fin()


func deconnecter() -> void:
	if jeton != "":
		_appel(HTTPClient.METHOD_POST, "/auth/v1/logout?scope=local", {}, jeton)
	connecte = false
	id = ""
	pseudo = ""
	jeton = ""
	_reprise = ""
	erreur = ""
	if FileAccess.file_exists(fichier):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	change.emit()


# se choisir un pseudo : gardé sur le compte (ses « métadonnées »), pas dans la sauvegarde de Stone Valley
func nommer(p: String) -> void:
	p = propre(p)
	if occupe or not connecte or p == "":
		return
	_debut()
	var r := await _appel(HTTPClient.METHOD_PUT, "/auth/v1/user", {"data": {"pseudo": p}}, jeton)
	if r.code == 200:
		pseudo = p
	else:
		erreur = "Le pseudo n'a pas pu être gardé."
	_fin()


# appeler une fonction de la base, en son nom : rend sa réponse, ou {erreur}
func fonction(nom_fonction: String, params: Dictionary) -> Dictionary:
	if not connecte:
		return {"erreur": "connexion"}
	if Time.get_ticks_msec() - _jeton_le > 45 * 60 * 1000 and _reprise != "":      # le jeton vieillit : on le renouvelle
		_jeton_le = Time.get_ticks_msec()
		await _recevoir(await _appel(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _reprise}))
		if not connecte:
			change.emit()
			return {"erreur": "connexion"}
	var r := await _appel(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + nom_fonction, params, jeton)
	if r.code == 200 and r.json is Dictionary:
		return r.json
	return {"erreur": "reseau" if r.code == 0 else ("connexion" if r.code == 401 or r.code == 403 else "refus %d" % r.code)}


func _debut() -> void:
	occupe = true
	erreur = ""
	change.emit()


func _fin() -> void:
	occupe = false
	change.emit()


func _recevoir(r: Dictionary) -> bool:
	var j = r.json
	if r.code == 200 and j is Dictionary and str(j.get("access_token", "")) != "" and j.get("user") is Dictionary:
		jeton = str(j.access_token)
		_jeton_le = Time.get_ticks_msec()
		_reprise = str(j.get("refresh_token", ""))
		id = str(j.user.get("id", ""))
		pseudo = ""
		var meta = j.user.get("user_metadata")
		if meta is Dictionary and meta.get("pseudo") is String:
			pseudo = propre(meta.pseudo)
		if pseudo == "":
			await _pseudo_de_stone_valley()
		var f := FileAccess.open(fichier, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"reprise": _reprise}))
			f.close()
		connecte = true
		erreur = ""
		return true
	connecte = false
	var code := str(j.get("error_code", "")) if j is Dictionary else ""
	if r.code == 0:
		erreur = "Le service des comptes ne répond pas. Vérifie ta connexion."
	elif code == "invalid_credentials":
		erreur = "E-mail ou mot de passe incorrect."
	elif code == "email_not_confirmed":
		erreur = "Ce compte n'a pas encore confirmé son e-mail."
	elif r.code == 429:
		erreur = "Trop d'essais. Attends une minute."
	else:
		erreur = "Connexion refusée (%d)." % r.code
	return false


# le pseudo de sa sauvegarde Stone Valley, si elle en a un (chacun ne peut lire que la sienne)
func _pseudo_de_stone_valley() -> void:
	var r := await _appel(HTTPClient.METHOD_GET, "/rest/v1/vp_comptes?select=pseudo:donnees-%3E%3Epseudo", null, jeton)
	if r.code == 200 and r.json is Array and not r.json.is_empty() and r.json[0] is Dictionary and r.json[0].get("pseudo") is String:
		pseudo = propre(r.json[0].pseudo)


func _appel(methode: int, chemin: String, corps = null, porteur: String = "") -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 15.0
	add_child(h)
	var entetes := PackedStringArray(["apikey: " + CLE, "Content-Type: application/json"])
	if porteur != "":
		entetes.append("Authorization: Bearer " + porteur)
	if h.request(url + chemin, entetes, methode, "" if corps == null else JSON.stringify(corps)) != OK:
		h.queue_free()
		return {"code": 0, "json": null}
	var r: Array = await h.request_completed
	h.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "json": null}
	var texte: String = r[3].get_string_from_utf8()
	return {"code": int(r[1]), "json": JSON.parse_string(texte) if texte.strip_edges() != "" else null}
