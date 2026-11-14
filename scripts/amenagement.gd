extends RefCounted
# Portefaix — meubler la maison (scripts/amenagement.gd)
# Chaque pièce est meublée selon son métier, comme on meuble une vraie maison : le canapé dos au mur, la télé en face sur son meuble,
# la table basse entre les deux ; le lit la tête au mur, ses tables de nuit de part et d'autre, une lampe dessus ; la table à manger
# au milieu, ses chaises autour ; le plan de travail, la cuisinière et le frigo le long des murs de la cuisine ; les tableaux et les
# miroirs accrochés. Rien ne se pose devant une porte, rien ne se chevauche.
# Il en sort deux listes : les objets (ce qu'on emporte : des corps qui tombent et se cassent) et les décors (ce qui tient à la maison :
# la baignoire, le lavabo, le plan de travail, les tapis). Le hasard est celui de la graine : tout le monde meuble pareil.

const R = preload("res://scripts/regles.gd")

# de quel côté regarde ce qu'on adosse à un mur : le mur du nord, du sud, de l'ouest, de l'est
const YAW := [0.0, PI, PI * 0.5, -PI * 0.5]
const EN_FACE := [1, 0, 3, 2]

var objets: Array = []            # {type, pos: Vector3, yaw: float, accroche: bool}
var decors: Array = []            # {pos: Vector3, yaw: float, boites: [[centre, taille, couleur]], solide: bool}
var lourds: Array = []            # la place au sol de ce qui arrête le fantôme : les meubles qui pèsent, ce qui tient à la maison
var fixes: Array = []             # parmi eux, ce qui tient à la maison (la baignoire, le plan de travail) : cela ne bougera pas
var m
var h: RandomNumberGenerator
var _r := Rect2()                 # la pièce qu'on meuble, en mètres
var _pris: Array = []             # ce qui est posé au sol : [emprise, hauteur]
var _libres: Array = []           # ce qu'il faut laisser devant les portes
var _aux_murs: Array = []         # ce qui est accroché
var _chambres := 0
var _horloge := false
var lourds_n: Array = []         # le niveau de chacun des lourds
var fixes_n: Array = []
var _n := 0                       # le niveau de la pièce qu'on meuble
var _y0 := 0.0                    # et la hauteur de son plancher
var _cachettes: Array = []        # où l'on peut cacher quelque chose : [le point, le niveau, la pièce, en hauteur ?]
var _piece := 0
var _passage := false             # la pièce qu'on meuble est un passage (un couloir, une entrée) : on n'y cache rien
var _prime := false              # on meuble une pièce bonus : ce qu'on y pose est de la prime


func amenager(maison, hasard: RandomNumberGenerator) -> void:
	m = maison
	h = hasard
	for p in m.pieces:
		_piece += 1
		_passage = p.type in ["couloir", "entree", "palier", "passerelle"]
		_r = Rect2(p.rect)
		_pris = []
		_aux_murs = []
		_n = p.get("niveau", 0)
		_y0 = m.y_de(_n)
		_libres = m.devants_de_porte(p.rect, _n)
		_prime = R.BONUS.has(p.type)
		match p.type:
			"cave":
				_cave()
			"garage":
				_garage()
			"tresor":
				_tresor()
			"arcade":
				_arcade()
			"nains":
				_nains()
			"trone":
				_trone()
			"salon":
				_salon()
			"manger":
				_manger()
			"cuisine":
				_cuisine()
			"chambre":
				_chambre()
			"bureau":
				_bureau()
			"bain":
				_bain()
			"entree":
				_entree()
			"couloir":
				_couloir()
			"debarras":
				_debarras()
			"palier":
				_palier()
			"passerelle":
				_passerelle()
			"garde":
				_garde()
			"vestiaire":
				_vestiaire()
			"reserve":
				_reserve()
			"dortoir":
				_dortoir()
			"refectoire":
				_refectoire()
			"controle":
				_controle()
			"infirmerie":
				_infirmerie()
			"hall":
				_hall()
			"armurerie":
				_armurerie()
			"citerne":
				_citerne()
			"dechets":
				_dechets()
			"reacteur":
				_reacteur()
			"buanderie":
				_buanderie()
			"chaufferie":
				_chaufferie()
		# les coins restés libres de cette pièce : de quoi y cacher quelque chose, par terre
		if not p.type in ["couloir", "entree", "palier", "passerelle"] and not _prime:
			for coin: Vector2 in [_r.position + Vector2(0.3, 0.3), Vector2(_r.end.x - 0.3, _r.position.y + 0.3), Vector2(_r.position.x + 0.3, _r.end.y - 0.3), _r.end - Vector2(0.3, 0.3)]:
				if _libre(Rect2(coin - Vector2(0.2, 0.2), Vector2(0.4, 0.4)), 0.0):
					_cachettes.append([Vector3(coin.x, _y0, coin.y), _n, _piece, false])
	_cacher()


