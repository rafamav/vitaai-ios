# Changelog

All notable changes to this project will be documented in this file.

## [unreleased]

### Bug Fixes

- Corrige workflow CI — seleção dinâmica Xcode, remove xcpretty
- Add -destination generic/platform=iOS no archive
- Corrige erros de compilação Swift (async/await + MainActor)
- Forçar Apple Distribution signing no archive
- Archive sem signing, export assina com API key
- Add app icon assets, fix Info.plist, generate icon in CI
- Add AppIcon.appiconset with universal 1024x1024 entry
  - Add CI step to generate cyan 1024x1024 PNG icon via Python
  - Fix Info.plist: CFBundleIconName, UIDeviceFamily (iPhone only), empty UILaunchScreen
  - Fix Assets.xcassets catalog root
- Force iPhone-only TARGETED_DEVICE_FAMILY=1 in project.yml
XcodeGen defaults to "1,2" (universal) causing iPad multitasking
  validation errors on export. Setting TARGETED_DEVICE_FAMILY=1
  explicitly forces iPhone-only build.
- TARGETED_DEVICE_FAMILY=1 in archive cmd + iPad orientation keys
- Pass TARGETED_DEVICE_FAMILY=1 explicitly in xcodebuild archive
  - Add UISupportedInterfaceOrientations~ipad to satisfy validator
  - Belt-and-suspenders: both cmd line and Info.plist fix
- Find IPA dynamically in upload step
Export may place IPA in subdirectory; use find instead of hardcoded path.
- Remove redundant altool upload — export step already uploads
With method=app-store-connect in ExportOptions.plist, xcodebuild
  -exportArchive handles the TestFlight upload automatically.
  altool step was failing because IPA was already uploaded.
- Correct production API URL to vita-ai.cloud
medcoach.bymav.com does not exist. App was hanging on startup
  because all API calls were timing out against the wrong host.
- Observe authManager via @ObservedObject to fix stuck spinner
AppRouter was reading isLoading via @Environment which doesn't
  trigger re-renders. Passing authManager as @ObservedObject ensures
  the view updates when isLoading changes to false.
