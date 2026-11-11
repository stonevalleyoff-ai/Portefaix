#!/usr/bin/env bash
# Portefaix — CONSTRUIRE L'APPLICATION WEB (outils/construire.sh)
# Exporte le jeu pour un navigateur, en application installable (PWA), dans site/ : c'est ce dossier que GitHub Pages publie.
#   outils/construire.sh [dossier]        (site/ par défaut)
set -euo pipefail
cd "$(dirname "$0")/.."
SITE="${1:-site}"
outils/godot.sh --modeles-web
outils/godot.sh --headless --path . --import > /dev/null 2>&1 || true
rm -rf "$SITE" && mkdir -p "$SITE"
outils/godot.sh --headless --path . --export-release Web "$(cd "$SITE" && pwd)/index.html" 2>&1 | grep -v -e 'Parameter "m" is null' -e 'mesh_get_surface_count' -e 'savepack' || true
# (un export à moitié fait n'est pas publié)
test -s "$SITE/index.wasm" && test -s "$SITE/index.pck" && test -s "$SITE/index.service.worker.js"
node outils/pwa.js "$SITE"
touch "$SITE/.nojekyll"
du -sh "$SITE" | sed 's/^/  le site : /'
