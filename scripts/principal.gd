extends Node
# Portefaix — le chef d'orchestre (scripts/principal.gd)
# Il tient le menu, le réseau et la partie. L'hôte fait foi : c'est lui qui fait tomber les meubles, penser la chose, compter le
# chargement et dépouiller les votes ; il le redit aux autres. Chaque joueur ne mène que son porteur, et demande le reste à l'hôte.
# Tout le monde bâtit la même maison et les mêmes meubles, d'après une graine que l'hôte donne au départ. Seul, on est son propre hôte.

const R = preload("res://scripts/regles.gd")
const Maison = preload("res://scripts/maison.gd")
const Objet = preload("res://scripts/objet.gd")
const Joueur = preload("res://scripts/joueur.gd")
const Creature = preload("res://scripts/creature.gd")
const Chat = preload("res://scripts/chat.gd")
const Micro = preload("res://scripts/micro.gd")
const Sons = preload("res://scripts/sons.gd")
const Interface = preload("res://scripts/interface.gd")
const Tactile = preload("res://scripts/tactile.gd")
const Compte = preload("res://scripts/compte.gd")
const Bourse = preload("res://scripts/bourse.gd")
const Salon = preload("res://scripts/salon.gd")
const Amenagement = preload("res://scripts/amenagement.gd")
const Essai = preload("res://scripts/essai.gd")

enum { MENU, SALON, PARTIE, FIN }

var etat := MENU
var serveur := true
var en_reseau := false
var mon_id := 1
var monde: Node3D
var maison
var chose                         # la créature (la première, s'il y en a plusieurs)
var choses: Array = []            # toutes : le manoir en a une, le bunker plusieurs
var chat
var micro
var sons
var ui
var tactile
var compte
var bourse = Bourse.new()         # la caisse de qui joue ici : ce qu'il a gagné, ce qu'il doit, ce qu'il a acheté
var equipes := {}                 # chez l'hôte : ce que chaque porteur a emporté cette nuit
var _bourse_de := "?"
var salon
var noms := {}                    # le numéro d'un joueur → son pseudo, tel qu'il l'a donné en entrant au salon
var web := OS.has_feature("web")  # dans un navigateur : on joue seul (pas de port à ouvrir), le doigt ou le clavier
# « --hors-ligne » : la page qui porte le jeu ne laisse rien sortir vers le réseau (ni comptes, ni chat de Twitch) ; on n'y propose ni l'un ni l'autre
var hors_ligne := OS.get_cmdline_args().has("--hors-ligne") or OS.get_cmdline_user_args().has("--hors-ligne")
var moi
var joueurs := {}
var objets := {}
var hasard := RandomNumberGenerator.new()
var temps := 0.0
var total := 0
var prime := 0                    # ce que valent les trésors d'une maison bonus (hors quota)
var quota := 0
var charge := 0
var gagne := false
var torche_au_depart := true      # (les essais partent torche éteinte : le fantôme la voit de loin)
var lieu := "manoir"              # où l'on joue la prochaine nuit : le manoir, ou le bunker
var doses := {}                   # chez l'hôte : la dose de chaque porteur, de 0 à 1 (au bunker)
var ma_dose := 0.0
var _t_dose := 0.0
var _t_geiger := 0.0
var _sans_liaison := {}           # au salon : depuis quand chaque membre attend d'être relié (son numéro → l'heure, en ms)
var etages_voulus := false       # pour les essais : la maison d'essai, avec son étage et son sous-sol
var bonus_voulu: Array = []      # pour les essais : la maison d'essai, avec ces pièces bonus
var graine := -1                # la graine de la maison ; -1, le hasard la choisit ; une autre négative : la maison d'essai
var repit: float = R.REPIT       # la chose dort jusque-là (l'essai le repousse)
var bras := {}                    # chez l'hôte : le porteur → ce qu'il reste à ses deux bras pour repousser
var blessures := {}               # chez l'hôte : le porteur terrifié → depuis combien de temps il est revenu au camion
var effets := {}                  # les sabotages en cours : nom → {reste, param}
var _vote := {"ouvert": false, "options": [], "voix": [0, 0, 0], "reste": 0.0}
var _poussees := {}
var _tour := 0
var _t_objets := 0.0
var _t_etat := 0.0
var _t_ecoute := 0.0
var _t_charge := 0.0
var _t_vote := 0.0
var _t_coeur := 0.0
var _t_temoin := 0.0
var _t_niveaux := 0.0
var graine_jouee := 0             # la graine de la maison où l'on joue


func _ready() -> void:
	hasard.randomize()
	sons = Sons.new()
	sons.name = "Sons"
	add_child(sons)
	micro = Micro.new()
	micro.name = "Micro"
	add_child(micro)
	chat = Chat.new()
	chat.name = "Chat"
	add_child(chat)
	chat.vote_clos.connect(_sur_vote)
	ui = Interface.new()
	ui.name = "Interface"
	add_child(ui)
	ui.seul.connect(jouer_seul)
	ui.heberger.connect(heberger)
	ui.rejoindre.connect(rejoindre)
	ui.commencer.connect(lancer)
	ui.rejouer.connect(lancer)
	ui.quitter.connect(retour_menu)
	compte = Compte.new()
	compte.name = "Compte"
	add_child(compte)
	compte.change.connect(_sur_compte)
	ui.connexion.connect(compte.connecter)
	ui.deconnexion.connect(compte.deconnecter)
	ui.pseudo_choisi.connect(compte.nommer)
	ui.creation.connect(compte.creer)
	ui.oubli.connect(compte.oublie)
	ui.nouveau_mot_de_passe.connect(compte.changer_mot_de_passe)
	ui.page_compte.connect(func():
		compte.erreur = ""
		compte.avis = ""
		_sur_compte())
	ui.vers_connexion.connect(ui.page_connexion)
	ui.sans_compte.connect(func(): ui.menu(""))
	ui.lieu_change.connect(func():
		lieu = "bunker" if lieu == "manoir" else "manoir"
		ui.lieu(lieu))
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "--lieu=bunker":
			lieu = "bunker"
	if web and str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('lieu') || ''", true)) == "bunker":
		lieu = "bunker"
	ui.lieu(lieu)
	ui.vers_boutique.connect(func(): ui.boutique(bourse))
	ui.achat.connect(func(nom: String):
		var refus: String = bourse.acheter(nom)
		_dire_bourse()
		ui.boutique(bourse, refus if refus != "" else "Acheté : %s." % R.BOUTIQUE[nom].nom))
	salon = Salon.new()
	salon.name = "Salon"
	salon.principal = self
	salon.compte = compte
	add_child(salon)
	salon.change.connect(_sur_salon)
	ui.salon_creer.connect(ouvrir_salon)
	ui.salon_rejoindre.connect(entrer_salon)
	ui.en_ligne(Salon.disponible())
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--service="):          # un autre service de comptes et de salons (les essais)
			compte.url = a.get_slice("=", 1)
	_sur_compte()
	tactile = Tactile.new()
	tactile.name = "Tactile"
	tactile.jeu = self
	add_child(tactile)
	if web:
		ui.passer_au_navigateur()
	multiplayer.peer_connected.connect(_arrive)
	multiplayer.peer_disconnected.connect(_part)
	multiplayer.connected_to_server.connect(_connecte)
	multiplayer.connection_failed.connect(func(): retour_menu("L'hôte ne répond pas."))
	multiplayer.server_disconnected.connect(func(): retour_menu("L'hôte a fermé la partie."))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--essai"):
			bourse.garder = false            # (les essais ne touchent pas à la caisse gardée sur l'appareil)
			bourse.ouvrir("essai")
			_bourse_de = "essai"
			var e := Essai.new()
			e.name = "Essai"
			e.mode = a
			add_child(e)
			return
	if hors_ligne:
		ui.passer_hors_ligne()
		return
	# la première page : la connexion, sauf si l'on était resté connecté
	ui.page_connexion()
	# arrivé par le lien d'un e-mail (un compte à confirmer, un mot de passe à refaire) ? L'adresse de la page le dit ; on l'en efface.
	if web:
		var lien = JavaScriptBridge.eval("location.hash", true)
		if lien is String and (lien.contains("access_token=") or lien.contains("error")):
			JavaScriptBridge.eval("history.replaceState(null, '', location.pathname + location.search)", true)
			await compte.lire_lien(lien)
	if not compte.connecte:
		await compte.reprendre()
	_sur_compte()
	if web:                              # (la page dit de quelle construction elle est : outils/pwa.js)
		var v = JavaScriptBridge.eval("window.PORTEFAIX_VERSION || ''", true)
		if typeof(v) == TYPE_STRING and v != "":
			ui.version("version " + v)


