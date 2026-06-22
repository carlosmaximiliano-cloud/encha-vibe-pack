#!/usr/bin/env bash
# tools/update-checksum.sh — calcula o SHA-256 do tarball da TAG publicada no
# GitHub e grava em install.sh (variável ENCHA_TARBALL_SHA256) e em checksums.txt.
#
# Use DEPOIS de criar e enviar a tag (git tag vX.Y.Z && git push --tags).
#
# Uso:
#   tools/update-checksum.sh [<tag>]
# Ex.: tools/update-checksum.sh v0.1.0
#
# ⚠ LIMITAÇÃO CONHECIDA (checksum circular) — IMPORTANTE:
#   O SHA-256 é gravado dentro de install.sh, que por sua vez está DENTRO do
#   tarball da tag. Ou seja: gravar o SHA muda o conteúdo do tarball, o que muda
#   o próprio SHA. Por isso o valor embutido NUNCA bate 100% com o tarball da
#   mesma tag, a menos que se re-tague em loop (impossível de fechar).
#   Efeito prático: `curl …/<tag>/install.sh | bash` pode ABORTAR no passo de
#   verificação de integridade quando o SHA embutido na tag não corresponde ao
#   tarball real daquela tag.
#
#   Trilha Windows (install.ps1) NÃO é afetada: ela não usa tarball nem checksum.
#
#   Soluções recomendadas (escolha uma; fora do escopo deste script):
#     1) Deixe ENCHA_TARBALL_SHA256 VAZIO no install.sh commitado. A raiz de
#        confiança passa a ser HTTPS + tag imutável (já documentado no README,
#        seção "Modelo de confiança"). Publique o SHA real como nota da release
#        para quem quiser conferir manualmente.
#     2) Publique checksums.txt como ASSET da GitHub Release (fora da árvore do
#        repo) e faça o install.sh baixá-lo separadamente — assim o hash não
#        entra no tarball que ele verifica.

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
