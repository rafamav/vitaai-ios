# 🚀 Deploy AGORA — Passo a Passo

**Tudo pronto! Siga este guia para ter o app no seu iPhone em 30 minutos.**

---

## ✅ VERIFICADO

- ✅ Código MindMap implementado (1541 linhas)
- ✅ GitHub Actions configurado
- ✅ Fastlane pronto
- ✅ Workflow testflight.yml criado
- ✅ Documentação completa

**Tudo commitado e pushed para `rafamav/vitaai-ios`**

---

## 📱 PASSO 1: GitHub Secrets (5 min)

**Abrir:** https://github.com/rafamav/vitaai-ios/settings/secrets/actions

**Clicar:** "New repository secret" (5 vezes)

### Secret 1: APPLE_ID
- Name: `APPLE_ID`
- Value: `seu-email@bymav.com` (ou Apple ID que você usa)
- Add secret

### Secret 2: TEAM_ID
- Name: `TEAM_ID`
- Value: **OBTER AQUI:** https://developer.apple.com/account → Membership → Team ID (10 caracteres)
- Add secret

### Secret 3: MATCH_PASSWORD
- Name: `MATCH_PASSWORD`
- Value: Criar senha forte (ex: `VitaAI2024!Secure`)
- Add secret

### Secret 4: MATCH_KEYCHAIN_PASSWORD
- Name: `MATCH_KEYCHAIN_PASSWORD`
- Value: Criar senha (ex: `KeychainVita123`)
- Add secret

### Secret 5: APP_SPECIFIC_PASSWORD ⚠️ **MAIS IMPORTANTE!**
- **Gerar primeiro:** https://appleid.apple.com → Sign-In and Security → App-Specific Passwords → Generate
- Nome: "GitHub Actions VitaAI"
- **Copiar senha:** `xxxx-xxxx-xxxx-xxxx`
- Name: `APP_SPECIFIC_PASSWORD`
- Value: `xxxx-xxxx-xxxx-xxxx` (a senha que copiou)
- Add secret

**Resultado:** 5 secrets adicionados ✅

---

## 📦 PASSO 2: Repo de Certificados (2 min)

**Abrir:** https://github.com/new

**Preencher:**
- Repository name: `vitaai-certificates`
- Description: "iOS certificates for VitaAI (Match)"
- **Private** ✅ (IMPORTANTE!)
- **NÃO** inicializar com README (deixar vazio)

**Clicar:** Create repository

**Copiar URL:** `https://github.com/SEU-USUARIO/vitaai-certificates`

**Voltar para vitaai-ios e editar Matchfile:**

Opção A - Via GitHub Web:
1. https://github.com/rafamav/vitaai-ios/blob/main/fastlane/Matchfile
2. Click ✏️ (Edit)
3. Linha 3, trocar para: `git_url("https://github.com/SEU-USUARIO/vitaai-certificates")`
4. Commit changes

Opção B - Via terminal (se tiver git):
```bash
cd /home/mav/vita-ios
# Editar fastlane/Matchfile linha 3
git add fastlane/Matchfile
git commit -m "fix: update Match certificates repo"
git push
```

**Resultado:** Repo criado e Matchfile atualizado ✅

---

## 🎬 PASSO 3: Trigger Build (1 clique!)

**Abrir:** https://github.com/rafamav/vitaai-ios/actions

**Sidebar esquerda:**
- Clicar em: **"Deploy TestFlight"**

**Página do workflow:**
- Clicar botão: **"Run workflow"** (direita, dropdown verde)
- Branch: `main` (já selecionado)
- Clicar: **"Run workflow"** (botão verde)

**Resultado:** Build iniciado! 🚀

---

## ⏱️ PASSO 4: Aguardar Build (15-20 min)

**Acompanhar progresso:**
- GitHub Actions mostra steps em tempo real
- Cada step tem ✓ ou ✗

**Steps esperados:**
1. ✅ Checkout code
2. ✅ Setup Ruby
3. ✅ Install Fastlane
4. ✅ Install XcodeGen
5. ✅ Setup .env
6. ✅ Setup Keychain
7. ✅ Generate Xcode Project
8. ✅ Build & Upload to TestFlight ← **mais demorado (10 min)**

**Se tudo ✅:**
- Workflow fica verde
- "Build deployed to TestFlight successfully!"

**Se ❌ (erro):**
- Clicar no step vermelho
- Ver log de erro
- **Comum na primeira vez:** Match precisa criar certificados
  - Pode pedir aprovação manual no Apple Developer Portal
  - Aprovar e re-run workflow

---

## 🍎 PASSO 5: App Store Connect (5 min)

**Abrir:** https://appstoreconnect.apple.com

**Login com Apple ID**

**Navegar:**
- Apps → VitaAI (ou criar app se não existir)
- TestFlight (tab no topo)

**Ver build:**
- Status: **"Processing"** 🔄 (aguardar 5-15 min)
- Status: **"Ready to Test"** ✅ (pronto!)

**Se app não existir ainda:**
1. Apps → ➕ (criar app)
2. Nome: VitaAI
3. Bundle ID: `com.bymav.vitaai`
4. SKU: `vitaai-ios`
5. Criar

