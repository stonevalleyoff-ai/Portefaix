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
signal creation(email: String, mot_de_passe: String, pseudo: String)
signal oubli(email: String)
signal nouveau_mot_de_passe(nouveau: String, encore: String)
signal page_compte                 # on change de page de compte : ce qui était écrit ne vaut plus
signal salon_creer
signal salon_rejoindre(code: String)
signal vers_boutique
signal lieu_change
signal achat(nom: String)

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
var _trouble: ColorRect
var _fin_defile: ScrollContainer
var _b_partir: Button
var _b_lieu: Button
var _dose: Label
var _vert: ColorRect
var _screamer: Control
var _screamer_face: Control
var _screamer_gueule: Control
var _screamer_reste := 0.0
var _boutique: Control
var _boutique_lignes: VBoxContainer
var _boutique_caisse: Label
var _boutique_avis: Label
var _boutique_boutons := {}
var _b_boutique: Button
var _bourse_texte: Label
var _fin_compte: Label
var _connexion: Control
var _creation: Control
var _oubli: Control
var _nouveau: Control
var _avis_compte: Array = []      # la ligne d'avis de chaque page de compte : la même partout
var _c: Dictionary = {}           # les champs et les boutons des pages de compte, par leur nom
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
	_creation = _page(racine)
	_oubli = _page(racine)
	_nouveau = _page(racine)
	_salon = _page(racine)
	_fin = _page(racine)
	_boutique = _page(racine)
	_partie = Control.new()
	_partie.set_anchors_preset(Control.PRESET_FULL_RECT)
	_partie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(_partie)
	_faire_menu()
	_faire_connexion()
	_faire_comptes()
	_faire_salon()
	_faire_partie()
	_faire_fin()
	_faire_boutique()
	_faire_screamer(racine)
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
	_texte(_menu, "Videz le manoir avant l'aube. Ne réveillez pas ce qui y dort.", 20)
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
	# la caisse, et la boutique
	var ligne_bourse := HBoxContainer.new()
	_menu.add_child(ligne_bourse)
	_bourse_texte = Label.new()
	_bourse_texte.add_theme_font_size_override("font_size", 18)
	_bourse_texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne_bourse.add_child(_bourse_texte)
	_b_boutique = _bouton(ligne_bourse, "La boutique", func(): vers_boutique.emit())
	_b_lieu = _bouton(_menu, "", func(): lieu_change.emit())
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
		+ "E ou clic : prendre, poser · clic droit : lancer · F : torche (le fantôme la voit de loin) · V : crier · G : lancer un réveil · Échap : libérer la souris", 15, Color(0.6, 0.62, 0.66))


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
	_avis_compte.append(_connexion_avis)
	_connexion_bouton = _bouton(_connexion, "Se connecter", func(): connexion.emit(_email.text, _mdp.text))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	_connexion.add_child(ligne)
	_c["vers_creer"] = _bouton(ligne, "Créer un compte", func(): _vers(_creation))
	_c["vers_oubli"] = _bouton(ligne, "Mot de passe oublié ?", func(): _vers(_oubli))
	for b in ligne.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_b_sans = _bouton(_connexion, "Jouer sans compte", func(): sans_compte.emit())
	_texte(_connexion, "C'est le même compte que dans Stone Valley. Ton mot de passe n'est pas gardé sur cet appareil.", 15, Color(0.6, 0.62, 0.66))


