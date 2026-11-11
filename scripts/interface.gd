extends CanvasLayer
# Portefaix — ce qui s'écrit à l'écran (scripts/interface.gd)
# Le menu, le salon d'attente, la partie (l'heure, le quota, le bruit qu'on fait, le vote du chat, ce qu'on regarde) et la fin.

const R = preload("res://scripts/regles.gd")

signal seul
signal heberger
signal rejoindre(adresse: String)
signal commencer
signal rejouer
signal quitter
signal connexion(email: String, mot_de_passe: String)
signal deconnexion
signal sans_compte
signal vers_connexion
signal pseudo_choisi(pseudo: String)
signal salon_creer
signal salon_rejoindre(code: String)

var _menu: Control
var _salon: Control
var _partie: Control
var _fin: Control
var _avis: Label
var _adresse: LineEdit
var _chaine: LineEdit
var _micro: CheckBox
var _salon_texte: Label
var _salon_code: Label
var _salon_bouton: Button
var _heure: Label
var _quota: Label
var _bruit: ProgressBar
var _indice: Label
var _annonce: Label
var _annonce_reste := 0.0
var _vote: PanelContainer
var _vote_texte: Label
var _mort: Label
var _fin_texte: Label
var _fin_rejouer: Button
var _aide: Label
var _connexion: Control
var _email: LineEdit
var _mdp: LineEdit
var _connexion_avis: Label
var _connexion_bouton: Button
var _compte_texte: Label
var _compte_bouton: Button
var _pseudo_ligne: HBoxContainer
var _pseudo: LineEdit
var _connecte := false
var _ligne_bloc: VBoxContainer     # jouer en ligne : ouvrir un salon, ou entrer par un code
var _ligne_creer: Button
var _ligne_rang: HBoxContainer
var _ligne_code: LineEdit
var _ligne_note: Label
var _ligne_possible := false
var _b_seul: Button
var _b_entrer: Button
var _b_sans: Button
var _en_ligne: Array = []          # ce qui demande le réseau du dehors : le compte, le chat de Twitch
var _reseau: Array = []           # ce qui sert à jouer à plusieurs, caché dans un navigateur


func _ready() -> void:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)
	_menu = _page(racine)
	_connexion = _page(racine)
	_salon = _page(racine)
	_fin = _page(racine)
	_partie = Control.new()
	_partie.set_anchors_preset(Control.PRESET_FULL_RECT)
	_partie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(_partie)
	_faire_menu()
	_faire_connexion()
	_faire_salon()
	_faire_partie()
	_faire_fin()
	menu("")


func _page(racine: Control) -> Control:
	var voile := ColorRect.new()          # la partie, derrière, s'assombrit
	voile.color = Color(0.01, 0.012, 0.02, 0.72)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.add_child(centre)
	var boite := VBoxContainer.new()
	boite.custom_minimum_size = Vector2(520, 0)
	boite.add_theme_constant_override("separation", 10)
	centre.add_child(boite)
	return boite


