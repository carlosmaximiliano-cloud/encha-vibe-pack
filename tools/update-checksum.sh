#!/usr/bin/env bash
# tools/update-checksum.sh — calcula o SHA-256 do tarball da TAG publicada no
# GitHub e grava em install.sh (variável ENCHA_TARBALL_SHA256) e em checksums.txt.
#
# Use DEPOIS de criar e enviar a tag (git tag vX.Y.Z && git push --tags).
#
# Uso:
#   tools/update-checksum.sh [<tag>]
# Ex.: tools/update-checksum.sh v0.1.0

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${ENCHA_REPO:-carlosmaximiliano-cloud/encha-vibe-pack}"
REF="${1:-$(grep -E '^ENCHA_REF=' "$ROOT/install.sh" | sed -E 's/.*:-([^}]*)\}.*/\1/' | head -n1)}"
REF="${REF:-v$(cat "$ROOT/VERSION")}"

url="https://codeload.github.com/${REPO}/tar.gz/refs/tags/${REF}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo "Baixando $url"
curl -fsSL "$url" -o "$tmp/t.tar.gz"

if command -v shasum >/dev/null 2>&1; then
  sha="$(shasum -a 256 "$tmp/t.tar.gz" | awk '{print $1}')"
else
  sha="$(sha256sum "$tmp/t.tar.gz" | awk '{print $1}')"
fi
echo "SHA-256: $sha"

# Atualiza install.sh (linha ENCHA_TARBALL_SHA256=...).
tmpfile="$tmp/install.sh"
sed -E "s|^ENCHA_TARBALL_SHA256=.*|ENCHA_TARBALL_SHA256=\"\${ENCHA_TARBALL_SHA256:-$sha}\"     # SHA-256 do tarball ($REF)|" \
  "$ROOT/install.sh" > "$tmpfile"
mv "$tmpfile" "$ROOT/install.sh"
echo "install.sh atualizado."

# Gera checksums.txt.
printf '%s  encha-vibe-pack-%s.tar.gz\n' "$sha" "$REF" > "$ROOT/checksums.txt"
echo "checksums.txt gerado."

echo
echo "Pronto. Faça commit das alterações em install.sh e checksums.txt."