# Les objets précieux, cachés. Deux sortes de cachettes : le dessus d'un meuble haut (une armoire, une bibliothèque, un casier : il faut
# lever les yeux), et un coin de pièce resté libre, par terre, dans l'ombre. Une cachette par pièce au plus, de tout à chaque niveau.
func _cacher() -> void:
	var combien: int = R.CACHES.get(m.lieu, 5)
	var sortes: Array = _melange(R.PRECIEUX.get(m.lieu, R.PRECIEUX["manoir"]).duplicate())
	var ou: Array = _melange(_cachettes)
	var pieces_prises := {}
	var par_niveau := {}
	var faites := 0
	for tour in 2:                           # d'abord une par niveau, puis ce qui reste
		for c in ou:
			if faites >= combien or pieces_prises.has(c[2]) or (tour == 0 and par_niveau.has(c[1])):
				continue
			var type: String = sortes[faites % sortes.size()]
			var t := _t(type)
			objets.append({"type": type, "pos": c[0] + Vector3(0.0, t.y * 0.5 + 0.02, 0.0), "yaw": h.randf() * TAU, "accroche": false, "bonus": true, "cache": true})
			pieces_prises[c[2]] = true
			par_niveau[c[1]] = true
			faites += 1


# --- les pièces ---

func _salon() -> void:
	var canape := _mur("canape")
	if not canape.is_empty():
		var basse := _devant(canape, "table_basse", 1.3, 0.0, false)
		_tapis(canape.c + _avant(canape) * 1.3, Vector2(2.4, 1.7) if canape.cote < 2 else Vector2(1.7, 2.4), Color(0.45, 0.2, 0.18))
		var meuble := _mur("meuble_tele", [EN_FACE[canape.cote]], canape.u)
		if meuble.is_empty():
			meuble = _mur("meuble_tele")
		_sur(meuble, "tele")
		if h.randf() < 0.5:
			_sur(basse, "vase")
	if _r.get_area() >= 40.0:
		_mur("piano")
	_mur("bibliotheque")
	_mur("fauteuil")
	if _r.get_area() >= 35.0:
		_mur("fauteuil")
	_mur("horloge")
	_horloge = true
	_coin("lampe")
	_coin("plante")
	_mural("tableau")
	_mural("tableau")


func _manger() -> void:
	var table := _milieu("table", 0.0 if _r.size.x >= _r.size.y else PI * 0.5)
	if not table.is_empty():
		_tapis(table.c, Vector2(2.6, 2.0) if _r.size.x >= _r.size.y else Vector2(2.0, 2.6), Color(0.2, 0.3, 0.32))
		for cote in [-1.0, 1.0]:
			for d in [-0.38, 0.38]:
				_chaise(table.c + _avant(table) * cote * (table.t.z * 0.5 + 0.3) + _droite(table) * d, table.yaw + (PI if cote > 0.0 else 0.0))
			_chaise(table.c + _droite(table) * cote * (table.t.x * 0.5 + 0.3), table.yaw - cote * PI * 0.5)
		_sur(table, "vase" if h.randf() < 0.6 else "assiettes")
	var buffet := _mur("buffet")
	_sur(buffet, "assiettes", -0.45)
	_sur(buffet, "vase", 0.4)
	if not _horloge:
		_mur("horloge")
		_horloge = true
	_coin("plante")
	_mural("tableau")
	if h.randf() < 0.5:
		_mural("miroir")


func _cuisine() -> void:
	var blanc := Color(0.86, 0.85, 0.8)
	var plan := _decor_au_mur(Vector3(2.4, 0.9, 0.6), [
		[Vector3(0, 0.43, 0), Vector3(2.4, 0.86, 0.6), blanc],
		[Vector3(0, 0.88, 0), Vector3(2.44, 0.04, 0.64), Color(0.2, 0.2, 0.22)],
		[Vector3(-0.6, 0.9, 0.02), Vector3(0.5, 0.02, 0.4), Color(0.6, 0.62, 0.65)]])
	var cuisiniere := {}
	if not plan.is_empty():
		_sur(plan, "micro_ondes", 0.85)
		_sur(plan, "grille_pain", 0.25, 0.05)
		_sur(plan, "assiettes", -1.02)
		cuisiniere = _mur("cuisiniere", [plan.cote], plan.u + 1.55)
	if cuisiniere.is_empty():
		cuisiniere = _mur("cuisiniere")
	_sur(cuisiniere, "casserole", 0.12, 0.1)
	_mur("frigo")
	if _r.get_area() >= 24.0:
		var table := _milieu("table", 0.0 if _r.size.x >= _r.size.y else PI * 0.5)
		if not table.is_empty():
			for cote in [-1.0, 1.0]:
				_chaise(table.c + _avant(table) * cote * (table.t.z * 0.5 + 0.3), table.yaw + (PI if cote > 0.0 else 0.0))
	_ou_il_reste("carton")


func _chambre() -> void:
	_chambres += 1
	var lit := _mur("lit")
	if not lit.is_empty():
		_sur(_a_cote(lit, "table_nuit", -1.0), "lampe_chevet")
		if h.randf() < 0.7:
			_sur(_a_cote(lit, "table_nuit", 1.0), "reveil")
		_sur(lit, "coussin", -0.35, -0.72)
		_sur(lit, "coussin", 0.35, -0.72)
		_tapis(lit.c + _droite(lit) * 1.25 + _avant(lit) * 0.2, Vector2(0.8, 1.4) if lit.cote < 2 else Vector2(1.4, 0.8), Color(0.55, 0.5, 0.38))
	_mur("armoire")
	var commode := _mur("commode")
	_sur(commode, "boite_bijoux", 0.25)
	if h.randf() < 0.4:
		_sur(commode, "vase", -0.3)
	if _chambres == 2:                 # la deuxième chambre a de quoi travailler
		var bureau := _mur("bureau")
		_devant(bureau, "chaise", 0.72)
		_sur(bureau, "lampe_chevet", 0.4, -0.1)
	_mural("miroir" if h.randf() < 0.5 else "tableau")
	if h.randf() < 0.4:
		_coin("plante")
	if h.randf() < 0.5:
		_ou_il_reste("carton")


