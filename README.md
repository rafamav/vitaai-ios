# VitaAI iOS

App nativo iOS para estudantes de medicina — Canvas LMS integration, PDFs, Flashcards, Simulados, MindMaps.

**Platform:** iOS 17+
**Language:** Swift 6
**UI:** SwiftUI
**Architecture:** MVVM + SwiftData

---

## Features

- ✅ **Auth & Onboarding** — Login + 5-step onboarding
- ✅ **Dashboard** — Greeting, study modules, upcoming exams, agenda
- ✅ **Chat** — VitaChat SSE streaming
- ✅ **Agenda** — Calendar + events
- ✅ **Estudos** — 5 tabs (Disciplinas, Notebooks, MindMaps, Flashcards, PDFs)
- ✅ **Notebooks** — Rich text editor + drawing canvas
- ✅ **MindMap** — Visual mind mapping (NEW - P1)
- ✅ **Flashcards** — Anki-style SRS with flip 3D
- ✅ **PDF Viewer** — Annotations, ink canvas, export
- ✅ **Simulados** — 6 screens (config, session, result, review, diagnostics)
- ✅ **Canvas LMS** — OAuth integration
- ✅ **WebAluno** — WebView portal
- ✅ **Profile** — Settings, appearance, notifications, about

---

## Recent Updates

### 2026-03-03: MindMap Feature (P1)

**Implementation:** 1541 lines (9 new files + 5 modifications)

**Files:**
- Domain: `MindMapModels.swift`
- Data: `MindMapEntity.swift`, `MindMapRepository.swift`
- State: `MindMapStore.swift`, `MindMapListViewModel.swift`, `MindMapEditorViewModel.swift`
- UI: `MindMapListView.swift`, `MindMapCanvasView.swift`, `MindMapEditorView.swift`

**Features:**
- Grid 2-column list with FAB, empty state, skeleton
- Interactive canvas (pan/zoom/drag)
- Bezier curves connecting parent→child nodes
- 8-color palette
- Double-tap text editing
- Auto-save with 2s debounce
- SwiftData persistence (JSON serialization)

**Docs:**
- Implementation: `MINDMAP_IMPLEMENTATION.md`
- Parity: Updated `MOBILE_PARITY.md`

**Commit:** `e2ce8d7`

---

## Development

### Setup

**Requirements:**
- macOS 13+ (Ventura or later)
- Xcode 15+
- Homebrew
- XcodeGen

**Install XcodeGen:**
```bash
brew install xcodegen
```

**Generate Xcode project:**
```bash
xcodegen generate
open VitaAI.xcodeproj
```

### Build & Run

**Simulator:**
```bash
# Generate project
xcodegen generate

# Open Xcode
open VitaAI.xcodeproj

# In Xcode:
# - Select device: iPhone 15 Pro
# - Cmd+R to run
```

**Physical Device:**
1. Connect iPhone via USB
2. Xcode → Select device
3. Cmd+R
4. Trust developer on iPhone

---

## TestFlight Deploy (Automated)

**One-command deploy via Fastlane:**

```bash
./scripts/deploy-testflight.sh
```

