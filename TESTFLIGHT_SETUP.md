# VitaAI iOS — TestFlight Setup Guide

**Objetivo:** Distribuir VitaAI iOS (com MindMap) via TestFlight para testes no celular.

**ETA Total:** 2-4 horas (primeira vez), 30 min (builds seguintes)

---

## Pré-requisitos

### 1. Apple Developer Account
- [ ] Inscrição: https://developer.apple.com/programs/
- [ ] Custo: $99/ano
- [ ] Aprovação: 24-48h

**Status atual:** ❓ Verificar se já existe

### 2. Ferramentas
- [ ] Mac com macOS 13+ (Ventura ou superior)
- [ ] Xcode 15+ instalado (App Store)
- [ ] Homebrew instalado: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- [ ] XcodeGen instalado: `brew install xcodegen`

### 3. Acesso App Store Connect
- [ ] Login: https://appstoreconnect.apple.com
- [ ] Credenciais: Apple ID do Developer Account

---

## Fase 1: Configuração Inicial (Primeira Vez)

### Step 1.1: Certificates & Provisioning Profiles

**No Mac:**

1. Abrir **Xcode**
2. **Xcode → Settings → Accounts**
3. Adicionar Apple ID (Developer Account)
4. Selecionar Team → **Manage Certificates**
5. Criar certificados:
   - ✅ Apple Development (para testar no device)
   - ✅ Apple Distribution (para TestFlight/App Store)

**Automaticamente via Xcode:**
- Xcode gerencia provisioning profiles automaticamente
- **Recommended:** deixar "Automatically manage signing" ✅

### Step 1.2: Registrar App ID

**App Store Connect:**

1. Login: https://appstoreconnect.apple.com
2. **Apps → ➕ (Novo App)**
3. Preencher:
   - **Platform:** iOS
   - **Name:** VitaAI
   - **Primary Language:** Portuguese (Brazil)
   - **Bundle ID:** Criar novo → `com.bymav.vitaai` (ou seu domínio)
   - **SKU:** `vitaai-ios`
   - **User Access:** Full Access

4. **Salvar**

**⚠️ IMPORTANTE:** O Bundle ID deve ser **único** globalmente (não pode repetir de outro app).

### Step 1.3: Configurar project.yml (XcodeGen)

**Arquivo:** `/home/mav/vita-ios/project.yml`

Verificar/adicionar:

```yaml
name: VitaAI
options:
  bundleIdPrefix: com.bymav
  deploymentTarget:
    iOS: 17.0

targets:
  VitaAI:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - VitaAI
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.bymav.vitaai
        PRODUCT_NAME: VitaAI
        TARGETED_DEVICE_FAMILY: 1  # iPhone only
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: <YOUR_TEAM_ID>  # ← PREENCHER com Team ID
        INFOPLIST_FILE: VitaAI/Info.plist
        MARKETING_VERSION: 1.0.0
        CURRENT_PROJECT_VERSION: 1
```

**Como obter TEAM_ID:**
- Xcode → Settings → Accounts → Team → copiar ID (10 caracteres)
- Ou App Store Connect → Membership → Team ID

---

## Fase 2: Build & Archive (Cada Deploy)

### Step 2.1: Gerar Xcode Project

**Terminal (Mac):**

```bash
cd /home/mav/vita-ios

# Gerar .xcodeproj
xcodegen generate

# Abrir Xcode
open VitaAI.xcodeproj
```

### Step 2.2: Verificar Configuração

**No Xcode:**

1. Selecionar target **VitaAI** (sidebar esquerda)
2. **Signing & Capabilities** tab:
   - ✅ **Automatically manage signing** marcado
   - **Team:** Selecionar seu Apple Developer Team
   - **Bundle Identifier:** `com.bymav.vitaai` (deve estar cinza se auto)
   - **Provisioning Profile:** "Xcode Managed Profile" (auto)

3. **General** tab:
   - **Display Name:** VitaAI
   - **Version:** 1.0.0
   - **Build:** 1 (incrementar a cada upload)

### Step 2.3: Incrementar Build Number

**A cada novo upload TestFlight:**

