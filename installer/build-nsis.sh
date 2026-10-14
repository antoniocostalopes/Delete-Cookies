#!/usr/bin/env bash
# Builds dist/DeleteCookies-Setup-<version>.exe from macOS or Linux.
#   macOS: brew install makensis     Linux: apt install nsis
set -euo pipefail
cd "$(dirname "$0")"
command -v makensis >/dev/null || { echo "makensis nao encontrado (brew install makensis)"; exit 1; }
mkdir -p dist
makensis DeleteCookies.nsi
echo
echo "Instalador em: $(pwd)/dist"
