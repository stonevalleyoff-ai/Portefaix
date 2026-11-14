extends Node
# Portefaix — l'essai sans écran (scripts/essai.gd)
# Trois façons de le lancer, chacune sort avec le code 0 si tout passe, 1 sinon :
#   outils/godot.sh --headless --path . -- --essai          une partie seul, jouée par le programme : la maison, les meubles,
#       porter un carton jusqu'au camion, traîner puis soulever à deux un canapé, casser un vase, la chose qui entend, voit devant elle, crie,
#       chasse, blesse puis tue, et qu'on sème en sortant,
#       le mort qui pousse, le chat (ses votes, les lignes de Twitch), chaque sabotage, le klaxon, l'aube
#   outils/godot.sh --headless --path . -- --essai-reseau   un hôte, qui lance lui-même un invité (un second programme) sur
#       cette machine, et vérifie avec lui que les deux voient la même partie
#   outils/godot.sh --headless --path . -- --essai-compte   la connexion, contre un faux service de comptes que l'essai
#       ouvre lui-même sur cette machine : un mauvais mot de passe, un bon, le pseudo, rester connecté, le service en panne, se déconnecter,
#       créer un compte, le confirmer par le lien de l'e-mail, demander un nouveau mot de passe et le choisir
#       (avec --en-ligne : un mauvais mot de passe aussi contre le vrai service, sans rien y écrire)
#   (-- --essai-client : l'invité que lance l'essai du réseau)

const R = preload("res://scripts/regles.gd")

var mode := "--essai"
var jeu
var ok := true
var n := 0
var rapports := {}
var _fini := false


func _ready() -> void:
	jeu = get_parent()
	jeu.torche_au_depart = false
	_lancer.call_deferred()


func _lancer() -> void:
	match mode:
		"--essai-reseau":
			await _hote()
		"--essai-client":
			await _invite()
		"--essai-compte":
			await _compte()
		_:
			await _seul()
	if mode != "--essai-client":
		print("\n%s : %d vérifications" % ["Tout passe" if ok else "ÉCHEC", n])
	get_tree().quit(0 if ok else 1)


func verif(c: bool, m: String) -> void:
	n += 1
	if not c:
		ok = false
	print(("  ✓ " if c else "  ✗ ") + m)


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _images(k: int) -> void:
	for i in k:
		await get_tree().physics_frame


func _trouver(type: String, rang: int = 0):
	for o in jeu.objets.values():
		if o.type == type:
			if rang == 0:
				return o
			rang -= 1
	return null


# poser un porteur devant un objet, à cette distance, les yeux dessus
func _devant(j, o, d: float, de: Vector3 = Vector3(0, 0, 1)) -> void:
	j.global_position = Vector3(o.global_position.x, 0.05, o.global_position.z) + de.normalized() * d
	_tourner(j, o.global_position)


func _tourner(j, vers: Vector3) -> void:
	var d: Vector3 = vers - (j.global_position + Vector3(0.0, R.YEUX, 0.0))
	j.yaw = atan2(-d.x, -d.z)
	j.pitch = atan2(d.y, Vector2(d.x, d.z).length())


# marcher jusqu'à un point, par le chemin de la maison, à pas d'homme
func _marcher(j, vers: Vector3, vitesse: float = 3.0) -> void:
	var route: PackedVector3Array = jeu.maison.chemin(j.global_position, vers)
	route.append(vers)
	for p in route:
		while true:
			var d := Vector3(p.x - j.global_position.x, 0.0, p.z - j.global_position.z)
			if d.length() < 0.1:
				break
			j.yaw = lerp_angle(j.yaw, atan2(-d.x, -d.z), 0.15)
			j.global_position += d.normalized() * minf(vitesse / 60.0, d.length())
			await get_tree().physics_frame


func _pilote(j) -> void:
	j.pilote = true
	j.bruit = 0.0                  # (tenu par l'essai, il ne fait plus de bruit : sans cela son dernier pas résonnerait sans fin)
	j.collision_layer = 0


# --- seul ---

# poser un objet là, à plat, immobile (l'essai le veut à un endroit dégagé et connu)
func _mettre(o, ou: Vector3) -> void:
	o.decrocher()
	o.global_position = ou
	o.rotation = Vector3.ZERO
	o.linear_velocity = Vector3.ZERO
	o.angular_velocity = Vector3.ZERO
	o.sleeping = false


# les maisons inventées : douze graines, et ce qu'on attend de chacune
func _maisons() -> void:
	print("0. Les maisons inventées")
	var Maison = load("res://scripts/maison.gd")
	var Amenagement = load("res://scripts/amenagement.gd")
	var jointes := true
	var metiers := true
	var meublees := true
	var portes_libres := true
	var rangees := true
	var antres := true
	var plans := {}
	var moins := 999
	var plus := 0
	var pieces_min := 99
	var portes_min := 99
	for graine in range(1, 13):
		var m = Maison.new()
		m.construire(graine)
		var h := RandomNumberGenerator.new()
		h.seed = graine + 1
		var a = Amenagement.new()
		a.amenager(m, h)
		plans["".join(m.plan)] = true
		pieces_min = mini(pieces_min, m.pieces.size())
		portes_min = mini(portes_min, m.portes.size())
		for z in m.profondeur:
			for x in m.largeur:
				for n in m.niveaux:
					if m.plans[n][z][x] in [".", "D", "P"] and m.chemin(m.seuil, m.centre(Vector2i(x, z), n)).is_empty():
						jointes = false
		var vus := {}
		for p in m.pieces:
			vus[p.type] = true
		metiers = metiers and vus.has("salon") and vus.has("cuisine") and vus.has("chambre") and vus.has("manger") and vus.has("entree")
		var types := {}
		for o in a.objets:
			types[o.type] = true
			rangees = rangees and m.dedans(o.pos) and m.lettre(int(o.pos.x), int(o.pos.z), m.niveau_de(o.pos.y)) == "."
			var no: int = m.niveau_de(o.pos.y)
			if not o.accroche and o.pos.y - m.y_de(no) < 1.0:            # rien au sol devant une porte
				for p in m.pieces:
					for libre in m.devants_de_porte(p.rect, p.niveau):
						if p.niveau == no and libre.grow(-0.05).has_point(Vector2(o.pos.x, o.pos.z)):
							portes_libres = false
		meublees = meublees and types.has("canape") and types.has("lit") and types.has("table") and types.has("frigo") and types.has("tele") and types.has("tableau")
		m.encombrer(a.lourds, a.fixes, a.lourds_n, a.fixes_n)
		for i in a.lourds.size():
			if a.lourds_n[i] == m.niveau_de(m.taniere.y) and a.lourds[i].grow(0.25).has_point(Vector2(m.taniere.x, m.taniere.z)):
				antres = false
		moins = mini(moins, a.objets.size())
		plus = maxi(plus, a.objets.size())
		if graine == 1:                 # la même graine : la même maison, meublée pareil
			var m2 = Maison.new()
			m2.construire(1)
			var h2 := RandomNumberGenerator.new()
			h2.seed = 2
			var a2 = Amenagement.new()
			a2.amenager(m2, h2)
			var pareil: bool = m2.plan == m.plan and a2.objets.size() == a.objets.size()
			for i in mini(a.objets.size(), a2.objets.size()):
				pareil = pareil and a.objets[i].type == a2.objets[i].type and a.objets[i].pos.is_equal_approx(a2.objets[i].pos)
			verif(pareil, "une même graine donne la même maison, meublée pareil (chez tous les joueurs)")
			m2.free()
		m.free()
	verif(plans.size() == 12, "douze graines, douze plans différents")
	verif(jointes, "dans chacune, tout le sol se rejoint depuis l'entrée : personne n'est enfermé")
	verif(metiers and pieces_min >= 6, "chacune a son salon, sa cuisine, sa salle à manger, une chambre (%d pièces au moins)" % pieces_min)
	verif(portes_min >= 6, "des portes partout : %d au moins par maison" % portes_min)
	verif(meublees and moins >= 40, "chacune est meublée : un canapé, une télé, un lit, une table, un frigo, des tableaux (de %d à %d objets)" % [moins, plus])
	verif(rangees and portes_libres, "tout est posé sur du sol, dans la maison, et rien ne barre une porte")
	verif(antres, "dans chacune, le fantôme se réveille à un endroit dégagé de sa pièce, pas dans un meuble")
	_bonus(Maison, Amenagement)


# les maisons bonus : une sur quatre, avec ses pièces loufoques et ses trésors
func _bonus(Maison, Amenagement) -> void:
	var combien := 0
	var vues := {}
	for graine in range(1, 401):
		var t: Array = Maison.tirage_bonus(graine)
		if not t.is_empty():
			combien += 1
			vues[t[0]] = true
	verif(combien >= 70 and combien <= 130 and vues.size() == R.BONUS.size(), "sur 400 graines, %d maisons bonus (une sur quatre, à peu près), et chaque pièce bonus sort" % combien)
	var attendus := {"cave": ["grimoire", "calice", "bougie", "statue_bouc"], "garage": ["moto", "velo", "caisse_outils"], "tresor": ["coffre_fort", "lingot", "vase_ming"],
		"arcade": ["borne_arcade", "flipper", "jukebox"], "nains": ["nain_dore", "nain"], "trone": ["toilettes_or", "chandelier", "rouleau_or"]}
	var pleines := 0
	var essayees := 0
	var manques := {}
	var ordinaires := true
	var riches := true
	var rangees := true
	var jointes := true
	var graine := 0
	var faites := 0
	while faites < 24 and graine < 400:
		graine += 1
		if Maison.tirage_bonus(graine).is_empty():
			continue
		faites += 1
		var m = Maison.new()
		m.construire(graine)
		var h := RandomNumberGenerator.new()
		h.seed = graine + 1
		var a = Amenagement.new()
		a.amenager(m, h)
		var metiers := {}
		for p in m.pieces:
			metiers[p.type] = true
		ordinaires = ordinaires and metiers.has("salon") and metiers.has("cuisine") and metiers.has("chambre") and metiers.has("bain") and m.bonus.size() >= 1
		var prime := 0
		var reste := 0
		var types := {}
		for o in a.objets:
			if o.bonus:
				prime += R.CATALOGUE[o.type].valeur
				types[o.type] = true
			else:
				reste += R.CATALOGUE[o.type].valeur
			rangees = rangees and m.dedans(o.pos) and m.lettre(int(o.pos.x), int(o.pos.z), m.niveau_de(o.pos.y)) == "."
		riches = riches and prime >= 3000 and reste >= 3000
		for b in m.bonus:
			essayees += 1
			var complet := true
			for t in attendus[b]:
				if not types.has(t):
					complet = false
					manques["%s sans %s (graine %d)" % [b, t, graine]] = true
			if complet:
				pleines += 1
		m.encombrer(a.lourds, a.fixes, a.lourds_n, a.fixes_n)
		for z in m.profondeur:
			for x in m.largeur:
				for n in m.niveaux:
					if m.plans[n][z][x] in [".", "D", "P"] and m.chemin(m.seuil, m.centre(Vector2i(x, z), n)).is_empty():
						jointes = false
		m.free()
	if not manques.is_empty():
		print("     (", ", ".join(manques.keys().slice(0, 6)), ")")
	verif(faites == 24 and ordinaires, "une maison bonus garde son salon, sa cuisine, une chambre, sa salle de bain, et gagne une à trois pièces bonus")
	verif(pleines >= essayees * 0.9, "les pièces bonus sont meublées de leurs trésors (%d sur %d au complet)" % [pleines, essayees])
	verif(riches and rangees and jointes, "leurs trésors valent une fortune, tout y est posé sur du sol, et la maison reste d'un seul tenant")
	# la maison d'essai, avec chaque pièce bonus tour à tour
	var toutes := true
	for b in R.BONUS:
		var m = Maison.new()
		m.bonus_voulu = [b]
		m.construire(-7)
		var h := RandomNumberGenerator.new()
		h.seed = 8
		var a = Amenagement.new()
		a.amenager(m, h)
		var la := false
		for o in a.objets:
			la = la or (o.bonus and o.type == attendus[b][0])
		toutes = toutes and m.bonus == [b] and la
		if not la:
			print("     (", b, " sans ", attendus[b][0], ")")
		m.free()
	verif(toutes, "chacune des six pièces bonus se meuble dans la maison d'essai")


