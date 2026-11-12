extends Node
# Portefaix — le compte du joueur (scripts/compte.gd)
# On se connecte avec son compte Stone Valley : le même e-mail, le même mot de passe (les comptes du projet Supabase « Vallée de pierre »).
# Le jeu ne lit que qui l'on est et son pseudo ; il ne touche pas à la sauvegarde de Stone Valley (vp_comptes).
# Le mot de passe n'est jamais gardé : seul un jeton de reprise l'est, sur l'appareil, pour rester connecté d'une fois sur l'autre.
# Le pseudo : celui qu'on se choisit ici (gardé sur le compte), sinon celui de Stone Valley.
# On peut aussi créer son compte ici (c'est alors un compte Stone Valley comme un autre), et demander un nouveau mot de passe : le
# service envoie un e-mail, dont le lien ramène à la page du jeu ; le jeu y lit de quoi confirmer le compte, ou changer le mot de passe.

const SUPABASE := "https://ldazucyrnpewkqdneznc.supabase.co"
const CLE := "sb_publishable_qUrfgAsAUzc3jd_tiqkY9g_EVkkQRAs"      # la clé publique du projet : faite pour être dans le jeu
const PSEUDO_MAX := 16
const SITE := "https://stonevalleyoff-ai.github.io/Portefaix/"      # où ramène le lien d'un e-mail, hors d'un navigateur
const MDP_MIN := 6

signal change

var url := SUPABASE
var fichier := "user://compte.json"
var connecte := false
var occupe := false
var id := ""
var pseudo := ""
var erreur := ""
var avis := ""                    # ce qui s'est bien passé, à dire au joueur (« un e-mail vient de partir »)
var a_changer := false            # arrivé par le lien « mot de passe oublié » : il lui faut en choisir un nouveau
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


# où ramener celui qui clique le lien d'un e-mail : la page du jeu (il faut qu'elle soit permise dans le projet Supabase :
# Authentication › URL Configuration › Redirect URLs ; sinon le lien ramène au site par défaut du projet)
func retour() -> String:
	if OS.has_feature("web"):
		var ici = JavaScriptBridge.eval("location.origin + location.pathname", true)
		if ici is String and ici.begins_with("http"):
			return ici
	return SITE


func _adresse(email: String) -> bool:
	var e := email.strip_edges()
	return e.length() >= 5 and e.count("@") == 1 and not e.begins_with("@") and e.get_slice("@", 1).contains(".") and not e.contains(" ")


# créer son compte : le service envoie un e-mail de confirmation (ou connecte tout de suite, si le projet n'en demande pas)
func creer(email: String, mot_de_passe: String, p: String) -> void:
	if occupe:
		return
	avis = ""
	email = email.strip_edges()
	if not _adresse(email):
		erreur = "Cette adresse e-mail ne se lit pas."
	elif mot_de_passe.length() < MDP_MIN:
		erreur = "Le mot de passe doit faire %d caractères au moins." % MDP_MIN
	else:
		erreur = ""
	if erreur != "":
		change.emit()
		return
	_debut()
	var corps := {"email": email, "password": mot_de_passe}
	if propre(p) != "":
		corps["data"] = {"pseudo": propre(p)}
	var r := await _appel(HTTPClient.METHOD_POST, "/auth/v1/signup?redirect_to=" + retour().uri_encode(), corps)
	var j = r.json
	if r.code == 200 and j is Dictionary:
		if str(j.get("access_token", "")) != "":
			await _recevoir(r)
		elif j.get("identities") is Array and j.identities.is_empty():       # (le service répond ainsi pour une adresse déjà prise)
			erreur = "Cette adresse a déjà un compte : connecte-toi, ou demande un nouveau mot de passe."
		else:
			avis = "Un e-mail de confirmation vient de partir à %s. Clique le lien qu'il contient, puis connecte-toi." % email
	else:
		erreur = _dire(r)
	_fin()


