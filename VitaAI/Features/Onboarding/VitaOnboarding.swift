import SwiftUI
import UserNotifications

// MARK: - VitaOnboarding — Full onboarding flow coordinator
// Steps: Sleep -> Welcome -> Connect -> Syncing -> Subjects -> Notifications -> Trial -> Done

private struct PortalSheetItem: Identifiable {
    let id: String
    var portalType: String { id }
}

struct VitaOnboarding: View {
    @Environment(\.appContainer) private var container
    @State private var step: OnboardingStep = .sleep
    @State private var mascotState: MascotState = .sleeping
    @State private var viewModel: OnboardingViewModel?
    @State private var speechText = ""
    @State private var showContent = false
    @State private var isTyping = false
    @State private var connectSheet: PortalSheetItem?
    @State private var inlineConnectPortal: String?
    @State private var sleepOpacity: Double = 1.0
    @State private var wakeFlash: Double = 0
    @State private var mascotScale: CGFloat = 1.0
    @State private var showManualEntry = false
    @State private var typeTextId: UUID = UUID()
    var userName: String = ""
    var onLogout: (() -> Void)?
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            VitaColors.surface
                .ignoresSafeArea()

            // Enhanced starfield with nebula
            OnboardingStarfieldLayer()
                .ignoresSafeArea()

