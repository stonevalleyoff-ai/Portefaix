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
var m
var h: RandomNumberGenerator
var _r := Rect2()                 # la pièce qu'on meuble, en mètres
var _pris: Array = []             # ce qui est posé au sol : [emprise, hauteur]
var _libres: Array = []           # ce qu'il faut laisser devant les portes
var _aux_murs: Array = []         # ce qui est accroché
var _chambres := 0
var _horloge := false


func amenager(maison, hasard: RandomNumberGenerator) -> void:
	m = maison
	h = hasard
	for p in m.pieces:
		_r = Rect2(p.rect)
		_pris = []
		_aux_murs = []
		_libres = m.devants_de_porte(p.rect)
		match p.type:
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
	for i in 3:
		_mural("tableau")


func _debarras() -> void:
	_mur("bibliotheque")
	_mur("machine_laver")
	for i in 4:
		_ou_il_reste("carton")
	_ou_il_reste("chaise")
	_ou_il_reste("panier")


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
	objets.append({"type": type, "pos": Vector3(c.x, y + t.y * 0.5 + 0.02, c.y), "yaw": yaw, "accroche": false})
	if y <= 0.0:
		_pris.append([e, t.y])
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
			if m.lettre(x, z) != "#":
				return false
	else:
		var x := int(_r.position.x) - 1 if cote == 2 else int(_r.end.x)
		for z in range(int(floor(e.position.y)), int(floor(e.end.y - 0.001)) + 1):
			if m.lettre(x, z) != "#":
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
			objets.append({"type": type, "pos": Vector3(c.x, hauteur, c.y), "yaw": YAW[cote], "accroche": true})
			return


# --- les décors : ce qui tient à la maison ---

func _decor_au_mur(t: Vector3, boites: Array) -> Dictionary:
	var ou := _place_au_mur(t, [], NAN, 0.02)
	if ou.is_empty():
		return {}
	_pris.append([ou.e, t.y])
	decors.append({"pos": Vector3(ou.c.x, 0.0, ou.c.y), "yaw": ou.yaw, "boites": boites, "solide": true})
	return {"c": ou.c, "yaw": ou.yaw, "t": t, "haut": t.y, "e": ou.e, "cote": ou.cote, "u": ou.u}


func _tapis(c: Vector2, t: Vector2, couleur: Color) -> void:
	var e := Rect2(c - t * 0.5, t)
	if not _r.grow(-0.1).encloses(e):
		return
	decors.append({"pos": Vector3(c.x, 0.0, c.y), "yaw": 0.0, "solide": false,
		"boites": [[Vector3(0, 0.008, 0), Vector3(t.x, 0.016, t.y), couleur], [Vector3(0, 0.012, 0), Vector3(t.x - 0.3, 0.016, t.y - 0.3), couleur.lightened(0.15)]]})