func _bureau() -> void:
	var bureau := _mur("bureau")
	_devant(bureau, "chaise", 0.72)
	_sur(bureau, "ordinateur", 0.0, -0.1)
	_sur(bureau, "lampe_chevet", 0.48, -0.1)
	_mur("bibliotheque")
	_mur("bibliotheque")
	_mur("fauteuil")
	_coin("lampe")
	_mural("tableau")
	for i in 3:
		_ou_il_reste("carton")


func _bain() -> void:
	var email := Color(0.9, 0.91, 0.92)
	_decor_au_mur(Vector3(1.7, 0.6, 0.75), [
		[Vector3(0, 0.3, 0), Vector3(1.7, 0.6, 0.75), email],
		[Vector3(0, 0.58, 0), Vector3(1.5, 0.05, 0.55), Color(0.55, 0.7, 0.78)]])
	_decor_au_mur(Vector3(0.6, 0.86, 0.45), [
		[Vector3(0, 0.4, 0), Vector3(0.5, 0.8, 0.4), Color(0.4, 0.3, 0.22)],
		[Vector3(0, 0.83, 0), Vector3(0.6, 0.06, 0.45), email]])
	_decor_au_mur(Vector3(0.4, 0.8, 0.65), [
		[Vector3(0, 0.2, 0.06), Vector3(0.38, 0.4, 0.5), email],
		[Vector3(0, 0.58, -0.22), Vector3(0.38, 0.44, 0.18), email]])
	_mur("machine_laver")
	_mural("miroir", 1.5)
	_ou_il_reste("panier")


func _entree() -> void:
	var commode := _mur("commode", [2, 3])
	_sur(commode, "vase")
	_mural("miroir")
	_coin("plante")
	for i in 2:
		_ou_il_reste("carton")


func _couloir() -> void:
	if m.lieu == "bunker":                       # au bunker : des couloirs nus, un fût ou une caisse oubliés contre un mur
		_mur("casier")
		_ou_il_reste("fut")
		_ou_il_reste("conserves")
		return
	if _n >= 0:                                  # un long tapis rouge, usé, d'un bout à l'autre
		var long := _r.size.x >= _r.size.y
		_tapis(_r.get_center(), Vector2(_r.size.x - 1.0, 1.1) if long else Vector2(1.1, _r.size.y - 1.0), Color(0.42, 0.07, 0.09))
	for i in 3 if _n >= 0 else 0:
		_mural("tableau")


func _debarras() -> void:
	_mur("bibliotheque")
	_mur("machine_laver")
	for i in 4:
		_ou_il_reste("carton")
	_ou_il_reste("chaise")
	_ou_il_reste("panier")


# --- les pièces bonus : une maison sur quatre en a (maison.bonus) ---

# la cave : quelqu'un y a tracé un pentagramme, et ne l'a pas effacé en partant
func _cave() -> void:
	var c := _r.get_center()
	var rouge := Color(0.75, 0.05, 0.04)
	var rayon := clampf(minf(_r.size.x, _r.size.y) * 0.5 - 1.0, 0.7, 1.5)
	var traits: Array = []
	var pointes: Array = []
	for i in 5:
		pointes.append(Vector2(cos(i * TAU / 5.0 - PI * 0.5), sin(i * TAU / 5.0 - PI * 0.5)) * rayon)
	for i in 5:                                  # l'étoile : de chaque pointe à la deuxième suivante
		traits.append(_trait(pointes[i], pointes[(i + 2) % 5], rouge))
	for i in 16:                                 # le cercle autour
		traits.append(_trait(Vector2(cos(i * TAU / 16.0), sin(i * TAU / 16.0)) * rayon * 1.08, Vector2(cos((i + 1) * TAU / 16.0), sin((i + 1) * TAU / 16.0)) * rayon * 1.08, rouge))
	decors.append({"pos": Vector3(c.x, _y0, c.y), "yaw": 0.0, "solide": false, "boites": traits})
	var pierre := Color(0.3, 0.29, 0.31)
	var autel := _decor_au_mur(Vector3(1.5, 0.9, 0.65), [
		[Vector3(0, 0.4, 0), Vector3(1.3, 0.8, 0.5), pierre],
		[Vector3(0, 0.85, 0), Vector3(1.5, 0.1, 0.65), pierre.darkened(0.3)],
		[Vector3(0, 0.905, 0), Vector3(0.5, 0.012, 0.65), rouge]])
	_sur(autel, "grimoire")
	_sur(autel, "calice", -0.52)
	_sur(autel, "crane", 0.52)
	for p in pointes:                            # une bougie noire à chaque pointe, et un crâne au milieu
		if _libre(_emprise(c + p, _t("bougie"), 0.0), 0.0):
			_poser("bougie", c + p, 0.0)
	if _libre(_emprise(c, _t("crane"), 0.0), 0.0):
		_poser("crane", c, h.randf() * TAU)
	_mur("statue_bouc")
	_coin("tonneau")
	_coin("tonneau")
	_ou_il_reste("casier_vin")
	_ou_il_reste("casier_vin")
	_ou_il_reste("carton")


