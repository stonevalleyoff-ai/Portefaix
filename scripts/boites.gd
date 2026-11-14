extends RefCounted
# Portefaix — des boîtes fondues en un seul maillage (scripts/boites.gd)
# Tout le jeu est fait de boîtes. Une par maillage, une maison en compte plus de mille à l'écran : dans un navigateur, passé ce
# nombre, plus rien ne se dessine. On les fond donc : un meuble est un seul maillage, un pan de maison aussi. Chaque boîte garde sa
# couleur, portée par ses sommets.

# les six faces d'une boîte : leur normale, et un côté
const FACES := [[Vector3.RIGHT, Vector3.UP], [Vector3.LEFT, Vector3.UP], [Vector3.UP, Vector3.BACK], [Vector3.DOWN, Vector3.BACK], [Vector3.BACK, Vector3.RIGHT], [Vector3.FORWARD, Vector3.RIGHT]]
static var _matieres := {}

var _sommets := PackedVector3Array()
var _normales := PackedVector3Array()
var _couleurs := PackedColorArray()
var _indices := PackedInt32Array()

# Les matières. Chaque boîte porte sa couleur dans ses sommets ; la matière y ajoute une texture, petite, à gros points nets (du
# low-poly), fabriquée ici et plaquée d'après la place des faces dans le monde : il n'y a rien à déplier.
#   grain   le bois des meubles, le plâtre : presque rien, de quoi accrocher la lumière
#   bois    un parquet à lames
#   mur     un mur de manoir : un lambris sombre en bas, un papier peint à rayures, une corniche (la hauteur d'un niveau)
#   pierre  des moellons : la façade, le sous-sol
#   herbe   la cour
static func matiere(sorte: String) -> StandardMaterial3D:
	if _matieres.has(sorte):
		return _matieres[sorte]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true      # (nos couleurs sont celles qu'on voit, comme celles des autres matières)
	m.roughness = 0.88
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_world_triplanar = sorte != "grain"     # (un meuble emporte son grain avec lui ; la maison, elle, ne bouge pas)
	var h := RandomNumberGenerator.new()
	h.seed = sorte.hash()
	var im: Image
	match sorte:
		"bois":
			im = _lames(h)
			m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		"mur":
			im = _tenture(h)
			m.uv1_scale = Vector3(0.5, 1.0 / 3.1, 0.5)
		"pierre":
			im = _moellons(h)
			m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		"beton":
			im = _beton(h)
			m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		"metal":
			im = _toles(h)
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
		"grille":
			im = _mailles(h)
			m.uv1_scale = Vector3(2.0, 2.0, 2.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"lueur":                          # ce qui luit : un écran, un voyant, une flamme (sa couleur, sans ombre)
			im = _bruit(h, 8, 0.96, 1.0)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"herbe":
			im = _bruit(h, 32, 0.55, 1.0)
			m.uv1_scale = Vector3(0.4, 0.4, 0.4)
		_:
			im = _bruit(h, 32, 0.86, 1.0, true)
			m.uv1_scale = Vector3(1.3, 1.3, 1.3)
	im.generate_mipmaps()
	m.albedo_texture = ImageTexture.create_from_image(im)
	_matieres[sorte] = m
	return m


static func teinte() -> StandardMaterial3D:
	return matiere("grain")


# des points plus ou moins clairs ; en fils, pour un bois
static func _bruit(h: RandomNumberGenerator, cote: int, de: float, a: float, fils: bool = false) -> Image:
	var im := Image.create(cote, cote, false, Image.FORMAT_RGB8)
	for x in cote:
		var fil := h.randf_range(de, a)
		for y in cote:
			var v := lerpf(fil, h.randf_range(de, a), 0.35) if fils else h.randf_range(de, a)
			im.set_pixel(x, y, Color(v, v, v))
	return im


# du béton banché : les joints des coffrages, les trous des tiges, des coulures
static func _beton(h: RandomNumberGenerator) -> Image:
	var im := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var coulures := []
	for x in 64:
		coulures.append(h.randf_range(0.0, 1.0))
	for x in 64:
		for y in 64:
			var v := h.randf_range(0.84, 1.0)
			if x % 32 == 0 or y % 32 == 0:
				v *= 0.7
			if (x % 32 == 8 or x % 32 == 24) and (y % 32 == 8 or y % 32 == 24):
				v = 0.45
			if coulures[x] > 0.9 and y % 32 < 4 + int(coulures[x] * 100.0) % 22:
				v *= 0.82
			im.set_pixel(x, y, Color(v, v, v * 0.98))
	return im


# des tôles rivetées
static func _toles(h: RandomNumberGenerator) -> Image:
	var im := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for x in 32:
		for y in 32:
			var v := h.randf_range(0.88, 1.0)
			if x % 16 == 0 or y % 16 == 0:
				v *= 0.6
			if (x % 16 == 3 or x % 16 == 13) and (y % 16 == 3 or y % 16 == 13):
				v = 1.0
			im.set_pixel(x, y, Color(v, v, v))
	return im


# un caillebotis : des barres, et le vide entre elles
static func _mailles(_h: RandomNumberGenerator) -> Image:
	var im := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for x in 16:
		for y in 16:
			var plein := x % 8 < 2 or y % 8 < 2
			im.set_pixel(x, y, Color(1, 1, 1, 1) if plein else Color(0, 0, 0, 0))
	return im


# un parquet : quatre lames par mètre, leurs joints sombres, des bouts décalés, une teinte par lame
static func _lames(h: RandomNumberGenerator) -> Image:
	var im := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for lame in 8:
		var bout := h.randi_range(0, 63)
		var teinte := h.randf_range(0.72, 1.0)
		for x in range(lame * 8, lame * 8 + 8):
			for y in 64:
				var v := teinte * h.randf_range(0.93, 1.0)
				if x == lame * 8 or y == bout:
					v *= 0.45
				if (y + bout) % 64 == 32:
					teinte = clampf(teinte + h.randf_range(-0.12, 0.12), 0.7, 1.0)
				im.set_pixel(x, y, Color(v, v * 0.97, v * 0.93))
	return im


# un mur de manoir, du sol au plafond : le lambris, sa cimaise, le papier peint à rayures et à losanges, la corniche
static func _tenture(h: RandomNumberGenerator) -> Image:
	var im := Image.create(64, 96, false, Image.FORMAT_RGB8)
	var lambris := Color(0.36, 0.23, 0.14)
	var papier := Color(0.62, 0.6, 0.5)
	for x in 64:
		for y in 96:                       # (y = 0 en haut du mur)
			var c: Color
			if y < 5:                                  # la corniche
				c = Color(0.82, 0.78, 0.68) * (0.8 if y == 4 else 1.0)
			elif y < 62:                               # le papier peint
				c = papier * (1.0 if (x / 8) % 2 == 0 else 0.86)
				var lx := x % 16 - 8
				var ly := (y - 5) % 19 - 9
				if (x / 8) % 2 == 0 and absi(lx + 4) + absi(ly) <= 2:
					c = Color(0.5, 0.2, 0.18)
			elif y < 66:                               # la cimaise
				c = lambris * (1.25 if y < 64 else 0.6)
			else:                                      # le lambris, en panneaux
				c = lambris * h.randf_range(0.9, 1.0)
				var px := x % 32
				if px < 2 or y > 92 or ((px == 6 or px == 27) and y > 70 and y < 89) or ((y == 70 or y == 89) and px >= 6 and px <= 27):
					c = lambris * 0.62
			im.set_pixel(x, y, Color(c.r, c.g, c.b))
	return im


# des moellons : des rangs de pierres inégales, décalés, leurs joints sombres
static func _moellons(h: RandomNumberGenerator) -> Image:
	var im := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for rang in 4:
		var x := h.randi_range(0, 12)
		while x < 64 + 12:
			var large := h.randi_range(10, 22)
			var teinte := h.randf_range(0.68, 1.0)
			for dx in large:
				for dy in 16:
					var v := teinte * h.randf_range(0.92, 1.0)
					if dx == 0 or dy == 0:
						v = 0.4
					im.set_pixel((x + dx) % 64, rang * 16 + dy, Color(v, v, v * 1.03))
			x += large
	return im


func vide() -> bool:
	return _sommets.is_empty()


# une boîte de plus : son milieu, sa taille, sa couleur, et comment elle est tournée
func ajouter(centre: Vector3, taille: Vector3, couleur: Color, base: Basis = Basis.IDENTITY) -> void:
	var d := _sommets.size()
	var demi := taille * 0.5
	for face in FACES:                               # six faces, quatre sommets chacune, deux triangles (dans le sens des aiguilles, vus du dehors)
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = n.cross(u)
		for coin: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			_sommets.append(centre + base * ((n + u * coin.x + v * coin.y) * demi))
			_normales.append(base * n)
			_couleurs.append(couleur)
		for k in [0, 2, 1, 0, 3, 2]:
			_indices.append(d + k)
		d += 4


func maillage() -> ArrayMesh:
	var t := []
	t.resize(Mesh.ARRAY_MAX)
	t[Mesh.ARRAY_VERTEX] = _sommets
	t[Mesh.ARRAY_NORMAL] = _normales
	t[Mesh.ARRAY_COLOR] = _couleurs
	t[Mesh.ARRAY_INDEX] = _indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, t)
	return m


# le maillage, dans un nœud prêt à poser, de cette matière
func noeud(sorte: String = "grain") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = maillage()
	mesh.material_override = matiere(sorte)
	return mesh
