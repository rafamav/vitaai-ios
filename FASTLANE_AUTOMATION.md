# VitaAI iOS - Automação Fastlane

**Objetivo:** Deploy automático para TestFlight com 1 comando.

---

## Setup Inicial (Primeira Vez)

### 1. Instalar Fastlane (Mac)

```bash
# Via Homebrew (recomendado)
brew install fastlane

# OU via RubyGems
sudo gem install fastlane -NV
```

### 2. Configurar Credenciais

**Copiar template:**
```bash
cd /home/mav/vita-ios
cp .env.example .env
```

**Editar `.env`:**
```bash
# Abrir com editor
nano .env

# OU
code .env
```

**Preencher:**
```env
APPLE_ID=seu-email@bymav.com
TEAM_ID=ABCDE12345  # Obter em App Store Connect → Membership
MATCH_PASSWORD=senha-para-certificados
```

### 3. Setup Certificados (Match)

**Primeira vez:**
```bash
fastlane match init
```

**Perguntas:**
- Storage mode: **git**
- Git URL: `https://github.com/rafamav/vitaai-certificates` (criar repo privado)
- Senha: (usar MATCH_PASSWORD do .env)

**Gerar certificados:**
```bash
fastlane match appstore
```

**O que acontece:**
- ✅ Cria certificados Apple Distribution
- ✅ Cria provisioning profiles
- ✅ Salva encriptado no git repo
- ✅ Instala no Keychain local

---

## Deploy para TestFlight

### Opção 1: Script Automático (FÁCIL)

```bash
./scripts/deploy-testflight.sh
```

**O que faz:**
1. ✅ Verifica ambiente (Mac, Fastlane, XcodeGen)
2. ✅ Carrega .env
3. ✅ Gera Xcode project
4. ✅ Incrementa build number
5. ✅ Configura code signing
6. ✅ Build + Archive
7. ✅ Upload TestFlight
8. ✅ Commit build number
9. ✅ Push para git

**ETA:** 10-15 minutos

### Opção 2: Fastlane Direto

```bash
fastlane beta
```

**Lanes disponíveis:**
- `fastlane setup` — Setup inicial (gerar xcodeproj)
- `fastlane build` — Build local (teste)
- `fastlane test` — Rodar testes
- `fastlane beta` — Upload TestFlight
- `fastlane release` — Testes + Upload
- `fastlane bump` — Incrementar build number

---

## App Store Connect API (SEM SENHA)

**Recomendado para CI/CD e automação completa.**

### Setup

1. **App Store Connect → Users and Access → Keys**
2. **Generate API Key:**
   - Name: VitaAI Fastlane
   - Access: App Manager (ou Admin)
   - Download .p8 file

3. **Adicionar ao .env:**
```env
ASC_KEY_ID=ABC123XYZ
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_KEY_CONTENT=-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----
```

4. **Usar no Fastlane:**
```ruby
# Fastfile já configurado para usar automaticamente
upload_to_testflight(
  api_key_path: "./fastlane/AppStoreAPIKey.json"
)
```

**Vantagens:**
- ✅ Sem precisar de senha
- ✅ Sem 2FA (two-factor auth)
- ✅ Funciona em CI/CD
- ✅ Mais seguro

---

## CI/CD (GitHub Actions)

**Arquivo:** `.github/workflows/testflight.yml`

```yaml
name: Deploy TestFlight

on:
  push:
    branches: [main]
    paths:
      - 'VitaAI/**'
      - 'project.yml'

jobs:
  deploy:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Install Fastlane
        run: bundle install

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Setup .env
        run: |
          echo "APPLE_ID=${{ secrets.APPLE_ID }}" >> .env
          echo "TEAM_ID=${{ secrets.TEAM_ID }}" >> .env
          echo "MATCH_PASSWORD=${{ secrets.MATCH_PASSWORD }}" >> .env
          echo "ASC_KEY_ID=${{ secrets.ASC_KEY_ID }}" >> .env
          echo "ASC_ISSUER_ID=${{ secrets.ASC_ISSUER_ID }}" >> .env

      - name: Deploy to TestFlight
        run: fastlane beta
        env:
          MATCH_KEYCHAIN_PASSWORD: ${{ secrets.MATCH_KEYCHAIN_PASSWORD }}

      - name: Notify Slack
        if: success()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -H 'Content-Type: application/json' \
            -d '{"text":"✅ VitaAI iOS deployed to TestFlight!"}'
```

**GitHub Secrets (Settings → Secrets):**
- `APPLE_ID`
- `TEAM_ID`
- `MATCH_PASSWORD`
- `MATCH_KEYCHAIN_PASSWORD`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_CONTENT`

---

## Troubleshooting

### Erro: "No code signing identity found"

```bash
fastlane match appstore --force
```

### Erro: "Provisioning profile doesn't include signing certificate"

```bash
fastlane match nuke distribution
fastlane match appstore
```

### Erro: "Build number already exists"

```bash
fastlane bump
```

### Clean build completo

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
fastlane beta
```

---

## Comandos Úteis

**Ver certificados instalados:**
```bash
security find-identity -v -p codesigning
```

**Ver provisioning profiles:**
```bash
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```

**Limpar cache Fastlane:**
```bash
fastlane fastlane-credentials remove --username YOUR_APPLE_ID
```

**Ver logs detalhados:**
```bash
fastlane beta --verbose
```

---

## Estrutura de Arquivos

```
vita-ios/
├── fastlane/
│   ├── Fastfile          # Lanes (comandos)
│   ├── Appfile           # App config
│   ├── Matchfile         # Certificados config
│   └── README.md         # Auto-gerado
├── scripts/
│   └── deploy-testflight.sh  # Script automático
├── .env.example          # Template credenciais
├── .env                  # Credenciais (git ignored)
├── Gemfile               # Ruby dependencies
└── FASTLANE_AUTOMATION.md  # Este arquivo
```

---

## Timeline

**Setup inicial:** 30-60 min (primeira vez)
**Deploy seguinte:** 10-15 min (automatizado)
**CI/CD:** 15-20 min (GitHub Actions)

---

## Recursos

**Documentação:**
- Fastlane: https://docs.fastlane.tools/
- Match: https://docs.fastlane.tools/actions/match/
- TestFlight: https://docs.fastlane.tools/actions/upload_to_testflight/

**Exemplos:**
- https://github.com/fastlane/examples

---

**Automação completa configurada!** 🚀

Próximo passo: `./scripts/deploy-testflight.sh` no Mac