# --- le compte ---

func _dire_bourse() -> void:
	ui.bourse(bourse.dire(), bourse.argent < 0)


func _sur_compte() -> void:
	var a_qui: String = compte.id if compte.connecte else ""
	if a_qui != _bourse_de:               # chaque compte a sa caisse (et qui joue sans compte, la sienne)
		_bourse_de = a_qui
		bourse.ouvrir(a_qui)
		_dire_bourse()
	var entre: bool = compte.connecte and not compte.occupe and ui.sur_un_compte()
	ui.compte(compte.connecte, compte.nom(), compte.occupe, compte.erreur, compte.avis)
	if compte.connecte and compte.a_changer and etat == MENU:
		ui.page_nouveau_mot_de_passe()       # venu par « mot de passe oublié » : d'abord en choisir un nouveau
	elif entre:               # connecté : les pages de compte laissent la place au menu
		ui.menu(compte.avis)
	if etat == SALON:
		if serveur:
			_dire_salon()
		elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			se_presenter.rpc_id(1, compte.nom())


# un invité dit son pseudo à l'hôte en entrant au salon (l'hôte le croit sur parole : ce sera vérifié avec le jeu en ligne)
@rpc("any_peer", "call_remote", "reliable")
func se_presenter(p: String) -> void:
	if not serveur or etat != SALON:
		return
	var qui := multiplayer.get_remote_sender_id()
	var propre: String = Compte.propre(p)
	noms[qui] = propre if propre != "" else "Porteur"
	_dire_salon()


# --- le salon en ligne ---

func ouvrir_salon() -> void:
	ui.menu("On ouvre un salon…")
	var refus: String = await salon.creer()
	if refus != "":
		ui.menu(refus)


func entrer_salon(code: String) -> void:
	ui.menu("On frappe à la porte du salon…")
	var refus: String = await salon.rejoindre(code)
	if refus != "":
		ui.menu(refus)


# le salon a relié les joueurs : le jeu passe par là
func brancher(pair: MultiplayerPeer, hote: bool) -> void:
	multiplayer.multiplayer_peer = pair
	en_reseau = true
	serveur = hote
	mon_id = multiplayer.get_unique_id()
	etat = SALON
	_dire_salon()


func _sur_salon() -> void:
	if etat == SALON and salon.code != "":
		_dire_salon()


# --- le menu et le réseau ---

func jouer_seul() -> void:
	_hors_ligne()
	lancer()


func heberger() -> bool:
	_hors_ligne()
	var pair := ENetMultiplayerPeer.new()
	if pair.create_server(R.PORT, R.JOUEURS_MAX - 1) != OK:
		ui.menu("Le port %d est déjà pris : une autre partie tourne sur cette machine ?" % R.PORT)
		return false
	multiplayer.multiplayer_peer = pair
	en_reseau = true
	etat = SALON
	noms = {1: compte.nom()}
	_dire_salon()
	return true


func rejoindre(adresse: String) -> void:
	_hors_ligne()
	var pair := ENetMultiplayerPeer.new()
	if adresse == "" or pair.create_client(adresse, R.PORT) != OK:
		ui.menu("Cette adresse ne se lit pas.")
		return
	multiplayer.multiplayer_peer = pair
	en_reseau = true
	serveur = false
	etat = SALON
	ui.salon("On frappe chez %s…" % adresse, false)


func debrancher() -> void:
	_hors_ligne()


func _hors_ligne() -> void:
	_sans_liaison.clear()
	chat.arreter()
	salon.quitter()
	if en_reseau:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	en_reseau = false
	serveur = true
	mon_id = 1


func _arrive(id: int) -> void:
	if not serveur:
		return
	if etat != SALON:          # on n'entre pas dans une nuit commencée
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	_dire_salon()


func _part(id: int) -> void:
	if not serveur:
		return
	noms.erase(id)
	if etat == SALON:
		_dire_salon()
	elif etat == PARTIE and joueurs.has(id):
		tuer(id)


func _connecte() -> void:
	mon_id = multiplayer.get_unique_id()
	if salon.code != "":              # en ligne, le salon sait déjà qui je suis
		_dire_salon()
		return
	se_presenter.rpc_id(1, compte.nom())
	ui.salon("Tu es dans le salon, %s. L'hôte lance la nuit." % compte.nom(), false)