# le garage : une moto qui n'a pas roulé depuis longtemps, et de quoi la réparer
func _garage() -> void:
	var c := _r.get_center()
	var jaune := Color(0.9, 0.75, 0.1)
	var long := _r.size.x >= _r.size.y
	var place := Vector2(2.7, 1.5) if long else Vector2(1.5, 2.7)
	if _r.grow(-0.5).encloses(Rect2(c - place * 0.5, place)):      # la place peinte au sol, et la tache d'huile
		decors.append({"pos": Vector3(c.x, _y0, c.y), "yaw": 0.0 if long else PI * 0.5, "solide": false, "boites": [
			[Vector3(0, 0.006, -0.75), Vector3(2.7, 0.012, 0.08), jaune], [Vector3(0, 0.006, 0.75), Vector3(2.7, 0.012, 0.08), jaune],
			[Vector3(-1.35, 0.006, 0), Vector3(0.08, 0.012, 1.58), jaune], [Vector3(0.5, 0.005, 0.2), Vector3(0.5, 0.01, 0.4), Color(0.05, 0.05, 0.06), 0.5]]})
	_milieu("moto", 0.0 if long else PI * 0.5)
	var bois := Color(0.45, 0.32, 0.2)
	var etabli := _decor_au_mur(Vector3(1.8, 0.9, 0.6), [
		[Vector3(0, 0.86, 0), Vector3(1.8, 0.08, 0.6), bois],
		[Vector3(-0.8, 0.41, 0), Vector3(0.1, 0.82, 0.5), bois.darkened(0.3)], [Vector3(0.8, 0.41, 0), Vector3(0.1, 0.82, 0.5), bois.darkened(0.3)],
		[Vector3(0, 0.25, 0), Vector3(1.5, 0.05, 0.5), bois.darkened(0.2)],
		[Vector3(0.6, 0.98, -0.1), Vector3(0.18, 0.16, 0.3), Color(0.25, 0.3, 0.4)]])
	_sur(etabli, "caisse_outils", -0.3)
	_mur("velo")
	_coin("pneus")
	_coin("pneus")
	_ou_il_reste("bidon")
	_ou_il_reste("bidon")
	_ou_il_reste("caisse_outils")
	_ou_il_reste("carton")


# la chambre forte : ce que les propriétaires n'ont jamais déclaré
func _tresor() -> void:
	var c := _r.get_center()
	_tapis(c, Vector2(minf(_r.size.x - 1.0, 3.0), minf(_r.size.y - 1.0, 3.0)), Color(0.5, 0.06, 0.1))
	var marbre := Color(0.85, 0.84, 0.8)
	var socle := _socle(c, Vector3(0.6, 0.95, 0.6), [
		[Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.6), marbre], [Vector3(0, 0.47, 0), Vector3(0.42, 0.75, 0.42), marbre.darkened(0.1)],
		[Vector3(0, 0.9, 0), Vector3(0.6, 0.1, 0.6), marbre]])
	_sur(socle, "vase_ming")                     # (très cher, très fragile, et posé bien haut)
	var coffre := _mur("coffre_fort")
	_sur(coffre, "lingot")
	_mur("armure")
	_mur("armure")
	_mural("tableau_maitre")
	_mural("tableau_maitre")
	for i in 4:
		_ou_il_reste("lingot")
	_ou_il_reste("boite_bijoux")


# la salle d'arcade : tout marche encore, c'est bien le problème
func _arcade() -> void:
	_tapis(_r.get_center(), Vector2(minf(_r.size.x - 0.8, 3.4), minf(_r.size.y - 0.8, 3.4)), Color(0.3, 0.1, 0.45))
	_milieu("baby_foot", 0.0 if _r.size.x >= _r.size.y else PI * 0.5)
	_mur("borne_arcade")
	_mur("borne_arcade")
	_mur("jukebox")
	_mur("flipper")
	_mur("borne_arcade")
	_ou_il_reste("coussin")
	_ou_il_reste("coussin")
	_ou_il_reste("carton")


# le cercle des nains : ils regardent tous celui du milieu. Personne ne sait depuis quand.
func _nains() -> void:
	var c := _r.get_center()
	_tapis(c, Vector2(_r.size.x - 0.5, _r.size.y - 0.5), Color(0.2, 0.5, 0.18))
	var socle := _socle(c, Vector3(0.4, 0.3, 0.4), [[Vector3(0, 0.15, 0), Vector3(0.4, 0.3, 0.4), Color(0.5, 0.5, 0.48)]])
	if socle.is_empty():
		_ou_il_reste("nain_dore")
	else:
		_sur(socle, "nain_dore")
	var rayon := clampf(minf(_r.size.x, _r.size.y) * 0.5 - 0.7, 0.8, 1.7)
	var combien := int(clampf(rayon * 6.0, 6.0, 10.0))
	for i in combien:
		var a := i * TAU / combien
		for pres: float in [1.0, 0.72, 0.5]:         # (devant une porte, il se serre vers le milieu)
			var ou := c + Vector2(cos(a), sin(a)) * rayon * pres
			if _libre(_emprise(ou, _t("nain"), 0.0), 0.0):
				_poser("nain", ou, atan2(-cos(a), -sin(a)))      # tourné vers le milieu
				break
	_coin("plante")
	_coin("plante")
	_coin("nain")                                # (et un qui boude)