func _champ(parent: Control, nom: String, invite: String, secret: bool = false, clavier: int = LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	var c := LineEdit.new()
	c.placeholder_text = invite
	c.secret = secret
	c.virtual_keyboard_type = clavier
	c.add_theme_font_size_override("font_size", 20)
	parent.add_child(c)
	_c[nom] = c
	return c


# créer un compte ; mot de passe oublié ; choisir un nouveau mot de passe (quand on arrive par le lien de l'e-mail)
func _faire_comptes() -> void:
	_texte(_creation, "Créer un compte", 40, Color(1.0, 0.86, 0.5))
	_texte(_creation, "Il te servira aussi dans Stone Valley.", 18)
	var pseudo := _champ(_creation, "c_pseudo", "ton pseudo (16 lettres au plus)")
	pseudo.max_length = 16
	var email := _champ(_creation, "c_email", "ton e-mail", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	var mdp := _champ(_creation, "c_mdp", "un mot de passe (6 caractères au moins)", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	mdp.text_submitted.connect(func(_t): creation.emit(email.text, mdp.text, pseudo.text))
	_avis_compte.append(_texte(_creation, "", 18))
	_c["c_creer"] = _bouton(_creation, "Créer mon compte", func(): creation.emit(email.text, mdp.text, pseudo.text))
	_c["c_retour"] = _bouton(_creation, "Retour", func(): _vers(_connexion))

	_texte(_oubli, "Mot de passe oublié", 40, Color(1.0, 0.86, 0.5))
	_texte(_oubli, "Donne l'e-mail de ton compte : tu y recevras un lien pour en choisir un nouveau.", 18)
	var o_email := _champ(_oubli, "o_email", "ton e-mail", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	o_email.text_submitted.connect(func(t): oubli.emit(t))
	_avis_compte.append(_texte(_oubli, "", 18))
	_c["o_envoyer"] = _bouton(_oubli, "Envoyer le lien", func(): oubli.emit(o_email.text))
	_c["o_retour"] = _bouton(_oubli, "Retour", func(): _vers(_connexion))

	_texte(_nouveau, "Nouveau mot de passe", 40, Color(1.0, 0.86, 0.5))
	var n1 := _champ(_nouveau, "n_mdp", "ton nouveau mot de passe (6 caractères au moins)", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	var n2 := _champ(_nouveau, "n_encore", "encore une fois", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	n2.text_submitted.connect(func(_t): nouveau_mot_de_passe.emit(n1.text, n2.text))
	_avis_compte.append(_texte(_nouveau, "", 18))
	_c["n_valider"] = _bouton(_nouveau, "Enregistrer", func(): nouveau_mot_de_passe.emit(n1.text, n2.text))


# d'une page de compte à l'autre : l'e-mail déjà tapé suit, les avis s'effacent
func _vers(page: Control) -> void:
	if page == _creation and _c["c_email"].text == "":
		_c["c_email"].text = _email.text
	if page == _oubli and _c["o_email"].text == "":
		_c["o_email"].text = _email.text
	page_compte.emit()
	_montrer(page)


func _faire_salon() -> void:
	_texte(_salon, "Le salon", 40, Color(1.0, 0.86, 0.5))
	_salon_code = _texte(_salon, "", 54, Color(1.0, 0.95, 0.8))     # le code d'un salon en ligne, en grand : c'est lui qu'on dicte
	_salon_texte = _texte(_salon, "", 20)
	_salon_bouton = _bouton(_salon, "Commencer la nuit", func(): commencer.emit())
	_bouton(_salon, "Retour", func(): quitter.emit())


func _faire_boutique() -> void:
	_texte(_boutique, "La boutique", 40, Color(1.0, 0.86, 0.5))
	_boutique_caisse = _texte(_boutique, "", 22)
	_boutique_avis = _texte(_boutique, "", 17, Color(1.0, 0.5, 0.4))
	_boutique_lignes = VBoxContainer.new()
	_boutique_lignes.add_theme_constant_override("separation", 8)
	_boutique.add_child(_boutique_lignes)
	_boutique_boutons["retour_boutique"] = _bouton(_boutique, "Retour", func(): quitter.emit())


# la boutique, pour cette caisse : chaque article, son prix, ce qu'il fait, et s'il l'a déjà
func boutique(bourse, avis: String = "") -> void:
	_boutique_caisse.text = bourse.dire()
	_boutique_caisse.add_theme_color_override("font_color", Color(0.86, 0.86, 0.82) if bourse.argent >= 0 else Color(1.0, 0.45, 0.35))
	_boutique_avis.text = avis
	_boutique_avis.visible = avis != ""
	for c in _boutique_lignes.get_children():
		_boutique_lignes.remove_child(c)
		c.queue_free()
	var retour: Button = _boutique_boutons["retour_boutique"]
	_boutique_boutons = {"retour_boutique": retour}
	for nom in R.BOUTIQUE:
		var article: Dictionary = R.BOUTIQUE[nom]
		var ligne := HBoxContainer.new()
		_boutique_lignes.add_child(ligne)
		var l := Label.new()
		var a := ""
		if bourse.a(nom):
			a = "  (tu en as %d)" % bourse.combien(nom) if article.une_fois else "  (acquis)"
		l.text = "%s — %d €%s\n%s" % [article.nom, article.prix, a, article.dit]
		l.add_theme_font_size_override("font_size", 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(l)
		var b := _bouton(ligne, "Acheter", func(): achat.emit(nom))
		b.disabled = bourse.argent < article.prix or (bourse.a(nom) and not article.une_fois) or bourse.combien(nom) >= R.STOCK_MAX
		_boutique_boutons["achat_" + nom] = b
	_montrer(_boutique)


# au menu : ce qu'il a en caisse, ou ce qu'il doit
func bourse(t: String, dette: bool) -> void:
	_bourse_texte.text = t
	_bourse_texte.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if dette else Color(0.86, 0.86, 0.82))


func _faire_fin() -> void:
	_fin_texte = _texte(_fin, "", 22)
	# les boutons d'abord, toujours à l'écran ; la facture dessous, dans un cadre qui défile si elle est longue
	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 12)
	_fin.add_child(boutons)
	_fin_rejouer = _bouton(boutons, "Une autre maison", func(): rejouer.emit())
	_bouton(boutons, "Retour au menu", func(): quitter.emit())
	_fin_defile = ScrollContainer.new()
	_fin_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fin.add_child(_fin_defile)
	_fin_compte = _texte(_fin_defile, "", 15, Color(0.8, 0.8, 0.76))
	_fin_compte.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# la peur bleue : tout l'écran se dédouble, ondule, bleuit, et se referme sur les bords
const TROUBLE := """
shader_type canvas_item;
uniform sampler2D ecran : hint_screen_texture, filter_linear;
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec2 d = vec2(sin(t * 9.0 + uv.y * 30.0), cos(t * 7.0 + uv.x * 26.0)) * 0.004;
	vec3 c = texture(ecran, uv + d).rgb * 0.34;
	c += texture(ecran, uv - d * 2.0 + vec2(0.007, 0.0)).rgb * 0.22;
	c += texture(ecran, uv + d * 2.0 - vec2(0.007, 0.0)).rgb * 0.22;
	c += texture(ecran, uv + vec2(0.0, 0.008)).rgb * 0.11;
	c += texture(ecran, uv - vec2(0.0, 0.008)).rgb * 0.11;
	float gris = dot(c, vec3(0.3, 0.6, 0.1));
	c = mix(c, vec3(gris * 0.7, gris * 0.88, gris * 1.3), 0.5);
	float bord = smoothstep(0.3, 0.8, distance(uv, vec2(0.5)));
	c *= 1.0 - bord * 0.75 * (0.8 + 0.2 * sin(t * 5.0));
	COLOR = vec4(c, 1.0);
}
"""


# le screamer : quand le fantôme vous attrape, sa face vous saute au visage, d'un coup, et hurle
const SCREAMER := 0.85            # sa durée, en secondes

func _faire_screamer(racine: Control) -> void:
	_screamer = Control.new()
	_screamer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screamer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screamer.visible = false
	racine.add_child(_screamer)            # (en dernier : par-dessus tout)
	var noir := ColorRect.new()
	noir.color = Color(0.0, 0.0, 0.0, 0.93)
	noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screamer.add_child(noir)
	_screamer_face = Control.new()         # une face de 400 sur 560, dessinée autour de son milieu
	_screamer_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screamer.add_child(_screamer_face)
	var os := Color(0.8, 0.79, 0.72)
	var creux := Color(0.03, 0.02, 0.02)
	var sang := Color(1.0, 0.1, 0.05)
	var morceaux := [
		[Rect2(-170, -280, 340, 300), os], [Rect2(-200, -220, 400, 200), os], [Rect2(-130, 0, 260, 120), os.darkened(0.12)],      # le crâne, les pommettes
		[Rect2(-150, -150, 110, 120), creux], [Rect2(40, -150, 110, 120), creux],                                                    # les orbites
		[Rect2(-118, -112, 44, 44), sang], [Rect2(74, -112, 44, 44), sang], [Rect2(-104, -98, 16, 16), Color(1, 0.9, 0.6)], [Rect2(88, -98, 16, 16), Color(1, 0.9, 0.6)],
		[Rect2(-22, -20, 18, 50), creux], [Rect2(4, -20, 18, 50), creux],                                                            # le nez
		[Rect2(-200, -60, 30, 220), os.darkened(0.3)], [Rect2(170, -60, 30, 220), os.darkened(0.3)],                                  # des mèches
	]
	for m in morceaux:
		_morceau(_screamer_face, m[0], m[1])
	_screamer_gueule = Control.new()       # la gueule : elle s'ouvre
	_screamer_gueule.position = Vector2(0, 60)
	_screamer_gueule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screamer_face.add_child(_screamer_gueule)
	_morceau(_screamer_gueule, Rect2(-110, 0, 220, 200), creux)
	_morceau(_screamer_gueule, Rect2(-60, 60, 120, 120), Color(0.35, 0.02, 0.03))
	for k in 7:                            # les dents, en haut et en bas
		_morceau(_screamer_gueule, Rect2(-104 + k * 30, 0, 22, 34 + (k % 2) * 14), os)
		_morceau(_screamer_gueule, Rect2(-104 + k * 30, 200 - 30 - (k % 3) * 8, 22, 30 + (k % 3) * 8), os.darkened(0.1))


func _morceau(parent: Control, r: Rect2, c: Color) -> void:
	var m := ColorRect.new()
	m.color = c
	m.position = r.position
	m.size = r.size
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)


func screamer() -> void:
	_screamer_reste = SCREAMER
	_screamer.visible = true
	_animer_screamer()


func _animer_screamer() -> void:
	var a := 1.0 - _screamer_reste / SCREAMER          # de 0 à 1
	var ecran := get_viewport().get_visible_rect().size
	var grandeur := ecran.y / 560.0 * lerpf(0.7, 2.4, 1.0 - pow(1.0 - a, 3.0))      # elle arrive très vite, puis vous colle
	_screamer_face.scale = Vector2(grandeur, grandeur)
	_screamer_face.position = ecran * 0.5 + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 16.0 * (1.0 - a) + Vector2(0, 40.0 * grandeur)
	_screamer_face.rotation = randf_range(-0.05, 0.05)
	_screamer_gueule.scale = Vector2(1.0, lerpf(0.5, 1.25, minf(1.0, a * 4.0)))
	_screamer.modulate.a = 1.0 if a < 0.75 else (1.0 - a) / 0.25


# où l'on joue : le bouton du menu passe de l'un à l'autre
func lieu(nom: String) -> void:
	_b_lieu.text = "Lieu : le bunker (plusieurs créatures, des radiations) — changer" if nom == "bunker" else "Lieu : le manoir hanté — changer"


# la dose de radiations : un compteur, et l'écran qui verdit
func dose(d: float, rayonne: float, au_bunker: bool) -> void:
	_dose.visible = au_bunker
	_dose.text = "Dose : %d %%%s" % [int(d * 100.0), "   ☢ zone radioactive" if rayonne > 0.0 else ""]
	_dose.add_theme_color_override("font_color", Color(0.9, 0.9, 0.86).lerp(Color(0.4, 1.0, 0.3), clampf(d * 1.5 + rayonne * 0.4, 0.0, 1.0)))
	_vert.visible = d > 0.02 or rayonne > 0.0
	_vert.color = Color(0.25, 1.0, 0.2, clampf(d * 0.3 + rayonne * 0.06, 0.0, 0.36))


func trouble(oui: bool) -> void:
	_trouble.visible = oui


func _faire_partie() -> void:
	_trouble = ColorRect.new()             # (avant tout le reste : l'heure et le quota restent nets par-dessus)
	_trouble.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trouble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ombre := Shader.new()
	ombre.code = TROUBLE
	var voile := ShaderMaterial.new()
	voile.shader = ombre
	_trouble.material = voile
	_trouble.visible = false
	_partie.add_child(_trouble)
	_vert = ColorRect.new()
	_vert.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vert.visible = false
	_partie.add_child(_vert)
	_dose = _coin(Control.PRESET_TOP_LEFT, Vector2(18, 44), Vector2(420, 30), 18)
	_dose.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dose.visible = false
	_heure = _coin(Control.PRESET_CENTER_TOP, Vector2(-100, 12), Vector2(200, 40), 30)
	_quota = _coin(Control.PRESET_TOP_LEFT, Vector2(18, 12), Vector2(420, 60), 22)
	_quota.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_annonce = _coin(Control.PRESET_CENTER_TOP, Vector2(-400, 70), Vector2(800, 70), 24)
	_annonce.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	var viseur := _coin(Control.PRESET_CENTER, Vector2(-10, -14), Vector2(20, 28), 20)
	viseur.text = "+"
	_indice = _coin(Control.PRESET_CENTER, Vector2(-400, 30), Vector2(800, 60), 18)
	_b_partir = Button.new()
	_b_partir.text = "Quitter la partie"
	_b_partir.add_theme_font_size_override("font_size", 18)
	_b_partir.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_b_partir.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_b_partir.position += Vector2(-16, 14)
	_b_partir.visible = false
	_b_partir.pressed.connect(func(): quitter.emit())
	_partie.add_child(_b_partir)
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
	for p in [_menu, _connexion, _creation, _oubli, _nouveau, _salon, _fin, _boutique]:
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
		"entrer": _b_entrer, "commencer": _salon_bouton, "boutique": _b_boutique, "lieu": _b_lieu, "partir": _b_partir}
	for nom in _boutique_boutons:
		choses[nom] = _boutique_boutons[nom]
	for nom in _c:
		choses[nom] = _c[nom]
	for nom in choses:
		var c: Control = choses[nom]
		if c.is_visible_in_tree():
			var p: Vector2 = vers * c.get_global_rect().get_center()
			r[nom] = [int(p.x), int(p.y)]
	return r


# --- les écrans ---

# la version du jeu, en petit, en bas à droite de tous les écrans : on sait laquelle on a sous les yeux
func version(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.position += Vector2(-10, -6)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


func menu(avis: String) -> void:
	_avis.text = avis
	_avis.visible = avis != ""
	_montrer(_menu)


func page_connexion() -> void:
	_montrer(_connexion)


func page_nouveau_mot_de_passe() -> void:
	_montrer(_nouveau)


# une page de compte est-elle à l'écran ?
func sur_un_compte() -> bool:
	return _connexion.is_visible_in_tree() or _creation.is_visible_in_tree() or _oubli.is_visible_in_tree() or _nouveau.is_visible_in_tree()


# l'état du compte, redit aux deux écrans qui en parlent
func compte(connecte: bool, nom: String, occupe: bool, erreur: String, avis: String = "") -> void:
	_connecte = connecte
	for l in _avis_compte:         # la même ligne sur chaque page de compte : on attend, ça a marché, ou ce qui n'a pas marché
		l.text = "On frappe à la porte…" if occupe else (erreur if erreur != "" else avis)
		l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82) if occupe else (Color(1.0, 0.5, 0.4) if erreur != "" else Color(0.6, 0.95, 0.6)))
	for nom_bouton in ["c_creer", "o_envoyer", "n_valider"]:
		_c[nom_bouton].disabled = occupe
	_connexion_bouton.disabled = occupe
	_compte_texte.text = ("Connecté : %s" % nom) if connecte else "Sans compte"
	_compte_bouton.text = "Se déconnecter" if connecte else "Se connecter"
	_compte_bouton.disabled = occupe
	_pseudo_ligne.visible = connecte
	_en_ligne_maj()
	if connecte:
		_mdp.text = ""
		for champ in ["c_mdp", "n_mdp", "n_encore"]:
			_c[champ].text = ""
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
	_trouble.visible = false
	_b_partir.visible = false
	_annonce.text = ""
	_mort.text = ""
	_vote.visible = false
	_montrer(_partie)


func fin(t: String, hote: bool, compte_: String = "") -> void:
	_fin_texte.text = t
	_fin_compte.text = compte_
	_fin_defile.visible = compte_ != ""
	# la facture prend ce qu'il reste de l'écran, pas plus : au-delà, elle défile
	var ecran := get_viewport().get_visible_rect().size
	_fin_compte.custom_minimum_size.x = minf(520.0, ecran.x - 40.0)
	_fin_defile.custom_minimum_size = Vector2(minf(540.0, ecran.x - 24.0), clampf(ecran.y - 300.0, 90.0, 360.0))
	_fin_defile.scroll_vertical = 0
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


# mort, on peut partir : un bouton, en haut à droite (la partie continue pour les autres)
func peut_partir(oui: bool) -> void:
	_b_partir.visible = oui


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
	if _screamer_reste > 0.0:
		_screamer_reste -= dt
		if _screamer_reste <= 0.0:
			_screamer.visible = false
		else:
			_animer_screamer()
	if _annonce_reste > 0.0:
		_annonce_reste -= dt
		if _annonce_reste <= 0.0:
			_annonce.text = ""
