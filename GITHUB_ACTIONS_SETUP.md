# Build iOS SEM MAC — GitHub Actions

GitHub fornece runners macOS grátis. Build acontece na nuvem!

## Setup Rápido (30 min)

### 1. Adicionar 5 Secrets no GitHub

**vitaai-ios repo → Settings → Secrets → Actions → New secret**

| Nome | Valor | Como Obter |
|------|-------|------------|
| APPLE_ID | seu@email.com | Seu Apple ID |
| TEAM_ID | ABC1234567 | developer.apple.com → Membership |
| MATCH_PASSWORD | senha123 | Criar senha forte |
| MATCH_KEYCHAIN_PASSWORD | keychain123 | Criar senha |
| APP_SPECIFIC_PASSWORD | xxxx-xxxx-xxxx-xxxx | appleid.apple.com → App-Specific Passwords (**CRÍTICO**) |

### 2. Trigger Build

1. GitHub → Actions → Deploy TestFlight
2. Run workflow → main
3. Aguardar 15 min
4. Build no TestFlight ✅

### 3. Instalar no iPhone

1. App Store → TestFlight app
2. App Store Connect → adicionar testador
3. Email convite → Install
4. Testar MindMap! 🎉

## Custo

- Repo público: **GRÁTIS** ✅
- Repo privado: ~$1.20 por build

**SEM MAC NECESSÁRIO!**