# --- seul ---

func _seul() -> void:
	_maisons()
	jeu.graine = -7                # la maison d'essai, toujours la même : l'essai ne dépend pas du hasard
	jeu.jouer_seul()
	await _attendre(0.3)
	jeu.repit = 1e9
	jeu.chat.reste = 1e9
	var m = jeu.maison
	var moi = jeu.moi
	var cour := Vector3(m.porte_x, 0.05, m.profondeur + 2.6)        # entre la porte et la rampe du camion

	print("1. La maison d'essai")
	var lignes_egales := true
	var sols := 0
	var atteints := 0
	var entree: Vector2i = m.case_de(m.depart(0))
	for l in m.plan.size():
		lignes_egales = lignes_egales and m.plan[l].length() == m.largeur
		for c in m.plan[l].length():
			if m.plan[l][c] != "#":
				sols += 1
				if m.grille.get_id_path(entree, Vector2i(c, l)).size() > 0:
					atteints += 1
	verif(lignes_egales and m.portes.size() == 5 and m.lampes.size() >= m.pieces.size(), "un plan de %d sur %d cases, %d pièces, 5 portes à claquer, %d lampes" % [m.largeur, m.profondeur, m.pieces.size(), m.lampes.size()])
	verif(sols > 200 and atteints == sols, "les %d cases de sol se rejoignent toutes depuis la cour" % sols)
	var libre := true
	for o in jeu.objets.values():
		if o.mass >= R.OBJET_LEGER and Vector2(o.global_position.x - m.taniere.x, o.global_position.z - m.taniere.z).length() < 0.45:
			libre = false
	verif(m.chemin(m.taniere, Vector3(12, 0, 20)).size() > 10 and Rect2(19, 1, 7, 5).has_point(Vector2(m.taniere.x, m.taniere.z)) and libre,
		"la tanière est dans la pièce la plus loin de l'entrée (le bureau), à un endroit dégagé, et le fantôme a un chemin jusqu'au camion")
	verif(m.dans_zone(Vector3(12, 0.6, 24.0)) and not m.dans_zone(Vector3(12, 0.5, 19.0)) and not m.dans_zone(Vector3(12, 0.5, 14)) and not m.dans_zone(Vector3(15.0, 0.6, 24.0)),
		"la zone de chargement est dans la caisse du camion : ni devant, dans la cour, ni à côté")

	print("2. Les meubles")
	var dedans := true
	var nombre: int = jeu.objets.size()
	for o in jeu.objets.values():
		dedans = dedans and m.dedans(o.global_position)
	verif(nombre >= 40 and dedans, "%d objets, tous dans la maison, pour %d €" % [nombre, jeu.total])
	verif(jeu.quota == R.quota(jeu.total, 1) and jeu.quota > 0 and jeu.quota < jeu.total / 2, "le quota d'un porteur seul : %d €" % jeu.quota)
	verif(R.quota(jeu.total, 4) > jeu.quota and R.quota(jeu.total, 9) <= int(jeu.total * R.QUOTA_MAX) + 10, "il monte avec le nombre de porteurs, sans passer %d %%" % int(R.QUOTA_MAX * 100))
	var tele = _trouver("tele")
	var meuble = _trouver("meuble_tele")
	var canape = _trouver("canape")
	var tableau = _trouver("tableau")
	verif(tele != null and meuble != null and canape != null and tableau != null and _trouver("piano") != null and _trouver("lit") != null, "le salon a son canapé, sa télé, son piano ; la chambre son lit ; des tableaux aux murs")
	var places: Dictionary = {}
	for o in jeu.objets.values():
		places[o.id] = o.global_position
	await _attendre(2.4)
	var poses := true
	var intacts := true
	var bouge := 0.0
	for o in jeu.objets.values():
		poses = poses and m.dedans(o.global_position) and o.global_position.y > 0.0 and o.global_position.y < R.HAUTEUR
		intacts = intacts and o.valeur == o.valeur_neuve
		bouge = maxf(bouge, o.global_position.distance_to(places[o.id]))
	verif(poses and intacts and bouge < 0.15, "posés, ils restent où on les a mis, sans rien casser (le plus remuant a bougé de %d cm)" % int(bouge * 100))
	verif(tele.global_position.y > meuble.global_position.y + 0.4 and Vector2(tele.global_position.x - meuble.global_position.x, tele.global_position.z - meuble.global_position.z).length() < 0.1,
		"la télé est sur son meuble")
	var face: Vector3 = canape.global_transform.basis.z
	var vers_tele: Vector3 = (tele.global_position - canape.global_position) * Vector3(1, 0, 1)
	verif(face.dot(vers_tele.normalized()) > 0.7, "et le canapé la regarde")
	verif(tableau.accroche and tableau.freeze and tableau.global_position.y > 1.2, "un tableau tient à son mur, à hauteur d'yeux")
	var chose = jeu.chose
	chose.entendre(m.taniere + Vector3(3, 0, 0), 8.0)
	verif(chose.mode == chose.DORT and not chose.visible, "le fantôme dort dans le bureau ; un bruit modeste ne le réveille pas")
	chose.entendre(m.taniere + Vector3(3, 0, 0), 20.0)
	verif(chose.mode == chose.ENQUETE, "un grand fracas, si, avant l'heure")
	chose.mode = chose.DORT       # qu'elle laisse l'essai porter en paix

	print("3. Porter")
	_pilote(moi)
	_tourner(moi, tableau.global_position)
	moi.global_position = tableau.global_position + tableau.global_transform.basis.z * 1.5 + Vector3(0, -1.5, 0)
	_tourner(moi, tableau.global_position)
	await _images(3)
	jeu.prendre(1, tableau.id)
	verif(tableau.porteurs == [1] and not tableau.accroche and not tableau.freeze, "pris, le tableau se décroche")
	jeu.lacher(1, tableau.id, false)
	var carton = _trouver("carton")
	_mettre(carton, Vector3(4.5, 0.3, 7.5))            # au bout du couloir
	await _attendre(0.5)
	_devant(moi, carton, 1.3)
	await _images(3)
	verif(moi.regard() == carton, "le porteur a un carton sous les yeux")
	verif(jeu._indice().contains("un carton") and jeu._indice().contains("prendre"), "l'écran le lui dit : « %s »" % jeu._indice())
	moi.agir()                     # la touche d'action elle-même : E, le clic, le bouton Agir
	verif(carton.porteurs == [1] and moi.porte == carton.id and carton.prises.size() == 2, "la touche d'action le prend, à deux mains")
	verif(jeu._indice().contains("poser"), "et l'écran propose de le poser")
	moi.pitch = 0.0
	await _attendre(0.8)
	verif(carton.global_position.y > 0.9 and carton.global_position.distance_to(moi.point_de_prise(carton.taille)) < 0.4, "le carton monte à ses mains (%.2f m du sol)" % carton.global_position.y)
	verif(moi.frein() < 1.0 and moi.frein() > 0.8, "un carton le ralentit à peine (%d %%)" % int(moi.frein() * 100))
	await _marcher(moi, cour + Vector3(0, 0, -1.7))
	verif(carton.porteurs == [1], "il le garde en main à travers la maison, jusque dans la cour")
	# il monte dans le camion, pour de bon : la rampe, puis la caisse
	moi.pilote = false
	moi.yaw = PI                   # (vers le camion)
	moi.pitch = 0.0
	var t_rampe := Time.get_ticks_msec()
	while moi.global_position.z < m.zone.position.y + 2.0 and Time.get_ticks_msec() - t_rampe < 8000:
		jeu.tactile.vecteur = Vector2(0.0, -1.0)
		await get_tree().physics_frame
	jeu.tactile.vecteur = Vector2.ZERO
	await _images(20)
	verif(m.zone.has_point(Vector2(moi.global_position.x, moi.global_position.z)) and absf(moi.global_position.y - m.PLATEAU) < 0.08 and carton.porteurs == [1],
		"il monte la rampe du camion à pied, le carton en main, jusque dans la caisse (%.2f m du sol)" % moi.global_position.y)
	_pilote(moi)
	await _attendre(0.3)
	moi.agir()                     # la même touche le pose
	await _attendre(1.2)
	jeu.compter()
	verif(moi.porte == -1 and m.dans_zone(carton.global_position), "il le pose dans la caisse")
	verif(jeu.charge == carton.valeur and jeu.charge > 0, "le chargement compte le carton : %d €" % jeu.charge)

	print("4. Les bras")
	var petit = _trouver("carton", 1)
	_mettre(petit, Vector3(18.0, 0.3, 20.0))           # dans la cour, hors de la zone
	await _attendre(0.5)
	_devant(moi, petit, 1.3)
	await _images(3)
	jeu.prendre(1, petit.id)
	moi.pitch = 0.0
	await _attendre(0.6)
	var mains: Array = moi.accroches()
	verif(mains.size() == 2 and mains[0][0] != mains[1][0] and mains[0][1].distance_to(mains[1][1]) > 0.3, "ses deux mains s'accrochent au carton, une de chaque côté")
	var gauche: Vector3 = mains[0][1] if mains[0][0] == 0 else mains[1][1]
	var droite: Vector3 = mains[1][1] if mains[0][0] == 0 else mains[0][1]
	verif((droite - gauche).dot(moi.tete.global_transform.basis.x) > 0.2, "la gauche à gauche, la droite à droite")
	verif(moi.epaule(0).distance_to(gauche) < R.BRAS_TENDU, "ses bras ne sont pas tendus")
	jeu.arracher(1, 1, petit.id)
	verif(petit.prises.size() == 1 and petit.prises[0][1] == 0 and moi.porte == petit.id and moi.repousse[1] > 0.0 and moi.bras_libres() == 1,
		"un bras arraché : il tient encore de l'autre")
	await _attendre(0.8)
	verif(petit.global_position.y > 0.8, "d'un seul bras, le carton reste en l'air (%.2f m)" % petit.global_position.y)
	jeu.lacher(1, petit.id, false)
	await _attendre(0.6)
	jeu.prendre(1, petit.id)
	verif(petit.prises.size() == 1 and petit.prises[0][1] == 0, "il le reprend : d'une main, l'autre n'a pas repoussé")
	jeu.lacher(1, petit.id, false)
	jeu.bras[1] = [0.0, 0.05]
	moi.repousse[1] = 0.05
	await _attendre(0.3)
	jeu.prendre(1, petit.id)
	verif(petit.prises.size() == 2 and moi.bras_libres() == 2, "le bras repousse (en %d s) : il reprend à deux mains" % int(R.BRAS_REPOUSSE))
	await _attendre(0.5)
	moi.global_position += Vector3(0, 0, 9.0)          # il s'en va d'un coup, bien trop loin
	await _images(4)
	verif(petit.prises.is_empty() and moi.porte == -1 and moi.bras_libres() == 0, "tiré de trop loin (plus de %.1f m), ses deux bras s'arrachent, et le carton tombe" % R.BRAS_MAX)
	moi.global_position = Vector3(18.0, 0.05, 21.3)
	_tourner(moi, petit.global_position)
	await _images(3)
	jeu.prendre(1, petit.id)
	verif(petit.prises.is_empty() and moi.porte == -1, "sans bras, il ne prend plus rien")
	jeu.bras[1] = [0.0, 0.0]
	moi.repousse = [0.0, 0.0]

	print("5. Les lourds")
	_mettre(canape, Vector3(5.0, 0.45, 20.0))          # dans la cour, à l'aise
	await _attendre(0.8)
	var piece := Vector3(canape.global_position.x, 0.0, canape.global_position.z)
	_devant(moi, canape, 2.0)
	moi.pitch = 0.0
	await _images(3)
	var sol: float = canape.global_position.y
	jeu.prendre(1, canape.id)
	await _attendre(1.2)
	verif(canape.porteurs == [1] and canape.lourd() and canape.global_position.y < sol + 0.25, "seul, le canapé (%d kg) ne décolle pas" % int(canape.mass))
	verif(moi.frein() < 0.5, "et il ralentit son porteur de plus de moitié")
	moi.global_position += Vector3(0, 0, 1.2)
	await _attendre(2.0)
	var traine := Vector2(canape.global_position.x - piece.x, canape.global_position.z - piece.z).length()
	verif(traine > 0.3 and canape.porteurs == [1], "mais il se traîne (%.1f m en deux secondes)" % traine)
	var second = jeu.ajouter_joueur(2, moi.global_position, 1)
	_pilote(second)
	second.yaw = moi.yaw
	await _images(2)
	jeu.prendre(2, canape.id)
	await _attendre(2.2)
	verif(canape.porteurs.size() == 2 and canape.prises.size() == 4 and canape.global_position.y > sol + 0.3, "à deux, quatre mains dessus, il se soulève (%.2f m)" % canape.global_position.y)
	jeu.lacher(1, canape.id, false)
	jeu.lacher(2, canape.id, false)
	verif(canape.porteurs.is_empty() and moi.porte == -1 and second.porte == -1, "ils le lâchent")
	var chaise = _trouver("chaise")
	_mettre(chaise, Vector3(8.5, 0.5, 19.0))
	await _attendre(0.6)
	_devant(moi, chaise, 1.3)
	await _images(3)
	jeu.prendre(1, chaise.id)
	moi.pitch = 0.0
	await _attendre(0.6)
	jeu.lacher(1, chaise.id, true)
	await _images(2)
	verif(chaise.porteurs.is_empty() and chaise.linear_velocity.length() > 5.0, "une chaise se lance (%.1f m/s)" % chaise.linear_velocity.length())
	var avant: Vector3 = chaise.global_position

	print("6. La casse et le bruit")
	moi.global_position = cour      # dans la cour, hors de vue
	second.global_position = cour + Vector3(1.5, 0, 0)
	chose.mode = chose.DORT
	chose.global_position = m.taniere
	chose.reveiller()
	await _images(2)
	verif(chose.mode == chose.RODE and chose.visible, "à son heure, le fantôme se réveille et rôde")
	var vase = _trouver("vase")
	chose.global_position = Vector3(12.5, 0.0, 10.5)
	chose._roder(60.0)
	_mettre(vase, Vector3(12.5, 2.3, 7.5))             # lâché de haut, dans le couloir
	await _attendre(1.3)
	verif(vase.valeur < vase.valeur_neuve, "un vase tombé de deux mètres perd de sa valeur (%d € sur %d)" % [vase.valeur, vase.valeur_neuve])
	verif(chose.mode == chose.ENQUETE, "le fantôme l'a entendu : il va voir")
	chose.global_position = m.taniere
	chose._roder(60.0)
	moi.bruit = R.BRUIT_PAS
	chose.entendre(moi.global_position, moi.bruit)
	verif(chose.mode == chose.RODE, "des pas dans la cour ne portent pas jusqu'au bureau")
	var klaxon := Vector3(m.camion.end.x - 0.15, 1.2, m.camion.end.y - 0.9)       # le flanc de la cabine, au bout du camion
	moi.global_position = klaxon + Vector3(1.5, -1.15, 0)
	_tourner(moi, klaxon)
	await _images(3)
	verif(jeu._indice().contains("klaxonner"), "à la cabine du camion, l'écran propose de klaxonner")
	moi.global_position = Vector3(m.porte_x, m.PLATEAU + 0.05, m.zone.position.y + 1.0)
	_tourner(moi, Vector3(m.zone.end.x, 1.5, m.zone.position.y + 2.0))
	await _images(3)
	verif(not jeu._indice().contains("klaxonner"), "dans la caisse, on ne klaxonne pas par mégarde en visant ses parois")
	moi.global_position = klaxon + Vector3(1.5, -1.15, 0)
	_tourner(moi, klaxon)
	await _images(3)
	moi.agir()
	verif(chose.mode == chose.ENQUETE and jeu.etat == jeu.PARTIE, "un coup de klaxon sans le quota, si : il vient, et le camion reste")
	moi.global_position = cour
	moi.bruit = 0.0

	print("7. Le fantôme")
	var poser := func(ou: Vector3, vers: Vector3):     # le fantôme, là, tourné vers ce point, prêt à voir
		chose.global_position = ou
		chose._roder(60.0)
		chose._repue = 0.0
		chose._butees = 0
		chose._evite.clear()
		chose._allure = 0.0
		chose.rotation.y = atan2(-(vers.x - ou.x), -(vers.z - ou.z))
	var couloir := Vector3(8.5, 0.0, 7.5)
	var fond := Vector3(25.0, 0.0, 7.5)
	var loin := Vector3(3.0, 1.1, 24.0)                 # un coin de la cour, pour ranger ce qui gêne
	var armoire = _trouver("armoire")
	verif(chose._os.size() >= 15 and chose._lambeaux.size() >= 6 and chose.collision_mask == (R.COUCHE_DECOR | R.COUCHE_OBJETS),
		"il a un corps : %d articulations, des lambeaux, et de quoi se cogner aux murs et aux meubles" % chose._os.size())
	print("   sa vue")
	poser.call(couloir, fond)
	second.global_position = Vector3(14.5, 0.05, 7.5)
	await _attendre(0.5)
	verif(chose.mode == chose.RODE, "à six mètres devant lui dans le couloir, il ne voit pas le porteur")
	# la torche : elle se voit de loin, et son faisceau se sent
	second.torche_voulue = true
	_tourner(second, Vector3(25.0, 1.6, 7.5))              # (il éclaire ailleurs : le fond du couloir)
	await _attendre(0.5)
	verif(chose.mode == chose.ALERTE and chose.proie == 2, "le même, torche allumée, sans même l'éclairer : il le voit (jusqu'à %d m, devant lui)" % int(R.CHOSE_VUE * R.CHOSE_TORCHE))
	poser.call(couloir, fond)
	second.accroupi = true
	await _attendre(0.5)
	verif(chose.mode == chose.RODE, "accroupi, torche allumée, à six mètres : il ne le voit pas")
	second.accroupi = false
	second.global_position = Vector3(2.5, 0.05, 7.5)       # six mètres dans son dos
	_tourner(second, Vector3(2.5, 1.6, 0.0))
	await _attendre(0.5)
	var de_dos: bool = chose.mode == chose.RODE
	_tourner(second, chose.global_position + Vector3(0.0, 1.4, 0.0))
	await _attendre(0.5)
	verif(de_dos and chose.mode == chose.ALERTE and chose.proie == 2, "dans son dos, torche allumée : rien tant qu'il éclaire le mur ; le faisceau sur lui, il se retourne")
	second.torche_voulue = false
	poser.call(couloir, fond)
	await _attendre(0.5)
	verif(chose.mode == chose.RODE, "torche éteinte, toujours dans son dos : plus rien")
	second.global_position = Vector3(14.5, 0.05, 7.5)
	second.global_position = Vector3(6.0, 0.05, 7.5)
	await _attendre(0.5)
	verif(chose.mode == chose.RODE, "ni à deux mètres et demi dans son dos")
	second.global_position = Vector3(11.5, 0.05, 7.5)
	second.accroupi = true
	await _attendre(0.5)
	verif(chose.mode == chose.RODE, "ni accroupi, à trois mètres devant lui")
	second.accroupi = false
	_mettre(armoire, Vector3(10.5, 1.02, 7.5))
	second.global_position = Vector3(12.5, 0.05, 7.5)
	await _attendre(0.6)
	verif(chose.mode == chose.RODE, "ni debout à quatre mètres, derrière une armoire")
	_mettre(armoire, loin)
	await _attendre(0.6)
	verif(chose.mode == chose.ALERTE and chose.proie == 2 and chose.global_position.distance_to(couloir) < 0.1, "l'armoire ôtée, il le voit : il crie, sans avancer")
	await _images(20)
	verif(chose._os["machoire"].rotation.x < -0.5 and absf(chose._os["epaule_g"].rotation.z) > 0.6, "la mâchoire décrochée, les bras écartés")
	await _attendre(R.CHOSE_ALERTE)
	verif(chose.mode == chose.CHASSE, "près de deux secondes plus tard, il s'élance")
	var t0 := Time.get_ticks_msec()
	var vite := 0.0
	while not second.blesse and Time.get_ticks_msec() - t0 < 6000:
		vite = maxf(vite, chose._vitesse_vue)
		await get_tree().physics_frame
	verif(second.blesse and second.vivant and chose.mode == chose.RODE, "son premier coup blesse sans tuer (après %.1f s de chasse)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	verif(vite > 3.0 and vite <= R.CHOSE_CHASSE + 0.3, "il a couru : déjà %.1f m/s sur trois mètres d'élan (il va jusqu'à %.1f, plus vite qu'on ne marche)" % [vite, R.CHOSE_CHASSE])
	var coup: Vector3 = chose.global_position
	await _attendre(1.5)
	verif(chose.mode == chose.RODE and chose.global_position.distance_to(coup) > 1.5 and second.vivant, "puis il s'en va vers sa tanière, sans plus regarder le blessé")
	await _attendre(1.0)
	verif(second.blesse, "la peur bleue ne passe pas toute seule")
	second.global_position = Vector3(m.camion.position.x - 1.2, 0.05, m.camion.position.y + 2.0)       # au camion, contre son flanc
	await _attendre(R.REPRISE * 0.5)
	var encore: bool = second.blesse
	await _attendre(R.REPRISE * 0.5 + 0.4)
	verif(encore and not second.blesse, "il faut revenir au camion, et y rester %d secondes, pour reprendre ses esprits" % int(R.REPRISE))
	second.global_position = cour + Vector3(1.5, 0, 0)
	jeu.frapper(2)
	verif(second.blesse and second.vivant, "un autre coup le terrifie de nouveau")
	jeu.frapper(2)
	verif(not second.vivant, "et blessé, le coup suivant le tue")
	verif(moi.vivant and jeu.etat == jeu.PARTIE, "la partie continue tant qu'un porteur vit")
	second.global_position = Vector3(2.0, 0.05, 20.0)
	poser.call(Vector3(6.5, 0.0, 7.5), Vector3(6.5, 0.0, 3.5))
	moi.global_position = Vector3(6.5, 0.05, 3.5)        # dans la chambre : un mur entre eux
	await _attendre(0.5)
	verif(chose.mode == chose.RODE, "derrière un mur, à quatre mètres, il ne voit rien")
	poser.call(m.seuil, Vector3(12.0, 0.0, 20.0))
	moi.global_position = Vector3(12.0, 0.05, 17.5)
	await _attendre(0.5)
	verif(chose.mode == chose.RODE, "dans la cour, à trois mètres du seuil, il ne voit pas le porteur non plus")
	poser.call(Vector3(12.0, 0.0, 8.0), m.seuil)
	moi.global_position = Vector3(12.0, 0.05, 11.5)
	await _attendre(0.5)
	verif(chose.mode == chose.ALERTE and chose.proie == 1, "dans l'entrée, à trois mètres et demi, il le voit et crie")
	moi.global_position = Vector3(12.0, 0.05, 19.0)      # il sort pendant que l'autre crie
	await _attendre(R.CHOSE_ALERTE + R.CHOSE_PERTE + 3.0)
	verif(chose.mode != chose.CHASSE and chose.mode != chose.ALERTE and m.dedans(chose.global_position) and moi.vivant and not moi.blesse,
		"sorti dans la cour, il le sème : le fantôme ne passe pas le seuil")
	moi.global_position = cour
	print("   son pas, et ce qui l'arrête")
	poser.call(couloir, fond)
	chose.entendre(Vector3(20.0, 0.0, 7.5), 14.0)
	await _attendre(1.6)
	verif(chose.mode == chose.ENQUETE and chose._vitesse_vue > R.CHOSE_RODE and chose._vitesse_vue < R.MARCHE and chose.global_position.x > 10.5,
		"un bruit au fond du couloir : il y va d'un pas pressé (%.1f m/s), sans courir" % chose._vitesse_vue)
	verif(chose._os["epaule_g"].rotation.x > 0.35 and chose._os["epaule_d"].rotation.x > 0.35, "les bras tendus devant lui : il tâtonne")
	# l'encadrement d'une porte : du couloir à la chambre, par sa porte
	poser.call(couloir, Vector3(4.0, 0.0, 6.5))
	chose.entendre(Vector3(4.5, 0.0, 3.5), 14.0)
	var a_bute := false
	t0 = Time.get_ticks_msec()
	while chose.global_position.z > 5.6 and Time.get_ticks_msec() - t0 < 7000:
		a_bute = a_bute or chose.bute
		await get_tree().physics_frame
	verif(chose.global_position.z <= 5.6 and not a_bute, "il passe l'encadrement d'une porte, du couloir à la chambre, sans buter (en %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# une armoire dans le couloir, qui en laisse la moitié : il la contourne
	# (dans le bout de couloir sans porte ni ouverture, de x = 14 à 21 : il n'y a qu'un côté où passer)
	_mettre(armoire, Vector3(17.5, 1.02, 7.62))
	armoire.rotation.y = PI * 0.5                       # (dos au mur du nord : elle prend le couloir de 7 à 8,2 ; il reste 80 cm au sud)
	await _attendre(0.8)
	poser.call(Vector3(14.0, 0.0, 7.25), fond)
	chose.entendre(Vector3(20.5, 0.0, 7.25), 14.0)
	a_bute = false
	var sud := 0.0
	t0 = Time.get_ticks_msec()
	while chose.global_position.x < 19.5 and Time.get_ticks_msec() - t0 < 8000:
		a_bute = a_bute or chose.bute
		if absf(chose.global_position.x - 17.5) < 0.6:
			sud = maxf(sud, chose.global_position.z)
		await get_tree().physics_frame
	verif(chose.global_position.x >= 19.5 and not a_bute and sud > 8.3, "une armoire dans le couloir : il la contourne par le côté libre, sans buter (il passe à z = %.1f)" % sud)
	# et s'il la trouve devant lui en chemin : on la pousse de l'autre côté pendant qu'il arrive
	_mettre(armoire, loin)
	await _attendre(0.4)
	poser.call(Vector3(14.0, 0.0, 8.5), fond)
	chose.entendre(Vector3(20.5, 0.0, 8.5), 14.0)
	a_bute = false
	var nord := 99.0
	var posee := false
	t0 = Time.get_ticks_msec()
	while chose.global_position.x < 19.5 and Time.get_ticks_msec() - t0 < 9000:
		if not posee and chose.global_position.x > 14.8:  # il vient par le sud : l'armoire tombe là, au sud, à moins de trois mètres devant lui
			posee = true
			_mettre(armoire, Vector3(17.5, 1.02, 8.38))
			armoire.rotation.y = PI * 0.5
		a_bute = a_bute or chose.bute
		if absf(chose.global_position.x - 17.5) < 0.6:
			nord = minf(nord, chose.global_position.z)
		await get_tree().physics_frame
	verif(posee and chose.global_position.x >= 19.5 and not a_bute and nord < 7.7, "une armoire poussée devant lui pendant qu'il marche : il change de côté, sans buter (il passe à z = %.1f)" % nord)
	_mettre(armoire, loin)
	_mettre(canape, Vector3(13.5, 0.45, 8.0))           # un canapé en travers du couloir : il le barre d'un mur à l'autre
	canape.rotation.y = PI * 0.5
	await _attendre(0.8)
	var place: Vector3 = canape.global_position
	poser.call(couloir, fond)
	chose.entendre(Vector3(20.0, 0.0, 7.5), 14.0)
	a_bute = false
	var passe := false               # est-il de l'autre côté du canapé, dans le couloir ?
	t0 = Time.get_ticks_msec()
	while (chose.mode == chose.ENQUETE or Time.get_ticks_msec() - t0 < 1000) and Time.get_ticks_msec() - t0 < 12000:
		a_bute = a_bute or chose.bute
		passe = passe or (chose.global_position.x > 14.0 and chose.global_position.z > 7.0 and chose.global_position.z < 9.0)
		await get_tree().physics_frame
	verif(not passe and canape.global_position.distance_to(place) < 0.25, "un canapé en travers du couloir, d'un mur à l'autre : il ne le passe pas, et ne le pousse pas")
	verif(a_bute and not chose._atteint, "faute de passage, il va au plus près du bruit, et cogne contre ce qui l'en sépare")
	verif(chose.mode == chose.RODE, "puis il renonce")
	_mettre(canape, loin + Vector3(4, 0, 0))
	_mettre(petit, Vector3(11.5, 0.25, 7.5))             # un carton, lui, ne pèse pas assez
	await _attendre(0.6)
	poser.call(couloir, fond)
	chose.entendre(Vector3(17.0, 0.0, 7.5), 14.0)
	t0 = Time.get_ticks_msec()
	while chose.global_position.x < 14.0 and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().physics_frame
	verif(chose.global_position.x >= 14.0, "un carton sur son chemin ne l'arrête pas (%d kg : il passe au travers)" % int(petit.mass))
	jeu.sabotage("porte", 30.0, 1, Vector3.ZERO)        # la porte du salon, claquée
	await _images(3)
	poser.call(Vector3(11.5, 0.0, 7.5), Vector3(11.5, 0.0, 3.0))
	chose.entendre(Vector3(13.0, 0.0, 3.5), 14.0)
	await _attendre(3.0)
	verif(chose.global_position.z > 6.8, "une porte claquée l'arrête comme un mur")
	jeu.effets["porte"].reste = 0.0
	await _attendre(0.2)
	moi.global_position = cour
	chose.global_position = m.taniere
	chose._roder(60.0)

	print("8. Le mort")
	_mettre(petit, Vector3(18.0, 0.3, 20.0))
	await _attendre(0.5)
	_devant(second, petit, 1.5)
	second.pitch = -0.5
	await _images(3)
	avant = petit.global_position
	second.agir()                  # mort, la touche d'action pousse (par l'hôte, comme s'il la demandait lui-même)
	jeu.pousser(2, petit.id)
	await _attendre(0.5)
	verif(petit.global_position.distance_to(avant) > 0.4, "un mort pousse un carton (%.1f m)" % petit.global_position.distance_to(avant))
	avant = canape.global_position
	_devant(second, canape, 2.0)
	await _images(3)
	jeu.pousser(2, canape.id)
	jeu.prendre(2, petit.id)
	await _attendre(0.4)
	verif(canape.global_position.distance_to(avant) < 0.05 and petit.porteurs.is_empty(), "mais ni un canapé, ni rien qu'il puisse porter")

	print("9. Le chat")
	var chat = jeu.chat
	chat.ouvrir()
	var distincts := {}
	for o in chat.options:
		distincts[o] = R.SABOTAGES.has(o)
	verif(chat.ouvert and distincts.size() == 3 and not distincts.values().has(false), "un vote s'ouvre : trois sabotages différents")
	verif(chat.lire_ligne("PING :tmi.twitch.tv") == "PONG :tmi.twitch.tv", "Twitch demande si l'on est là : on répond")
	chat.lire_ligne(":alice!alice@alice.tmi.twitch.tv PRIVMSG #chaine :!2")
	chat.lire_ligne(":alice!alice@alice.tmi.twitch.tv PRIVMSG #chaine :1")
	chat.lire_ligne(":bob!bob@bob.tmi.twitch.tv PRIVMSG #chaine :2")
	chat.lire_ligne(":carol!carol@carol.tmi.twitch.tv PRIVMSG #chaine :salut 3 les amis")
	chat.lire_ligne(":dan!dan@dan.tmi.twitch.tv PRIVMSG #chaine :3")
	verif(chat.voix == [0, 2, 1], "le chat vote 1, 2 ou 3 (ou !2), une voix par personne, le bavardage ne compte pas")
	var elu: Array = []
	var note := func(g): elu.append(g)
	chat.vote_clos.connect(note)
	var voulu: String = chat.options[1]
	chat.clore()
	chat.vote_clos.disconnect(note)
	chat.reste = 1e9
	verif(elu == [voulu] and not chat.ouvert, "le plus voté l'emporte : « %s »" % R.SABOTAGES[voulu].nom)
	for nom in jeu.effets:
		jeu.effets[nom].reste = 0.0
	await _attendre(0.2)
	chose.global_position = m.taniere
	chose._roder(60.0)

	print("10. Les sabotages")
	jeu.sabotage("noir", 0.5, -1, Vector3.ZERO)
	verif(not m.eclairee and not m.lampes[0].lumiere.visible, "le courant coupé, la maison est noire")
	await _attendre(0.8)
	verif(m.eclairee and m.lampes[0].lumiere.visible, "puis il revient")
	var a := Vector3(4.0, 1.0, 5.0)
	var b := Vector3(4.0, 1.0, 8.0)
	verif(m.voit(a, b), "par la porte de la chambre, on voit le couloir")
	jeu.sabotage("porte", 0.6, 0, Vector3.ZERO)
	await _images(3)
	verif(m.portes[0].verrou and not m.voit(a, b), "la porte claquée, on ne voit plus, et l'on ne passe plus")
	await _attendre(0.9)
	verif(not m.portes[0].verrou and m.voit(a, b), "puis elle se rouvre")
	moi.torche_voulue = true
	await _images(2)
	var allumee: bool = moi.torche.visible
	jeu.sabotage("torches", 0.5, -1, Vector3.ZERO)
	await _images(2)
	verif(allumee and not moi.torche.visible, "les torches grillées s'éteignent")
	await _attendre(0.8)
	verif(moi.torche.visible, "puis se rallument")
	moi.torche_voulue = false
	var piano = _trouver("piano")
	sol = piano.global_position.y
	jeu.sabotage("plume", 1.5, -1, Vector3.ZERO)
	await _attendre(1.0)
	verif(piano.gravity_scale < 0.1 and piano.global_position.y > sol + 0.3, "en apesanteur, le piano décolle (%.2f m)" % (piano.global_position.y - sol))
	await _attendre(1.6)
	verif(is_equal_approx(piano.gravity_scale, 1.0) and piano.global_position.y < sol + 0.2, "puis il retombe")
	chose.global_position = m.taniere
	chose._roder(60.0)
	jeu._sur_vote("vacarme")
	verif(chose.mode == chose.ENQUETE, "un vacarme sur un porteur : le fantôme y va")

	print("11. La fin")
	jeu.compter()
	verif(jeu.charge > 0 and jeu.charge < jeu.quota, "le carton de la zone ne fait pas le quota (%d € sur %d)" % [jeu.charge, jeu.quota])
	jeu.quota = jeu.charge
	jeu.klaxonner(1)
	verif(jeu.etat == jeu.FIN and jeu.gagne, "le quota atteint, un coup de klaxon : le camion part, c'est gagné")
	jeu.lancer()
	await _attendre(0.3)
	jeu.repit = 1e9
	verif(jeu.etat == jeu.PARTIE and jeu.objets.size() == nombre and jeu.joueurs.size() == 1 and jeu.charge == 0, "une autre maison : une nuit neuve, les mêmes règles")
	verif(get_tree().get_nodes_in_group("rien").is_empty() and jeu.get_node("Monde") == jeu.monde, "l'ancienne maison est partie")
	jeu.temps = 0.05
	await _attendre(0.3)
	verif(jeu.etat == jeu.FIN and not jeu.gagne, "l'aube sur un camion vide : c'est perdu")
	jeu.lancer()
	await _attendre(0.3)
	jeu.tuer(1)
	await _attendre(0.2)
	verif(jeu.etat == jeu.FIN and not jeu.gagne, "plus un porteur en vie : c'est perdu")

	print("12. La maison bonus")
	var ordinaire: int = jeu.total
	jeu.bonus_voulu = ["cave", "garage"]
	jeu.lancer()
	await _attendre(0.5)
	verif(jeu.maison.bonus == ["cave", "garage"] and jeu.ui._annonce.text.contains("MANOIR BONUS") and jeu.ui._annonce.text.contains("la cave au rituel"),
		"la maison d'essai, avec une cave et un garage : l'écran l'annonce")
	var tresors := 0
	for o in jeu.objets.values():
		if o.bonus:
			tresors += o.valeur
	verif(jeu.prime == tresors and jeu.prime >= 3000 and jeu.quota == R.quota(jeu.total, 1) and jeu.total < ordinaire,
		"ses trésors valent %d €, en plus : le quota (%d €) ne compte que le mobilier ordinaire" % [jeu.prime, jeu.quota])
	var moto = _trouver("moto")
	var grimoire = _trouver("grimoire")
	verif(moto != null and grimoire != null and moto.physics_material_override.friction < 0.2, "il y a une moto au garage (elle roule), et un grimoire sur l'autel de la cave")
	await _attendre(1.0)
	verif(moto.global_position.y < 0.8 and grimoire.global_position.y > 0.8 and moto.valeur == moto.valeur_neuve and grimoire.valeur == grimoire.valeur_neuve, "posés, ils ne bougent pas et ne cassent rien")
	var lingot = jeu.objets.values().filter(func(o): return o.type == "caisse_outils")[0]
	jeu.moi.global_position = lingot.global_position + Vector3(0.0, 0.0, 0.9)
	jeu.moi.global_position.y = 0.05
	jeu.prendre(1, lingot.id)
	await _attendre(0.2)
	verif(jeu.chose.mode == jeu.chose.DORT, "prendre un trésor ordinaire ne réveille personne")
	jeu.lacher(1, lingot.id, false)
	jeu.moi.global_position = grimoire.global_position + Vector3(0.0, 0.0, 0.9)
	jeu.moi.global_position.y = 0.05
	jeu.prendre(1, grimoire.id)
	await _attendre(0.2)
	verif(jeu.chose.mode == jeu.chose.ENQUETE and jeu.ui._annonce.text.contains("grimoire"), "prendre le grimoire, si : le fantôme se réveille et vient voir, d'où qu'il soit")
	jeu.lacher(1, grimoire.id, false)
	jeu.tuer(1)
	await _attendre(0.2)
	jeu.bonus_voulu = []
	await _bruits()
	await _argent()
	await _etages()
	jeu.retour_menu()
	verif(jeu.etat == jeu.MENU and jeu.monde == null and jeu.joueurs.is_empty(), "et l'on revient au menu")


# faire marcher un porteur pour de bon (ses jambes, la pesanteur), droit vers l'est ou l'ouest, jusqu'à cette abscisse ; vrai s'il y arrive
func _avancer(j, sens: float, jusque: float, delai: float = 8.0) -> bool:
	j.pilote = false
	j.yaw = -PI * 0.5 * sens
	j.pitch = 0.0
	var t0 := Time.get_ticks_msec()
	while (j.global_position.x - jusque) * sens < 0.0 and Time.get_ticks_msec() - t0 < delai * 1000.0:
		jeu.tactile.vecteur = Vector2(0.0, -1.0)
		await get_tree().physics_frame
	jeu.tactile.vecteur = Vector2.ZERO
	await _images(20)
	return (j.global_position.x - jusque) * sens >= 0.0


# attendre que le fantôme soit à ce niveau, près de ce point ; en chemin, noter s'il est passé par les marches
func _suivre(vers: Vector3, delai: float) -> Array:
	var chose = jeu.chose
	var marches := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < delai * 1000.0:
		marches = marches or jeu.maison.escalier_sous(chose.global_position) != null
		if absf(chose.global_position.y - vers.y) < 0.2 and Vector2(chose.global_position.x - vers.x, chose.global_position.z - vers.z).length() < 1.6:
			return [true, marches, (Time.get_ticks_msec() - t0) / 1000.0]
		await get_tree().physics_frame
	return [false, marches, delai]


# l'argent : la facture d'une nuit, la caisse, la dette, la boutique, et ce que font les achats
func _argent() -> void:
	print("15. L'argent")
	var b = jeu.bourse
	# la facture, sur le papier
	var bonne: Dictionary = R.facture(6000, 5000, 200, 0)
	var maigre: Dictionary = R.facture(2000, 5000, 0, 1)
	var pris := 6000 - int(bonne.net)
	verif(bonne.net > 300 and bonne.net < 1500 and pris > 4500, "une bonne nuit : 6 000 € chargés, il en reste %d une fois l'agence, les frais, les cotisations, la casse et l'impôt servis (%d %% de pris)" % [bonne.net, pris * 100 / 6000])
	verif(maigre.net < -1500, "une mauvaise : 2 000 € chargés pour un quota de 5 000, un mort : on doit %d €" % -int(maigre.net))
	# une nuit jouée : la part va en caisse
	b.argent = 0
	b.objets = {}
	jeu.lancer()
	await _attendre(0.4)
	jeu.repit = 1e9
	jeu.chat.reste = 1e9
	jeu.charge = jeu.quota + 3000
	var attendu: int = R.facture(jeu.charge, jeu.quota, 0, 0).net
	jeu.finir(true, "Le camion part, chargé.")
	await _attendre(0.3)
	verif(jeu.etat == jeu.FIN and b.argent == attendu and attendu > 0 and jeu.ui._fin_compte.text.contains("commission") and jeu.ui._fin_compte.text.contains("En caisse : %d €" % attendu),
		"la nuit gagnée : l'écran de fin détaille la facture, et il reste %d € en caisse" % b.argent)
	# la boutique
	b.argent = 2000
	jeu.ui.boutique(b)
	var r: Dictionary = jeu.ui.reperes()
	verif(r.has("achat_chaussons") and r.has("achat_sangles") and r.has("retour_boutique") and jeu.ui._boutique_caisse.text.contains("2000"), "la boutique : six articles, leur prix, et ce qu'on a en caisse")
	jeu.ui.achat.emit("chaussons")
	jeu.ui.achat.emit("trousse")
	jeu.ui.achat.emit("leurre")
	var refus: String = b.acheter("sangles")
	var deja: String = b.acheter("chaussons")
	verif(b.argent == 2000 - 400 - 300 - 250 and b.a("chaussons") and b.a("trousse") and b.a("leurre") and refus.contains("manque") and deja.contains("déjà"),
		"on y achète des chaussons, une trousse et un réveil ; pas les sangles (%s) ni deux fois les chaussons" % refus.to_lower())
	b.objets["sangles"] = 1
	b.objets["gants"] = 1
	b.objets["lampe"] = 1
	# ce que font les achats, la nuit suivante
	jeu.lancer()
	await _attendre(0.4)
	jeu.repit = 1e9
	jeu.chat.reste = 1e9
	var moi = jeu.moi
	verif(is_equal_approx(moi.discret, R.CHAUSSONS) and moi.torche.spot_range > 20.0, "les chaussons étouffent ses pas, la grosse torche porte plus loin")
	verif(is_equal_approx(jeu.force(1), R.FORCE_PORTEUR * R.SANGLES) and is_equal_approx(jeu.allonge(1), R.BRAS_MAX + R.GANTS), "l'hôte sait qu'il a des sangles (il porte %d N) et des gants (ses bras tiennent jusqu'à %.1f m)" % [int(jeu.force(1)), jeu.allonge(1)])
	jeu.frapper(1)
	await _attendre(0.1)
	var sauve: bool = moi.vivant and not moi.blesse and not b.a("trousse")
	await _attendre(jeu.ui.SCREAMER + 0.2)
	var passe: bool = not jeu.ui._screamer.visible
	jeu.frapper(1)
	await _attendre(0.1)
	verif(sauve and moi.blesse, "la trousse de secours : le premier coup ne le blesse pas, et elle est vide ; le suivant, si")
	verif(passe and jeu.ui._screamer.visible and jeu.ui._screamer_face.scale.x > 0.5 and jeu.ui._trouble.visible, "chaque fois qu'il l'attrape, sa face lui saute au visage (moins d'une seconde), puis la vue reste trouble")
	_pilote(moi)
	moi.global_position = Vector3(13.0, 0.05, 8.0)
	_tourner(moi, Vector3(3.0, 1.6, 8.0))
	await _oreille(Vector3(22.0, 0.0, 8.0))
	jeu.lancer_leurre()
	await _attendre(0.1)
	verif(not b.a("leurre") and jeu.chose.mode == jeu.chose.ENQUETE and jeu.chose._destination.x < 6.0, "le réveil à lancer : il sonne au bout du couloir, le fantôme y court, et il n'en reste plus")
	# une mauvaise nuit : la dette, ses intérêts, l'huissier
	b.argent = 100
	jeu.charge = 0
	jeu.tuer(1)
	await _attendre(0.3)
	var dette: int = -b.argent
	verif(jeu.etat == jeu.FIN and dette > 1500 and jeu.ui._fin_compte.text.contains("Dette") and b.acheter("leurre").contains("crédit"), "une nuit perdue, rien de chargé, un mort : %d € de dette, et la boutique ne fait plus crédit" % dette)
	b.argent = -1000
	var dit: Array = b.encaisser(-500)
	verif(b.argent == -1600 and dit.size() == 1, "la dette porte intérêt à chaque nuit : 1 000 € dus, une nuit à −500 €, on doit 1 600 €")
	b.argent = -4900
	b.objets = {"sangles": 1, "chaussons": 1}
	dit = b.encaisser(-500)
	verif(not b.a("sangles") and not b.a("chaussons") and b.argent == -4900 - 490 - 500 + 750 + 200 and dit.size() == 3,
		"passé %d € de dette, l'huissier saisit ce qu'on a de plus cher, repris à moitié prix, jusqu'à repasser dessous : les sangles, puis les chaussons" % R.SAISIE)
	b.argent = 0
	b.objets = {}


# le fantôme, éveillé, tranquille, à cette distance du porteur : a-t-il entendu, une fois ce délai passé ?
func _oreille(ou: Vector3) -> void:
	var chose = jeu.chose
	chose.reveiller()
	chose._roder(600.0)
	chose._repue = 0.0
	chose._interet = 0.0
	chose.global_position = ou
	chose.rotation.y = PI          # (le dos tourné : il ne voit personne, il ne peut qu'entendre)
	await _images(3)


func _entendu(vers: Vector3) -> bool:
	var chose = jeu.chose
	if chose.mode == chose.ALERTE or chose.mode == chose.CHASSE:      # (il a entendu, s'est retourné, et l'a vu)
		return true
	return chose.mode == chose.ENQUETE and Vector2(chose._destination.x - vers.x, chose._destination.z - vers.z).length() < 2.0


# tout ce qui fait du bruit, et que le fantôme entend : un par un, lui à quelques mètres, le dos tourné
func _bruits() -> void:
	print("13. Le bruit")
	jeu.lancer()
	await _attendre(0.5)
	jeu.repit = 1e9
	jeu.chat.reste = 1e9
	var m = jeu.maison
	var moi = jeu.moi
	var couloir := Vector3(13.0, 0.05, 8.0)        # le milieu du couloir de la maison d'essai
	var pres := Vector3(18.0, 0.0, 8.0)            # le fantôme, cinq mètres plus loin
	for o in jeu.objets.values():                   # (un couloir vide : rien d'autre ne fera de bruit)
		if absf(o.global_position.z - 8.0) < 1.2:
			_mettre(o, Vector3(2.5 + (o.id % 4) * 1.6, 0.5, m.profondeur + 2.0 + ((o.id / 4) % 6) * 1.6))      # (à l'écart du camion)
	await _attendre(1.0)
	# immobile : rien
	moi.pilote = false
	moi.global_position = couloir
	moi.velocity = Vector3.ZERO
	await _oreille(pres)
	await _attendre(0.6)
	verif(jeu.chose.mode == jeu.chose.RODE and moi.bruit < 0.5, "un porteur immobile ne fait aucun bruit : le fantôme, à cinq mètres, le dos tourné, ne bouge pas")
	# accroupi : on ne l'entend pas à cinq mètres ; en marchant, pas à cinq mètres non plus (4 m), mais à trois
	moi.yaw = PI * 0.5                               # (vers l'ouest : il s'éloigne)
	jeu.tactile.accroupi = true
	for i in 30:
		jeu.tactile.vecteur = Vector2(0.0, -1.0)
		await get_tree().physics_frame
	jeu.tactile.accroupi = false
	verif(jeu.chose.mode == jeu.chose.RODE and moi.bruit > 0.5, "accroupi, ses pas ne portent pas jusque-là (%.1f m)" % R.BRUIT_ACCROUPI)
	moi.global_position = couloir + Vector3(2.5, 0.0, 0.0)
	await _oreille(pres)
	for i in 25:
		jeu.tactile.vecteur = Vector2(0.0, -1.0)
		await get_tree().physics_frame
	verif(_entendu(moi.global_position), "ses pas, à moins de %d m : le fantôme y va" % int(R.BRUIT_PAS))
	# la course, de plus loin
	moi.global_position = couloir + Vector3(-3.0, 0.0, 0.0)
	moi.velocity = Vector3.ZERO
	await _oreille(pres)
	jeu.tactile.court = true
	for i in 25:
		jeu.tactile.vecteur = Vector2(0.0, -1.0)
		await get_tree().physics_frame
	jeu.tactile.court = false
	jeu.tactile.vecteur = Vector2.ZERO
	verif(_entendu(moi.global_position), "sa course, à huit mètres et plus (elle porte à %d m)" % int(R.BRUIT_COURSE))
	# un saut : la réception
	moi.global_position = couloir
	moi.velocity = Vector3.ZERO
	await _attendre(1.2)           # (le bruit d'une course met près d'une seconde à retomber)
	await _oreille(pres)
	verif(jeu.chose.mode == jeu.chose.RODE and moi.bruit < 0.5, "arrêté, il se tait de nouveau")
	jeu.tactile.saut = true
	await _images(3)
	jeu.tactile.saut = false
	var haut := 0.0
	for i in 70:
		haut = maxf(haut, moi.global_position.y)
		await get_tree().physics_frame
	verif(haut > 0.4 and _entendu(couloir), "un saut sur place (%.0f cm) : il retombe, et le fantôme l'entend (%d m)" % [haut * 100.0, int(R.BRUIT_SAUT)])
	# une course contre un mur
	moi.global_position = couloir + Vector3(3.0, 0.0, 0.3)     # (devant un mur plein, pas devant une porte)
	moi.velocity = Vector3.ZERO
	await _attendre(0.5)
	await _oreille(Vector3(13.0, 0.0, 3.0) + Vector3(11.0, 0.0, 0.0))       # dans le bureau, à douze mètres : trop loin pour des pas
	moi.yaw = 0.0                                    # (vers le nord : le mur du couloir est à un mètre)
	var bruit_max := 0.0
	jeu.tactile.court = true
	for i in 40:
		jeu.tactile.vecteur = Vector2(0.0, -1.0)
		bruit_max = maxf(bruit_max, moi.bruit)
		await get_tree().physics_frame
	jeu.tactile.court = false
	jeu.tactile.vecteur = Vector2.ZERO
	verif(bruit_max > R.BRUIT_COURSE + 0.5 and _entendu(moi.global_position), "une course contre un mur : il s'y cogne, et cela s'entend plus loin que sa course (%.0f m)" % bruit_max)
	_pilote(moi)
	moi.global_position = Vector3(m.porte_x, 0.05, m.profondeur + 3.0)
	await _attendre(0.4)
	# un meuble : un petit choc s'entend sans rien casser, un grand casse
	var vase = _trouver("vase")
	_mettre(vase, couloir + Vector3(0.0, vase.taille.y * 0.5 + 0.1, 0.0))
	await _oreille(pres + Vector3(-1.5, 0.0, 0.0))
	await _attendre(0.8)
	verif(_entendu(couloir) and vase.valeur == vase.valeur_neuve, "un vase posé un peu vite (de dix centimètres) : intact, mais entendu")
	_mettre(vase, couloir + Vector3(0.0, 2.2, 0.0))
	await _oreille(pres + Vector3(1.0, 0.0, 0.0))
	await _attendre(1.2)
	verif(_entendu(couloir) and vase.valeur < vase.valeur_neuve, "le même, lâché de deux mètres : cassé, et entendu de plus loin")
	_mettre(vase, Vector3(3.0, 0.3, m.profondeur + 8.0))
	# un meuble lourd qu'on traîne
	var canape = _trouver("canape")
	_mettre(canape, couloir + Vector3(0.0, canape.taille.y * 0.5 + 0.02, 0.0))
	canape.rotation.y = PI * 0.5
	await _attendre(1.0)
	await _oreille(pres + Vector3(4.0, 0.0, 0.0))
	verif(jeu.chose.mode == jeu.chose.RODE, "un canapé posé là, immobile : silence")
	for i in 40:
		canape.sleeping = false
		canape.linear_velocity = Vector3(-1.2, canape.linear_velocity.y, 0.0)
		await get_tree().physics_frame
	verif(_entendu(canape.global_position), "traîné au sol, il racle : le fantôme l'entend à neuf mètres (%d m)" % int(R.BRUIT_TRAINE + sqrt(canape.mass)))
	_mettre(canape, Vector3(8.0, 0.6, m.profondeur + 8.0))
	# une porte qui claque, un bras qui s'arrache, un cri, le klaxon
	var porte: Dictionary = m.portes[0]
	await _oreille(porte.centre * Vector3(1, 0, 1) + Vector3(6.0, 0.0, 1.5))
	jeu._effet("porte", true, 0)
	verif(_entendu(porte.centre), "une porte qui claque")
	jeu._effet("porte", false, 0)
	var carton = _trouver("carton")
	_mettre(carton, couloir + Vector3(0.0, 0.3, 0.0))
	moi.global_position = couloir + Vector3(0.0, 0.0, 0.8)
	_tourner(moi, carton.global_position)
	await _attendre(0.6)
	jeu.prendre(1, carton.id)
	await _attendre(0.3)
	await _oreille(pres)
	jeu.arracher(1, 0, carton.id)
	verif(_entendu(carton.global_position), "un bras qui s'arrache")
	jeu.lacher(1, carton.id, false)
	moi.global_position = Vector3(m.porte_x, 0.05, m.profondeur + 3.0)
	await _oreille(Vector3(m.porte_x, 0.0, m.profondeur - 9.0))
	moi.pilote = false
	await _images(5)
	moi.crier()
	await _attendre(0.5)
	verif(_entendu(moi.global_position), "un cri dans la cour, à douze mètres : il vient jusqu'au seuil")
	await _oreille(Vector3(3.0, 0.0, 3.0))
	jeu.klaxonner(1)
	verif(jeu.chose.mode == jeu.chose.ENQUETE, "le klaxon, du fond de la maison")
	# ce qui l'empêche d'entendre : il dort (sauf grand fracas), il chasse, il vient de frapper
	jeu.chose.mode = jeu.chose.DORT
	jeu.chose._repue = 0.0
	jeu.chose._interet = 0.0
	jeu.chose.entendre(jeu.chose.global_position + Vector3(2.0, 0.0, 0.0), 9.0)
	var dort: bool = jeu.chose.mode == jeu.chose.DORT
	jeu.chose.entendre(jeu.chose.global_position + Vector3(2.0, 0.0, 0.0), 10.0)
	verif(dort and jeu.chose.mode == jeu.chose.ENQUETE, "endormi, seul un bruit fort le réveille (%d m et plus : une course, pas des pas) ; tout bruit plus loin que sa portée est perdu" % int(15.0 / R.CHOSE_OUIE))
	jeu.tuer(1)
	await _attendre(0.2)


func _etages() -> void:
	print("14. L'étage et le sous-sol")
	jeu.etages_voulus = true
	jeu.lancer()
	await _attendre(0.5)
	jeu.repit = 1e9
	jeu.chat.reste = 1e9
	var m = jeu.maison
	var moi = jeu.moi
	var H: float = m.PAS
	var par := {-1: 0, 0: 0, 1: 0}
	var objets := {-1: 0, 0: 0, 1: 0}
	for p in m.pieces:
		if not p.type in ["couloir", "palier"]:
			par[p.niveau] += 1
	for o in jeu.objets.values():
		objets[m.niveau_de(o.global_position.y)] += 1
	verif(m.niveaux == [-1, 0, 1] and par[1] >= 4 and par[-1] >= 2 and m.escaliers.size() == 2,
		"la maison d'essai, avec un étage (%d pièces) et un sous-sol (%d pièces), et deux escaliers au bout du couloir" % [par[1], par[-1]])
	verif(objets[1] >= 30 and objets[-1] >= 10 and objets[0] >= 60, "meublés : %d objets à l'étage, %d au rez-de-chaussée, %d au sous-sol" % [objets[1], objets[0], objets[-1]])
	var joints := true
	var cases := 0
	for n in m.niveaux:
		for z in m.profondeur:
			for x in m.largeur:
				if m.plans[n][z][x] in [".", "D", "P"]:
					cases += 1
					joints = joints and not m.chemin(m.seuil, m.centre(Vector2i(x, z), n)).is_empty()
	verif(joints, "les %d cases de sol des trois niveaux se rejoignent depuis l'entrée, par les escaliers" % cases)
	var places := {}
	for o in jeu.objets.values():
		places[o.id] = o.global_position
	await _attendre(1.5)
	var bouge := 0.0
	var intacts := true
	for o in jeu.objets.values():
		bouge = maxf(bouge, o.global_position.distance_to(places[o.id]))
		intacts = intacts and o.valeur == o.valeur_neuve
	verif(bouge < 0.15 and intacts, "à chaque niveau, les meubles restent où on les a posés : les planchers tiennent (le plus remuant a bougé de %d cm)" % int(bouge * 100))
	var lit = null
	for o in jeu.objets.values():
		if o.type == "lit" and m.niveau_de(o.global_position.y) == 1:
			lit = o
	verif(lit != null and absf(lit.global_position.y - (H + lit.taille.y * 0.5)) < 0.06, "un lit, à l'étage, sur son plancher (%.2f m plus haut)" % H)
	# monter, pour de bon
	var monte: Dictionary = m.escaliers[0]
	var descend: Dictionary = m.escaliers[1]
	moi.global_position = monte.bas + Vector3(-0.5, 0.05, 0.0)
	moi.velocity = Vector3.ZERO
	await _images(10)
	var arrive: bool = await _avancer(moi, 1.0, monte.haut.x)
	verif(arrive and absf(moi.global_position.y - H) < 0.1 and moi.is_on_floor(), "le porteur monte les marches à pied, jusqu'au palier de l'étage (%.2f m)" % moi.global_position.y)
	jeu._niveler()
	var la_haut_allumees := 0
	for l in m.lampes:
		if l.lumiere.visible and l.niveau == 1:
			la_haut_allumees += 1
	verif(la_haut_allumees >= 5 and lit.visible and jeu._mailles() < 600, "là-haut, les lampes de l'étage sont allumées, ses meubles dessinés ; %d maillages à l'écran en tout (dans un navigateur, passé le millier, plus rien ne se dessine)" % jeu._mailles())
	arrive = await _avancer(moi, -1.0, monte.bas.x)
	verif(arrive and absf(moi.global_position.y) < 0.1, "et les redescend (%.2f m)" % moi.global_position.y)
	moi.global_position = descend.haut + Vector3(-0.5, 0.05, 0.0)
	moi.velocity = Vector3.ZERO
	await _images(10)
	arrive = await _avancer(moi, 1.0, descend.bas.x)
	verif(arrive and absf(moi.global_position.y + H) < 0.1, "l'autre volée le mène au sous-sol (%.2f m)" % moi.global_position.y)
	moi.global_position = Vector3(3.0, -H + 0.05, m.cage.position.y + 2.0)
	jeu._niveler()
	verif(not lit.visible, "d'en bas, loin de l'escalier, on ne dessine plus les meubles de l'étage")
	# les lampes : jamais plus qu'une vingtaine d'allumées à la fois, où qu'on soit (le moteur n'en dessine qu'une trentaine)
	var pire := 0
	var eclaire := true
	for n in m.niveaux:
		for x: float in [3.0, m.cage.position.x - 3.0, m.cage.position.x + 1.0, m.cage.end.x - 1.0]:
			moi.global_position = Vector3(x, m.y_de(n) + 0.05, m.cage.position.y + 2.0)
			jeu._niveler()
			var allumees := 0
			var ici := 0
			for l in m.lampes:
				if l.lumiere.visible:
					allumees += 1
					if l.niveau == n:
						ici += 1
			pire = maxi(pire, allumees)
			eclaire = eclaire and ici >= 5
	verif(m.lampes.size() > 32 and pire <= 24 and eclaire, "la maison a %d lampes ; à chaque niveau, près ou loin de l'escalier, pas plus de %d ne sont allumées à la fois, dont toutes celles du niveau" % [m.lampes.size(), pire])
	# un carton lâché en haut des marches : il les dévale
	var carton = _trouver("carton")
	_mettre(carton, monte.haut + Vector3(-1.6, 0.5, 0.0))
	await _attendre(3.0)
	verif(carton.global_position.y < H - 0.5 and m.escalier_sous(carton.global_position) != null or carton.global_position.y < 0.5,
		"un carton lâché en haut des marches les dévale (il est à %.1f m)" % carton.global_position.y)
	_mettre(carton, Vector3(3.0, 0.3, m.profondeur + 3.0))
	# le fantôme, d'un niveau à l'autre
	_pilote(moi)
	moi.global_position = Vector3(m.porte_x, 0.05, m.profondeur + 3.0)
	var chose = jeu.chose
	chose.reveiller()
	chose._repue = 0.0
	chose.global_position = Vector3(m.cage.position.x - 6.0, 0.0, m.cage.position.y + 2.0)
	var la_haut: Vector3 = m.centre(Vector2i(4, m.cage.position.y + 2), 1)
	chose.entendre(la_haut, 200.0)
	var suivi: Array = await _suivre(la_haut, 40.0)
	verif(suivi[0] and suivi[1], "un bruit à l'étage : le fantôme prend l'escalier et y monte (en %.0f s)" % suivi[2])
	var en_bas: Vector3 = m.centre(Vector2i(4, m.cage.position.y + 2), -1)
	chose._interet = 0.0
	chose.entendre(en_bas, 200.0)
	suivi = await _suivre(en_bas, 70.0)
	verif(suivi[0] and suivi[1], "un bruit au sous-sol : il redescend les deux volées (en %.0f s)" % suivi[2])
	# juste au-dessus de lui, on est à l'abri de ses yeux et de ses coups
	chose._roder(60.0)
	chose._repue = 0.0
	moi.global_position = Vector3(chose.global_position.x, 0.05, chose.global_position.z - 1.0)
	chose.rotation.y = 0.0
	await _attendre(0.6)
	verif(chose.mode == chose.RODE and moi.vivant and not moi.blesse, "un porteur juste au-dessus de lui, au rez-de-chaussée : il ne le voit pas à travers le plancher")
	moi.global_position = chose.global_position + Vector3(0.0, 0.05, -1.5)
	await _attendre(0.6)
	verif(chose.mode == chose.ALERTE, "au même niveau, devant lui, si")
	jeu.tuer(1)
	await _attendre(0.2)
	jeu.etages_voulus = false


# --- le réseau : l'hôte ---

@rpc("any_peer", "call_remote", "reliable")
func rapport(nom: String, bon: bool) -> void:
	rapports[nom] = bon


func _rapport(nom: String, quoi: String, args: Array, dit: String) -> void:
	etape.rpc(nom, quoi, args)
	var t0 := Time.get_ticks_msec()
	while not rapports.has(nom) and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
	verif(rapports.get(nom, false), dit + ("" if rapports.has(nom) else " (l'invité n'a pas répondu)"))


func _hote() -> void:
	print("Le réseau : un hôte et un invité sur cette machine")
	verif(jeu.heberger() and jeu.etat == jeu.SALON, "l'hôte ouvre le salon (port %d)" % R.PORT)
	var invite := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--essai-client"])
	var t0 := Time.get_ticks_msec()
	while multiplayer.get_peers().is_empty() and Time.get_ticks_msec() - t0 < 25000:
		await get_tree().process_frame
	verif(multiplayer.get_peers().size() == 1, "l'invité entre au salon")
	if multiplayer.get_peers().is_empty():
		OS.kill(invite)
		return
	var lui: int = multiplayer.get_peers()[0]
	await _attendre(0.5)
	verif(jeu.noms.get(lui, "") == "Invité d'essai" and jeu.ui._salon_texte.text.contains("Porteur, Invité d'essai"), "il dit son pseudo, et le salon l'affiche")
	jeu.lancer()
	jeu.repit = 1e9
	jeu.chat.reste = 1e9
	await _attendre(2.6)
	var moi = jeu.moi
	verif(jeu.joueurs.size() == 2 and jeu.joueurs.has(lui) and jeu.quota == R.quota(jeu.total, 2) and jeu.maison.pieces.size() >= 6 and jeu.objets.size() >= 40, "la nuit commence à deux, le quota est celui de deux porteurs (%d €)" % jeu.quota)
	verif(jeu.joueurs[lui].nom == "Invité d'essai" and moi.nom == "Porteur", "dans la partie, chacun porte son pseudo")
	var ou: Array = []
	for i in jeu.objets.size():
		ou.append(jeu.objets[i].global_position)
	await _rapport("maison", "maison", [jeu.quota, ou], "l'invité a la même maison, les mêmes meubles aux mêmes endroits, le même quota")

	_pilote(moi)
	var carton = _trouver("carton")
	var cour: Vector3 = jeu.maison.depart(0)             # (la maison est inventée : on se repère à sa cour)
	moi.global_position = cour
	moi.yaw = 0.0
	await _images(2)
	_mettre(carton, moi.point_de_prise(carton.taille))
	jeu.prendre(1, carton.id)
	await _attendre(1.0)
	verif(carton.prises.size() == 2 and carton.porteurs == [1], "l'hôte prend un carton, à deux mains")
	await _rapport("porte", "objet", [carton.id, carton.global_position, [1], 2], "l'invité voit le carton dans les mains de l'hôte, au même endroit, tenu par ses deux bras")

	var chaise = _trouver("chaise")
	var la := cour + Vector3(4.0, 0.0, -1.0)
	_mettre(chaise, la + Vector3(0, 0.5, 0))
	await _attendre(1.0)
	var sol: float = chaise.global_position.y
	await _rapport("prend", "prends", [chaise.id, la + Vector3(0, 0, 1.3)], "l'invité demande la chaise à l'hôte, et l'a en main")
	await _attendre(0.8)
	var j = jeu.joueurs[lui]
	verif(j.global_position.distance_to(la + Vector3(0, 0, 1.3)) < 0.5, "l'hôte voit l'invité là où il s'est mis")
	verif(chaise.porteurs == [lui] and j.porte == chaise.id and chaise.global_position.y > sol + 0.4, "chez l'hôte, la chaise monte aux mains de l'invité (%.2f m)" % chaise.global_position.y)

	jeu.chose.reveiller()
	jeu.chose.global_position = jeu.maison.taniere
	jeu.chose._roder(60.0)
	await _attendre(0.5)
	await _rapport("chose", "chose", [jeu.chose.global_position], "l'invité voit la chose réveillée, là où elle est")
	jeu.arracher(lui, 0, chaise.id)
	await _rapport("bras", "bras", [chaise.id], "un bras de l'invité s'arrache : il le sait, et tient encore la chaise de l'autre")
	jeu.sabotage.rpc("noir", 5.0, -1, Vector3.ZERO)
	await _rapport("noir", "noir", [], "le courant coupé l'est aussi chez l'invité")
	jeu.tuer(lui)
	await _rapport("mort", "mort", [], "pris par la chose, l'invité se sait mort")
	verif(chaise.porteurs.is_empty() and not j.vivant, "et la chaise lui tombe des mains")
	jeu.finir(false, "L'essai s'arrête là.")
	await _rapport("fin", "fin", [], "la fin de la partie arrive chez l'invité")
	etape.rpc("au revoir", "partir", [])
	await _attendre(0.5)
	if OS.is_process_running(invite):
		OS.kill(invite)


# --- le réseau : l'invité, qui fait ce que l'hôte lui dit et lui rend compte ---

func _invite() -> void:
	jeu.compte.pseudo = "Invité d'essai"
	jeu.rejoindre("127.0.0.1")
	var t0 := Time.get_ticks_msec()
	while not _fini and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	ok = _fini


@rpc("authority", "call_remote", "reliable")
func etape(nom: String, quoi: String, args: Array) -> void:
	var bon := false
	var moi = jeu.moi
	match quoi:
		"maison":
			bon = moi != null and moi.nom == "Invité d'essai" and jeu.joueurs[1].nom == "Porteur"
			bon = bon and jeu.etat == jeu.PARTIE and jeu.quota == args[0] and jeu.objets.size() == args[1].size() and jeu.joueurs.size() == 2 and moi != null
			for i in jeu.objets.size():
				bon = bon and jeu.objets[i].global_position.distance_to(args[1][i]) < 0.4
		"objet":
			await _attendre(0.4)
			var o = jeu.objets[args[0]]
			bon = o.global_position.distance_to(args[1]) < 0.4 and o.porteurs == args[2] and o.prises.size() == args[3] and jeu.joueurs[1].accroches().size() == args[3]
		"prends":
			var o = jeu.objets[args[0]]
			moi.global_position = args[1]
			_tourner(moi, o.global_position)
			await _attendre(0.6)
			jeu.vouloir("prendre", [o.id])
			moi.pitch = 0.0
			await _attendre(0.8)
			bon = o.porteurs == [jeu.mon_id] and moi.porte == o.id
		"bras":
			var o = jeu.objets[args[0]]
			bon = moi.repousse[0] > 0.0 and moi.bras_libres() == 1 and o.prises.size() == 1 and moi.porte == o.id
		"chose":
			bon = jeu.chose.mode != jeu.chose.DORT and jeu.chose.visible and jeu.chose.global_position.distance_to(args[0]) < 1.0
		"noir":
			bon = not jeu.maison.eclairee
		"mort":
			bon = not moi.vivant and moi.porte == -1
		"fin":
			bon = jeu.etat == jeu.FIN and not jeu.gagne
		"partir":
			_fini = true
			return
	rapport.rpc_id(1, nom, bon)


# --- le compte : un faux service de comptes, sur cette machine, qui répond comme le vrai ---

const PORT_COMPTES := 24691
var _srv: TCPServer
var _clients: Array = []
var _vus: Array = []              # les demandes reçues : « POST /auth/v1/… »
var _sans_cle := 0
var _meta_pseudo := ""            # le pseudo gardé sur le compte
var _pseudo_sv := "Ada des Pierres"
var _cree = null                  # le compte qu'on vient de créer : ce que le jeu a envoyé
var _demandes: Array = []         # les adresses pour lesquelles on a demandé un nouveau mot de passe
var _nouveau_mdp := ""


func _process(_dt: float) -> void:
	if _srv == null:
		return
	while _srv.is_connection_available():
		_clients.append({"pair": _srv.take_connection(), "lu": PackedByteArray(), "fait": false})
	for c in _clients:
		var p: StreamPeerTCP = c.pair
		p.poll()
		if c.fait or p.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		var n := p.get_available_bytes()
		if n > 0:
			c.lu.append_array(p.get_data(n)[1])
		var texte: String = c.lu.get_string_from_utf8()
		var coupe := texte.find("\r\n\r\n")
		if coupe < 0:
			continue
		var tete := texte.substr(0, coupe)
		var corps := texte.substr(coupe + 4)
		var longueur := 0
		for l in tete.split("\r\n"):
			if l.to_lower().begins_with("content-length:"):
				longueur = int(l.get_slice(":", 1))
		if corps.to_utf8_buffer().size() < longueur:
			continue
		c.fait = true
		var r := _repondre(tete, corps)
		var json := JSON.stringify(r[1]).to_utf8_buffer()
		p.put_data(("HTTP/1.1 %d Essai\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [r[0], json.size()]).to_utf8_buffer() + json)


func _repondre(tete: String, corps: String) -> Array:
	var ligne := tete.get_slice("\r\n", 0).get_slice(" HTTP", 0)
	_vus.append(ligne)
	if not tete.contains("apikey: sb_publishable_"):
		_sans_cle += 1
	var j = JSON.parse_string(corps) if corps.strip_edges() != "" else {}
	var session := func(n: int) -> Dictionary:
		return {"access_token": "jeton-%d" % n, "refresh_token": "reprise-%d" % n, "expires_in": 3600,
			"user": {"id": "u-1", "email": "ada@exemple.fr", "user_metadata": {"pseudo": _meta_pseudo} if _meta_pseudo != "" else {}}}
	if ligne.begins_with("POST /auth/v1/token?grant_type=password"):
		if j is Dictionary and j.get("email") == "ada@exemple.fr" and j.get("password") == "bon":
			return [200, session.call(1)]
		return [400, {"code": 400, "error_code": "invalid_credentials", "msg": "Invalid login credentials"}]
	if ligne.begins_with("POST /auth/v1/token?grant_type=refresh_token"):
		if j is Dictionary and j.get("refresh_token") == "reprise-1":
			return [200, session.call(2)]
		return [400, {"code": 400, "error_code": "refresh_token_not_found"}]
	if ligne.begins_with("POST /auth/v1/signup"):
		if not ligne.contains("redirect_to=http"):
			return [400, {"error_code": "validation_failed"}]
		if j is Dictionary and str(j.get("password", "")).length() < 6:
			return [422, {"code": 422, "error_code": "weak_password"}]
		if j is Dictionary and j.get("email") == "ada@exemple.fr":         # déjà prise : le vrai service répond par un compte sans identité
			return [200, {"id": "u-faux", "email": "ada@exemple.fr", "identities": []}]
		_cree = j
		return [200, {"id": "u-2", "email": j.get("email"), "identities": [{"provider": "email"}], "confirmation_sent_at": "2026-11-12T12:00:00Z"}]
	if ligne.begins_with("POST /auth/v1/recover"):
		_demandes.append(str(j.get("email", "")) if j is Dictionary else "")
		return [200, {}] if ligne.contains("redirect_to=http") else [400, {"error_code": "validation_failed"}]
	if ligne.begins_with("GET /auth/v1/user"):
		if tete.contains("Authorization: Bearer lien-bon"):
			return [200, {"id": "u-1", "email": "ada@exemple.fr", "user_metadata": {"pseudo": _meta_pseudo} if _meta_pseudo != "" else {}}]
		return [403, {"code": 403, "error_code": "bad_jwt"}]
	if ligne.begins_with("PUT /auth/v1/user") and tete.contains("Authorization: Bearer lien-bon") and j is Dictionary and j.has("password"):
		if j.password == "bon":
			return [422, {"code": 422, "error_code": "same_password"}]
		_nouveau_mdp = str(j.password)
		return [200, {"id": "u-1"}]
	var porteur := tete.contains("Authorization: Bearer jeton-") or tete.contains("Authorization: Bearer lien-bon")
	if ligne.begins_with("GET /rest/v1/vp_comptes?select=pseudo:donnees-%3E%3Epseudo"):
		return [200, [{"pseudo": _pseudo_sv}]] if porteur else [401, {"message": "JWT manquant"}]
	if ligne.begins_with("PUT /auth/v1/user") and porteur and j is Dictionary and j.get("data") is Dictionary:
		_meta_pseudo = str(j.data.get("pseudo", ""))
		return [200, {"id": "u-1"}]
	if ligne.begins_with("POST /auth/v1/logout") and porteur:
		return [204, {}]
	return [404, {}]


func _compte() -> void:
	print("La connexion : contre un faux service de comptes, sur cette machine")
	_srv = TCPServer.new()
	verif(_srv.listen(PORT_COMPTES, "127.0.0.1") == OK, "le faux service écoute (port %d)" % PORT_COMPTES)
	var Compte = jeu.Compte
	var c = jeu.compte
	c.url = "http://127.0.0.1:%d" % PORT_COMPTES
	c.fichier = "user://compte-essai.json"
	var chemin := ProjectSettings.globalize_path(c.fichier)
	DirAccess.remove_absolute(chemin)
	jeu.ui.page_connexion()
	verif(c.url != c.SUPABASE and c.SUPABASE.begins_with("https://") and c.CLE.begins_with("sb_publishable_"), "le jeu connaît le vrai service et sa clé publique ; l'essai, lui, parle au faux")

	print("1. Se connecter")
	await c.connecter("", "")
	verif(not c.connecte and c.erreur != "" and _vus.is_empty(), "sans e-mail ni mot de passe : rien n'est envoyé, et c'est dit")
	await c.connecter("ada@exemple.fr", "faux")
	verif(not c.connecte and c.erreur == "E-mail ou mot de passe incorrect." and not FileAccess.file_exists(c.fichier), "un mauvais mot de passe : refusé, et c'est dit")
	verif(jeu.ui._connexion.is_visible_in_tree() and jeu.ui._connexion_avis.text == c.erreur, "la page de connexion reste là, avec l'explication")
	await c.connecter("  ada@exemple.fr ", "bon")
	verif(c.connecte and c.id == "u-1" and c.jeton == "jeton-1" and c.erreur == "", "le bon : connecté")
	verif(c.pseudo == "Ada des Pierres" and c.nom() == "Ada des Pierres", "sans pseudo choisi ici, c'est celui de sa sauvegarde Stone Valley")
	var garde := FileAccess.get_file_as_string(c.fichier)
	verif(garde.contains("reprise-1") and not garde.contains("bon") and not garde.contains("ada@") and not garde.contains("jeton-1"), "sur l'appareil : le jeton de reprise seulement, ni le mot de passe, ni l'e-mail")
	verif(jeu.ui._menu.is_visible_in_tree() and jeu.ui._compte_texte.text == "Connecté : Ada des Pierres" and jeu.ui._mdp.text == "", "la page de connexion laisse la place au menu, qui dit qui l'on est")

	print("2. Le pseudo")
	await c.nommer("  Ada <la> Portefaix de la nuit  ")
	verif(c.pseudo == "Ada la Portefaix" and _meta_pseudo == c.pseudo, "un pseudo choisi ici est nettoyé, coupé à 16 lettres, et gardé sur le compte : « %s »" % c.pseudo)
	verif(not _vus.any(func(l): return l.contains("vp_sauver") or (l.contains("vp_comptes") and not l.begins_with("GET"))), "la sauvegarde de Stone Valley est lue, jamais écrite")
	jeu.graine = 7
	jeu.jouer_seul()
	await _attendre(0.3)
	verif(jeu.moi.nom == "Ada la Portefaix", "dans la partie, le porteur porte ce pseudo")
	jeu.retour_menu()

	print("3. Rester connecté")
	var c2 = Compte.new()
	c2.url = c.url
	c2.fichier = c.fichier
	add_child(c2)
	await c2.reprendre()
	verif(c2.connecte and c2.jeton == "jeton-2" and c2.pseudo == "Ada la Portefaix", "au lancement suivant : connecté sans rien retaper, avec son pseudo")
	verif(FileAccess.get_file_as_string(c.fichier).contains("reprise-2"), "et le jeton de reprise est renouvelé")
	var c3 = Compte.new()
	c3.url = "http://127.0.0.1:%d" % (PORT_COMPTES + 7)       # personne n'écoute là
	c3.fichier = c.fichier
	add_child(c3)
	await c3.reprendre()
	verif(not c3.connecte and c3.erreur == "" and FileAccess.file_exists(c.fichier), "le service en panne au lancement : pas connecté, sans reproche, et le jeton est gardé pour la prochaine fois")
	await c3.connecter("ada@exemple.fr", "bon")
	verif(not c3.connecte and c3.erreur.begins_with("Le service des comptes ne répond pas"), "en panne quand on se connecte : c'est dit")
	FileAccess.open(c.fichier, FileAccess.WRITE).store_string(JSON.stringify({"reprise": "perimee"}))
	var c4 = Compte.new()
	c4.url = c.url
	c4.fichier = c.fichier
	add_child(c4)
	await c4.reprendre()
	verif(not c4.connecte and not FileAccess.file_exists(c.fichier), "un jeton de reprise périmé : pas connecté, et il est jeté")

	print("4. Se déconnecter")
	c2.deconnecter()
	c.deconnecter()
	await _attendre(0.4)
	verif(not c.connecte and c.jeton == "" and c.nom() == "Porteur" and not FileAccess.file_exists(c.fichier), "déconnecté : plus de jeton, plus rien sur l'appareil")
	verif(_vus.any(func(l): return l.begins_with("POST /auth/v1/logout")) and _sans_cle == 0, "le service en est prévenu ; chaque demande portait la clé publique")
	verif(jeu.ui._compte_texte.text == "Sans compte" and jeu.ui._compte_bouton.text == "Se connecter" and not jeu.ui._pseudo_ligne.visible, "le menu le dit, et propose de se reconnecter")
	print("5. Créer un compte")
	jeu.ui._vers(jeu.ui._creation)
	var avant := _vus.size()
	await c.creer("pas-une-adresse", "motdepasse", "Zoé")
	verif(not c.connecte and c.erreur != "" and _vus.size() == avant, "une adresse qui n'en est pas une : rien n'est envoyé, et c'est dit")
	await c.creer("zoe@exemple.fr", "court", "Zoé")
	verif(c.erreur.contains("six") or c.erreur.contains("6"), "un mot de passe de moins de six caractères : refusé avant d'être envoyé")
	await c.creer("ada@exemple.fr", "motdepasse", "Ada")
	verif(not c.connecte and c.erreur.contains("déjà un compte") and c.avis == "", "une adresse déjà prise : c'est dit, avec quoi faire")
	await c.creer(" zoe@exemple.fr ", "motdepasse", " Zoé <la> Déménageuse de la nuit ")
	verif(not c.connecte and c.erreur == "" and c.avis.contains("zoe@exemple.fr") and c.avis.contains("confirmation"), "une adresse neuve : le compte est créé, un e-mail de confirmation part")
	verif(_cree is Dictionary and _cree.email == "zoe@exemple.fr" and _cree.data.pseudo == "Zoé la Déménageu" and _vus[_vus.size() - 1].contains("redirect_to=http"),
		"le service reçoit l'adresse, le pseudo nettoyé, et où ramener le lien de l'e-mail")
	verif(jeu.ui._creation.is_visible_in_tree() and jeu.ui._avis_compte[1].text == c.avis and not FileAccess.file_exists(c.fichier), "la page le dit, et attend : on n'est pas connecté tant que l'e-mail n'est pas confirmé")
	await c.lire_lien("#access_token=lien-bon&refresh_token=reprise-1&expires_in=3600&token_type=bearer&type=signup")
	verif(c.connecte and not c.a_changer and c.avis.contains("confirmé") and jeu.ui._menu.is_visible_in_tree(), "revenu par le lien de l'e-mail : le compte est confirmé, on est connecté, au menu")
	c.deconnecter()
	await _attendre(0.2)

	print("6. Mot de passe oublié")
	jeu.ui.page_connexion()
	jeu.ui._email.text = "ada@exemple.fr"
	jeu.ui._vers(jeu.ui._oubli)
	verif(jeu.ui._oubli.is_visible_in_tree() and jeu.ui._c["o_email"].text == "ada@exemple.fr", "« Mot de passe oublié ? » : la page reprend l'e-mail déjà tapé")
	await c.oublie("ada@exemple.fr")
	verif(_demandes == ["ada@exemple.fr"] and c.erreur == "" and c.avis.contains("e-mail") and not c.connecte, "le lien est demandé au service ; la page dit d'aller voir ses e-mails, sans dire si le compte existe")
	await c.lire_lien("#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired")
	verif(not c.connecte and c.erreur.contains("expiré"), "un lien expiré : c'est dit, on le redemande")
	await c.lire_lien("#access_token=lien-faux&refresh_token=x&type=recovery")
	verif(not c.connecte and c.erreur.contains("expiré"), "un lien qui ne vaut rien : pareil")
	await c.lire_lien("#access_token=lien-bon&refresh_token=reprise-1&expires_in=3600&token_type=bearer&type=recovery")
	verif(c.connecte and c.a_changer and jeu.ui._nouveau.is_visible_in_tree(), "le bon lien : la page « Nouveau mot de passe » s'ouvre")
	await c.changer_mot_de_passe("court", "court")
	verif(c.a_changer and c.erreur != "" and _nouveau_mdp == "", "trop court : refusé")
	await c.changer_mot_de_passe("nouveau-secret", "nouveau-secrte")
	verif(c.a_changer and c.erreur.contains("pas les mêmes") and _nouveau_mdp == "", "deux saisies différentes : refusé")
	await c.changer_mot_de_passe("nouveau-secret", "nouveau-secret")
	verif(not c.a_changer and c.connecte and _nouveau_mdp == "nouveau-secret" and jeu.ui._menu.is_visible_in_tree() and jeu.ui._avis.text.contains("changé"),
		"le nouveau mot de passe est enregistré : on est connecté, au menu, et c'est dit")
	verif(not FileAccess.get_file_as_string(c.fichier).contains("nouveau-secret"), "et il n'est pas gardé sur l'appareil")
	c.deconnecter()
	await _attendre(0.2)
	_srv.stop()
	_srv = null

	if OS.get_cmdline_user_args().has("--en-ligne"):
		print("7. Le vrai service (un mauvais mot de passe, rien n'y est écrit)")
		var vrai = Compte.new()
		vrai.fichier = c.fichier
		add_child(vrai)
		await vrai.connecter("essai@example.invalid", "mauvais-mot-de-passe")
		verif(not vrai.connecte and vrai.erreur == "E-mail ou mot de passe incorrect." and not FileAccess.file_exists(c.fichier), "le vrai service répond, et refuse un compte qui n'existe pas")