**First time setup (30 min):**
1. Copy credentials template:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env`:
   ```env
   APPLE_ID=your-email@bymav.com
   TEAM_ID=ABCDE12345
   MATCH_PASSWORD=your-match-password
   ```

3. Setup certificates:
   ```bash
   fastlane match appstore
   ```

4. Deploy:
   ```bash
   ./scripts/deploy-testflight.sh
   ```

**Subsequent builds (10-15 min):**
```bash
./scripts/deploy-testflight.sh
```

**What it does:**
- ✅ Generates Xcode project
- ✅ Increments build number
- ✅ Configures code signing
- ✅ Builds + archives
- ✅ Uploads to TestFlight
- ✅ Commits build number
- ✅ Pushes to git

**Documentation:**
- Automation: `FASTLANE_AUTOMATION.md`
- Manual setup: `TESTFLIGHT_SETUP.md`

---

## Architecture

### Layers

```
VitaAI/
├── Core/
│   ├── DI/              # Dependency injection (AppContainer)
│   └── Network/         # HTTP client, API, auth
├── Data/
│   └── Persistence/     # SwiftData entities + repositories
├── Features/
│   ├── Auth/            # Login, onboarding
│   ├── Dashboard/       # Home screen
│   ├── Chat/            # VitaChat
│   ├── Estudos/         # Study tabs
│   ├── Notes/           # Notebooks
│   ├── MindMap/         # Mind mapping (NEW)
│   ├── Flashcard/       # SRS flashcards
│   ├── PDF/             # PDF viewer + annotations
│   ├── Simulado/        # Practice exams
│   └── Profile/         # Settings
├── DesignSystem/
│   ├── Theme/           # VitaColors, VitaTypography
│   └── Components/      # Reusable UI components
├── Navigation/          # Route enum + AppRouter
└── Models/              # Domain models
```

### Design System

**Colors:** `VitaColors` (cyan ambient glass)
- Primary: Cyan #22D3EE
- Surface: Near-black with cool tint
- Glass: Low-opacity overlays

**Typography:** `VitaTypography` (system font with semantic sizes)

**Components:**
- `VitaButton`, `VitaGlassCard`, `VitaInput`
- `VitaTopBar`, `VitaTabBar`
- `VitaEmptyState`, `VitaErrorState`
- `ProgressRingView`, `VitaShimmer`

### State Management

**Pattern:** @Observable + @State
- ViewModels: `@Observable` classes
- Views: `@State private var viewModel`
- Shared state: Stores (e.g., `NotebookStore`, `MindMapStore`)

**Persistence:** SwiftData
- Entities: `@Model` classes
- Repositories: CRUD operations via `ModelContext`
- Schema: Registered in `AppContainer`

---

## Testing

### Unit Tests
```bash
xcodebuild test -scheme VitaAI -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### E2E Tests (Fastlane)
```bash
fastlane test
```

### Manual Testing
- Simulator: Cmd+R
- Device: Connect + Cmd+R
- TestFlight: Deploy + install

---

## Parity with Android

**Status:** Updated `MOBILE_PARITY.md`

**Recent achievements:**
- ✅ MindMap (was P1 gap, now complete)
- ✅ Simulado (6 screens)
- ✅ PDF Viewer (basic annotations)

**Remaining gaps (P2-P4):**
- P2: FlashcardStats, Charts (4), TrabalhoEditor
- P3: VitaBadgeGrid, VitaMarkdown, VitaStreakBadge, VitaVoiceInput, VitaXpBar
- P4: PDF advanced (Audio, Lasso, Layers, etc)

---

## CI/CD

**GitHub Actions:** `.github/workflows/testflight.yml` (example in `FASTLANE_AUTOMATION.md`)

**Secrets required:**
- `APPLE_ID`
- `TEAM_ID`
- `MATCH_PASSWORD`
- `MATCH_KEYCHAIN_PASSWORD`
- `ASC_KEY_ID` (optional, for passwordless auth)
- `ASC_ISSUER_ID` (optional)

---

## Project Configuration

**File:** `project.yml` (XcodeGen)

**Key settings:**
```yaml
name: VitaAI
bundleIdPrefix: com.bymav
deploymentTarget:
  iOS: 17.0

targets:
  VitaAI:
    type: application
    platform: iOS
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.bymav.vitaai
      DEVELOPMENT_TEAM: <YOUR_TEAM_ID>
      MARKETING_VERSION: 1.0.0
      CURRENT_PROJECT_VERSION: 1
```

---

## Resources

**Documentation:**
- Implementation: `MINDMAP_IMPLEMENTATION.md`
- TestFlight Setup: `TESTFLIGHT_SETUP.md`
- Fastlane Automation: `FASTLANE_AUTOMATION.md`
- Mobile Parity: `../bymav/packages/design-tokens/reference/MOBILE_PARITY.md`

**Repositories:**
- iOS: `rafamav/vitaai-ios`
- Android: `by-mav/bymav-mobile`
- Backend: `by-mav/pixio` (monorepo)

**Links:**
- App Store Connect: https://appstoreconnect.apple.com
- Apple Developer: https://developer.apple.com
- Fastlane Docs: https://docs.fastlane.tools

---

## License

Proprietary - BYMAV © 2026

---

**Last updated:** 2026-03-03
**Version:** 1.0.0 (Build 1)
**Latest feature:** MindMap P1 ✅
