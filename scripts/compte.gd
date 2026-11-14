extends Node
# Portefaix — le compte du joueur (scripts/compte.gd)
# On se connecte avec son compte Stone Valley : le même e-mail, le même mot de passe (les comptes du projet Supabase « Vallée de pierre »).
# Le jeu ne lit que qui l'on est et son pseudo ; il ne touche pas à la sauvegarde de Stone Valley (vp_comptes).
# Le mot de passe n'est jamais gardé : seul un jeton de reprise l'est, sur l'appareil, pour rester connecté d'une fois sur l'autre.
# Le pseudo : celui qu'on se choisit ici (gardé sur le compte), sinon celui de Stone Valley.
# On peut aussi créer son compte ici (c'est alors un compte Stone Valley comme un autre), et demander un nouveau mot de passe : le
# service envoie un e-mail, dont le lien ramène à la page du jeu ; le jeu y lit de quoi confirmer le compte, ou changer le mot de passe.
# Dans un navigateur, la session est celle du portail et des autres jeux du site (même adresse, même stockage, sous la clé
# « stonevalley:session ») : connecté au portail, on l'est ici en arrivant, et l'inverse ; se déconnecter déconnecte partout. Un
# jeton de reprise ne sert qu'une fois : avant de renouveler, on regarde si un autre ne vient pas de le faire.

const SUPABASE := "https://ldazucyrnpewkqdneznc.supabase.co"
const CLE := "sb_publishable_qUrfgAsAUzc3jd_tiqkY9g_EVkkQRAs"      # la clé publique du projet : faite pour être dans le jeu
const PSEUDO_MAX := 16
const SITE := "https://stonevalleyoff-ai.github.io/Portefaix/"      # où ramène le lien d'un e-mail, hors d'un navigateur
const MDP_MIN := 6
const COMMUNE := "stonevalley:session"      # dans un navigateur : la session commune au portail et aux jeux

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
var _email := ""


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
	if occupe:
		return
	# (dans un navigateur : la session du portail, si l'on y est connecté ; un jeton encore bon sert tel quel, sans le renouveler)
	var c := _commune()
	if not c.is_empty():
		_debut()
		var reste := (float(c.get("exp", 0.0)) - Time.get_unix_time_from_system() * 1000.0) / 1000.0
		var r := {"code": 0, "json": null}
		if reste > 60.0:
			var u := await _appel(HTTPClient.METHOD_GET, "/auth/v1/user", null, str(c.jeton))
			if u.code == 200 and u.json is Dictionary:
				r = {"code": 200, "json": {"access_token": str(c.jeton), "refresh_token": str(c.get("refresh", "")), "expires_in": reste, "user": u.json}}
		if r.code != 200 and str(c.get("refresh", "")) != "":
			r = await _appel(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": str(c.refresh)})
		if not await _recevoir(r):
			erreur = ""
			if r.code >= 400 and not _renouvelee_ailleurs():      # elle ne vaut plus rien, pour personne
				_ecrire_commune(false)
		_fin()
		return
	if not FileAccess.file_exists(fichier):
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
	_email = ""
	if FileAccess.file_exists(fichier):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	_ecrire_commune(false)
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
	if Time.get_ticks_msec() - _jeton_le > 45 * 60 * 1000 and _reprise != "" and not _renouvelee_ailleurs():      # le jeton vieillit : on le renouvelle
		_jeton_le = Time.get_ticks_msec()
		var id_avant := id
		var pseudo_avant := pseudo
		if not await _recevoir(await _appel(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _reprise})):
			id = id_avant
			if _renouvelee_ailleurs():       # (un autre l'a renouvelée pendant qu'on demandait)
				connecte = true
				pseudo = pseudo_avant
				erreur = ""
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
		# (un jeton repris au portail a déjà vécu : on compte son âge)
		_jeton_le = Time.get_ticks_msec() - int(maxf(0.0, 3600.0 - float(j.get("expires_in", 3600))) * 1000.0)
		_reprise = str(j.get("refresh_token", ""))
		id = str(j.user.get("id", ""))
		_email = str(j.user.get("email", ""))
		pseudo = ""
		var meta = j.user.get("user_metadata")
		if meta is Dictionary and meta.get("pseudo") is String:
			pseudo = propre(meta.pseudo)
		if pseudo == "":
			await _pseudo_de_stone_valley()
		if OS.has_feature("web"):
			# (dans un navigateur, la session se garde sous la clé commune, et là seulement : sinon une session fermée au portail renaîtrait d'ici)
			if FileAccess.file_exists(fichier):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
			_ecrire_commune(true, float(j.get("expires_in", 3600)))
		else:
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


# --- la session commune du site (dans un navigateur seulement) ---

# telle qu'elle est gardée ({} : aucune, ou hors d'un navigateur). Sa forme : { jeton, refresh, exp (millisecondes), uid, email, pseudo }
func _commune() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var t = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % COMMUNE, true)
	if not (t is String) or t == "":
		return {}
	var c = JSON.parse_string(t)
	if not (c is Dictionary) or str(c.get("jeton", "")) == "" or str(c.get("uid", "")) == "":
		return {}
	return c


func _ecrire_commune(dedans: bool, dure: float = 3600.0) -> void:
	if not OS.has_feature("web"):
		return
	if not dedans:
		JavaScriptBridge.eval("try{localStorage.removeItem('%s')}catch(e){}" % COMMUNE, true)
		return
	var texte := JSON.stringify({"jeton": jeton, "refresh": _reprise, "exp": int((Time.get_unix_time_from_system() + dure) * 1000.0), "uid": id, "email": _email, "pseudo": pseudo})
	JavaScriptBridge.eval("try{localStorage.setItem('%s',%s)}catch(e){}" % [COMMUNE, JSON.stringify(texte)], true)


# le portail ou un autre jeu vient-il de renouveler la session commune ? Alors on prend la leur, sans rien demander au service
func _renouvelee_ailleurs() -> bool:
	var c := _commune()
	if c.is_empty() or str(c.get("uid", "")) != id or str(c.get("refresh", "")) in ["", _reprise]:
		return false
	var reste := float(c.get("exp", 0.0)) / 1000.0 - Time.get_unix_time_from_system()
	if reste <= 60.0:
		return false
	jeton = str(c.jeton)
	_reprise = str(c.refresh)
	_jeton_le = Time.get_ticks_msec() - int(maxf(0.0, 3600.0 - reste) * 1000.0)
	return true


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
