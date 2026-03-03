#!/bin/bash
# Checklist de verificação antes do deploy

echo "🔍 VitaAI iOS - Verificação de Prontidão"
echo "========================================"
echo ""

# Check 1: Git status
echo "✅ Git Status:"
git status --short | head -5 || echo "Clean"
echo ""

# Check 2: Arquivos críticos
echo "✅ Arquivos Críticos:"
files=(
  ".github/workflows/testflight.yml"
  "fastlane/Fastfile"
  "fastlane/Matchfile"
  "project.yml"
  "GITHUB_ACTIONS_SETUP.md"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✓ $file"
  else
    echo "  ✗ $file (FALTANDO!)"
  fi
done
echo ""

# Check 3: Commits recentes
echo "✅ Últimos 3 Commits:"
git log --oneline -3
echo ""

# Check 4: GitHub Actions workflow
if [ -f ".github/workflows/testflight.yml" ]; then
  echo "✅ GitHub Actions: Configurado"
  echo "  - Workflow: testflight.yml"
  echo "  - Runner: macos-14"
  echo "  - Trigger: workflow_dispatch (manual)"
else
  echo "❌ GitHub Actions: NÃO configurado"
fi
echo ""

# Check 5: Próximos passos
echo "📋 PRÓXIMOS PASSOS (VOCÊ FAZ):"
echo ""
echo "1️⃣  GitHub Secrets (vitaai-ios repo → Settings → Secrets):"
echo "   [ ] APPLE_ID"
echo "   [ ] TEAM_ID"
echo "   [ ] MATCH_PASSWORD"
echo "   [ ] MATCH_KEYCHAIN_PASSWORD"
echo "   [ ] APP_SPECIFIC_PASSWORD"
echo ""
echo "2️⃣  Criar repo: github.com/SEU-USUARIO/vitaai-certificates (Private)"
echo ""
echo "3️⃣  GitHub → Actions → Deploy TestFlight → Run workflow"
echo ""
echo "4️⃣  Aguardar 15-20 min → Build no TestFlight"
echo ""
echo "5️⃣  App Store Connect → Adicionar testador → Instalar no iPhone"
echo ""
echo "========================================"
echo "🚀 ESTÁ PRONTO! Siga os 5 passos acima."
echo ""