func _dire_salon() -> void:
	if salon.code != "":
		# en ligne : le code à donner aux autres, qui est là, et qui est déjà relié
		var relies: Array = multiplayer.get_peers()
		var gens: Array = []
		var maintenant := Time.get_ticks_msec()
		var bloque := false                # quelqu'un attend sa liaison depuis trop longtemps : les deux réseaux ne se laissent pas relier
		for m in salon.membres:
			var n := int(m.get("numero", 0))
			var lie: bool = n == salon.numero or relies.has(n) or (not salon.hote() and n != 1)
			if lie:
				_sans_liaison.erase(n)
			elif not _sans_liaison.has(n):
				_sans_liaison[n] = maintenant
			var long: bool = not lie and maintenant - int(_sans_liaison[n]) > 25000
			bloque = bloque or long
			gens.append(str(m.get("pseudo", "Porteur")) + ("" if lie else (" (la liaison n'aboutit pas)" if long else " (en route…)")))
		var suite := "Donne ce code aux autres. Lance la nuit quand tout le monde est là." if salon.hote() \
			else ("L'hôte lance la nuit." if relies.has(1) else "On te relie à l'hôte…")
		if bloque:
			suite += "\n\nLa liaison directe entre vos deux appareils n'aboutit pas. C'est en général le réseau de l'un des deux qui la refuse (un téléphone en 4G ou 5G, un réseau d'entreprise ou d'école, un VPN). Essayez depuis une box ordinaire, ou coupez le VPN."
		ui.salon("C'est le code de ce salon.\n\nDans le salon : %s.\n%s" % [", ".join(gens), suite], salon.hote(), salon.code)
		return
	var adresses: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			adresses.append(a)
	var presents: Array = [compte.nom()]
	for id in multiplayer.get_peers():
		presents.append(str(noms.get(id, "…")))
	ui.salon("Dans le salon : %s.\nLes autres te rejoignent à l'adresse : %s (port %d, UDP)."
		% [", ".join(presents), " ou ".join(adresses) if not adresses.is_empty() else "celle de cette machine", R.PORT], true)


# l'hôte (ou le joueur seul) lance la nuit pour tout le monde
func lancer() -> void:
	if not serveur:
		return
	var ids: Array = [1]
	for id in multiplayer.get_peers():
		ids.append(id)
	ids.sort()
	noms[1] = compte.nom()
	if salon.code != "":             # en ligne, les pseudos sont ceux du salon, et plus personne n'entre
		for id in ids:
			noms[id] = salon.pseudo_de(id)
		salon.partir()
	var pseudos: Array = []
	for id in ids:
		pseudos.append(str(noms.get(id, "Porteur")))
	chat.chaine = "" if hors_ligne else ui.chaine()
	commencer.rpc(graine if graine != -1 else _au_hasard(), ids, pseudos, lieu)


func retour_menu(avis: String = "") -> void:
	_vider()
	_hors_ligne()
	etat = MENU
	sons.nuit(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.menu(avis)


func _vider() -> void:
	if monde != null:
		monde.name = "Vieux%d" % Time.get_ticks_usec()
		monde.queue_free()
	monde = null
	maison = null
	chose = null
	choses = []
	moi = null
	joueurs.clear()
	objets.clear()
	effets.clear()
	blessures.clear()
	bras.clear()
	_poussees.clear()


# --- le début d'une nuit, chez tout le monde ---

# la graine de la nuit. « --bonus=cave,garage » (ou « ?bonus=cave,garage » dans l'adresse de la page) : on en cherche une qui donne ces pièces-là
func _au_hasard() -> int:
	var voulu := ""
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--bonus="):
			voulu = a.trim_prefix("--bonus=")
	if web and voulu == "":
		voulu = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('bonus') || ''", true))
	if web:                                      # « ?graine=1234 » : cette maison-là (pour retrouver celle où quelque chose cloche)
		var dite := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('graine') || ''", true))
		if dite.is_valid_int() and int(dite) > 0:
			return int(dite)
	var sortes: Array = Array(voulu.split(",", false)).filter(func(s): return R.BONUS.has(s)).slice(0, 2)
	if voulu != "" and sortes.is_empty():        # « ?bonus=oui » : n'importe laquelle, mais une maison bonus
		sortes = [""]
	for essai in 50000:
		var g := int(hasard.randi())
		if sortes.is_empty():
			return g
		var tire: Array = Maison.tirage_bonus(g).slice(0, 2)
		if not tire.is_empty() and sortes.all(func(s): return s == "" or tire.has(s)):
			return g
	return int(hasard.randi())


@rpc("authority", "call_local", "reliable")
func commencer(graine: int, ids: Array, pseudos: Array, ou_donc: String = "manoir") -> void:
	graine_jouee = graine
	_vider()
	mon_id = multiplayer.get_unique_id()
	serveur = multiplayer.is_server()
	monde = Node3D.new()
	monde.name = "Monde"
	add_child(monde)
	_ambiance()
	maison = Maison.new()
	maison.name = "Maison"
	monde.add_child(maison)
	if graine < 0:
		maison.bonus_voulu = bonus_voulu
		maison.etages_voulus = etages_voulus
	elif ou_donc == "bunker":
		maison.lieu = "bunker"
	maison.construire(graine)
	_meubler(graine)
	for k in ids.size():
		ajouter_joueur(int(ids[k]), maison.depart(k), k, Compte.propre(str(pseudos[k])) if k < pseudos.size() else "Porteur")
	moi = joueurs.get(mon_id)
	choses = []
	for k in maison.tanieres.size():           # une créature par tanière
		var c := Creature.new()
		c.name = "Chose" if k == 0 else "Chose%d" % k
		c.sorte = 1 if maison.lieu == "bunker" else 0
		c.taniere = maison.tanieres[k]
		monde.add_child(c)
		c.preparer(self)
		choses.append(c)
	chose = choses[0]
	quota = R.quota(total, ids.size())
	temps = R.DUREE_NUIT
	charge = 0
	gagne = false
	_vote = {"ouvert": false, "options": [], "voix": [0, 0, 0], "reste": 0.0}
	etat = PARTIE
	if serveur:
		chat.recommencer()
	# ce qu'on a acheté : les chaussons et la torche sont l'affaire de chacun ; le reste, l'hôte doit le savoir
	equipes = {}
	if moi != null:
		moi.discret = R.CHAUSSONS if bourse.a("chaussons") else 1.0
		if bourse.a("lampe"):
			moi.torche.spot_range = 26.0
			moi.torche.spot_angle = 38.0
			moi.torche.light_energy = 3.0
	vouloir("equipe", [bourse.equipement()])
	micro.regler(ui.micro() and DisplayServer.get_name() != "headless")
	sons.nuit(true)
	ui.partie()
	doses = {}
	ma_dose = 0.0
	ui.dose(0.0, 0.0, false)
	if maison.lieu == "bunker":
		ui.annoncer("Le bunker : trois niveaux sous terre, par l'escalier au bout du couloir. Ils sont %d là-dessous.\nChargez pour %d € avant 6 h. Fuyez ce qui luit en vert." % [choses.size(), quota], 10.0)
	elif maison.bonus.is_empty():
		ui.annoncer("Chargez pour %d € dans la zone jaune avant 6 h. Puis klaxonnez.%s" % [quota, "\nL'escalier est au bout du couloir : un étage, un sous-sol." if maison.niveaux.size() > 1 else ""], 9.0)
	else:
		var noms: Array = maison.bonus.map(func(b): return maison.NOMS[b])
		ui.annoncer("MANOIR BONUS ! Ici : %s. Une fortune, en plus du quota.\nChargez pour %d € avant 6 h, puis klaxonnez." % [" et ".join(noms) if noms.size() < 3 else "%s, %s et %s" % noms, quota], 10.0)
	if not tactile.actif:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ambiance() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.015, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.45, 0.7)
	env.ambient_light_energy = 0.16
	env.fog_enabled = true
	env.fog_light_color = Color(0.015, 0.02, 0.035)
	env.fog_density = 0.035
	var w := WorldEnvironment.new()
	w.environment = env
	monde.add_child(w)


