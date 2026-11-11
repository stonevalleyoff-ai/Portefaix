extends RefCounted
# Portefaix — les règles du jeu, en un seul endroit (scripts/regles.gd)
# Tout ce qui se règle quand on équilibre le jeu est ici : la nuit, le corps, le portage, le bruit, la casse, la chose, le chat, le mobilier.

# le réseau : l'hôte ouvre ce port (UDP), les autres le rejoignent par son adresse
const PORT := 24680
const JOUEURS_MAX := 6
# en ligne : ce qui aide deux joueurs à se trouver à travers leurs box (un serveur STUN public ; il ne voit pas la partie)
const STUN := ["stun:stun.l.google.com:19302"]

# la nuit : dix minutes de 22 h à 6 h ; la chose dort pendant le répit du début
const DUREE_NUIT := 600.0
const REPIT := 60.0
const HAUTEUR := 2.8          # sous plafond ; les portes font 2,2 m

# le corps (mètres, secondes)
const MARCHE := 3.4
const COURSE := 5.6
const ACCROUPI := 1.6
const SAUT := 4.3
const GRAVITE := 12.0
const YEUX := 1.6
const YEUX_ACCROUPI := 1.0
const SOURIS := 0.0025
const FANTOME := 5.0          # la vitesse d'un mort
const FANTOME_MASSE := 12.0   # ce qu'un mort peut pousser, au plus (kg)

# porter : chaque porteur donne au plus cette force ; seul on soulève 45 kg, à deux 90, à trois 135. Le reste se traîne.
const PORTEE := 3.0
const FORCE_PORTEUR := 450.0
const PORT_RAIDEUR := 7.0
const PORT_VITESSE := 5.0
const PORT_GAIN := 10.0
const LANCER := 7.0           # la vitesse donnée à un objet lancé…
const LANCER_MAX := 70.0      # … tant que l'élan ne dépasse pas ça (les lourds tombent aux pieds)
const FREIN := 45.0           # les kilos portés qui divisent la marche par deux

# le bruit : le rayon, en mètres, où la chose l'entend
const BRUIT_ACCROUPI := 1.5
const BRUIT_PAS := 4.0
const BRUIT_COURSE := 11.0
const BRUIT_CRI := 17.0
const BRUIT_MICRO := 18.0     # le vrai micro, à pleine voix
const MICRO_SEUIL := -38.0    # dB : en dessous, le micro ne compte pas
const MICRO_PLEIN := -8.0
const BRUIT_KLAXON := 30.0

# la casse : un choc, c'est la vitesse perdue d'un coup (m/s)
const CHOC_SEUIL := 2.2
const CHOC_PLEIN := 9.0

# la chose
# la chose : elle doit faire peur, pas tuer d'office. On peut passer dans son dos, on a le temps de fuir quand elle crie, on la sème
# en courant ou en sortant de la maison (elle ne passe pas le seuil), et son premier coup blesse sans tuer.
const CHOSE_RODE := 1.5
const CHOSE_ENQUETE := 2.5
const CHOSE_CHASSE := 4.0     # plus vite qu'on ne marche, moins qu'on ne court
const CHOSE_VUE := 9.0
const CHOSE_VUE_ACCROUPI := 0.5
const CHOSE_CONE := 0.4       # elle voit devant elle : le cosinus du demi-angle (66° de chaque côté)…
const CHOSE_PRES := 2.5       # … et sent ce qui est tout près, même dans son dos
const CHOSE_ALERTE := 1.8     # quand elle voit un porteur, elle crie tout ce temps avant de s'élancer
const CHOSE_SOUFFLE := 10.0   # elle ne chasse pas plus longtemps d'une traite
const CHOSE_PERTE := 2.5      # sans voir sa proie tout ce temps, elle renonce
const CHOSE_REPUE := 10.0     # après un coup, elle rentre à sa tanière sans rien regarder
const CHOSE_ALLONGE := 1.2
const BLESSURE := 45.0        # le premier coup blesse ; passé ce temps, on est guéri. Blessé, le coup suivant tue.

# le chat : un vote toutes les 40 secondes, 15 secondes pour voter (1, 2 ou 3)
const VOTE_PAUSE := 40.0
const VOTE_DUREE := 15.0
const SABOTAGES := {
	"noir": {"nom": "Couper le courant", "duree": 25.0},
	"porte": {"nom": "Claquer une porte", "duree": 25.0},
	"vacarme": {"nom": "Faire du vacarme", "duree": 0.0},
	"torches": {"nom": "Griller les torches", "duree": 15.0},
	"plume": {"nom": "Meubles en apesanteur", "duree": 15.0},
}