- Use correct path to find simulator .app bundle
- Remove pipe that hid xcodebuild errors in simulator build
- Use iPhone 16 simulator (Xcode 16.2 doesn't have iPhone 15)
- *(login)* Align iOS layout 1:1 with Android GlassAuthButton spec
- GlassAuthButton: height 52→42, radius 14→8, font bodyLarge→labelLarge
    Matches Android: height=42dp, cornerRadius=8dp, font=14sp/500
  - Image: scaledToFill→scaledToFit+frame(width:screenWidth)
    Implements ContentScale.FillWidth — fills width, clips bottom, no zoom
  - Footer: frame(maxWidth:∞)+padding(h:48) — matches Android Column(36)+Text(12)=48dp
    Prevents text overflow outside screen bounds
  - VStack: frame(maxWidth:∞) — anchors to screen width in ZStack context
- *(login)* Reduce image zoom 10% + push buttons to screen bottom
- Image: frame(width: W*0.9) inside full-width outer frame — matches Android
    ContentScale.FillWidth at 90% scale (no more portrait crop zoom)
  - Buttons VStack: frame(maxHeight: .infinity) so Spacer() actually expands
    in ZStack context and pushes buttons to bottom of screen
- *(login)* Push buttons further down (bottom padding 28→48pt)
- *(login)* Full-bleed image + buttons pinned to bottom third
- scaledToFill edge-to-edge (no black bars on sides)
  - Spacer(minLength: H*0.62) guarantees buttons in bottom ~38% of screen
- *(login)* Image zoom -5% + buttons to bottom 30%
- *(login)* Image mask fade (no hard edge) + zoom 90% + footer fits
- mask LinearGradient on image ZStack → smooth fade to black, no clip line
  - scaleEffect(0.90) — 10% less zoom total
  - frame height 75%→82% to give mask more room to fade
  - minLength 0.70→0.58 so footer is no longer cut off
- *(login)* Zoom -10% more (0.80) + buttons 20% lower (0.68)
- *(login)* Match Android fade-in (slide 14pt not full screen)
Android uses slideInVertically { fullHeight/3 } = ~14pt slide + fadeIn.
  iOS was using .move(edge: .bottom) = full screen slide, way too dramatic.
- *(login)* ScaledToFit (no black bars) + buttons lower + ignoresSafeArea
- scaledToFit replaces scaledToFill+scaleEffect(0.80) — fills width,
    proportional height, no crop, no shrink-induced black bars
  - minLength 0.68→0.72, bottom spacer 36→16 — buttons lower, footer fits
  - ignoresSafeArea on ZStack — eliminates top/bottom safe area black bars
- *(login)* Revert to scaledToFill (scaledToFit was too zoomed out)
- *(login)* Use same portrait image from Android (1536x2752 vs 1536x1024)
The iOS image was landscape (1024h), requiring heavy zoom to fill portrait screen.
  Android uses a proper portrait image (2752h) — same image, no zoom needed.
- Remove ambiguous Color(hex:) overload causing build failure
Two initializers (UInt with alpha: vs UInt32 with opacity:) made integer
  literals ambiguous. Kept single init(hex: UInt, opacity:) — all callers
  already use this signature.
- Resolve 3 build errors — duplicate types, ambiguous init, missing ref
- StrokePoint: renamed to NoteStrokePoint in NotebookModels to avoid
    ambiguity with PdfAnnotationModels.StrokePoint
  - ShimmerModifier: removed duplicate from FlashcardSessionScreen (already
    defined in VitaShimmer.swift design system component)
  - PushManager: replaced VitaAPI.shared (non-existent singleton) with
    injectable api property, fixed registerPushToken label
- Add @escaping @Sendable to PdfExporter closure params
Task.detached captures closures as @escaping @Sendable, requiring
  the function parameters to be annotated accordingly.
- *(ios)* Add missing .mindMaps case to EstudosSkeleton switch
Non-exhaustive switch on EstudosTab caused BUILD FAILED in CI.
- *(ios)* Resolve 5 Swift compiler errors in MindMap files
- MindMapCanvasView: remove invalid Color(Color) wrapper
  - MindMapCanvasView: VitaColors.border → surfaceBorder (property didn't exist)
  - MindMapCanvasView: use resolved text API for Canvas draw
  - MindMapEditorView: VitaColors.border → surfaceBorder
  - MindMapStore: guard let + try → try? (non-optional binding)
- *(ci)* Configure Git credentials for Match to access private certificates repo
- *(ci)* Use GIT_PAT instead of GITHUB_TOKEN for private repo access
GITHUB_TOKEN cannot access other private repos. Using PAT with repo scope.
- *(ci)* Set Match readonly=false to create certificates on first run
- *(ci)* Configure API Key before Match to avoid Apple ID login
Match now uses App Store Connect API Key instead of requiring Apple ID password.
- *(ci)* Use build.keychain-db to match GitHub Actions keychain
- *(ci)* Use project instead of workspace for build_app
VitaAI uses xcodeproj, not xcworkspace.
- *(ci)* Use Xcode 16.1 to support project format 77
- *(ci)* Add DEVELOPMENT_TEAM to build_app for code signing
- *(ci)* Use manual code signing for Release builds
Set CODE_SIGN_STYLE=Manual and PROVISIONING_PROFILE_SPECIFIER for Release config.
- *(ci)* Resolve codesign hang by configuring keychain partition list
Root cause: codesign process hung for 60 minutes waiting for keychain password prompt that never came in CI.
- *(ci)* Remove premature partition-list command, let Match handle it
Previous error: tried to set partition list on empty keychain (before certs imported).
- *(ci)* Login demo + full error logs + screenshots de todas features novas
- VitaAIApp: suporte a --vita-demo-login injetando sessão antes do AppContainer
    bootar, garantindo que AuthManager encontre token válido na primeira checagem
  - CI: remove tail -50 que cortava erros do compilador; usa tee + grep para
    mostrar erros completos e falhar corretamente com exit 1
  - CI: screenshots cobrem todas as features da sprint de paridade:
    Dashboard (XpBar/Streak), Estudos, FlashcardStats, Insights (4 charts),
    Trabalhos, TrabalhoEditor, Chat (VoiceInput), MindMap
- *(ci)* Use keychain PASSWORD for partition list configuration
Root cause: Match cannot configure partition list with empty password.
  security set-key-partition-list requires valid password to work.
- *(ios)* Resolve duplicate struct declarations for Release build
- *(ci)* Screenshots resilientes — continue-on-error + upload always
- set +e no step de screenshots: taps falhos não abortam o job
  - continue-on-error: true no step: build e upload continuam mesmo se naveg falha
  - if: always() no upload: artifacts são salvos independente de falha de navegação
  - Helpers snap()/tap() com || true para captura best-effort de todas as telas
- *(ci)* Injetar sessão via defaults write antes do app abrir
- TokenStore: lê vita_ci_token de UserDefaults como fallback (DEBUG only),
    evitando dependência do Keychain que não funciona via simctl antes do launch
  - CI: xcrun simctl spawn defaults write injeta token + onboarding ANTES de
    lançar o app, garantindo que AuthManager encontre sessão válida na 1ª leitura
  - Remove --vita-demo-login que não tinha efeito na prática
- *(ci)* Login via ProcessInfo.environment — lê dentro do sandbox
defaults write escreve fora do sandbox (não funciona). A abordagem correta
  é xcrun simctl launch --env que injeta direto no processo do app.

  - TokenStore: VITA_CI_TOKEN via ProcessInfo.environment → token + onboarded
  - CI: xcrun simctl launch --env VITA_CI_TOKEN=demo-ci-token

### Documentation

- *(ios)* Add complete TestFlight setup guide
Comprehensive guide for distributing VitaAI iOS via TestFlight:
  - Prerequisites (Apple Developer Account, Xcode, XcodeGen)
  - Phase 1: Initial setup (certificates, App ID, project config)
  - Phase 2: Build & Archive workflow
  - Phase 3: TestFlight processing
  - Phase 4: Add testers (internal/external)
  - Phase 5: Install on iPhone
  - Phase 6: Update builds
  - Troubleshooting common issues

  Total ETA: 2-4h (first time), 30 min (subsequent builds)
- *(ios)* Add comprehensive README with MindMap + Fastlane info
Complete project documentation:
  - Features list (MindMap highlighted)
  - Recent updates (2026-03-03 MindMap)
  - Development setup (XcodeGen)
  - TestFlight deploy (one-command via Fastlane)
  - Architecture overview
  - Design system summary
  - Testing instructions
  - Parity status with Android
  - CI/CD info
  - Project configuration
  - Resources and links
- Add step-by-step deploy guide
Complete walkthrough for deploying to TestFlight without Mac:
  - 8 numbered steps with exact links
  - Screenshots needed marked
  - Troubleshooting section
  - 30-40 min total ETA
  - Checklist for tracking progress

  Includes check-ready.sh script for verification.

### Features

- VitaAI iOS app — 5 telas implementadas + CI/CD TestFlight
- EstudosScreen: hub de estudo (flashcards, simulados, PDFs, notas)
  - AgendaScreen: planner semanal com timeline unificada
  - InsightsScreen: progresso com stats, matérias e provas
  - TrabalhoScreen: tarefas Canvas + notas
  - VitaChatScreen: chat IA com SSE streaming
  - project.yml: XcodeGen config
  - GitHub Actions: build + TestFlight deploy automático
- Rewrite iOS UI to match vita-ai.cloud web design
- LoginScreen: V badge, Google + email/password form, sign in/up/forgot modes
  - VitaTabBar: 5 tabs matching web MOBILE_TABS (Home, Estudo, Chat center, Agenda, Perfil)
  - AppRouter: remove Trabalho + Insights tabs, 4-tab page view
  - AuthManager: add signInWithEmail, signUpWithEmail, forgotPassword via better-auth
- Add real VitaAI logo as login background (matches Android)
- Add login_bg asset (logo1.png) to Assets.xcassets
  - Revert LoginScreen to Android design: image bg + organic glow + staggered buttons
  - Design now matches bymav-mobile/template/auth/LoginScreen.kt exactly
- *(flashcard)* Implement Anki-style spaced repetition system
- FlashcardViewModel: @Observable VM with SM-2 algorithm, offline fallback to mock,
    fire-and-forget API reviews that never block the session
  - FlashcardCard: 3D Y-axis flip (rotation3DEffect) with drag-to-tilt spring gesture,
    cyan front / indigo back design matching Android
  - RatingButtons: Again/Hard/Good/Easy with SM-2 interval previews and spring press animation
  - FlashcardSessionScreen: progress bar gradient, loading skeleton, timer, error states
  - SessionSummaryScreen: count-up animated stats grid (cards, time, accuracy, streak)
  - FlashcardModels: domain models, FlashcardReviewRequest, FlashcardEntry.toDomain() mapping
  - VitaAPI: reviewFlashcard endpoint (fire-and-forget POST)
  - VitaColors: add dataBlue + dataIndigo semantic tokens
  - Color+Hex: add opacity: label overload for SwiftUI consistency
  - Route: flashcardSession(deckId:) added
  - EstudosScreen: deck rows now tappable, fullScreenCover opens flashcard session
- Add PDF viewer, notes editor, design system, settings & services
5-front parallel implementation bringing iOS to feature parity with Android:

  - Design System: 11 reusable components (VitaButton, VitaShimmer, VitaBottomSheet,
    VitaEmptyState, VitaErrorState, VitaHandle, VitaInput, VitaScreenSkeleton,
    VitaToast, VideoBackground)
  - PDF Viewer: full PDFKit viewer with ink/highlight/shape/text annotations,
    color picker, thumbnail sidebar, undo/redo, export to annotated PDF
  - Notes/Canvas: PencilKit-based notebook editor with FileManager persistence,
    rich toolbar, drawing canvas, notebook list management
  - Settings: AboutScreen, AppearanceScreen (light/dark/system with @AppStorage),
    NotificationSettingsScreen (9 preferences + time picker + system permission check)
  - Services: DeepLinkHandler (12 routes), PushManager (APNs registration),
    SentryConfig (stub ready for SPM package)
  - AppRouter: wired all new navigation destinations (flashcards, pdf, notebooks,
    about, appearance, notifications)
- Complete iOS parity — onboarding, canvas, insights, estudos, swiftdata
Sprint 2: 5-front parallel implementation closing all remaining gaps:

  - Onboarding: enriched all 5 steps to match Android (432→1193 lines),
    stagger animations, university search autocomplete, 4 goal cards,
    semester chip grid, time picker 2x2, dynamic summary card
  - Canvas Connect: new CanvasConnectScreen + ViewModel (488 lines),
    status card, sync flow, connect form matching Android
  - WebAluno: new ConnectScreen + ViewModel + WKWebView (653 lines),
    session cookie capture, PHPSESSID extraction, sync flow
  - Insights: enriched with Swift Charts (392→934 lines), overview card,
    stats row, weekly accuracy chart, WebAluno/Canvas grade rows
  - Estudos: complete rewrite with 4-tab architecture (Disciplinas,
    Notebooks, Flashcards, PDFs), Canvas banner, file download, stagger
  - SwiftData: migrated Notes from FileManager to SwiftData (Room DB
    equivalent), NotebookEntity/PageEntity/AnnotationEntity @Model,
    NotebookRepository, StrokeFileStorage for PencilKit binary data
  - Navigation: all routes fully wired in AppRouter, ProfileScreen
    settings rows connected, DashboardScreen module taps routed
- *(ios)* Implement MindMap feature for P1 parity (9 files + 5 integrations)
Achieves Android parity for MindMap mental organization tool.

  - Domain: MindMapNode/Data/Map models with ARGB color support
  - Data: SwiftData Entity + Repository (JSON serialization like Android)
  - State: MindMapStore @Observable + 2 ViewModels (List/Editor)
  - UI: List (grid 2-col, FAB, empty state, skeleton shimmer)
  - UI: Editor (Canvas pan/zoom/drag, bezier curves, toolbar, dialogs)
  - Canvas: Custom rendering, hit testing, gesture state machine
  - Integration: AppContainer schema + Route + Estudos tab
- *(ios)* Add complete Fastlane automation for TestFlight
Automação 100% do processo build → TestFlight com 1 comando.
- *(ci)* Configure App Store Connect API Key for TestFlight
- Use API Key instead of app-specific password (more secure)
  - Add ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT to workflow
  - Update Fastfile to configure app_store_connect_api_key
  - Add fastlane/keys/ to .gitignore
- *(ci)* Add automated screenshots for multiple screens
Generate 6 screenshots:
  - Launch/Login
  - Dashboard
  - Estudos
  - MindMap List
  - MindMap Editor
  - MindMap Interaction
- *(ios)* Add VitaMarkdown + VitaVoiceInput components (BYM P3)
- *(trabalho)* TrabalhoEditorView — full iOS assignment editor
Port Android AssignmentEditorScreen.kt to SwiftUI/iOS 17+:

  - TrabalhoEditorView: full-screen editor with dark top bar + inline title field
    - Escrever / Visualizar tab switcher with animated transitions
    - Markdown formatting toolbar: bold, italic, H1/H2/H3, lists, blockquote, divider
    - MarkdownPreview: lightweight renderer for Visualizar tab (headings, lists, dividers)
    - Template chooser bottom sheet (VitaBottomSheet + VitaGlassCard cards)
    - AI assistant bottom sheet with quick-prompt chips + placeholder AI response
    - Delete confirmation bottom sheet with haptic feedback
    - Auto-save (3s debounce via Task) + save status indicator
    - Word count badge in bottom bar

  - TrabalhoEditorViewModel (@Observable, @MainActor):
    - loadOrCreate: loads existing draft or creates new with template
    - SwiftData persistence via ModelContext (LocalAssignmentEntity)
    - scheduleAutoSave with Task-based 3s debounce (mirrors Android Job)
    - forceSave on dismiss, deleteAssignment, AI suggestion placeholder

  - LocalAssignmentEntity (@Model SwiftData):
    - Mirrors Android LocalAssignmentEntity Room entity
    - Fields: id, title, content, templateType, status, wordCount, createdAt, updatedAt

  - AssignmentTemplate model + assignmentTemplates list:
    - blank, essay (Redação), report (Relatório), research (Pesquisa), presentation

  - TrabalhoScreen: FAB "Novo Trabalho" + tap-to-edit assignment rows
    - fullScreenCover presentation with editorAssignmentId state

  - AppContainer: LocalAssignmentEntity added to SwiftData Schema

  All tokens from VitaColors.* + VitaTypography.* — zero Color(hex:) literals.
  @Observable + @MainActor throughout. iOS 17+ APIs only.
- *(ios/flashcard)* Add FlashcardStats screen with charts (parity with Android)
- FlashcardStatsView: full stats screen with staggered animations
    - 2 rows of mini stat cards (Total, Hoje, Taxa / Streak, Tempo, Revisões)
    - HeatmapCalendarView: 13-week activity grid with intensity colors
    - RetentionLineChartView: daily retention % using Swift Charts
    - ForecastBarChartView: 7-day due-card forecast bar chart
    - CardDistributionDonutView: new/young/mature breakdown with SectorMark
    - StatsLoadingSkeleton: shimmer placeholders matching Android layout
  - FlashcardStatsViewModel (@Observable, @MainActor):
    - Client-side stats computed from getFlashcardDecks() FSRS state
    - Enriched from getFlashcardStats() API endpoint when available
    - Parallel fetch with graceful fallback (fire-and-forget pattern)
  - VitaAPI: add getFlashcardStats() → study/flashcards/stats
  - FlashcardStatsResponse + DailyRetentionEntry models (Codable)
  - Route.flashcardStats + AppRouter destination wired
  - EstudosScreen.FlashcardsTab: "Ver Estatísticas" entry button (cyan accent)
  - Zero Color(hex:) literals — all VitaColors.* tokens
  - iOS 17+ only: @Observable, SectorMark, Swift Charts
- *(gamification)* Add VitaXpBar, VitaXpToast, VitaStreakBadge, VitaBadgeGrid
Implements P3 gamification components ported from Android VitaXpBar.kt,
  VitaXpToast.kt, VitaStreakBadge.kt, VitaBadgeGrid.kt:
- *(insights)* Add 4 chart components for iOS parity
- RetentionChartView: Ebbinghaus forgetting curve (AreaMark + LineMark via Swift Charts)
  - HeatmapCalendarView: 13-week GitHub-style study intensity calendar grid
  - ForecastBarView: 7-day flashcard review forecast (BarMark) with today highlight
  - CardDistributionDonutView: Novo/Aprendendo/Revisão/Dominado donut (SectorMark, iOS 17+)
  - InsightsChartModels: shared data model types (RetentionPoint, StudyDay, ForecastDay, CardCategory)
  - InsightsViewModel: chart data builders (deterministic, no random values)
  - InsightsScreen: integrate all 4 charts in dedicated Flashcards + Histórico sections
- *(billing)* Stripe paywall for VitaAI iOS (BYM-185) (#2)
* fix(design-system): add Tokens.swift + fix VitaColors drift

  - Add DesignSystem/Tokens.swift (VitaTokens) — auto-generated from
    packages/design-tokens, now lives inside the iOS project
  - VitaColors.swift: replace all Color(hex:) with VitaTokens.* references
    Eliminates hardcoded color drift. Glass opacities (0.025/0.04/0.06) kept
    as-is (no exact token equivalent, intentional)

  New tokens now available: cyan300, indigo400, glowB, glowC,
  bgSubtle, borderSurface

### Miscellaneous

- Add Xcode Cloud pre-build script (XcodeGen)
- Add simulator preview job with screenshots + app bundle
- Builds for iOS Simulator (no signing needed)
  - Boots iPhone 15, installs and launches app
  - Takes screenshot after launch
  - Uploads screenshots as GitHub artifact (view in Actions)
  - Uploads .app zip for Appetize.io interactive testing
- Increase screenshot delay 4s→10s to capture login screen
- Screenshot delay 10s→15s (splash takes longer on CI)
- Add GitHub Actions workflow for cloud build
Build iOS sem Mac usando GitHub Actions macOS runners.
- Add testflight.yml workflow file
Minimal GitHub Actions workflow for iOS build without Mac.
- *(ci)* Add PR title validation and auto changelog (#1)
* fix(design-system): add Tokens.swift + fix VitaColors drift

  - Add DesignSystem/Tokens.swift (VitaTokens) — auto-generated from
    packages/design-tokens, now lives inside the iOS project
  - VitaColors.swift: replace all Color(hex:) with VitaTokens.* references
    Eliminates hardcoded color drift. Glass opacities (0.025/0.04/0.06) kept
    as-is (no exact token equivalent, intentional)

  New tokens now available: cyan300, indigo400, glowB, glowC,
  bgSubtle, borderSurface
- Update changelog

