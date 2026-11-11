#!/usr/bin/env bash
# Portefaix — LANCER GODOT (outils/godot.sh)
# Lance Godot 4.3, la version officielle et seulement elle : la première fois, il la télécharge depuis les versions publiées
# de Godot (github.com/godotengine/godot), vérifie son empreinte (SHA-512, celle que Godot publie), et la garde en cache.
# À chaque lancement, il revérifie l'empreinte du programme avant de le lancer : un programme modifié ne se lance pas.
#   outils/godot.sh --version                                  la version
#   outils/godot.sh --headless --path . --import              tout ce que Godot accepte
#   outils/godot.sh --modeles-web                              installe les modèles d'export web (téléchargés, vérifiés)
# Le cache : $GODOT_CACHE, sinon ~/.cache/portefaix/godot-4.3. Les modèles vont où Godot les cherche.
set -euo pipefail

VERSION=4.3-stable
DEPOT=https://github.com/godotengine/godot/releases/download/$VERSION
ZIP=Godot_v4.3-stable_linux.x86_64.zip
ZIP_SHA512=fd52bb4ba8acc30ca5accd1c566d470ad7282f891ccc0995dfafabcf92bcf76280ce182bf9d80ebd885f3ed2165d01e1fc3f2928436b15498dfbd98656c2a45a
BIN=Godot_v4.3-stable_linux.x86_64
BIN_SHA512=c0ab57f75962a32b35d4a598ca1d669e7408c1ccfe1518d327ff67b9008625b455d3f35720261fe0d8b1d71cf208715fbe1666e5c68565e6dd75438a9786a263
TPZ=Godot_v4.3-stable_export_templates.tpz
TPZ_SHA512=476366caf0fd45a8f24136cf9cf1dc0bc2b96f7c82d53e5f82200b55aefd07b286d283fd6f1ce29e0de70648c5a51d3b12f96c6d4fafd4e8c4878ecda6406d6a

CACHE="${GODOT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/portefaix/godot-4.3}"
MODELES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.3.stable"

dit() { echo "godot.sh : $*" >&2; }
verifie() {   # verifie <fichier> <empreinte attendue>
  local vu; vu=$(sha512sum "$1" | cut -d' ' -f1)
  if [ "$vu" != "$2" ]; then dit "empreinte inattendue pour $(basename "$1") : refusé"; return 1; fi
}
telecharge() {   # telecharge <nom> <destination>
  dit "téléchargement de $1"
  curl -fL --retry 4 --retry-delay 2 -sS -o "$2" "$DEPOT/$1"
}

if [ "${1:-}" = "--modeles-web" ]; then
  if [ -f "$MODELES/web_nothreads_release.zip" ] && [ -f "$MODELES/web_nothreads_debug.zip" ]; then dit "modèles web déjà là ($MODELES)"; exit 0; fi
  mkdir -p "$CACHE" "$MODELES"
  telecharge "$TPZ" "$CACHE/$TPZ"
  verifie "$CACHE/$TPZ" "$TPZ_SHA512" || { rm -f "$CACHE/$TPZ"; exit 1; }
  # (le paquet entier fait 1 Go : on n'en garde que l'export web sans fils d'exécution, celui que lit n'importe quel navigateur)
  unzip -q -o -j "$CACHE/$TPZ" templates/web_nothreads_release.zip templates/web_nothreads_debug.zip templates/version.txt -d "$MODELES"
  rm -f "$CACHE/$TPZ"
  dit "modèles web installés dans $MODELES"
  exit 0
fi

if [ ! -f "$CACHE/$BIN" ]; then
  mkdir -p "$CACHE"
  telecharge "$ZIP" "$CACHE/$ZIP"
  verifie "$CACHE/$ZIP" "$ZIP_SHA512" || { rm -f "$CACHE/$ZIP"; exit 1; }
  unzip -q -o "$CACHE/$ZIP" "$BIN" -d "$CACHE"
  rm -f "$CACHE/$ZIP"
fi
verifie "$CACHE/$BIN" "$BIN_SHA512"
chmod +x "$CACHE/$BIN"
exec "$CACHE/$BIN" "$@"