# mot de passe oublié : le service envoie un e-mail, dont le lien ramène au jeu pour en choisir un autre
func oublie(email: String) -> void:
	if occupe:
		return
	avis = ""
	email = email.strip_edges()
	if not _adresse(email):
		erreur = "Cette adresse e-mail ne se lit pas."
		change.emit()
		return
	_debut()
	var r := await _appel(HTTPClient.METHOD_POST, "/auth/v1/recover?redirect_to=" + retour().uri_encode(), {"email": email})
	if r.code == 200:
		avis = "Si un compte existe pour %s, un e-mail vient de partir. Ouvre le lien qu'il contient pour choisir un nouveau mot de passe." % email
	else:
		erreur = _dire(r)
	_fin()


# arrivé par le lien d'un e-mail : l'adresse de la page porte de quoi entrer (« #access_token=…&refresh_token=…&type=recovery »),
# ou dit que le lien ne vaut plus rien (« #error=… »)
func lire_lien(fragment: String) -> void:
	var champs := {}
	for morceau in fragment.trim_prefix("#").split("&", false):
		champs[morceau.get_slice("=", 0)] = morceau.get_slice("=", 1).uri_decode()
	if champs.has("error") or champs.has("error_code"):
		erreur = "Ce lien a expiré, ou a déjà servi. Redemande-le."
		change.emit()
		return
	var passe := str(champs.get("access_token", ""))
	if passe == "" or occupe:
		return
	_debut()
	var r := await _appel(HTTPClient.METHOD_GET, "/auth/v1/user", null, passe)
	if r.code == 200 and r.json is Dictionary and await _recevoir({"code": 200, "json": {"access_token": passe, "refresh_token": str(champs.get("refresh_token", "")), "user": r.json}}):
		a_changer = str(champs.get("type", "")) == "recovery"
		avis = "Choisis ton nouveau mot de passe." if a_changer else "Ton compte est confirmé. Bienvenue !"
	else:
		connecte = false
		erreur = "Ce lien a expiré, ou a déjà servi. Redemande-le."
	_fin()


func changer_mot_de_passe(nouveau: String, encore: String) -> void:
	if occupe or not connecte:
		return
	avis = ""
	if nouveau.length() < MDP_MIN:
		erreur = "Le mot de passe doit faire %d caractères au moins." % MDP_MIN
	elif nouveau != encore:
		erreur = "Les deux mots de passe ne sont pas les mêmes."
	else:
		erreur = ""
	if erreur != "":
		change.emit()
		return
	_debut()
	var r := await _appel(HTTPClient.METHOD_PUT, "/auth/v1/user", {"password": nouveau}, jeton)
	if r.code == 200:
		a_changer = false
		avis = "Ton mot de passe est changé."
	else:
		erreur = _dire(r)
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
	avis = ""
	a_changer = false
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
	avis = ""
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
	erreur = _dire(r)
	return false


# ce que le service a refusé, en clair
func _dire(r: Dictionary) -> String:
	var code := str(r.json.get("error_code", "")) if r.json is Dictionary else ""
	if r.code == 0:
		return "Le service des comptes ne répond pas. Vérifie ta connexion."
	match code:
		"invalid_credentials":
			return "E-mail ou mot de passe incorrect."
		"email_not_confirmed":
			return "Ce compte n'a pas encore confirmé son e-mail : clique le lien reçu à sa création."
		"weak_password":
			return "Ce mot de passe est trop faible : %d caractères au moins." % MDP_MIN
		"same_password":
			return "C'est déjà ton mot de passe : choisis-en un autre."
		"user_already_exists", "email_exists":
			return "Cette adresse a déjà un compte : connecte-toi, ou demande un nouveau mot de passe."
		"email_address_invalid", "validation_failed":
			return "Cette adresse e-mail n'est pas acceptée."
		"signup_disabled", "email_provider_disabled":
			return "La création de compte est fermée pour l'instant."
		"over_email_send_rate_limit":
			return "Trop d'e-mails envoyés pour l'instant. Réessaie dans une heure."
		"otp_expired":
			return "Ce lien a expiré, ou a déjà servi. Redemande-le."
	if r.code == 429:
		return "Trop d'essais. Attends une minute."
	return "Le service a refusé (%d)." % r.code


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
