#!/usr/bin/env bash
# Copia os assets 3D glass do vitaai-mockup para o Assets.xcassets do iOS.
# Executar uma vez após clonar o repo (ou quando novos assets forem adicionados).
# Uso: ./scripts/copy-glass-assets.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/../VitaAI/Assets.xcassets"
SRC_DIR="/home/mav/vitaai-mockup/assets"

if [ ! -d "$SRC_DIR" ]; then
  echo "ERRO: Diretório de assets não encontrado: $SRC_DIR"
  exit 1
fi

NAMES=(
  "glassv2-exam-paper-nobg"
  "glassv2-flashcard-deck-nobg"
  "glassv2-calculator-nobg"
  "glassv2-anatomy-3d-nobg"
  "glassv2-disc-anatomia-nobg"
  "glassv2-disc-fisiologia-1-nobg"
  "glassv2-disc-bioquimica-nobg"
  "glassv2-disc-farmacologia-nobg"
  "glassv2-disc-patologia-geral-nobg"
  "glassv2-disc-neurologia-nobg"
  "glassv2-disc-pediatria-1-nobg"
  "glassv2-disc-cirurgia-1-nobg"
  "glassv2-disc-clinica-medica-1-nobg"
  "glassv2-disc-dermatologia-nobg"
  "glassv2-disc-microbiologia-nobg"
  "glassv2-disc-imunologia-nobg"
  "glassv2-disc-histologia-nobg"
  "glassv2-disc-genetica-nobg"
  "glassv2-disc-psiquiatria-1-nobg"
  "glassv2-disc-radiologia-nobg"
  "glassv2-disc-ortopedia-nobg"
  "glassv2-disc-otorrino-nobg"
  "glassv2-disc-oftalmologia-nobg"
  "glassv2-disc-semiologia-nobg"
)

for NAME in "${NAMES[@]}"; do
  DIR="$ASSETS_DIR/${NAME}.imageset"
  mkdir -p "$DIR"
  cp "$SRC_DIR/${NAME}.png" "$DIR/${NAME}.png"
  cat > "$DIR/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "${NAME}.png", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
  echo "  OK: ${NAME}"
done

echo ""
echo "Assets copiados: ${#NAMES[@]}"
