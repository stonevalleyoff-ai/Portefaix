extends CharacterBody3D
# Portefaix — un porteur (scripts/joueur.gd)
# Vu à la première personne. Chacun mène le sien et dit aux autres où il est, où il regarde et le bruit qu'il fait.
# Vivant : il marche, court, s'accroupit, saute, prend, pose, lance, crie. Mort : il hante, et pousse les petits objets.
# Ses bras sont élastiques : ils s'accrochent à ce qu'il prend, s'étirent quand il s'en éloigne, le rappellent, et s'arrachent s'il
# tire trop. Un bras arraché repousse en quelques secondes ; d'ici là, il porte d'une seule main, deux fois moins fort.

const R = preload("res://scripts/regles.gd")

var id := 1
var nom := "Porteur"
var local := false
var pilote := false           # l'essai tient les commandes
var principal
var vivant := true
var blesse := false           # un coup de la chose : le prochain tue
var accroupi := false
var bruit := 0.0              # le rayon, en mètres, où on l'entend
var yaw := 0.0
var pitch := 0.0
var porte := -1               # le numéro de l'objet qu'il tient
var torche_ok := true         # faux quand le chat a grillé les torches
var torche_voulue := true
var cible_pos := Vector3.ZERO
var tete: Node3D
var camera: Camera3D
var torche: SpotLight3D
var corps: Node3D
var _mat_corps: StandardMaterial3D
var _cri := 0.0
var _envoi := 0.0
var _pas := 0.0
var _chute := 0.0              # sa vitesse de chute, juste avant de toucher le sol
var _t_heurt := 0.0
var _prise_le := -1               # quand la souris a été prise (ce qu'elle dit juste après ne compte pas)
var repousse := [0.0, 0.0]        # ce qu'il reste à chaque bras (gauche, droit) pour repousser ; 0 : il est là
var couleur := Color.WHITE
var _bras: Array = []             # par côté : ses tronçons, sa main, où est son bout
var _racine_bras: Node3D

const TRONCONS := 6

const COULEURS := [Color(0.9, 0.55, 0.15), Color(0.2, 0.6, 0.9), Color(0.4, 0.75, 0.3), Color(0.85, 0.3, 0.5), Color(0.9, 0.85, 0.3), Color(0.6, 0.4, 0.85)]


func preparer(p, i: int, depart: Vector3, rang: int) -> void:
	principal = p
	id = i
	name = "j%d" % i
	set_multiplayer_authority(i)
	local = i == p.mon_id
	collision_layer = R.COUCHE_JOUEURS
	collision_mask = R.COUCHE_DECOR | R.COUCHE_OBJETS | R.COUCHE_LEGERS
	position = depart
	cible_pos = depart
	var forme := CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = 0.3
	c.height = 1.75
	forme.shape = c
	forme.position.y = 0.875
	add_child(forme)
	tete = Node3D.new()
	tete.position.y = R.YEUX
	add_child(tete)
	torche = SpotLight3D.new()
	torche.position = Vector3(0.2, -0.15, 0.0)
	torche.spot_range = 17.0
	torche.spot_angle = 30.0
	torche.spot_attenuation = 0.8
	torche.light_energy = 2.4
	torche.light_color = Color(1.0, 0.96, 0.85)
	torche.shadow_enabled = local
	tete.add_child(torche)
	if local:
		camera = Camera3D.new()
		camera.fov = 78.0
		camera.near = 0.05
		camera.far = 90.0
		tete.add_child(camera)
		camera.current = true
	# le corps que voient les autres : une salopette de sa couleur, une tête
	corps = Node3D.new()
	add_child(corps)
	couleur = COULEURS[rang % COULEURS.size()]
	_mat_corps = StandardMaterial3D.new()
	_mat_corps.albedo_color = couleur
	_mat_corps.roughness = 0.9
	_piece(corps, Vector3(0, 1.05, 0), Vector3(0.5, 0.75, 0.3))
	_piece(corps, Vector3(0, 0.35, 0), Vector3(0.42, 0.7, 0.26))
	_piece(tete, Vector3(0, 0.02, 0), Vector3(0.3, 0.32, 0.3))
	if not local:                 # son pseudo, au-dessus de sa tête, pour les autres
		var etiquette := Label3D.new()
		etiquette.text = nom
		etiquette.position.y = 2.05
		etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiquette.font_size = 40
		etiquette.pixel_size = 0.004
		etiquette.outline_size = 10
		etiquette.modulate = COULEURS[rang % COULEURS.size()].lightened(0.5)
		add_child(etiquette)
	if local:
		corps.visible = false
		tete.get_child(tete.get_child_count() - 1).visible = false
	_faire_bras()