---

## 👤 PASSO 6: Adicionar Testador (2 min)

**No App Store Connect → TestFlight:**

**Internal Testing:**
1. Clicar: "Internal Testing" (ou criar grupo se não existir)
2. Clicar: ➕ "Add Internal Testers"
3. Email: (seu Apple ID - mesmo email do login)
4. Clicar: "Add"

**Resultado:**
- Email automático enviado ✅
- "You're invited to test VitaAI"

---

## 📲 PASSO 7: Instalar no iPhone (5 min)

### A. Instalar TestFlight App

**No seu iPhone:**
1. App Store
2. Buscar: "TestFlight"
3. Instalar (app oficial Apple, ícone azul com avião)

### B. Aceitar Convite

**Opção 1 - Via Email (FÁCIL):**
1. Abrir email: "You're invited to test VitaAI"
2. Clicar: **"View in TestFlight"** (botão azul)
3. TestFlight app abre automaticamente

**Opção 2 - Via Link Direto:**
- Se tiver link do convite, abrir no Safari
- TestFlight abre automaticamente

### C. Instalar VitaAI

**No TestFlight app:**
1. Ver: "VitaAI" na lista
2. Clicar: **"Install"** (botão azul)
3. Aguardar download (50-200 MB, 1-3 min)
4. Clicar: **"Open"** ✅

**PRONTO! App instalado!** 🎉

---

## 🧪 PASSO 8: Testar MindMap (10 min)

**No VitaAI app:**

1. **Login** (se necessário)
2. **Onboarding** (se primeira vez)
3. **Dashboard** → Tap "Estudos"
4. **Tab bar** → Tap "Mapas" (3º tab)
5. **Empty state** → "Criar Mapa Mental"
6. **Editor abre** com "Tema Central"

**Testar funcionalidades:**
- ✅ **Add node:** Tap botão "+" toolbar
- ✅ **Drag node:** Arrastar node pelo canvas
- ✅ **Pan canvas:** Arrastar área vazia (scrollar)
- ✅ **Zoom:** Pinch com 2 dedos (abrir/fechar)
- ✅ **Edit text:** Double-tap no node → editar → salvar
- ✅ **Color picker:** Select node → Tap paleta → escolher cor
- ✅ **Delete node:** Select node → Tap trash → confirmar
- ✅ **Auto-save:** Voltar (back) → reabrir mapa → nodes salvos ✅

**Bugs encontrados?**
- Screenshot do problema
- Descrever passos para reproduzir
- Reportar (GitHub issue ou mensagem)

---

## 🔄 Próximas Atualizações

**Fazer mudanças no código:**
```bash
cd /home/mav/vita-ios
# ... editar arquivos ...
git commit -m "feat: nova feature"
git push
```

**Deploy atualização:**
1. GitHub → Actions → Deploy TestFlight
2. Run workflow
3. Aguardar 15 min
4. TestFlight notifica: "New build available"
5. Update no app ✅

---

## 📊 Checklist Completo

### Setup (uma vez)
- [ ] Adicionar 5 secrets no GitHub
- [ ] Criar repo `vitaai-certificates` (private)
- [ ] Atualizar Matchfile com repo URL
- [ ] Trigger workflow no GitHub Actions
- [ ] Aguardar build (15-20 min)
- [ ] Verificar App Store Connect
- [ ] Adicionar você como testador
- [ ] Instalar TestFlight app no iPhone
- [ ] Aceitar convite via email
- [ ] Instalar VitaAI no iPhone

### Teste
- [ ] Abrir app
- [ ] Navegar: Estudos → Mapas
- [ ] Criar mapa mental
- [ ] Testar 8 funcionalidades
- [ ] Verificar auto-save
- [ ] **SUCESSO!** 🎉

---

## ❓ Troubleshooting

### "Workflow failed"
- Ver logs do step que falhou
- **Comum:** Match precisa aprovar certificados
- Solução: Aprovar no Apple Developer Portal + re-run

### "No build in TestFlight"
- Aguardar 5-15 min (processing)
- Refresh página App Store Connect
- Verificar email (Apple pode pedir info)

### "Can't install TestFlight"
- Verificar iOS version (precisa iOS 12+)
- Verificar espaço (precisa ~100 MB livre)

### "Invite not received"
- Verificar spam/lixo eletrônico
- Verificar email correto (mesmo do Apple ID)
- Reenviar convite no App Store Connect

---

## 🎯 Resumo

**Total:** 30-40 minutos (primeira vez)

**Etapas:**
1. ✅ Secrets (5 min)
2. ✅ Repo certificados (2 min)
3. ✅ Trigger build (1 min)
4. ⏱️ Aguardar (15-20 min)
5. ✅ App Store Connect (5 min)
6. ✅ Adicionar testador (2 min)
7. ✅ Instalar (5 min)
8. ✅ Testar (10 min)

**Resultado:** VitaAI com MindMap no seu iPhone! 📱✨

---

**COMEÇAR:** Passo 1 → GitHub Secrets 🚀