```bash
# Editar Info.plist OU project.yml
# Incrementar CURRENT_PROJECT_VERSION: 1 → 2 → 3 ...
```

**Ou via Xcode:**
- General → Build: `1` → `2`

### Step 2.4: Selecionar Target "Any iOS Device"

**No Xcode (barra superior):**
- Clicar dropdown de device
- Selecionar: **"Any iOS Device (arm64)"**
- **NÃO** selecionar Simulator

### Step 2.5: Archive

**Xcode → Product → Archive**

Aguardar compilação (2-5 min primeira vez, 30s-1min seguintes).

**Se erros:**
- Verificar Signing & Capabilities
- Verificar Team ID no project.yml
- Verificar Bundle ID match com App Store Connect

**Sucesso:**
- Xcode Organizer abre automaticamente
- Archive aparece na lista

### Step 2.6: Distribute App

**No Xcode Organizer:**

1. Selecionar Archive recente
2. **Distribute App** (botão azul)
3. Escolher: **"TestFlight & App Store"**
4. **Next**
5. **Upload** (deixar padrões)
6. **Next**
7. Revisar signing:
   - ✅ Automatically manage signing
   - ✅ VitaAI Distribution certificate
8. **Upload**

**Aguardar upload (2-10 min dependendo conexão).**

**Sucesso:**
- "Upload Successful" ✅
- **Close**

---

## Fase 3: Processar Build no TestFlight

### Step 3.1: Aguardar Processing

**App Store Connect → TestFlight:**

1. Login: https://appstoreconnect.apple.com
2. **Apps → VitaAI → TestFlight**
3. Ver build na lista:
   - Status: **"Processing"** 🔄
   - Aguardar 5-15 min (até 1h se primeiro build)

**Quando pronto:**
- Status: **"Ready to Test"** ✅

### Step 3.2: Configurar Informações de Teste

**TestFlight → Build (1.0.0) → Test Details:**

1. **What to Test (opcional):**
   ```
   # Build 1.0.0 (1)

   ## Novas Features
   - ✅ MindMap: Mapas mentais para organização visual de conceitos
   - ✅ Canvas interativo com pan/zoom/drag
   - ✅ Paleta de 8 cores
   - ✅ Auto-save

   ## Como Testar MindMap
   1. Abrir app → Estudos → Tab "Mapas"
   2. Criar novo mapa mental
   3. Adicionar nodes (botão +)
   4. Arrastar nodes, fazer zoom (pinch)
   5. Double-tap para editar texto
   6. Trocar cor (botão paleta)

   ## Reporte Bugs
   - Screenshots ajudam muito!
   - Descrever passos para reproduzir
   ```

2. **Salvar**

### Step 3.3: Export Compliance (Primeira Vez)

**Se aparecer aviso "Missing Export Compliance":**

1. **Provide Export Compliance Information**
2. Perguntas:
   - **"Is your app designed to use cryptography or does it contain or incorporate cryptography?"**
     - Resposta: **NO** (a menos que você use criptografia customizada)
   - Se NO → concluído
   - Se YES → preencher formulário adicional

3. **Salvar**

---

## Fase 4: Adicionar Testadores

### Step 4.1: Internal Testing (Rápido)

**TestFlight → Internal Testing:**

1. **Internal Testing → ➕ Add Internal Testers**
2. Adicionar você mesmo:
   - Email: (seu Apple ID)
   - Nome: Rafael
3. **Add**

**Resultado:**
- Email automático enviado
- Install link disponível imediatamente

### Step 4.2: External Testing (Público, até 10k testadores)

**TestFlight → External Testing:**

1. **External Testing → ➕ Add Group**
2. Nome do grupo: "Beta Testers"
3. **Create**
4. **Add Testers:**
   - Email: (emails dos testadores)
5. **Select Build:**
   - Escolher build 1.0.0 (1)
6. **Next**
7. **Submit for Review** (Apple aprova em 24-48h)

**Aguardar aprovação Apple.**

**Quando aprovado:**
- Testadores recebem email
- Install link ativo

---

## Fase 5: Instalar no iPhone

### Step 5.1: Instalar TestFlight App