# la salle du trône : il fallait bien le mettre quelque part
func _trone() -> void:
	var or_ := Color(0.9, 0.72, 0.2)
	var pourpre := Color(0.45, 0.05, 0.12)
	var estrade := _decor_au_mur(Vector3(1.6, 0.2, 1.3), [
		[Vector3(0, 0.1, 0), Vector3(1.6, 0.2, 1.3), pourpre],
		[Vector3(0, 0.205, 0.6), Vector3(1.6, 0.012, 0.1), or_],
		[Vector3(0, 1.1, -0.57), Vector3(1.0, 1.8, 0.1), pourpre.lightened(0.1)],      # le dais, derrière
		[Vector3(-0.55, 1.1, -0.57), Vector3(0.1, 1.9, 0.14), or_], [Vector3(0.55, 1.1, -0.57), Vector3(0.1, 1.9, 0.14), or_],
		[Vector3(0, 2.05, -0.57), Vector3(1.3, 0.12, 0.16), or_], [Vector3(0, 2.2, -0.57), Vector3(0.3, 0.2, 0.12), or_]])
	if estrade.is_empty():
		_ou_il_reste("toilettes_or")
	else:
		_pris[_pris.size() - 1][1] = 2.3         # (le dais monte haut : rien d'accroché derrière)
		_sur(estrade, "toilettes_or", 0.0, -0.08)
		_sur(estrade, "rouleau_or", 0.55, -0.3)
		var devant: Vector2 = estrade.c + _avant(estrade) * 1.9      # le tapis rouge, jusqu'aux marches
		var t := Vector2(1.0, 2.2) if absf(_avant(estrade).y) > 0.5 else Vector2(2.2, 1.0)
		_tapis(devant, t, Color(0.6, 0.06, 0.08))
	for sens: float in [-1.0, 1.0]:
		if _a_cote(estrade, "chandelier", sens).is_empty():
			_ou_il_reste("chandelier")
	_mur("armure")                               # la garde
	_mur("armure")
	_mural("miroir", 1.5)
	_mural("tableau_maitre")
	_ou_il_reste("rouleau_or")
	_ou_il_reste("rouleau_or")
	_ou_il_reste("coussin")


# un trait peint au sol, d'un point à un autre (autour du milieu du décor) : une boîte plate, tournée, qui luit un peu
func _trait(a: Vector2, b: Vector2, couleur: Color) -> Array:
	var d := b - a
	return [Vector3((a.x + b.x) * 0.5, 0.008, (a.y + b.y) * 0.5), Vector3(d.length(), 0.016, 0.07), couleur, -atan2(d.y, d.x), 1.2]


# un socle qui tient à la maison, ici même (s'il y a la place)
func _socle(c: Vector2, t: Vector3, boites: Array) -> Dictionary:
	var e := _emprise(c, t, 0.0)
	if not _libre(e, 0.3):
		return {}
	_pris.append([e, t.y])
	_lourd(e)
	_fixe(e)
	decors.append({"pos": Vector3(c.x, _y0, c.y), "yaw": 0.0, "boites": boites, "solide": true})
	return {"c": c, "yaw": 0.0, "t": t, "haut": t.y, "e": e}


# la cage d'escalier : rien (il faut y passer avec un canapé)
func _palier() -> void:
	pass


# --- le bunker ---

# au bout de la passerelle, sur la plate-forme : ce qu'on y a monté, et oublié
func _passerelle() -> void:
	var y := 0.0
	for k in 2:
		var c := Vector2(_r.position.x + 1.0 + k * (_r.size.x - 2.0), _r.position.y + 1.0)
		objets.append({"type": "caisse_munitions" if k == 0 else "radio", "pos": Vector3(c.x, _y0 + y + _t("caisse_munitions").y * 0.5 + 0.03, c.y), "yaw": 0.0, "accroche": false, "bonus": false})


func _garde() -> void:
	var bureau := _mur("bureau")
	_sur(bureau, "radio")
	_devant(bureau, "chaise", 0.75)
	_mur("casier")
	_mur("casier")
	_ou_il_reste("masque_gaz")
	_ou_il_reste("carton")


func _vestiaire() -> void:
	for i in 4:
		_mur("casier")
	for i in 3:
		_ou_il_reste("masque_gaz")
	_ou_il_reste("chaise")
	_ou_il_reste("panier")


func _reserve() -> void:
	_mur("bibliotheque")
	_mur("bibliotheque")
	for i in 5:
		_ou_il_reste("conserves")
	_ou_il_reste("fut")
	_ou_il_reste("caisse_munitions")
	_ou_il_reste("carton")
	_ou_il_reste("bidon")


func _dortoir() -> void:
	for i in 5:
		var lit := _mur("lit_camp")
		if not lit.is_empty() and i % 2 == 0:
			_a_cote(lit, "casier", 1.0)
	_ou_il_reste("masque_gaz")
	_ou_il_reste("carton")
	_ou_il_reste("coussin")


func _refectoire() -> void:
	for k in 2:
		var table := _milieu("table", 0.0 if _r.size.x >= _r.size.y else PI * 0.5) if k == 0 else _ou_il_reste("table")
		if table.is_empty():
			continue
		for cote: float in [-1.0, 1.0]:
			_chaise(table.c + _avant(table) * cote * (table.t.z * 0.5 + 0.4), table.yaw + (PI if cote > 0 else 0.0))
	_mur("frigo")
	_mur("cuisiniere")
	_mur("buffet")
	for i in 3:
		_ou_il_reste("conserves")


func _controle() -> void:
	var premier := _mur("pupitre")
	_sur(premier, "radar")
	_devant(premier, "chaise", 0.8)
	for i in 2:
		var p := _mur("pupitre")
		_devant(p, "chaise", 0.8)
	var bureau := _mur("bureau")
	_sur(bureau, "ordinateur")
	_sur(bureau, "radio", 0.45)
	_mur("casier")
	_mural("tableau")


func _infirmerie() -> void:
	_mur("lit_camp")
	_mur("lit_camp")
	var commode := _mur("commode")
	_sur(commode, "pharmacie")
	_mur("casier")
	_mural("pharmacie", 1.5)
	_ou_il_reste("chaise")
	_ou_il_reste("masque_gaz")