# les bras : six tronçons et une main par côté, redessinés à chaque image de l'épaule jusqu'à ce qu'ils tiennent
func _faire_bras() -> void:
	_racine_bras = Node3D.new()
	_racine_bras.top_level = true
	add_child(_racine_bras)
	var peau := StandardMaterial3D.new()
	peau.albedo_color = Color(0.9, 0.72, 0.58)
	peau.roughness = 0.9
	for cote in 2:
		var manche := StandardMaterial3D.new()
		manche.albedo_color = couleur
		manche.roughness = 0.9
		var troncons: Array = []
		for i in TRONCONS:
			var t := MeshInstance3D.new()
			t.mesh = BoxMesh.new()
			t.material_override = manche
			_racine_bras.add_child(t)
			troncons.append(t)
		var paume := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.11, 0.11, 0.13)
		paume.mesh = b
		paume.material_override = peau
		_racine_bras.add_child(paume)
		_bras.append({"troncons": troncons, "main": paume, "manche": manche, "bout": Vector3.ZERO})


func epaule(cote: int) -> Vector3:
	return tete.global_transform * Vector3(-0.24 if cote == 0 else 0.24, -0.28, 0.02)


# les mains qu'il a sur ce qu'il porte : [côté, point d'accroche dans le monde]
func accroches() -> Array:
	var tenu = principal.objets.get(porte)
	var liste: Array = []
	if tenu != null:
		for prise in tenu.prises:
			if prise[0] == id:
				liste.append([prise[1], tenu.ancre(prise)])
	return liste


func bras_libres() -> int:
	return (1 if repousse[0] <= 0.0 else 0) + (1 if repousse[1] <= 0.0 else 0)


func _process(dt: float) -> void:
	for cote in 2:
		repousse[cote] = maxf(repousse[cote] - dt, 0.0)
	_racine_bras.visible = vivant
	if not vivant:
		return
	var tenus := accroches()
	for cote in 2:
		var b: Dictionary = _bras[cote]
		var de := epaule(cote)
		var vers: Vector3 = tete.global_transform * Vector3(-0.24 if cote == 0 else 0.24, -0.5, -0.42)       # au repos : devant lui, bas
		var tient := false
		for a in tenus:
			if a[0] == cote:
				vers = a[1]
				tient = true
		if repousse[cote] > 0.0:           # il repousse : un moignon, puis il s'allonge
			vers = de.lerp(vers, clampf((2.5 - repousse[cote]) / 2.5, 0.12, 1.0))
		if b.bout == Vector3.ZERO or b.bout.distance_to(vers) > 6.0:
			b.bout = vers
		b.bout = b.bout.lerp(vers, minf(1.0, dt * (24.0 if tient else 12.0)))
		var long := de.distance_to(b.bout)
		var milieu: Vector3 = (de + b.bout) * 0.5 + Vector3.DOWN * maxf(0.0, 0.75 - long) * 0.45        # détendu, il pend
		var epais := 0.085 / sqrt(maxf(long / 0.7, 1.0))                                                # étiré, il s'affine
		b.manche.albedo_color = couleur.lerp(Color(1.0, 0.12, 0.08), clampf(inverse_lerp(R.BRAS_TENDU, R.BRAS_MAX, long), 0.0, 1.0))
		var avant := de
		var base := Basis.IDENTITY
		for i in TRONCONS:
			var k := float(i + 1) / TRONCONS
			var p: Vector3 = de.lerp(milieu, k).lerp(milieu.lerp(b.bout, k), k)
			var d := p - avant
			var l := d.length()
			var t: MeshInstance3D = b.troncons[i]
			t.visible = l > 0.001
			if t.visible:
				var bz := d / l
				var bx := bz.cross(Vector3.UP)
				bx = Vector3.RIGHT if bx.length() < 0.01 else bx.normalized()
				base = Basis(bx, bz.cross(bx), bz)
				t.transform = Transform3D(Basis(base.x * epais, base.y * epais, base.z * l), (avant + p) * 0.5)
			avant = p
		b.main.transform = Transform3D(base, b.bout)