# les meubles : la même graine donne à tous les mêmes meubles aux mêmes endroits (scripts/amenagement.gd)
func _meubler(graine: int) -> void:
	var h := RandomNumberGenerator.new()
	h.seed = absi(graine) + 1
	var a := Amenagement.new()
	a.amenager(maison, h)
	for d in a.decors:
		maison.ajouter_decor(d)
	maison.encombrer(a.lourds, a.fixes, a.lourds_n, a.fixes_n)
	total = 0
	prime = 0
	for d in a.objets:
		var o := Objet.new()
		o.preparer(self, objets.size(), d.type)
		o.position = d.pos
		o.rotation.y = d.yaw
		o.cible_pos = o.position
		o.cible_rot = Quaternion(Vector3.UP, d.yaw)
		if d.accroche:
			o.accrocher()
		monde.add_child(o)
		if serveur:
			o.choc.connect(_sur_choc)
			o.traine.connect(_sur_traine)
		objets[o.id] = o
		o.bonus = d.get("bonus", false)
		if o.bonus:                      # la prime ne compte pas dans le quota : c'est en plus
			prime += o.valeur
		else:                            # (à l'étage, au sous-sol, au fond du bunker : cela pèse moins dans le quota)
			total += int(o.valeur * maison.poids(maison.niveau_de(d.pos.y)))


func ajouter_joueur(id: int, ou: Vector3, rang: int, pseudo: String = "Porteur"):
	var j := Joueur.new()
	j.nom = pseudo
	j.preparer(self, id, ou, rang)
	j.torche_voulue = torche_au_depart
	monde.add_child(j)
	joueurs[id] = j
	return j


# --- ce qu'un joueur demande à l'hôte ---

func vouloir(quoi: String, args: Array = []) -> void:
	if serveur:
		_demande(mon_id, quoi, args)
	else:
		demande.rpc_id(1, quoi, args)


@rpc("any_peer", "call_remote", "reliable")
func demande(quoi: String, args: Array) -> void:
	if serveur:
		_demande(multiplayer.get_remote_sender_id(), quoi, args)


func _demande(qui: int, quoi: String, args: Array) -> void:
	if etat != PARTIE or not joueurs.has(qui):
		return
	var ido := -1
	if args.size() >= 1 and typeof(args[0]) == TYPE_INT:
		ido = args[0]
	match quoi:
		"prendre":
			prendre(qui, ido)
		"lacher":
			lacher(qui, ido, args.size() >= 2 and typeof(args[1]) == TYPE_BOOL and args[1])
		"pousser":
			pousser(qui, ido)
		"klaxon":
			klaxonner(qui)
		"equipe":
			var e: Array = []
			if args.size() >= 1 and typeof(args[0]) == TYPE_ARRAY:
				for nom in args[0]:
					if typeof(nom) == TYPE_STRING and R.BOUTIQUE.has(nom) and not e.has(nom):
						e.append(nom)
			equipes[qui] = e
		"leurre":
			if a_equipe(qui, "leurre") and args.size() >= 1 and typeof(args[0]) == TYPE_VECTOR3:
				equipes[qui].erase("leurre")
				var ou: Vector3 = args[0]
				if ou.distance_to(joueurs[qui].global_position) > R.LEURRE_PORTEE + 3.0:
					ou = joueurs[qui].global_position
				_entendre(ou, R.LEURRE_BRUIT)
				son_a.rpc("vote", ou, 4.0)
				son_a.rpc("klaxon", ou, -6.0)
		"heurt":                         # il s'est cogné, ou il est retombé : tout le monde l'entend, le fantôme aussi
			var rayon := clampf(float(args[0]) if args.size() >= 1 and typeof(args[0]) in [TYPE_FLOAT, TYPE_INT] else 0.0, 0.0, 20.0)
			_entendre(joueurs[qui].global_position, rayon)
			son_a.rpc("choc", joueurs[qui].global_position + Vector3(0.0, 0.4, 0.0), clampf(rayon - 16.0, -10.0, 2.0))


func prendre(qui: int, ido: int) -> void:
	var j = joueurs[qui]
	var o = objets.get(ido)
	if o == null or not j.vivant or j.porte >= 0 or o.porteurs.has(qui):
		return
	if j.tete.global_position.distance_to(o.global_position) > R.PORTEE + o.taille.length() * 0.5:
		return
	# il le prend avec les bras qu'il a : deux, ou un seul si l'autre repousse
	var attente: Array = bras.get(qui, [0.0, 0.0])
	var libres: Array = []
	for cote in 2:
		if attente[cote] <= 0.0:
			libres.append(cote)
	if libres.is_empty():
		_dire_a(qui, "Tes bras repoussent encore.")
		return
	objet_info.rpc(ido, o.valeur, o.prises + o.accroches(j, libres))
	if o.maudit and not o.eveille:   # on ne touche pas au grimoire : dans la maison, ça s'entend de partout
		o.eveille = true
		for c in choses:
			c.reveiller()
		_entendre(o.global_position, 80.0)
		annonce.rpc("%s a pris le grimoire. Quelque chose, dans la maison, a tourné la tête." % j.nom)


func lacher(qui: int, ido: int, lance: bool) -> void:
	var o = objets.get(ido)
	if o == null or not o.porteurs.has(qui):
		return
	var reste: Array = o.prises.filter(func(p): return p[0] != qui)
	objet_info.rpc(ido, o.valeur, reste)
	if lance and reste.is_empty() and joueurs.has(qui):
		o.apply_central_impulse(joueurs[qui].vise() * minf(o.mass * R.LANCER, R.LANCER_MAX))


# un bras trop tendu s'arrache : il lâche, reste un moment pendu au meuble, et repousse
func arracher(qui: int, cote: int, ido: int) -> void:
	var o = objets.get(ido)
	if o == null:
		return
	var reste: Array = []
	var point := Vector3.ZERO
	var tenait := false
	for p in o.prises:
		if p[0] == qui and p[1] == cote:
			point = p[2]
			tenait = true
		else:
			reste.append(p)
	if not tenait:
		return
	var attente: Array = bras.get(qui, [0.0, 0.0]).duplicate()
	attente[cote] = R.BRAS_REPOUSSE
	bras[qui] = attente
	bras_arrache.rpc(qui, cote, ido, point)
	_entendre(o.global_position, R.BRUIT_ARRACHE)
	objet_info.rpc(ido, o.valeur, reste)