            // Wake flash overlay
            if wakeFlash > 0 {
                Color.white.opacity(wakeFlash * 0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                // Top bar (progress dots + back/logout button)
                if step != .sleep || onLogout != nil {
                    ZStack {
                        // Back button: left
                        HStack {
                            if step.rawValue > 1 {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    goBack()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.04))
                                        .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                                        .clipShape(Circle())
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(localized: "onboarding_a11y_back"))
                            }
                            Spacer()
                            if let onLogout {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onLogout()
                                } label: {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.04))
                                        .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                                        .clipShape(Circle())
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Sair")
                            }
                        }
                        // Progress dots: centered (exclude sleep, count visible steps)
                        let visibleSteps = OnboardingStep.allCases.filter { $0 != .sleep && !shouldSkipStep($0) }
                        let currentIndex = visibleSteps.firstIndex(of: step) ?? 0
                        OnboardingProgressDots(currentStep: currentIndex, totalDots: visibleSteps.count)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }

                // Mascot (tap to wake on sleep step, hidden during inline portal connect)
                if !(step == .connect && inlineConnectPortal != nil) {
                    VitaMascot(state: mascotState, size: step == .sleep ? 120 : 100)
                        .scaleEffect(mascotScale)
                        .padding(.top, step == .sleep ? 60 : 16)
                        .padding(.bottom, step == .sleep ? 0 : 8)
                        .onTapGesture {
                            if step == .sleep {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                wakeUp()
                            }
                        }
                }

                // Speech bubble + content
                if step == .sleep {
                    SleepStep(onWake: { wakeUp() })
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            if !speechText.isEmpty {
                                OnboardingSpeechBubble(text: speechText, isTyping: isTyping)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 16)
                            }

                            if showContent {
                                stepContent
                                    .padding(.horizontal, 20)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }

                    Spacer()

                    bottomButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
        .animation(.easeInOut(duration: 0.3), value: showContent)
        .sheet(isPresented: $showManualEntry) {
            ManualUniversitySheet { name, city, state in
                showManualEntry = false
                Task {
                    do {
                        try await container.api.requestUniversity(name: name, city: city, state: state)
                        await MainActor.run {
                            mascotState = .happy
                            typeText(String(localized: "onboarding_uni_request_sent"))
                        }
                    } catch {
                        print("[Onboarding] University request failed: \(error)")
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(tokenStore: container.tokenStore, api: container.api)
                Task { await viewModel?.loadUniversities() }
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .sleep:
            EmptyView()

        case .welcome:
            if let vm = viewModel {
                WelcomeStep(viewModel: vm, showManualEntry: $showManualEntry)
            }

        case .connect:
            if let activePortal = inlineConnectPortal {
                OnboardingPortalFlow(
                    portalType: activePortal,
                    university: viewModel?.selectedUniversity,
                    api: container.api,
                    onBack: { withAnimation { inlineConnectPortal = nil } },
                    onConnected: {
                        withAnimation { inlineConnectPortal = nil }
                    }
                )
            } else {
                ConnectStep(university: viewModel?.selectedUniversity, allPortalTypes: viewModel?.allPortalTypes ?? []) { portalType in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3)) {
                        inlineConnectPortal = portalType
                    }
                }
            }

        case .syncing:
            if let vm = viewModel {
                SyncingStep(api: container.api, viewModel: vm)
            }

        case .subjects:
            if let vm = viewModel {
                SubjectsStep(viewModel: vm)
            }

        case .notifications:
            NotificationsStep()

        case .trial:
            TrialStep()

        case .done:
            if let vm = viewModel {
                DoneStep(userName: userName, viewModel: vm)
            }
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                handleBottomButton()
            }) {
                HStack {
                    Text(buttonText)
                        .font(.system(size: 14, weight: .semibold))
                    if step == .done {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(VitaColors.accentLight.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VitaColors.accent.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VitaColors.accent.opacity(0.22), lineWidth: 1)
                        )
                )
            }
            .disabled(step == .welcome && viewModel?.selectedUniversity == nil)
            .opacity(step == .welcome && viewModel?.selectedUniversity == nil ? 0.3 : 1)

            if step == .welcome || step == .connect || step == .subjects {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    nextStep()
                }) {
                    Text(String(localized: "onboarding_btn_skip"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.20))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var buttonText: String {
        switch step {
        case .sleep: return ""
        case .welcome: return String(localized: "onboarding_btn_continue")
        case .connect: return String(localized: "onboarding_btn_continue")
        case .syncing: return String(localized: "onboarding_btn_continue")
        case .subjects: return String(localized: "onboarding_btn_continue")
        case .notifications: return String(localized: "onboarding_btn_notifications")
        case .trial: return String(localized: "onboarding_btn_trial")
        case .done: return String(localized: "onboarding_btn_done")
        }
    }

    // MARK: - Actions

    private func goBack() {
        guard step.rawValue > 1 else { return }
        showContent = false
        var prevRaw = step.rawValue - 1
        // Respect smart-skip: skip back past steps that should be skipped
        while prevRaw > 1, let candidate = OnboardingStep(rawValue: prevRaw), shouldSkipStep(candidate) {
            prevRaw -= 1
        }
        if let prev = OnboardingStep(rawValue: prevRaw) {
            withAnimation(.spring(response: 0.4)) {
                step = prev
                inlineConnectPortal = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { showContent = true }
            }
        }
    }


    private func handleBottomButton() {
        switch step {
        case .notifications:
            requestNotificationPermission()
            nextStep()
        case .done:
            withAnimation(.easeIn(duration: 0.5)) {
                mascotScale = 0.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onComplete()
            }
        default:
            nextStep()
        }
    }

    /// Smart skip: if current step has no useful content, jump to next meaningful step
    private func shouldSkipStep(_ step: OnboardingStep) -> Bool {
        guard let vm = viewModel else { return false }
        switch step {
        case .syncing:
            // Skip syncing if no portal was actually connected during onboarding.
            // Having portals listed for the university doesn't mean the user connected them.
            return vm.activeSyncId == nil
        case .subjects:
            // Skip subjects if sync didn't find any
            return vm.syncedSubjects.isEmpty
        default:
            return false
        }
    }

    private func wakeUp() {
        guard step == .sleep, mascotState == .sleeping else { return }

        // Phase 1: Mascot grows slightly
        withAnimation(.spring(response: 0.4)) {
            mascotScale = 1.15
            mascotState = .waking
        }

        // Phase 2: Flash + mascot awake
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                wakeFlash = 1.0
            }
            withAnimation(.spring(response: 0.4)) {
                mascotState = .awake
            }
        }

        // Phase 3: Flash fades, mascot settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.5)) {
                wakeFlash = 0
                mascotScale = 1.0
            }
        }

        // Phase 4: Transition to welcome
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                step = .welcome
                mascotState = .happy
            }
            let firstName = userName.split(separator: " ").first.map(String.init) ?? ""
            typeText(firstName.isEmpty ? String(localized: "onboarding_welcome_speech") : String(localized: "onboarding_welcome_speech_name").replacingOccurrences(of: "%@", with: firstName))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { showContent = true }
            }
        }
    }

    private func nextStep() {
        showContent = false
        var nextRaw = step.rawValue + 1

        // Smart skip: jump past steps that have no content
        while let candidate = OnboardingStep(rawValue: nextRaw), shouldSkipStep(candidate) {
            nextRaw += 1
        }

        guard let next = OnboardingStep(rawValue: nextRaw) else {
            onComplete()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4)) {
                step = next
            }

            switch next {
            case .connect:
                mascotState = .thinking
                let uniName = viewModel?.selectedUniversity?.shortName ?? ""
                let portalCount = viewModel?.selectedUniversity?.portals?.count ?? 0

                if portalCount > 1 {
                    typeText(String(localized: "onboarding_connect_multi").replacingOccurrences(of: "%1$@", with: uniName).replacingOccurrences(of: "%2$d", with: String(portalCount)))
                } else if portalCount == 1 {
                    let portalName = viewModel?.selectedUniversity?.primaryPortal?.displayName ?? "portal"
                    typeText(String(localized: "onboarding_connect_single").replacingOccurrences(of: "%1$@", with: uniName).replacingOccurrences(of: "%2$@", with: portalName))
                } else {
                    typeText(String(localized: "onboarding_connect_none").replacingOccurrences(of: "%@", with: uniName))
                }

            case .syncing:
                mascotState = .thinking
                let uniName = viewModel?.selectedUniversity?.shortName ?? "tua faculdade"
                typeText(String(localized: "onboarding_syncing_speech").replacingOccurrences(of: "%@", with: uniName))

            case .subjects:
                mascotState = .awake
                typeText(String(localized: "onboarding_subjects_speech"))

            case .notifications:
                mascotState = .happy
                typeText(String(localized: "onboarding_notifications_speech"))

            case .trial:
                mascotState = .happy
                typeText(String(localized: "onboarding_trial_speech"))

            case .done:
                mascotState = .happy
                let first = userName.split(separator: " ").first.map(String.init) ?? ""
                typeText(first.isEmpty ? String(localized: "onboarding_done_speech") : String(localized: "onboarding_done_speech_name").replacingOccurrences(of: "%@", with: first))
                Task { await saveOnboarding() }

            default:
                break
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { showContent = true }
            }
        }
    }

    private func typeText(_ text: String) {
        let currentId = UUID()
        typeTextId = currentId
        speechText = ""
        isTyping = true
        for (index, char) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.018) {
                guard self.typeTextId == currentId else { return }
                speechText += String(char)
                if index == text.count - 1 {
                    isTyping = false
                }
            }
        }
    }

    @ViewBuilder
    private func connectSheetView(for portalType: String) -> some View {
        OnboardingConnectSheet(
            portalType: portalType,
            university: viewModel?.selectedUniversity,
            api: container.api,
            onDismiss: { connectSheet = nil }
        )
    }

    private func saveOnboarding() async {
        guard let vm = viewModel else { return }
        await vm.complete()
        AppConfig.setOnboardingComplete(true)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}