# le hall des machines : sous la passerelle, de gros blocs qui tiennent au sol, et ce qu'on peut en emporter
func _hall() -> void:
	var acier := Color(0.3, 0.34, 0.33)
	for k in 2:
		_decor_au_mur(Vector3(2.2, 2.4, 1.2), [
			[Vector3(0, 1.0, 0), Vector3(2.2, 2.0, 1.2), acier],
			[Vector3(-0.6, 2.2, 0), Vector3(0.5, 0.5, 0.5), acier.darkened(0.3)], [Vector3(0.6, 2.9, 0), Vector3(0.3, 1.8, 0.3), acier.darkened(0.4)],
			[Vector3(0, 1.3, 0.61), Vector3(0.9, 0.5, 0.04), Color(0.9, 0.7, 0.1)], [Vector3(-0.7, 0.6, 0.61), Vector3(0.2, 0.2, 0.04), Color(0.2, 1.0, 0.3), 0.0, 2.0],
			[Vector3(0.7, 0.6, 0.61), Vector3(0.2, 0.2, 0.04), Color(1.0, 0.2, 0.1), 0.0, 2.0]])
	_mur("generateur")
	_mur("generateur")
	_coin("fut")
	_coin("fut")
	_ou_il_reste("caisse_outils")
	_ou_il_reste("caisse_outils")
	_ou_il_reste("bidon")
	_ou_il_reste("carton")
	_ou_il_reste("pneus")


func _armurerie() -> void:
	for i in 3:
		_mur("casier")
	for i in 4:
		_ou_il_reste("caisse_munitions")
	_ou_il_reste("masque_gaz")
	_ou_il_reste("radio")


func _citerne() -> void:
	var cuve := Color(0.26, 0.3, 0.34)
	for k in 2:
		_decor_au_mur(Vector3(1.6, 2.2, 1.6), [
			[Vector3(0, 1.1, 0), Vector3(1.4, 2.2, 1.4), cuve], [Vector3(0, 1.1, 0), Vector3(1.6, 0.12, 1.6), cuve.darkened(0.4)],
			[Vector3(0, 2.0, 0), Vector3(1.6, 0.12, 1.6), cuve.darkened(0.4)], [Vector3(0, 0.5, 0.75), Vector3(0.2, 0.2, 0.2), Color(0.7, 0.15, 0.1)]])
	_ou_il_reste("fut")
	_ou_il_reste("fut")
	_ou_il_reste("bidon")
	_ou_il_reste("bidon")
	_ou_il_reste("caisse_outils")


# le dépôt de déchets : des fûts qui fuient, une flaque qui luit. Ce qu'on y prend vaut cher, et se paie en dose.
func _dechets() -> void:
	var c := _r.get_center()
	decors.append({"pos": Vector3(c.x, _y0, c.y), "yaw": 0.0, "solide": false, "boites": [
		[Vector3(0, 0.008, 0), Vector3(1.8, 0.016, 1.3), Color(0.3, 1.0, 0.2), 0.3, 1.6], [Vector3(0.5, 0.009, 0.5), Vector3(1.0, 0.016, 1.2), Color(0.3, 1.0, 0.2), -0.5, 1.6]]})
	for i in 6:
		_ou_il_reste("fut_radioactif")
	_mur("caisse_plomb")
	_coin("caisse_plomb")
	_ou_il_reste("masque_gaz")


# le réacteur : son cœur luit au milieu de la salle. Les barres d'uranium valent une fortune.
func _reacteur() -> void:
	var c := _r.get_center()
	var coeur := _socle(c, Vector3(1.6, 1.4, 1.6), [
		[Vector3(0, 0.35, 0), Vector3(1.6, 0.7, 1.6), Color(0.3, 0.32, 0.34)], [Vector3(0, 1.0, 0), Vector3(1.0, 0.7, 1.0), Color(0.35, 1.0, 0.3), 0.0, 2.2],
		[Vector3(0, 1.4, 0), Vector3(1.3, 0.1, 1.3), Color(0.2, 0.22, 0.24)]])
	if coeur.is_empty():
		_decor_au_mur(Vector3(1.6, 1.4, 1.2), [[Vector3(0, 0.7, 0), Vector3(1.4, 1.4, 1.0), Color(0.35, 1.0, 0.3), 0.0, 2.2]])
	for i in 4:
		_ou_il_reste("barre_uranium")
	var p := _mur("pupitre")
	_devant(p, "chaise", 0.8)
	_mur("pupitre")
	_coin("caisse_plomb")
	_ou_il_reste("fut_radioactif")
	_ou_il_reste("fut_radioactif")


# au sous-sol : les machines, le linge
func _buanderie() -> void:
	_mur("machine_laver")
	_mur("machine_laver")
	_mur("bibliotheque")
	for i in 3:
		_ou_il_reste("panier")
	_ou_il_reste("chaise")
	_ou_il_reste("carton")


# au sous-sol : la chaudière, qui tient à la maison, et ce qu'on a entassé autour
func _chaufferie() -> void:
	var fonte := Color(0.3, 0.2, 0.16)
	_decor_au_mur(Vector3(1.2, 1.7, 0.9), [
		[Vector3(0, 0.8, 0), Vector3(1.0, 1.6, 0.8), fonte],
		[Vector3(0, 0.5, 0.41), Vector3(0.4, 0.4, 0.04), Color(1.0, 0.45, 0.1), 0.0, 1.5],      # le foyer
		[Vector3(0.35, 2.0, -0.2), Vector3(0.18, 1.0, 0.18), fonte.darkened(0.3)],
		[Vector3(-0.35, 1.2, 0.41), Vector3(0.12, 0.12, 0.04), Color(0.8, 0.8, 0.75)]])
	_coin("tonneau")
	for i in 4:
		_ou_il_reste("carton")
	_ou_il_reste("bidon")
	_ou_il_reste("caisse_outils")