func _dire_a(qui: int, t: String) -> void:
	if qui == mon_id:
		ui.annoncer(t)
	elif en_reseau:
		annonce.rpc_id(qui, t)


# un mort pousse un petit objet : pour aider, ou pas
func pousser(qui: int, ido: int) -> void:
	var j = joueurs[qui]
	var o = objets.get(ido)
	var maintenant := Time.get_ticks_msec()
	if o == null or j.vivant or o.mass > R.FANTOME_MASSE or maintenant - int(_poussees.get(qui, -9999)) < 1500:
		return
	if j.tete.global_position.distance_to(o.global_position) > R.PORTEE + 1.0:
		return
	_poussees[qui] = maintenant
	o.sleeping = false
	o.apply_central_impulse((j.vise() * 4.0 + Vector3.UP * 1.5) * o.mass)


func klaxonner(qui: int) -> void:
	var j = joueurs[qui]
	if not j.vivant:
		return
	var ou := Vector3(maison.camion.get_center().x, 1.5, maison.camion.get_center().y)
	son_a.rpc("klaxon", ou, 4.0)
	_entendre(ou, R.BRUIT_KLAXON)
	if charge >= quota:
		finir(true, "Le camion part, chargé.")
	else:
		annonce.rpc("Il manque %d € dans la zone. Et tout le monde a entendu." % (quota - charge))


func tuer(qui: int) -> void:
	var j = joueurs.get(qui)
	if j == null or not j.vivant:
		return
	for o in objets.values():
		if o.porteurs.has(qui):
			lacher(qui, o.id, false)
	mort.rpc(qui)


# la chose a vu un porteur : elle crie, et lui le sait
func reperer(qui: int, par_la_torche: bool = false, d_ou: Vector3 = Vector3.INF) -> void:
	repere.rpc(qui, d_ou if d_ou.is_finite() else chose.global_position, par_la_torche)


# un bruit : toutes les créatures qui sont à portée l'entendent
func _entendre(ou: Vector3, rayon: float) -> void:
	for c in choses:
		c.entendre(ou, rayon)


# ce que ce porteur a emporté (chez l'hôte)
func a_equipe(qui: int, nom: String) -> bool:
	return equipes.has(qui) and equipes[qui].has(nom)


# jusqu'où ses bras tiennent, et ce qu'il porte : des gants, des sangles
func allonge(qui: int) -> float:
	return R.BRAS_MAX + (R.GANTS if a_equipe(qui, "gants") else 0.0)


func force(qui: int) -> float:
	return R.FORCE_PORTEUR * (R.SANGLES if a_equipe(qui, "sangles") else 1.0)


# le réveil à lancer : il sonne là où l'on regarde, et le fantôme y court
func lancer_leurre() -> void:
	if etat != PARTIE or moi == null or not moi.vivant or not bourse.a("leurre"):
		return
	var de: Vector3 = moi.tete.global_position
	var vers: Vector3 = de + moi.vise() * R.LEURRE_PORTEE
	var touche: Dictionary = moi.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(de, vers, R.COUCHE_DECOR))
	bourse.consommer("leurre")
	vouloir("leurre", [touche.position if not touche.is_empty() else vers])
	ui.annoncer("Le réveil sonne là-bas. Il t'en reste %d." % bourse.combien("leurre"), 3.0)


@rpc("authority", "call_local", "reliable")
func trousse_servie() -> void:
	_screamer()
	bourse.consommer("trousse")
	ui.annoncer("Ta trousse de secours t'a sauvé la mise. Elle est vide.", 4.0)


@rpc("authority", "call_remote", "unreliable")
func dose_recue(d: float) -> void:
	ma_dose = clampf(d, 0.0, 1.0)


# le fantôme vient de vous attraper : sa face vous saute au visage, et hurle
func _screamer() -> void:
	ui.screamer()
	sons.jouer("screamer", 6.0)


# la chose touche un porteur : le premier coup blesse, le suivant tue
func frapper(qui: int) -> void:
	var j = joueurs.get(qui)
	if j == null or not j.vivant:
		return
	if a_equipe(qui, "trousse") and not j.blesse:      # une trousse : ce coup-là ne blesse pas
		equipes[qui].erase("trousse")
		if qui == mon_id:
			trousse_servie()
		else:
			trousse_servie.rpc_id(qui)
		return
	if j.blesse:
		tuer(qui)
	else:
		blessures[qui] = 0.0
		blessure.rpc(qui, true)


func finir(victoire: bool, raison: String) -> void:
	if etat == PARTIE:
		# la facture : ce qu'on a chargé (rien, si personne n'est là pour conduire le camion), moins tout le reste
		var morts := 0
		for j in joueurs.values():
			if not j.vivant:
				morts += 1
		var casse := 0
		for o in objets.values():
			casse += o.valeur_neuve - o.valeur
		var recette: int = charge if morts < joueurs.size() else 0
		fin.rpc(victoire, charge, quota, raison, R.facture(recette, quota, casse, morts))


# --- ce que l'hôte redit à tous ---

@rpc("authority", "call_local", "reliable")
func objet_info(ido: int, valeur: int, prises: Array) -> void:
	var o = objets.get(ido)
	if o == null:
		return
	o.valeur = valeur
	o.definir_prises(prises)
	for j in joueurs.values():
		if o.porteurs.has(j.id):
			j.porte = ido
		elif j.porte == ido:
			j.porte = -1


@rpc("authority", "call_local", "reliable")
func bras_arrache(qui: int, cote: int, ido: int, point: Vector3) -> void:
	var j = joueurs.get(qui)
	var o = objets.get(ido)
	if j == null or o == null or cote < 0 or cote > 1:
		return
	j.repousse[cote] = R.BRAS_REPOUSSE
	o.laisser_bras(point, j.couleur)
	sons.jouer_a("arrache", o.global_position, 6.0)
	if qui == mon_id:
		ui.annoncer("Un bras arraché ! Il repousse.", 3.0)


@rpc("authority", "call_remote", "unreliable")
func objets_etat(d: PackedFloat32Array) -> void:
	for k in range(0, d.size() - 7, 8):
		var o = objets.get(int(d[k]))
		if o != null:
			o.cible_pos = Vector3(d[k + 1], d[k + 2], d[k + 3])
			o.cible_rot = Quaternion(d[k + 4], d[k + 5], d[k + 6], d[k + 7]).normalized()