func _piece(parent: Node3D, c: Vector3, t: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = t
	mesh.mesh = b
	mesh.position = c
	mesh.material_override = _mat_corps
	parent.add_child(mesh)


# là où ses mains tiennent un objet de cette taille : devant ses yeux, un peu plus bas
func point_de_prise(t: Vector3) -> Vector3:
	var d: float = 1.0 + maxf(t.x, t.z) * 0.5
	var p: Vector3 = tete.global_position - tete.global_transform.basis.z * d + Vector3(0.0, -0.25, 0.0)
	p.y = maxf(p.y, 0.3)
	return p


func vise() -> Vector3:
	return -tete.global_transform.basis.z


# ce qu'il a sous les yeux, à portée de main : un meuble, le camion, ou rien
func regard() -> Object:
	var de := tete.global_position
	var q := PhysicsRayQueryParameters3D.create(de, de + vise() * R.PORTEE, R.COUCHE_DECOR | R.COUCHE_OBJETS | R.COUCHE_LEGERS)
	q.exclude = [get_rid()]
	var vu := get_world_3d().direct_space_state.intersect_ray(q)
	return vu.get("collider")


func mourir() -> void:
	vivant = false
	porte = -1
	accroupi = false
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	_mat_corps.albedo_color = Color(0.6, 0.8, 1.0, 0.3)
	_mat_corps.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_corps.emission_enabled = true
	_mat_corps.emission = Color(0.4, 0.6, 0.9)


func _unhandled_input(e: InputEvent) -> void:
	if not local or pilote or principal.etat != principal.PARTIE or principal.tactile.actif:
		return      # (au doigt, c'est scripts/tactile.gd qui mène : un toucher fait aussi un clic, qui ne doit rien prendre)
	var pris := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if e is InputEventMouseMotion:
		# quand la souris vient d'être prise, un navigateur peut annoncer un grand mouvement qui n'a pas eu lieu (le regard partait au
		# ciel) : on laisse passer un quart de seconde, et on ne croit jamais un bond de plus de 300 pixels d'un coup
		if not pris:
			_prise_le = -1
			return
		if _prise_le < 0:
			_prise_le = Time.get_ticks_msec()
		if Time.get_ticks_msec() - _prise_le < 250 or not e.relative.is_finite() or e.relative.length() > 300.0:
			return
		yaw -= e.relative.x * R.SOURIS
		pitch = clampf(pitch - e.relative.y * R.SOURIS, -1.4, 1.4)
	elif e is InputEventMouseButton and e.pressed:
		if not pris:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.button_index == MOUSE_BUTTON_LEFT:
			agir()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			lancer()
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_E:
				agir()
			KEY_F:
				torche_voulue = not torche_voulue
			KEY_V:
				crier()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func lancer() -> void:
	if vivant and porte >= 0:
		principal.vouloir("lacher", [porte, true])


func crier() -> void:
	if vivant:
		_cri = 0.7
		principal.sons.jouer("cri", -4.0)


# la touche d'action : prendre, poser, klaxonner ; mort, pousser
func agir() -> void:
	if vivant and porte >= 0:
		principal.vouloir("lacher", [porte, false])
		return
	var vu = regard()
	if vu == null:
		return
	if vu.has_method("definir_prises"):
		principal.vouloir("prendre" if vivant else "pousser", [vu.id])
	elif vivant and vu.has_meta("klaxon"):
		principal.vouloir("klaxon", [])


func _touche(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


func _physics_process(dt: float) -> void:
	if pilote:
		_regarder(dt)
		return
	if not local:
		global_position = global_position.lerp(cible_pos, minf(1.0, dt * 14.0))
		_regarder(dt)
		return
	var joue: bool = principal.etat == principal.PARTIE
	var doigt = principal.tactile          # le joystick et les boutons d'un écran tactile s'ajoutent au clavier
	var avance := clampf(_touche(KEY_W, KEY_UP) - _touche(KEY_S, KEY_DOWN) - doigt.vecteur.y, -1.0, 1.0) if joue else 0.0
	var cote := clampf(_touche(KEY_D, KEY_RIGHT) - _touche(KEY_A, KEY_LEFT) + doigt.vecteur.x, -1.0, 1.0) if joue else 0.0
	if vivant:
		var pousse := Vector3(cote, 0.0, -avance)
		var dir := (Basis(Vector3.UP, yaw) * pousse).normalized() if pousse.length() > 0.15 else Vector3.ZERO
		accroupi = joue and (Input.is_physical_key_pressed(KEY_CTRL) or doigt.accroupi)
		var court: bool = (Input.is_physical_key_pressed(KEY_SHIFT) or doigt.court) and not accroupi and dir != Vector3.ZERO
		var v: float = R.ACCROUPI if accroupi else (R.COURSE if court else R.MARCHE)
		v *= frein()
		var k := minf(1.0, dt * 12.0)
		velocity.x = lerpf(velocity.x, dir.x * v, k)
		velocity.z = lerpf(velocity.z, dir.z * v, k)
		if is_on_floor():
			if joue and (Input.is_physical_key_pressed(KEY_SPACE) or doigt.saut):
				velocity.y = R.SAUT
		else:
			velocity.y -= R.GRAVITE * dt
		# ses bras tendus le rappellent vers ce qu'il tient
		for a in accroches():
			var e := epaule(a[0])
			var trop: float = e.distance_to(a[1]) - R.BRAS_TENDU
			if trop > 0.0:
				var tire: Vector3 = (a[1] - e).normalized() * trop * R.BRAS_RAPPEL * dt
				velocity.x += tire.x
				velocity.z += tire.z
		var en_l_air := not is_on_floor()
		var lance := Vector2(velocity.x, velocity.z)
		if en_l_air:
			_chute = minf(velocity.y, 0.0)
		move_and_slide()
		# le bruit qu'il fait : ses pas, ses sauts, ce à quoi il se cogne, son cri, et son vrai micro
		var b := 0.0
		_t_heurt = maxf(_t_heurt - dt, 0.0)
		if en_l_air and is_on_floor() and _chute < -2.5:       # il retombe : d'un saut, ou de plus haut
			b = R.BRUIT_SAUT + maxf(-_chute - R.SAUT, 0.0) * R.BRUIT_CHUTE
			principal.vouloir("heurt", [b])
		var perdu := lance.length() - Vector2(velocity.x, velocity.z).length()
		if perdu > R.HEURT_SEUIL and get_slide_collision_count() > 0 and _t_heurt <= 0.0:      # il se cogne : un mur, un meuble
			_t_heurt = 0.4
			b = maxf(b, perdu * R.BRUIT_HEURT)
			principal.vouloir("heurt", [b])
		_chute = 0.0 if is_on_floor() else _chute
		if dir != Vector3.ZERO and is_on_floor():
			b = maxf(b, R.BRUIT_ACCROUPI if accroupi else (R.BRUIT_COURSE if court else R.BRUIT_PAS))
			_pas -= dt * (v / R.MARCHE)
			if _pas <= 0.0:
				_pas = 0.5
				principal.sons.jouer("pas", -22.0 if accroupi else (-8.0 if court else -14.0), randf_range(0.85, 1.15))
		if _cri > 0.0:
			_cri -= dt
			b = maxf(b, R.BRUIT_CRI)
		b = maxf(b, principal.micro.niveau() * R.BRUIT_MICRO)
		bruit = maxf(b, bruit - dt * 14.0)
	else:
		var dir3: Vector3 = tete.global_transform.basis * Vector3(cote, 0.0, -avance)
		velocity = dir3.normalized() * R.FANTOME
		move_and_slide()
		bruit = 0.0
	_regarder(dt)
	_envoi -= dt
	if _envoi <= 0.0 and principal.en_reseau:
		_envoi = 0.05
		etat.rpc(global_position, yaw, pitch, bruit, accroupi, torche_voulue)


# ce qu'il porte le ralentit : sa part du poids
func frein() -> float:
	var o = principal.objets.get(porte)
	if o == null:
		return 1.0
	return 1.0 / (1.0 + o.mass / float(maxi(o.porteurs.size(), 1)) / R.FREIN)


func _regarder(dt: float) -> void:
	if not is_finite(yaw) or not is_finite(pitch):      # (une souris qui rend n'importe quoi ne doit pas éteindre l'écran)
		yaw = 0.0
		pitch = 0.0
	rotation.y = yaw
	tete.rotation.x = pitch
	tete.position.y = lerpf(tete.position.y, R.YEUX_ACCROUPI if accroupi else R.YEUX, minf(1.0, dt * 10.0))
	torche.visible = torche_ok and torche_voulue and vivant


@rpc("authority", "call_remote", "unreliable_ordered")
func etat(p: Vector3, y: float, t: float, b: float, a: bool, lampe: bool) -> void:
	cible_pos = p
	yaw = y
	pitch = clampf(t, -1.4, 1.4)
	bruit = clampf(b, 0.0, R.BRUIT_MICRO)
	accroupi = a
	torche_voulue = lampe