func _lourd(e: Rect2) -> void:
	lourds.append(e)
	lourds_n.append(_n)


func _fixe(e: Rect2) -> void:
	fixes.append(e)
	fixes_n.append(_n)


# --- poser ---

func _t(type: String) -> Vector3:
	return R.CATALOGUE[type].taille


func _avant(p: Dictionary) -> Vector2:
	var v := Basis(Vector3.UP, p.yaw) * Vector3(0, 0, 1)
	return Vector2(v.x, v.z)


func _droite(p: Dictionary) -> Vector2:
	var v := Basis(Vector3.UP, p.yaw) * Vector3(1, 0, 0)
	return Vector2(v.x, v.z)


func _melange(a: Array) -> Array:
	var b := a.duplicate()
	for i in range(b.size() - 1, 0, -1):
		var k := h.randi_range(0, i)
		var x = b[i]
		b[i] = b[k]
		b[k] = x
	return b


# la place que prend au sol une chose de cette taille, tournée ainsi
func _emprise(c: Vector2, t: Vector3, yaw: float) -> Rect2:
	var d := Vector2(t.z, t.x) if absf(sin(yaw)) > 0.5 else Vector2(t.x, t.z)
	return Rect2(c - d * 0.5, d)


func _libre(e: Rect2, marge: float = 0.04) -> bool:
	if not _r.encloses(e):
		return false
	var large := e.grow(marge)
	for p in _pris:
		if p[0].intersects(large):
			return false
	for l in _libres:
		if l.intersects(e):
			return false
	return true


func _poser(type: String, c: Vector2, yaw: float, y: float = 0.0) -> Dictionary:
	var t := _t(type)
	var e := _emprise(c, t, yaw)
	objets.append({"type": type, "pos": Vector3(c.x, _y0 + y + t.y * 0.5 + 0.02, c.y), "yaw": yaw, "accroche": false, "bonus": _prime})
	if y <= 0.0 and t.y >= 1.7 and not _prime and not _passage:      # (le dessus d'un meuble haut : une cachette)
		_cachettes.append([Vector3(c.x, _y0 + t.y + 0.02, c.y), _n, _piece, true])
	if y <= 0.0:
		_pris.append([e, t.y])
		if R.CATALOGUE[type].masse >= R.OBJET_LEGER:
			_lourd(e)
	return {"type": type, "c": c, "yaw": yaw, "t": t, "haut": y + t.y, "e": e}


# le milieu d'une chose adossée à un mur, à l'abscisse u le long de ce mur
func _au_mur(cote: int, u: float, t: Vector3, ecart: float) -> Vector2:
	match cote:
		0:
			return Vector2(u, _r.position.y + ecart + t.z * 0.5)
		1:
			return Vector2(u, _r.end.y - ecart - t.z * 0.5)
		2:
			return Vector2(_r.position.x + ecart + t.z * 0.5, u)
	return Vector2(_r.end.x - ecart - t.z * 0.5, u)


# derrière, est-ce bien du mur (et pas une porte) ?
func _mur_plein(cote: int, e: Rect2) -> bool:
	if cote < 2:
		var z := int(_r.position.y) - 1 if cote == 0 else int(_r.end.y)
		for x in range(int(floor(e.position.x)), int(floor(e.end.x - 0.001)) + 1):
			if m.lettre(x, z, _n) != "#":
				return false
	else:
		var x := int(_r.position.x) - 1 if cote == 2 else int(_r.end.x)
		for z in range(int(floor(e.position.y)), int(floor(e.end.y - 0.001)) + 1):
			if m.lettre(x, z, _n) != "#":
				return false
	return true


# les endroits à essayer le long d'un mur : au hasard, ou du plus près d'une abscisse voulue
func _abscisses(cote: int, t: Vector3, pres: float) -> Array:
	var a := (_r.position.x if cote < 2 else _r.position.y) + t.x * 0.5 + 0.05
	var b := (_r.end.x if cote < 2 else _r.end.y) - t.x * 0.5 - 0.05
	var us: Array = []
	var u := a
	while u <= b + 0.001:
		us.append(u)
		u += 0.25
	if is_nan(pres):
		return _melange(us)
	us.sort_custom(func(x, y): return absf(x - pres) < absf(y - pres))
	return us


# une place contre un mur, pour une chose de cette taille : {c, yaw, cote, u, e}, ou rien
func _place_au_mur(t: Vector3, cotes: Array, pres: float, ecart: float) -> Dictionary:
	for cote in (cotes if not cotes.is_empty() else _melange([0, 1, 2, 3])):
		for u in _abscisses(cote, t, pres):
			var c := _au_mur(cote, u, t, ecart)
			var e := _emprise(c, t, YAW[cote])
			if _libre(e) and _mur_plein(cote, e):
				return {"c": c, "yaw": YAW[cote], "cote": cote, "u": u, "e": e}
	return {}