@rpc("authority", "call_remote", "unreliable")
func partie_etat(t: float, c: int, ou: Vector3, yaw: float, mode: int, bute: bool, autres: Array = []) -> void:
	temps = t
	charge = c
	if chose != null:
		chose.cible_pos = ou
		chose.cible_yaw = yaw
		chose.mode = clampi(mode, 0, 4)
		chose.bute = bute
	for k in range(1, choses.size()):              # les autres créatures : [où, vers où, quoi, bute] chacune
		var i := (k - 1) * 4
		if i + 3 < autres.size() and typeof(autres[i]) == TYPE_VECTOR3:
			choses[k].cible_pos = autres[i]
			choses[k].cible_yaw = float(autres[i + 1])
			choses[k].mode = clampi(int(autres[i + 2]), 0, 4)
			choses[k].bute = bool(autres[i + 3])


@rpc("authority", "call_local", "reliable")
func vote_etat(ouvert: bool, options: Array, voix: Array, reste: float) -> void:
	if ouvert and not _vote.ouvert:
		sons.jouer("vote", -6.0)
	_vote = {"ouvert": ouvert, "options": options, "voix": voix, "reste": reste}


@rpc("authority", "call_local", "reliable")
func sabotage(nom: String, duree: float, param: int, ou: Vector3) -> void:
	if not R.SABOTAGES.has(nom) or maison == null:
		return
	ui.annoncer("Le chat a choisi : %s !" % R.SABOTAGES[nom].nom, 5.0)
	if nom == "vacarme":
		sons.jouer_a("casse", ou, 8.0)
		sons.jouer_a("choc", ou, 8.0)
		return
	effets[nom] = {"reste": duree, "param": param}
	_effet(nom, true, param)


@rpc("authority", "call_local", "reliable")
func mort(qui: int) -> void:
	var j = joueurs.get(qui)
	if j == null:
		return
	j.mourir()
	sons.jouer_a("mort", j.global_position + Vector3.UP, 4.0)
	if qui == mon_id:
		_screamer()
		ui.trouble(false)
		ui.mort("Le fantôme t'a pris. Tu hantes la maison : %s pour pousser les petits objets." % ("le bouton Pousser" if tactile.actif else "E"))
	else:
		ui.annoncer("%s ne répond plus." % j.nom)


@rpc("authority", "call_local", "reliable")
func repere(qui: int, ou: Vector3, par_la_torche: bool = false) -> void:
	sons.jouer_a("hurle", ou + Vector3.UP * 2.0, 8.0)
	if qui == mon_id:
		ui.annoncer("Ta torche l'a attiré ! Éteins-la (%s) et cours." % ("le bouton Torche" if tactile.actif else "F") if par_la_torche else "Il t'a vu ! Cours, ou sors du manoir.", 3.5)


@rpc("authority", "call_local", "reliable")
func blessure(qui: int, oui: bool) -> void:
	var j = joueurs.get(qui)
	if j == null or not j.vivant:
		return
	j.blesse = oui
	if oui:
		sons.jouer_a("choc", j.global_position + Vector3.UP, 8.0)
	if qui == mon_id:
		if oui:
			_screamer()
		ui.mort("Peur bleue : retourne au camion reprendre tes esprits. Un coup de plus et c'est fini." if oui else "")
		ui.trouble(oui)
		if not oui:
			ui.annoncer("Tu as repris tes esprits.")


@rpc("authority", "call_local", "unreliable")
func son_a(nom: String, ou: Vector3, volume: float) -> void:
	sons.jouer_a(nom, ou, volume)


@rpc("authority", "call_local", "reliable")
func annonce(t: String) -> void:
	ui.annoncer(t)