# le quota : la part de la maison à charger, selon le nombre de porteurs
const QUOTA := 0.25
const QUOTA_PAR_JOUEUR := 0.06
const QUOTA_MAX := 0.6

# les bras : élastiques. Ils s'accrochent à ce qu'on prend, s'étirent, et s'arrachent si l'on tire trop ; puis ils repoussent.
const BRAS_TENDU := 2.1       # au-delà, le bras rougit, et rappelle son porteur vers ce qu'il tient
const BRAS_MAX := 3.3         # au-delà, il s'arrache
const BRAS_REPOUSSE := 8.0    # le temps qu'il met à repousser
const BRAS_RAPPEL := 9.0      # la force du rappel (m/s² par mètre de trop)
const BRAS_ECART := 0.24      # de combien les deux mains s'écartent sur ce qu'elles tiennent

# le mobilier : taille (m ; x le long du mur, y la hauteur, z la profondeur, le devant vers +z), masse (kg), valeur (€),
# fragile (la part de la valeur qu'un grand choc emporte)
const CATALOGUE := {
	"carton": {"nom": "un carton", "taille": Vector3(0.5, 0.4, 0.5), "masse": 5.0, "valeur": 40, "fragile": 0.2, "couleur": Color(0.6, 0.46, 0.28)},
	"panier": {"nom": "un panier à linge", "taille": Vector3(0.42, 0.5, 0.42), "masse": 2.0, "valeur": 20, "fragile": 0.0, "couleur": Color(0.72, 0.62, 0.42)},
	"coussin": {"nom": "un coussin", "taille": Vector3(0.42, 0.14, 0.42), "masse": 0.5, "valeur": 15, "fragile": 0.0, "couleur": Color(0.7, 0.35, 0.3)},
	"chaise": {"nom": "une chaise", "taille": Vector3(0.45, 0.9, 0.45), "masse": 6.0, "valeur": 60, "fragile": 0.3, "couleur": Color(0.45, 0.3, 0.18)},
	"lampe": {"nom": "un lampadaire", "taille": Vector3(0.35, 1.5, 0.35), "masse": 4.0, "valeur": 90, "fragile": 0.7, "couleur": Color(0.75, 0.7, 0.55)},
	"lampe_chevet": {"nom": "une lampe de chevet", "taille": Vector3(0.22, 0.38, 0.22), "masse": 1.5, "valeur": 45, "fragile": 0.8, "couleur": Color(0.8, 0.72, 0.5)},
	"reveil": {"nom": "un réveil", "taille": Vector3(0.14, 0.1, 0.08), "masse": 0.3, "valeur": 25, "fragile": 0.6, "couleur": Color(0.75, 0.2, 0.18)},
	"vase": {"nom": "un vase", "taille": Vector3(0.3, 0.5, 0.3), "masse": 2.0, "valeur": 150, "fragile": 0.95, "couleur": Color(0.55, 0.7, 0.85)},
	"plante": {"nom": "une plante verte", "taille": Vector3(0.4, 1.1, 0.4), "masse": 7.0, "valeur": 55, "fragile": 0.7, "couleur": Color(0.2, 0.45, 0.22)},
	"tableau": {"nom": "un tableau", "taille": Vector3(0.9, 0.7, 0.12), "masse": 4.0, "valeur": 220, "fragile": 0.6, "couleur": Color(0.7, 0.55, 0.2)},
	"miroir": {"nom": "un miroir", "taille": Vector3(0.6, 0.9, 0.08), "masse": 6.0, "valeur": 160, "fragile": 0.95, "couleur": Color(0.55, 0.45, 0.25)},
	"boite_bijoux": {"nom": "une boîte à bijoux", "taille": Vector3(0.24, 0.14, 0.18), "masse": 1.0, "valeur": 420, "fragile": 0.3, "couleur": Color(0.4, 0.12, 0.16)},
	"ordinateur": {"nom": "un ordinateur", "taille": Vector3(0.5, 0.42, 0.2), "masse": 5.0, "valeur": 480, "fragile": 0.85, "couleur": Color(0.12, 0.12, 0.14)},
	"tele": {"nom": "une télé", "taille": Vector3(1.0, 0.65, 0.25), "masse": 10.0, "valeur": 320, "fragile": 0.85, "couleur": Color(0.08, 0.08, 0.1)},
	"micro_ondes": {"nom": "un micro-ondes", "taille": Vector3(0.48, 0.3, 0.36), "masse": 11.0, "valeur": 110, "fragile": 0.6, "couleur": Color(0.82, 0.82, 0.8)},
	"grille_pain": {"nom": "un grille-pain", "taille": Vector3(0.28, 0.2, 0.18), "masse": 1.5, "valeur": 30, "fragile": 0.4, "couleur": Color(0.7, 0.7, 0.72)},
	"casserole": {"nom": "une casserole", "taille": Vector3(0.26, 0.14, 0.26), "masse": 1.2, "valeur": 25, "fragile": 0.1, "couleur": Color(0.5, 0.5, 0.52)},
	"assiettes": {"nom": "une pile d'assiettes", "taille": Vector3(0.26, 0.14, 0.26), "masse": 2.5, "valeur": 70, "fragile": 1.0, "couleur": Color(0.92, 0.9, 0.84)},
	"table_nuit": {"nom": "une table de nuit", "taille": Vector3(0.45, 0.5, 0.4), "masse": 9.0, "valeur": 60, "fragile": 0.3, "couleur": Color(0.42, 0.28, 0.17)},
	"table_basse": {"nom": "une table basse", "taille": Vector3(1.0, 0.4, 0.55), "masse": 14.0, "valeur": 90, "fragile": 0.3, "couleur": Color(0.36, 0.24, 0.15)},
	"meuble_tele": {"nom": "un meuble télé", "taille": Vector3(1.4, 0.5, 0.45), "masse": 28.0, "valeur": 140, "fragile": 0.2, "couleur": Color(0.3, 0.2, 0.13)},
	"table": {"nom": "une table", "taille": Vector3(1.4, 0.75, 0.8), "masse": 35.0, "valeur": 180, "fragile": 0.25, "couleur": Color(0.4, 0.27, 0.16)},
	"bureau": {"nom": "un bureau", "taille": Vector3(1.3, 0.76, 0.65), "masse": 32.0, "valeur": 210, "fragile": 0.25, "couleur": Color(0.33, 0.22, 0.14)},
	"fauteuil": {"nom": "un fauteuil", "taille": Vector3(0.9, 0.9, 0.85), "masse": 25.0, "valeur": 200, "fragile": 0.15, "couleur": Color(0.5, 0.2, 0.2)},
	"commode": {"nom": "une commode", "taille": Vector3(1.0, 0.85, 0.48), "masse": 38.0, "valeur": 230, "fragile": 0.25, "couleur": Color(0.38, 0.25, 0.15)},
	"horloge": {"nom": "une horloge comtoise", "taille": Vector3(0.5, 2.0, 0.4), "masse": 40.0, "valeur": 450, "fragile": 0.6, "couleur": Color(0.35, 0.22, 0.12)},
	"buffet": {"nom": "un buffet", "taille": Vector3(1.5, 0.95, 0.5), "masse": 50.0, "valeur": 320, "fragile": 0.3, "couleur": Color(0.34, 0.21, 0.12)},
	"cuisiniere": {"nom": "une cuisinière", "taille": Vector3(0.6, 0.9, 0.62), "masse": 50.0, "valeur": 280, "fragile": 0.3, "couleur": Color(0.85, 0.85, 0.83)},
	"bibliotheque": {"nom": "une bibliothèque", "taille": Vector3(1.0, 1.9, 0.35), "masse": 55.0, "valeur": 260, "fragile": 0.3, "couleur": Color(0.36, 0.23, 0.13)},
	"canape": {"nom": "un canapé", "taille": Vector3(2.0, 0.85, 0.9), "masse": 60.0, "valeur": 400, "fragile": 0.15, "couleur": Color(0.25, 0.38, 0.35)},
	"lit": {"nom": "un lit", "taille": Vector3(1.5, 0.55, 2.0), "masse": 65.0, "valeur": 380, "fragile": 0.1, "couleur": Color(0.4, 0.27, 0.17)},
	"machine_laver": {"nom": "une machine à laver", "taille": Vector3(0.6, 0.86, 0.6), "masse": 68.0, "valeur": 330, "fragile": 0.4, "couleur": Color(0.9, 0.9, 0.88)},
	"frigo": {"nom": "un frigo", "taille": Vector3(0.7, 1.8, 0.68), "masse": 75.0, "valeur": 420, "fragile": 0.4, "couleur": Color(0.88, 0.89, 0.9)},
	"armoire": {"nom": "une armoire", "taille": Vector3(1.2, 2.0, 0.6), "masse": 80.0, "valeur": 500, "fragile": 0.3, "couleur": Color(0.3, 0.19, 0.1)},
	"piano": {"nom": "un piano", "taille": Vector3(1.5, 1.2, 0.65), "masse": 120.0, "valeur": 900, "fragile": 0.5, "couleur": Color(0.06, 0.06, 0.07)},
}


static func quota(total: int, joueurs: int) -> int:
	var part: float = minf(QUOTA + QUOTA_PAR_JOUEUR * float(maxi(joueurs, 1) - 1), QUOTA_MAX)
	return int(round(float(total) * part / 10.0)) * 10
