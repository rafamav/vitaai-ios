#!/bin/bash
# VitaAI iOS - Deploy automático para TestFlight
# Uso: ./scripts/deploy-testflight.sh

set -e  # Exit on error

echo "🚀 VitaAI iOS → TestFlight Deploy"
echo "=================================="
echo ""

# Check if on Mac
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "❌ Este script deve rodar em macOS (Mac)"
  exit 1
fi

# Check if Fastlane is installed
if ! command -v fastlane &> /dev/null; then
  echo "📦 Instalando Fastlane..."
  sudo gem install fastlane -NV
fi

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
  echo "📦 Instalando XcodeGen..."
  brew install xcodegen
fi

# Check if .env exists
if [ ! -f ".env" ]; then
  echo "⚠️  Arquivo .env não encontrado"
  echo "Copiando .env.example → .env"
  cp .env.example .env
  echo ""
  echo "❗ IMPORTANTE: Edite .env com suas credenciais Apple:"
  echo "   - APPLE_ID"
  echo "   - TEAM_ID"
  echo "   - MATCH_PASSWORD"
  echo ""
  echo "Execute novamente após configurar .env"
  exit 1
fi

# Load .env
export $(cat .env | xargs)

# Check required env vars
if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ]; then
  echo "❌ .env incompleto. Preencha:"
  echo "   - APPLE_ID"
  echo "   - TEAM_ID"
  exit 1
fi

echo "✅ Ambiente configurado"
echo "   Apple ID: $APPLE_ID"
echo "   Team ID: $TEAM_ID"
echo ""

# Run Fastlane beta lane
echo "🏗️  Executando Fastlane beta lane..."
echo ""

fastlane beta

echo ""
echo "🎉 DEPLOY COMPLETO!"
echo "=================================="
echo ""
echo "📱 Próximos passos:"
echo "1. Aguardar processing no App Store Connect (5-15 min)"
echo "2. Adicionar testadores em TestFlight"
echo "3. Instalar via TestFlight app no iPhone"
echo ""
echo "🔗 App Store Connect: https://appstoreconnect.apple.com"
echo ""