**No iPhone:**

1. Abrir **App Store**
2. Buscar: **"TestFlight"**
3. Instalar app oficial Apple

### Step 5.2: Aceitar Convite

**Opção A — Email:**
1. Abrir email "You're invited to test VitaAI"
2. **View in TestFlight** (botão azul)
3. TestFlight app abre

**Opção B — Link direto:**
1. Abrir link do convite
2. TestFlight app abre

### Step 5.3: Instalar Build

**No TestFlight app:**

1. Ver **VitaAI** na lista
2. **Install** (botão azul)
3. Aguardar download (50-200 MB)
4. **Open**

**Pronto! App instalado.** ✅

---

## Fase 6: Atualizar Builds (Builds Futuros)

**Para cada novo build:**

1. Incrementar build number:
   ```yaml
   # project.yml
   CURRENT_PROJECT_VERSION: 2  # era 1
   ```

2. Gerar + Archive:
   ```bash
   xcodegen generate
   # Xcode → Product → Archive
   ```

3. Upload (Organizer → Distribute)

4. Aguardar processing (5-15 min)

5. Testadores recebem notificação automática:
   - "New build available"
   - Update no TestFlight app

**Versão vs Build:**
- **Version (MARKETING_VERSION):** 1.0.0 → 1.1.0 → 2.0.0 (features)
- **Build (CURRENT_PROJECT_VERSION):** 1 → 2 → 3 → ... (cada upload)

---

## Troubleshooting

### Erro: "No code signing identities found"

**Solução:**
1. Xcode → Settings → Accounts
2. Download Manual Profiles
3. Manage Certificates → ➕ Apple Distribution

### Erro: "Bundle ID mismatch"

**Solução:**
1. Verificar `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`
2. Verificar App Store Connect → App → Bundle ID
3. Devem ser **exatamente iguais**

### Erro: "Invalid provisioning profile"

**Solução:**
1. Xcode → Settings → Accounts → Download Manual Profiles
2. Signing & Capabilities → Team → trocar e voltar
3. Clean Build Folder (Cmd+Shift+K)
4. Archive novamente

### Build "Processing" há muito tempo (>2h)

**Solução:**
- Normal em primeiro build (até 4h)
- Verificar email (Apple pode pedir info adicional)
- Verificar App Store Connect → Activity (logs)

### TestFlight link não funciona

**Solução:**
1. Verificar se build está "Ready to Test"
2. Verificar se testador foi adicionado
3. Verificar email correto (mesmo do Apple ID)
4. Reenviar convite: TestFlight → Testers → Resend

---

## Checklist Final

### Primeira Vez (Setup Completo)
- [ ] Apple Developer Account ativo ($99/ano)
- [ ] Xcode instalado + configurado
- [ ] XcodeGen instalado (Homebrew)
- [ ] App registrado no App Store Connect
- [ ] Bundle ID único configurado
- [ ] Team ID em project.yml
- [ ] Certificates criados (Development + Distribution)
- [ ] Build 1 gerado e uploaded
- [ ] Build processado (Ready to Test)
- [ ] Export Compliance configurado
- [ ] Testador interno adicionado
- [ ] TestFlight app instalado no iPhone
- [ ] VitaAI instalado via TestFlight

### Builds Seguintes (Updates)
- [ ] Incrementar build number
- [ ] xcodegen generate
- [ ] Product → Archive
- [ ] Distribute App → Upload
- [ ] Aguardar processing
- [ ] Testar no device

---

## Recursos

**Documentação Apple:**
- TestFlight: https://developer.apple.com/testflight/
- App Store Connect: https://developer.apple.com/app-store-connect/
- Signing: https://developer.apple.com/support/code-signing/

**Suporte:**
- Apple Developer Support: https://developer.apple.com/support/
- Forum: https://developer.apple.com/forums/

**Videos:**
- TestFlight Tutorial: https://www.youtube.com/results?search_query=xcode+testflight+tutorial+2024

---

**Tempo estimado total (primeira vez):** 2-4 horas
**Tempo estimado (builds seguintes):** 30 minutos

**Pronto para começar!** 🚀