@rpc("authority", "call_local", "reliable")
func fin(victoire: bool, c: int, q: int, raison: String, facture: Dictionary = {}) -> void:
	etat = FIN
	gagne = victoire
	charge = c
	quota = q
	sons.nuit(false)
	sons.jouer("klaxon" if victoire else "mort", -4.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vivants := 0
	for j in joueurs.values():
		if j.vivant:
			vivants += 1
	# les comptes : la facture de la nuit, la part de chacun, et ce que cela fait à sa caisse
	var comptes := ""
	if facture.has("lignes"):
		for l in facture.lignes:
			comptes += "%s : %s%d €\n" % [l[0], "+" if l[1] >= 0 else "−", absi(l[1])]
		var net: int = facture.net
		var n: int = maxi(joueurs.size(), 1)
		var part := int(floor(float(net) / n))
		comptes += "\n%s : %s%d €" % ["Il reste" if net >= 0 else "Vous devez", "" if net >= 0 else "−", absi(net)]
		if n > 1:
			comptes += ", soit %s%d € chacun" % ["" if part >= 0 else "−", absi(part)]
		for dit in bourse.encaisser(part):
			comptes += "\n" + dit
		comptes += "\n" + bourse.dire()
		_dire_bourse()
	ui.fin("%s\n\n%s\nChargé : %d € sur %d € demandés.\n%d porteur(s) sur %d voient le jour."
		% [("LE BUNKER EST VIDÉ" if victoire else "LE BUNKER A GAGNÉ") if maison != null and maison.lieu == "bunker" else ("LE MANOIR EST VIDÉ" if victoire else "LE MANOIR A GAGNÉ"), raison, c, q, vivants, joueurs.size()], serveur, comptes)


# --- les sabotages ---

func _effet(nom: String, actif: bool, param: int) -> void:
	match nom:
		"noir":
			maison.lumieres(not actif)
			sons.jouer("porte", -8.0, 1.6)
		"porte":
			maison.verrouiller(param, actif)
			if param >= 0 and param < maison.portes.size():
				sons.jouer_a("porte", maison.portes[param].centre, 6.0)
				if serveur and actif and chose != null:      # une porte qui claque : il l'entend
					_entendre(maison.portes[param].centre, R.BRUIT_PORTE)
		"torches":
			for j in joueurs.values():
				j.torche_ok = not actif
		"plume":
			if serveur:
				for o in objets.values():
					if o.accroche:
						continue
					o.gravity_scale = 0.08 if actif else 1.0
					o.sleeping = false
					if actif:
						o.apply_central_impulse(Vector3.UP * o.mass * 1.2)


func _sur_vote(gagnant: String) -> void:
	var param := -1
	var ou := Vector3.ZERO
	if gagnant == "porte":
		param = _porte_libre()
		if param < 0:
			gagnant = "vacarme"
	if gagnant == "vacarme":
		var vivants: Array = []
		for j in joueurs.values():
			if j.vivant:
				vivants.append(j)
		if vivants.is_empty():
			return
		ou = vivants[hasard.randi_range(0, vivants.size() - 1)].global_position + Vector3.UP
		_entendre(ou, 26.0)
	sabotage.rpc(gagnant, R.SABOTAGES[gagnant].duree, param, ou)


# une porte que rien ni personne ne traverse à cet instant
func _porte_libre() -> int:
	var libres: Array = []
	for i in maison.portes.size():
		var c: Vector3 = maison.portes[i].centre
		var libre: bool = not maison.portes[i].verrou
		for j in joueurs.values():
			if Vector2(j.global_position.x - c.x, j.global_position.z - c.z).length() < 1.6:
				libre = false
		for o in objets.values():
			if Vector2(o.global_position.x - c.x, o.global_position.z - c.z).length() < 1.0 + o.taille.length() * 0.5:
				libre = false
		if libre:
			libres.append(i)
	return -1 if libres.is_empty() else libres[hasard.randi_range(0, libres.size() - 1)]


func _sur_choc(o, dv: float) -> void:
	var perte := int(round(o.valeur_neuve * o.fragile * clampf((dv - R.CHOC_SEUIL) / (R.CHOC_PLEIN - R.CHOC_SEUIL), 0.0, 1.0)))
	var avant: int = o.valeur
	o.valeur = maxi(o.valeur - perte, 0)
	if o.valeur != avant:
		objet_info.rpc(o.id, o.valeur, o.prises)
	_entendre(o.global_position, clampf(3.0 + dv * sqrt(o.mass) * 0.55, 3.0, 22.0))
	son_a.rpc("casse" if o.valeur != avant and o.fragile > 0.5 else "choc", o.global_position, clampf(dv * 2.0 - 12.0, -12.0, 6.0))


# un meuble lourd qu'on traîne : il racle, et cela s'entend d'autant plus loin qu'il pèse
func _sur_traine(o) -> void:
	_entendre(o.global_position, R.BRUIT_TRAINE + sqrt(o.mass))
	son_a.rpc("frotte", o.global_position, clampf(sqrt(o.mass) - 14.0, -12.0, 0.0))


# --- la partie qui tourne ---

func _physics_process(dt: float) -> void:
	if etat != PARTIE:
		return
	for nom in effets.keys():
		effets[nom].reste -= dt
		if effets[nom].reste <= 0.0:
			_effet(nom, false, effets[nom].param)
			effets.erase(nom)
	_vote.reste -= dt
	if not serveur:
		return
	temps -= dt
	if chose.mode == Creature.DORT and R.DUREE_NUIT - temps > repit:
		for c in choses:
			c.reveiller()
		annonce.rpc("Quelque chose s'est réveillé dans le manoir. Ça n'y voit presque pas, mais ça entend tout." if choses.size() == 1
			else "Ils se sont réveillés, là-dessous. Ils sont %d. Ils n'y voient presque pas, mais ils entendent tout." % choses.size())
	for c in choses:
		c.avancer(dt)
	for qui in bras:
		bras[qui] = [maxf(bras[qui][0] - dt, 0.0), maxf(bras[qui][1] - dt, 0.0)]
	for qui in blessures.keys():           # la peur bleue ne passe qu'au camion : il faut y rester un moment
		var apeure = joueurs.get(qui)
		if apeure == null or not apeure.vivant:
			blessures.erase(qui)
			continue
		blessures[qui] = blessures[qui] + dt if maison.pres_du_camion(apeure.global_position) else 0.0
		if blessures[qui] >= R.REPRISE:
			blessures.erase(qui)
			blessure.rpc(qui, false)
	# la radioactivité : dans une zone, la dose monte ; dehors, elle retombe ; pleine, on en meurt
	if not maison.radios.is_empty():
		_t_dose -= dt
		for j in joueurs.values():
			if not j.vivant:
				continue
			var r: float = maison.radiation(j.global_position)
			var d: float = doses.get(j.id, 0.0)
			if r > 0.0:
				d += r * dt / R.DOSE_MORTELLE * (R.COMBINAISON if a_equipe(j.id, "combinaison") else 1.0)
			else:
				d = maxf(d - dt / R.DOSE_REPOS, 0.0)
			doses[j.id] = d
			if d >= 1.0:
				doses[j.id] = 0.0
				annonce.rpc("%s a pris trop de radiations." % j.nom)
				tuer(j.id)
			elif _t_dose <= 0.0:
				if j.id == mon_id:
					ma_dose = d
				else:
					dose_recue.rpc_id(j.id, d)
		if _t_dose <= 0.0:
			_t_dose = 0.25
	_t_ecoute -= dt
	if _t_ecoute <= 0.0:
		_t_ecoute = 0.25
		for j in joueurs.values():
			if j.vivant and j.bruit > 0.5:
				_entendre(j.global_position, j.bruit)
	_t_charge -= dt
	if _t_charge <= 0.0:
		_t_charge = 0.5
		compter()
	chat.avancer(dt)
	_t_vote -= dt
	if chat.change and _t_vote <= 0.0:
		chat.change = false
		_t_vote = 0.3
		vote_etat.rpc(chat.ouvert, chat.options, chat.voix, chat.reste)
	if en_reseau:
		_t_etat -= dt
		if _t_etat <= 0.0:
			_t_etat = 0.1
			var autres: Array = []
			for k in range(1, choses.size()):
				autres.append_array([choses[k].global_position, choses[k].rotation.y, choses[k].mode, choses[k].bute])
			partie_etat.rpc(temps, charge, chose.global_position, chose.rotation.y, chose.mode, chose.bute, autres)
		_t_objets -= dt
		if _t_objets <= 0.0:
			_t_objets = 0.05
			_envoyer_objets()
	var vivants := 0
	for j in joueurs.values():
		if j.vivant:
			vivants += 1
	if temps <= 0.0:
		compter()
		finir(charge >= quota, "L'aube se lève." if charge >= quota else "L'aube se lève sur un camion trop vide.")
	elif vivants == 0:
		finir(false, "Plus personne ne porte rien.")


# ce qui est posé dans la zone, à sa valeur du moment
func compter() -> void:
	charge = 0
	for o in objets.values():
		if o.porteurs.is_empty() and maison.dans_zone(o.global_position):
			charge += o.valeur


# où sont les meubles : ceux qui bougent à chaque fois, tous une fois par seconde
func _envoyer_objets() -> void:
	_tour += 1
	var tous := _tour % 20 == 0
	var d := PackedFloat32Array()
	for o in objets.values():
		if tous or not (o.sleeping or o.freeze):
			var p: Vector3 = o.global_position
			var q: Quaternion = o.quaternion
			d.append_array(PackedFloat32Array([o.id, p.x, p.y, p.z, q.x, q.y, q.z, q.w]))
	if not d.is_empty():
		objets_etat.rpc(d)


# dans un navigateur : ce que le jeu sait de lui-même, posé dans la page (window.portefaix), pour les essais
func _temoigner(dt: float) -> void:
	_t_temoin -= dt
	if _t_temoin > 0.0:
		return
	_t_temoin = 0.3
	var ou := {}
	var pseudos := {}
	for j in joueurs.values():
		ou[str(j.id)] = [snappedf(j.global_position.x, 0.01), snappedf(j.global_position.z, 0.01)]
		pseudos[str(j.id)] = j.nom
	var t := {"etat": ["menu", "salon", "partie", "fin"][etat], "connecte": compte.connecte, "pseudo": compte.nom(), "avis": ui._avis.text,
		"refus": ui._connexion_avis.text, "a_changer": compte.a_changer, "avis_compte": compte.avis, "erreur_compte": compte.erreur, "code": salon.code, "numero": salon.numero, "membres": salon.membres, "relies": Array(multiplayer.get_peers()),
		"hote": serveur, "regard": [snappedf(moi.yaw, 0.01), snappedf(moi.pitch, 0.01)] if moi != null else [], "joueurs": ou, "pseudos": pseudos, "meubles": objets.size(), "pieces": maison.pieces.size() if maison != null else 0, "bonus": maison.bonus if maison != null else [], "prime": prime, "lieu": maison.lieu if maison != null else lieu, "creatures": choses.size(), "dose": snappedf(ma_dose, 0.01), "argent": bourse.argent, "achats": bourse.objets, "graine": graine_jouee, "mailles": _mailles(), "haut": snappedf(moi.global_position.y, 0.01) if moi != null else 0.0, "ips": Engine.get_frames_per_second(),
		"bras": moi.repousse if moi != null else [], "quota": quota, "reperes": ui.reperes()}
	if maison != null:
		t["cage"] = [maison.cage.position.x, maison.cage.position.y, maison.cage.size.x, maison.cage.size.y]
		t["pas"] = maison.PAS
	JavaScriptBridge.eval("window.portefaix=" + JSON.stringify(t) + ";", true)
	# pour les essais dans un navigateur : « window.portefaix_ou = [x, y, z, yaw, pitch] » pose le joueur là
	var pose = JavaScriptBridge.eval("(function(){var o=window.portefaix_ou;window.portefaix_ou=null;return o?o.join(','):''})()", true)
	if moi != null and typeof(pose) == TYPE_STRING and pose != "":
		var v: PackedStringArray = pose.split(",")
		if v.size() >= 5:
			moi.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
			moi.velocity = Vector3.ZERO
			moi.yaw = float(v[3])
			moi.pitch = float(v[4])
		if v.size() >= 6:                    # (et lui trouble la vue, ou non : la peur bleue, telle qu'on la voit)
			moi.blesse = v[5] == "1"
			ui.trouble(moi.blesse)


func _process(dt: float) -> void:
	if web:
		_temoigner(dt)
	if etat == SALON and salon.code != "":       # (au salon, on redit où en sont les liaisons : une qui n'aboutit pas finit par se dire)
		_t_niveaux -= dt
		if _t_niveaux <= 0.0:
			_t_niveaux = 2.0
			_dire_salon()
	if etat != PARTIE or moi == null:
		return
	var indice := _indice()
	if tactile.actif:        # au doigt, les boutons disent déjà quoi presser
		indice = indice.replace(" · E : poser · clic droit : lancer", "").replace("E : poser · clic droit : lancer", "").replace("E : ", "Agir : ")
	ui.dire(temps, charge, quota, moi.bruit, indice)
	if not maison.radios.is_empty():       # le compteur : il crépite d'autant plus qu'on est près, et l'écran verdit avec la dose
		var rayonne: float = maison.radiation(moi.global_position) if moi.vivant else 0.0
		ui.dose(ma_dose, rayonne, true)
		_t_geiger -= dt
		if rayonne > 0.0 and _t_geiger <= 0.0:
			_t_geiger = randf_range(0.02, 0.5) / (0.3 + rayonne * 3.0)
			sons.jouer("geiger", -10.0 + rayonne * 6.0, randf_range(0.9, 1.2))
	_t_niveaux -= dt
	if _t_niveaux <= 0.0:
		_t_niveaux = 0.25
		_niveler()
	ui.vote(_vote.ouvert, _vote.options, _vote.voix, _vote.reste)
	# le cœur bat quand la chose est près
	var d := 1e9                           # (la plus proche de celles qui sont éveillées)
	for c in choses:
		if c.mode != Creature.DORT:
			d = minf(d, moi.global_position.distance_to(c.global_position))
	_t_coeur -= dt
	if moi.vivant and d < 10.0 and _t_coeur <= 0.0:
		_t_coeur = remap(d, 0.0, 10.0, 0.45, 1.3)
		sons.jouer("coeur", remap(d, 0.0, 10.0, 2.0, -14.0))


# À chaque niveau ses lampes : ce qui bouge (les meubles, les porteurs, le fantôme) passe sur la couche du niveau où il est, pour n'être
# éclairé que par elles. Et l'on n'allume ni ne dessine ce qui est aux autres niveaux, sauf autour de l'escalier quand on en est près.
# combien de maillages à l'écran (les essais dans un navigateur s'assurent qu'on reste loin du millier)
func _mailles() -> int:
	if monde == null:
		return 0
	var n := 0
	var pile: Array = [monde]
	while not pile.is_empty():
		var noeud: Node = pile.pop_back()
		if noeud is Node3D and not noeud.visible:
			continue
		if noeud is MeshInstance3D:
			n += 1
		pile.append_array(noeud.get_children())
	return n


func _niveler() -> void:
	if maison.niveaux.size() < 2:
		return
	maison.regarder_de(moi.global_position)
	for o in objets.values():
		var n: int = maison.niveau_de(o.global_position.y)
		o.visible = maison.en_vue(o.global_position, n) or not o.porteurs.is_empty()


# ce que le joueur regarde, et ce qu'il peut en faire
func _indice() -> String:
	if moi.porte >= 0:
		var tenu = objets.get(moi.porte)
		if tenu != null and tenu.prises.size() * R.FORCE_PORTEUR * 0.5 < tenu.mass * 9.8:
			return "%s : trop lourd pour %d bras, il se traîne · E : lâcher" % [tenu.nom, tenu.prises.size()]
		if moi.bras_libres() < 2:
			return "D'un seul bras · E : poser · clic droit : lancer"
		return "E : poser · clic droit : lancer"
	var vu = moi.regard()
	if vu == null:
		return ""
	if vu.has_method("definir_prises"):
		if not moi.vivant:
			return "E : pousser" if vu.mass <= R.FANTOME_MASSE else ""
		return "%s — %d €%s · E : prendre" % [vu.nom, vu.valeur, " (lourd : à plusieurs)" if vu.lourd() else ""]
	if vu.has_meta("klaxon") and moi.vivant:
		return "E : klaxonner et partir" if charge >= quota else "Le camion attend son quota (E : klaxonner quand même)"
	return ""
