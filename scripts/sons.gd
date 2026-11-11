extends Node
# Portefaix — les sons (scripts/sons.gd)
# Tous faits ici, au lancement : du bruit, des sinusoïdes, des enveloppes. Aucun fichier.
# Des sons brefs, joués tels quels ou à un endroit de la maison, et deux boucles : le bourdon de la nuit, le grognement de la chose.

const TAUX := 16000

var _brefs := {}
var _boucles := {}
var _plats: Array = []
var _lieux: Array = []
var _i := 0
var _j := 0
var _r := RandomNumberGenerator.new()
var _bourdon: AudioStreamPlayer


func _ready() -> void:
	_r.seed = 11
	_brefs["pas"] = _wav(_frappe(0.09, 95.0, 0.5))
	_brefs["choc"] = _wav(_frappe(0.28, 70.0, 0.7))
	_brefs["casse"] = _wav(_eclats(0.45))
	_brefs["porte"] = _wav(_frappe(0.4, 48.0, 0.9))
	_brefs["vote"] = _wav(_notes([660.0, 880.0], 0.09, 0.0))
	_brefs["klaxon"] = _wav(_notes([370.0, 370.0, 370.0], 0.22, 466.0))
	_brefs["mort"] = _wav(_chute(0.9))
	_brefs["cri"] = _wav(_chute(0.3, 520.0, 760.0))
	_brefs["hurle"] = _wav(_chute(1.1, 150.0, 430.0))
	_brefs["coeur"] = _wav(_battement())
	_boucles["grogne"] = _wav(_grognement(2.0), true)
	_boucles["bourdon"] = _wav(_nappe(4.0), true)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_plats.append(p)
	for i in 8:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 40.0
		add_child(p)
		_lieux.append(p)
	_bourdon = AudioStreamPlayer.new()
	_bourdon.stream = _boucles["bourdon"]
	_bourdon.volume_db = -16.0
	add_child(_bourdon)


func boucle(nom: String) -> AudioStream:
	return _boucles[nom]


func nuit(oui: bool) -> void:
	if oui and not _bourdon.playing:
		_bourdon.play()
	elif not oui:
		_bourdon.stop()


func jouer(nom: String, volume_db: float = 0.0, hauteur: float = 1.0) -> void:
	var p: AudioStreamPlayer = _plats[_i % _plats.size()]
	_i += 1
	p.stream = _brefs[nom]
	p.volume_db = volume_db
	p.pitch_scale = hauteur
	p.play()


func jouer_a(nom: String, ou: Vector3, volume_db: float = 0.0) -> void:
	var p: AudioStreamPlayer3D = _lieux[_j % _lieux.size()]
	_j += 1
	p.stream = _brefs[nom]
	p.global_position = ou
	p.volume_db = volume_db
	p.play()


# --- la fabrique ---

func _wav(d: PackedFloat32Array, en_boucle: bool = false) -> AudioStreamWAV:
	var o := PackedByteArray()
	o.resize(d.size() * 2)
	for i in d.size():
		o.encode_s16(i * 2, int(clampf(d[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAUX
	w.data = o
	if en_boucle:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = d.size()
	return w


func _vide(duree: float) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(int(duree * TAUX))
	return d


# un coup sourd : une note grave qui s'éteint, et un souffle au début
func _frappe(duree: float, hz: float, souffle: float) -> PackedFloat32Array:
	var d := _vide(duree)
	for i in d.size():
		var t := float(i) / TAUX
		var e := exp(-t * 6.0 / duree)
		d[i] = (sin(TAU * hz * t * (1.0 - t * 0.8)) * 0.8 + _r.randf_range(-1.0, 1.0) * souffle * exp(-t * 60.0)) * e
	return d


# du verre et du bois : des grains de bruit et des tintements
func _eclats(duree: float) -> PackedFloat32Array:
	var d := _vide(duree)
	var tintements := [1900.0, 2700.0, 3500.0, 4300.0]
	for i in d.size():
		var t := float(i) / TAUX
		var v := _r.randf_range(-1.0, 1.0) * exp(-t * 14.0) * 0.7
		for k in tintements.size():
			v += sin(TAU * tintements[k] * t) * exp(-t * (9.0 + k * 4.0)) * 0.12
		d[i] = v
	return d


func _notes(hz: Array, pas: float, avec: float) -> PackedFloat32Array:
	var d := _vide(pas * hz.size())
	for i in d.size():
		var t := float(i) / TAUX
		var k := mini(int(t / pas), hz.size() - 1)
		var dans := t - k * pas
		var e := minf(dans * 80.0, 1.0) * minf((pas - dans) * 40.0, 1.0)
		var v := signf(sin(TAU * hz[k] * t)) * 0.25
		if avec > 0.0:
			v += signf(sin(TAU * avec * t)) * 0.25
		d[i] = v * e
	return d


func _chute(duree: float, de: float = 420.0, vers: float = 60.0) -> PackedFloat32Array:
	var d := _vide(duree)
	var phase := 0.0
	for i in d.size():
		var a := float(i) / d.size()
		phase += lerpf(de, vers, a) / TAUX
		d[i] = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.4 * sin(PI * a)
	return d


func _battement() -> PackedFloat32Array:
	var d := _vide(0.55)
	for i in d.size():
		var t := float(i) / TAUX
		var v := sin(TAU * 52.0 * t) * exp(-t * 22.0)
		if t > 0.24:
			v += sin(TAU * 46.0 * (t - 0.24)) * exp(-(t - 0.24) * 20.0) * 0.8
		d[i] = v * 0.9
	return d


# la gorge de la chose : une dent de scie grave, qui tremble, et un râle
func _grognement(duree: float) -> PackedFloat32Array:
	var d := _vide(duree)
	var grave := 0.0
	for i in d.size():
		var t := float(i) / TAUX
		var scie := fmod(t * 47.0, 1.0) * 2.0 - 1.0
		grave = lerpf(grave, _r.randf_range(-1.0, 1.0), 0.08)
		var tremble := 0.6 + 0.4 * sin(TAU * 7.0 * t) * sin(TAU * 0.5 * t)
		d[i] = (scie * 0.45 + grave * 0.9) * tremble * 0.7
	return d


func _nappe(duree: float) -> PackedFloat32Array:
	var d := _vide(duree)
	for i in d.size():
		var t := float(i) / TAUX
		d[i] = (sin(TAU * 48.0 * t) + sin(TAU * 72.25 * t) * 0.6 + sin(TAU * 96.5 * t) * 0.3) * 0.25 * (0.75 + 0.25 * sin(TAU * 0.25 * t))
	return d