# un meuble adossé à un mur, son devant vers la pièce
func _mur(type: String, cotes: Array = [], pres: float = NAN) -> Dictionary:
	var ou := _place_au_mur(_t(type), cotes, pres, 0.06)
	if ou.is_empty():
		return {}
	var p := _poser(type, ou.c, ou.yaw)
	p.cote = ou.cote
	p.u = ou.u
	return p


# devant un meuble, à cette distance ; tourné vers lui (une chaise devant un bureau) ou comme lui (une table basse)
func _devant(p: Dictionary, type: String, dist: float, lateral: float = 0.0, face: bool = true) -> Dictionary:
	if p.is_empty():
		return {}
	var c: Vector2 = p.c + _avant(p) * dist + _droite(p) * lateral
	var yaw: float = p.yaw + (PI if face else 0.0)
	if not _libre(_emprise(c, _t(type), yaw)):
		return {}
	return _poser(type, c, yaw)


# contre le même mur, juste à gauche (-1) ou à droite (+1)
func _a_cote(p: Dictionary, type: String, sens: float) -> Dictionary:
	if p.is_empty():
		return {}
	var t := _t(type)
	var c: Vector2 = p.c + _droite(p) * sens * (p.t.x * 0.5 + t.x * 0.5 + 0.06) - _avant(p) * (p.t.z * 0.5 - t.z * 0.5)
	if not _libre(_emprise(c, t, p.yaw)):
		return {}
	return _poser(type, c, p.yaw)


# posé dessus
func _sur(p: Dictionary, type: String, dx: float = 0.0, dz: float = 0.0) -> Dictionary:
	if p.is_empty():
		return {}
	return _poser(type, p.c + _droite(p) * dx + _avant(p) * dz, p.yaw, p.haut)


func _chaise(c: Vector2, yaw: float) -> void:
	if _libre(_emprise(c, _t("chaise"), yaw), 0.0):
		_poser("chaise", c, yaw)


# vers le milieu de la pièce, avec de quoi tourner autour
func _milieu(type: String, yaw: float) -> Dictionary:
	var t := _t(type)
	for k in 24:
		var c := _r.get_center()
		if k > 0:
			c += Vector2(h.randf_range(-1.0, 1.0) * _r.size.x * 0.18, h.randf_range(-1.0, 1.0) * _r.size.y * 0.18)
		if _libre(_emprise(c, t, yaw), 0.75):
			return _poser(type, c, yaw)
	return {}


func _coin(type: String) -> Dictionary:
	var t := _t(type)
	for k in _melange([0, 1, 2, 3]):
		var c := Vector2(_r.position.x + t.x * 0.5 + 0.12 if k % 2 == 0 else _r.end.x - t.x * 0.5 - 0.12,
			_r.position.y + t.z * 0.5 + 0.12 if k < 2 else _r.end.y - t.z * 0.5 - 0.12)
		if _libre(_emprise(c, t, 0.0)):
			return _poser(type, c, 0.0)
	return {}


# n'importe où, là où il reste de la place au sol (un carton qu'on a posé là)
func _ou_il_reste(type: String) -> Dictionary:
	var t := _t(type)
	for k in 40:
		var c := Vector2(h.randf_range(_r.position.x + 0.4, _r.end.x - 0.4), h.randf_range(_r.position.y + 0.4, _r.end.y - 0.4))
		var yaw := h.randi_range(0, 3) * PI * 0.5
		if _libre(_emprise(c, t, yaw), 0.15):
			return _poser(type, c, yaw)
	return {}


# accroché à un mur, à hauteur d'yeux : il tient au mur tant qu'on ne le prend pas
func _mural(type: String, hauteur: float = 1.6) -> void:
	var t := _t(type)
	for cote in _melange([0, 1, 2, 3]):
		for u in _abscisses(cote, t, NAN):
			var c := _au_mur(cote, u, t, 0.02)
			var e := _emprise(c, t, YAW[cote])
			if not _mur_plein(cote, e):
				continue
			var gene := false
			for p in _pris:              # un meuble haut, juste là
				if p[0].intersects(e.grow(0.06)) and p[1] > hauteur - t.y * 0.5 - 0.15:
					gene = true
			for q in _aux_murs:
				if q.intersects(e.grow(0.3)):
					gene = true
			if gene:
				continue
			_aux_murs.append(e)
			objets.append({"type": type, "pos": Vector3(c.x, _y0 + hauteur, c.y), "yaw": YAW[cote], "accroche": true, "bonus": _prime})
			return


# --- les décors : ce qui tient à la maison ---

func _decor_au_mur(t: Vector3, boites: Array) -> Dictionary:
	var ou := _place_au_mur(t, [], NAN, 0.02)
	if ou.is_empty():
		return {}
	_pris.append([ou.e, t.y])
	_lourd(ou.e)
	_fixe(ou.e)
	decors.append({"pos": Vector3(ou.c.x, _y0, ou.c.y), "yaw": ou.yaw, "boites": boites, "solide": true})
	return {"c": ou.c, "yaw": ou.yaw, "t": t, "haut": t.y, "e": ou.e, "cote": ou.cote, "u": ou.u}


func _tapis(c: Vector2, t: Vector2, couleur: Color) -> void:
	var e := Rect2(c - t * 0.5, t)
	if not _r.grow(-0.1).encloses(e):
		return
	decors.append({"pos": Vector3(c.x, _y0, c.y), "yaw": 0.0, "solide": false,
		"boites": [[Vector3(0, 0.008, 0), Vector3(t.x, 0.016, t.y), couleur], [Vector3(0, 0.012, 0), Vector3(t.x - 0.3, 0.016, t.y - 0.3), couleur.lightened(0.15)]]})
