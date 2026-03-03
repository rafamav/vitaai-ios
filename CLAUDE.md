# VitaAI iOS — CLAUDE.md

## IDENTIDADE
Qualquer agente trabalhando neste repo é SWIFT (iOS Worker).
Reporta para APEX. Policy completa: /home/mav/agents/policies/SWIFT.yaml

---

## REGRA ZERO — SEM XCODE LOCAL

Este repo roda em Linux (VPS). **Não há Xcode disponível.**
Isso significa: **NENHUM erro de compilação é detectado localmente.**
O CI (GitHub Actions macos-14) é o único compilador real.

### Consequência obrigatória: LER ANTES DE ESCREVER

**ANTES de usar QUALQUER componente SwiftUI/struct local:**
```bash
# 1. Verificar se existe
grep -rn "struct NomeComponente\|class NomeComponente" --include="*.swift" .

# 2. Ler o arquivo para ver a API EXATA (parâmetros, ordem, tipos)
cat VitaAI/DesignSystem/Components/NomeComponente.swift
```

**ANTES de criar qualquer arquivo .swift:**
```bash
# Verificar se já existe arquivo com mesmo nome (causa build error fatal)
find VitaAI -name "NomeArquivo.swift"
```

**ANTES de abrir PR:**
```bash
# Confirmar que TODOS os arquivos novos referenciados estão no commit
git status
git diff --cached --stat
```

---

## APIS LOCAIS — FONTE DE VERDADE

### VitaButton
```swift
// CORRETO
VitaButton(text: "Label", action: { ... })
VitaButton(text: "Label", action: { ... }, variant: .secondary)
VitaButton(text: "Label", action: { ... }, isEnabled: false)

// ERRADO — não existe
VitaButton(label: "Label", ...)       // ❌ label: não existe
VitaButton(text: "Label", variant: .secondary, action: ...) // ❌ action deve vir antes de variant
VitaButton(text: "Label", isDisabled: true, ...) // ❌ isDisabled não existe, é isEnabled
```

### FlowLayout
```swift
// Existe em: VitaAI/DesignSystem/Components/FlowLayout.swift
// NÃO criar nova FlowLayout em nenhum outro arquivo
FlowLayout(spacing: 8) { ... }
```

### AppContainer — registrar TODOS os novos serviços
```swift
// Ao criar novo XyzClient, OBRIGATÓRIO adicionar em AppContainer:
// 1. let xyzClient: XyzClient  (propriedade)
// 2. xyzClient = XyzClient(tokenStore: tokenStore)  (no init)
// 3. self.xyzClient = xyzClient  (atribuição)
```

### @ViewBuilder — proibições
```swift
// PROIBIDO: guard let em @ViewBuilder
@ViewBuilder func foo() -> some View {
    guard let x = y else { return }  // ❌ não compila
}

// CORRETO: if let
@ViewBuilder func foo() -> some View {
    if let x = y {
        // conteúdo
    }
}

// PROIBIDO: body/função @ViewBuilder muito complexa com muitos let
// CORRETO: extrair sub-structs ou @ViewBuilder funções menores
```

---

## WORKFLOW OBRIGATÓRIO

```
1. gh issue view BYM-XXX  →  entender o que fazer
2. grep/read  →  entender a codebase existente (APIs, structs, nomes)
3. find  →  confirmar que não há duplicatas do que vai criar
4. git checkout -b feat/BYM-XXX-descricao
5. implementar (seguindo as regras acima)
6. git status  →  confirmar TODOS os arquivos novos estão staged
7. git diff --cached  →  revisar o diff completo
8. git commit + git push
9. gh pr create
10. AGUARDAR CI verde antes de pedir merge
```

---

## ESTRUTURA DO PROJETO

```
VitaAI/
  Core/
    Auth/          # TokenStore, AuthManager
    DI/            # AppContainer (registro de serviços)
    Network/       # VitaAPI, HTTPClient, clientes SSE
  DesignSystem/
    Components/    # VitaButton, FlowLayout, etc — LER ANTES DE CRIAR
    Theme/         # VitaColors, VitaFonts
    Tokens.swift   # Design tokens gerados
  Features/
    [Feature]/     # Screen + ViewModel por feature
  Models/
    API/           # Structs Decodable/Encodable para API
    Domain/        # Structs de domínio
  Navigation/
    AppRouter.swift  # SEMPRE atualizar ao criar nova tela
    Route.swift      # Enum de rotas
```

---

## MAC MINI CHEGANDO (semana que vem)

Quando Mac Mini estiver configurado com self-hosted runner:
- Rodar `xcodebuild build -destination 'platform=iOS Simulator,...'` antes de qualquer commit
- Zero tolerância para erros de compilação