func _texte(parent: Control, t: String, corps: int = 18, couleur: Color = Color(0.86, 0.86, 0.82)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", corps)
	l.add_theme_color_override("font_color", couleur)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _bouton(parent: Control, t: String, quoi: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(quoi)
	parent.add_child(b)
	return b


func _faire_menu() -> void:
	_texte(_menu, "PORTEFAIX", 64, Color(1.0, 0.86, 0.5))
	_texte(_menu, "Videz la maison avant l'aube. Ne réveillez pas ce qui y dort.", 20)
	_avis = _texte(_menu, "", 18, Color(1.0, 0.5, 0.4))
	# le compte : qui l'on est, et le pseudo que les autres verront
	var ligne_compte := HBoxContainer.new()
	_menu.add_child(ligne_compte)
	_en_ligne.append(ligne_compte)
	_compte_texte = Label.new()
	_compte_texte.add_theme_font_size_override("font_size", 18)
	_compte_texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compte_texte.clip_text = true
	ligne_compte.add_child(_compte_texte)
	_compte_bouton = _bouton(ligne_compte, "Se connecter", func():
		if _connecte:
			deconnexion.emit()
		else:
			vers_connexion.emit())
	_pseudo_ligne = HBoxContainer.new()
	_menu.add_child(_pseudo_ligne)
	_pseudo = LineEdit.new()
	_pseudo.placeholder_text = "ton pseudo (16 lettres au plus)"
	_pseudo.max_length = 16
	_pseudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pseudo.add_theme_font_size_override("font_size", 18)
	_pseudo_ligne.add_child(_pseudo)
	_bouton(_pseudo_ligne, "Garder ce pseudo", func(): pseudo_choisi.emit(_pseudo.text))
	_b_seul = _bouton(_menu, "Jouer seul", func(): seul.emit())
	_ligne_bloc = VBoxContainer.new()
	_ligne_bloc.add_theme_constant_override("separation", 10)
	_menu.add_child(_ligne_bloc)
	_en_ligne.append(_ligne_bloc)
	_ligne_creer = _bouton(_ligne_bloc, "Ouvrir un salon en ligne (2 à 6 joueurs)", func(): salon_creer.emit())
	_ligne_rang = HBoxContainer.new()
	_ligne_bloc.add_child(_ligne_rang)
	_ligne_code = LineEdit.new()
	_ligne_code.placeholder_text = "le code d'un salon"
	_ligne_code.max_length = 5
	_ligne_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ligne_code.add_theme_font_size_override("font_size", 20)
	_ligne_code.text_changed.connect(func(t: String):
		if t != t.to_upper():
			var ou := _ligne_code.caret_column
			_ligne_code.text = t.to_upper()
			_ligne_code.caret_column = ou)
	_ligne_code.text_submitted.connect(func(t: String): salon_rejoindre.emit(t))
	_ligne_rang.add_child(_ligne_code)
	_b_entrer = _bouton(_ligne_rang, "Entrer dans ce salon", func(): salon_rejoindre.emit(_ligne_code.text))
	_ligne_note = _texte(_ligne_bloc, "", 15, Color(0.6, 0.62, 0.66))
	_reseau.append(_bouton(_menu, "Héberger en réseau local (2 à 6 joueurs)", func(): heberger.emit()))
	var ligne := HBoxContainer.new()
	_menu.add_child(ligne)
	_reseau.append(ligne)
	_adresse = LineEdit.new()
	_adresse.text = "127.0.0.1"
	_adresse.placeholder_text = "l'adresse de l'hôte"
	_adresse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_adresse.add_theme_font_size_override("font_size", 20)
	ligne.add_child(_adresse)
	_bouton(ligne, "Rejoindre", func(): rejoindre.emit(_adresse.text.strip_edges()))
	_chaine = LineEdit.new()
	_chaine.placeholder_text = "ta chaîne Twitch, pour que ton chat vote (facultatif)"
	_chaine.add_theme_font_size_override("font_size", 18)
	_menu.add_child(_chaine)
	_en_ligne.append(_chaine)
	_micro = CheckBox.new()
	_micro.text = "La chose entend mon micro"
	_micro.button_pressed = true
	_micro.add_theme_font_size_override("font_size", 18)
	_menu.add_child(_micro)
	_aide = _texte(_menu, "ZQSD : marcher · Maj : courir (bruyant) · Ctrl : s'accroupir · Espace : sauter\n"
		+ "E ou clic : prendre, poser · clic droit : lancer · F : torche · V : crier · Échap : libérer la souris", 15, Color(0.6, 0.62, 0.66))


func _faire_connexion() -> void:
	_texte(_connexion, "PORTEFAIX", 52, Color(1.0, 0.86, 0.5))
	_texte(_connexion, "Connecte-toi avec ton compte Stone Valley.", 20)
	_email = LineEdit.new()
	_email.placeholder_text = "ton e-mail"
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.add_theme_font_size_override("font_size", 20)
	_connexion.add_child(_email)
	_mdp = LineEdit.new()
	_mdp.placeholder_text = "ton mot de passe"
	_mdp.secret = true
	_mdp.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_mdp.add_theme_font_size_override("font_size", 20)
	_mdp.text_submitted.connect(func(_t): connexion.emit(_email.text, _mdp.text))
	_connexion.add_child(_mdp)
	_connexion_avis = _texte(_connexion, "", 18, Color(1.0, 0.5, 0.4))
	_connexion_bouton = _bouton(_connexion, "Se connecter", func(): connexion.emit(_email.text, _mdp.text))
	_b_sans = _bouton(_connexion, "Jouer sans compte", func(): sans_compte.emit())
	_texte(_connexion, "Pas encore de compte ? Il se crée dans Stone Valley.\nTon mot de passe n'est pas gardé sur cet appareil.", 15, Color(0.6, 0.62, 0.66))


func _faire_salon() -> void:
	_texte(_salon, "Le salon", 40, Color(1.0, 0.86, 0.5))
	_salon_code = _texte(_salon, "", 54, Color(1.0, 0.95, 0.8))     # le code d'un salon en ligne, en grand : c'est lui qu'on dicte
	_salon_texte = _texte(_salon, "", 20)
	_salon_bouton = _bouton(_salon, "Commencer la nuit", func(): commencer.emit())
	_bouton(_salon, "Retour", func(): quitter.emit())


func _faire_fin() -> void:
	_fin_texte = _texte(_fin, "", 26)
	_fin_rejouer = _bouton(_fin, "Une autre maison", func(): rejouer.emit())
	_bouton(_fin, "Retour au menu", func(): quitter.emit())


func _faire_partie() -> void:
	_heure = _coin(Control.PRESET_CENTER_TOP, Vector2(-100, 12), Vector2(200, 40), 30)
	_quota = _coin(Control.PRESET_TOP_LEFT, Vector2(18, 12), Vector2(420, 60), 22)
	_quota.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_annonce = _coin(Control.PRESET_CENTER_TOP, Vector2(-400, 70), Vector2(800, 70), 24)
	_annonce.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	var viseur := _coin(Control.PRESET_CENTER, Vector2(-10, -14), Vector2(20, 28), 20)
	viseur.text = "+"
	_indice = _coin(Control.PRESET_CENTER, Vector2(-400, 30), Vector2(800, 60), 18)
	_mort = _coin(Control.PRESET_CENTER_BOTTOM, Vector2(-400, -120), Vector2(800, 60), 20)
	_mort.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	var etiquette := _coin(Control.PRESET_BOTTOM_LEFT, Vector2(18, -64), Vector2(260, 24), 16)
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	etiquette.text = "le bruit que tu fais"
	_bruit = ProgressBar.new()
	_bruit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bruit.position += Vector2(18, -38)
	_bruit.custom_minimum_size = Vector2(260, 18)
	_bruit.size = Vector2(260, 18)
	_bruit.max_value = R.BRUIT_MICRO
	_bruit.show_percentage = false
	_partie.add_child(_bruit)
	_vote = PanelContainer.new()
	_vote.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vote.position += Vector2(-378, 150)
	_vote.custom_minimum_size = Vector2(360, 0)
	_partie.add_child(_vote)
	_vote_texte = Label.new()
	_vote_texte.add_theme_font_size_override("font_size", 18)
	_vote.add_child(_vote_texte)


func _coin(ancre: int, ou: Vector2, t: Vector2, corps: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(ancre)
	l.position += ou
	l.custom_minimum_size = t
	l.size = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", corps)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_partie.add_child(l)
	return l


func _montrer(page: Control) -> void:
	for p in [_menu, _connexion, _salon, _fin]:
		p.get_parent().get_parent().visible = p == page
	_partie.visible = page == _partie


# dans un navigateur, on joue seul : pas de port à ouvrir, et le micro attend qu'on le demande
func passer_au_navigateur() -> void:
	for c in _reseau:
		c.visible = false
	_micro.button_pressed = false
	_aide.text += "\nDans un navigateur, on joue seul. À plusieurs : la version de bureau (Godot 4.3)."


# sur une page qui ne laisse rien sortir vers le réseau : ni compte, ni chat de Twitch
func passer_hors_ligne() -> void:
	for c in _en_ligne:
		c.visible = false
	_aide.text += "\nSur cette page, on joue sans compte et sans chat : elle ne laisse pas le jeu joindre le réseau."


func passer_au_tactile() -> void:
	_micro.button_pressed = false
	_aide.text = "Le pouce gauche marche, le droit regarde en glissant.\nAgir : prendre, poser, klaxonner · Courir (bruyant) et Bas restent enfoncés."


# où sont les boutons et les champs qu'on voit, en pixels de la fenêtre : pour qu'un essai dans un navigateur clique au bon endroit
func reperes() -> Dictionary:
	var vers := get_viewport().get_screen_transform()
	var r := {}
	var choses := {"email": _email, "mdp": _mdp, "connecter": _connexion_bouton, "sans_compte": _b_sans, "seul": _b_seul, "ouvrir": _ligne_creer, "code": _ligne_code,
		"entrer": _b_entrer, "commencer": _salon_bouton}
	for nom in choses:
		var c: Control = choses[nom]
		if c.is_visible_in_tree():
			var p: Vector2 = vers * c.get_global_rect().get_center()
			r[nom] = [int(p.x), int(p.y)]
	return r


# --- les écrans ---

func menu(avis: String) -> void:
	_avis.text = avis
	_avis.visible = avis != ""
	_montrer(_menu)


func page_connexion() -> void:
	_montrer(_connexion)


# l'état du compte, redit aux deux écrans qui en parlent
func compte(connecte: bool, nom: String, occupe: bool, erreur: String) -> void:
	_connecte = connecte
	_connexion_avis.text = "On frappe à la porte…" if occupe else erreur
	_connexion_avis.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82) if occupe else Color(1.0, 0.5, 0.4))
	_connexion_bouton.disabled = occupe
	_compte_texte.text = ("Connecté : %s" % nom) if connecte else "Sans compte"
	_compte_bouton.text = "Se déconnecter" if connecte else "Se connecter"
	_compte_bouton.disabled = occupe
	_pseudo_ligne.visible = connecte
	_en_ligne_maj()
	if connecte:
		_mdp.text = ""
		if not _pseudo.has_focus():
			_pseudo.text = nom if nom != "Porteur" else ""


# jouer en ligne demande un compte, et de quoi relier les joueurs (tous les navigateurs l'ont)
func en_ligne(possible: bool) -> void:
	_ligne_possible = possible
	_en_ligne_maj()


func _en_ligne_maj() -> void:
	var ouvert := _ligne_possible and _connecte
	_ligne_creer.visible = ouvert
	_ligne_rang.visible = ouvert
	_ligne_note.visible = not ouvert
	_ligne_note.text = "Pour jouer en ligne : connecte-toi." if _ligne_possible else "Le jeu en ligne (salon et code) se joue dans un navigateur."


func salon(t: String, hote: bool, code: String = "") -> void:
	_salon_code.text = "  ".join(code.split(""))
	_salon_code.visible = code != ""
	_salon_texte.text = t
	_salon_bouton.visible = hote
	_montrer(_salon)


func partie() -> void:
	_annonce.text = ""
	_mort.text = ""
	_vote.visible = false
	_montrer(_partie)


func fin(t: String, hote: bool) -> void:
	_fin_texte.text = t
	_fin_rejouer.visible = hote
	_montrer(_fin)


func chaine() -> String:
	return _chaine.text


func micro() -> bool:
	return _micro.button_pressed


# --- pendant la partie ---

func annoncer(t: String, duree: float = 4.0) -> void:
	_annonce.text = t
	_annonce_reste = duree


func mort(t: String) -> void:
	_mort.text = t


func dire(temps: float, charge: int, quota: int, bruit: float, indice: String) -> void:
	# la nuit va de 22 h à 6 h
	var minutes := int((1.0 - clampf(temps / R.DUREE_NUIT, 0.0, 1.0)) * 480.0)
	_heure.text = "%02d:%02d" % [(22 + minutes / 60) % 24, minutes % 60]
	_heure.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if temps < 60.0 else Color(0.9, 0.9, 0.86))
	_quota.text = "Chargé : %d € / %d €" % [charge, quota]
	_quota.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55) if charge >= quota else Color(0.9, 0.9, 0.86))
	_bruit.value = bruit
	_indice.text = indice


func vote(ouvert: bool, options: Array, voix: Array, reste: float) -> void:
	_vote.visible = ouvert
	if not ouvert:
		return
	var t := "LE CHAT VOTE — %d s\n" % int(ceil(maxf(reste, 0.0)))
	for i in options.size():
		t += "%d. %s  (%d)\n" % [i + 1, R.SABOTAGES[options[i]].nom, voix[i]]
	_vote_texte.text = t.strip_edges()


func _process(dt: float) -> void:
	if _annonce_reste > 0.0:
		_annonce_reste -= dt
		if _annonce_reste <= 0.0:
			_annonce.text = ""
