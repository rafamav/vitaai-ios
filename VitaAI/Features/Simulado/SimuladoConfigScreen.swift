import SwiftUI

// MARK: - SimuladoConfigScreen — matches simulado-config-v1.html mockup exactly

struct SimuladoConfigScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    let onStartSession: (String) -> Void

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            if let vm {
                configContent(vm: vm)
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api, gamificationEvents: container.gamificationEvents) }
            vm?.loadConfigData()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Blue atmospheric background (simulado-config-v1.html)
    // radial-gradient blue tints on #08060a
    private var simuladoBlueAtmosphere: some View {
        ZStack {
            Color(red: 8/255, green: 6/255, blue: 10/255)
            Canvas { ctx, size in
                func drawR(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: Color, _ a: Double) {
                    let px = size.width * cx, py = size.height * cy
                    let rw = size.width * rx, rh = size.height * ry
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - rw, y: py - rh, width: rw * 2, height: rh * 2)),
                        with: .radialGradient(
                            Gradient(colors: [c.opacity(a), .clear]),
                            center: CGPoint(x: px, y: py),
                            startRadius: 0, endRadius: max(rw, rh)
                        )
                    )
                }
                let b1 = Color(red: 60/255, green: 120/255, blue: 200/255)
                let b2 = Color(red: 80/255, green: 160/255, blue: 220/255)
                let b3 = Color(red: 40/255, green: 100/255, blue: 180/255)
                drawR(0.5, 0.20, 0.35, 0.25, b1, 0.08)
                drawR(0.8, 0.60, 0.20, 0.20, b2, 0.05)
                drawR(0.2, 0.80, 0.20, 0.20, b3, 0.04)
            }
        }
    }

    // MARK: - Main content
    @ViewBuilder
    private func configContent(vm: SimuladoViewModel) -> some View {
        VStack(spacing: 0) {
            configTopBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Templates Rápidos
                    sectionLabel("Templates Rápidos")
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    templatesScroll(vm: vm)
                        .padding(.top, 10)

                    // Personalizado
                    sectionLabel("Personalizado")
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    VStack(spacing: 10) {
                        disciplineSection(vm: vm)
                        countSection(vm: vm)
                        timerSection(vm: vm)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Gold CTA
                    ctaButton(vm: vm)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 32)
                }
            }
        }
        .onChange(of: vm.state.currentAttemptId) { newId in
            if let id = newId, !vm.state.isGenerating, !vm.state.questions.isEmpty {
                onStartSession(id)
            }
        }
    }

    // MARK: - Top bar (VitaTopBar style with back button)
    private var configTopBar: some View {
        HStack(spacing: 8) {
            // Avatar ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 2.5)
                    .frame(width: 40, height: 40)
                Circle()
                    .trim(from: 0, to: 0.70)
                    .stroke(
                        LinearGradient(
                            colors: [VitaColors.accent.opacity(0.85), VitaColors.accentDark.opacity(0.65)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                Text("R")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(LinearGradient(
                            colors: [VitaColors.accent.opacity(0.3), VitaColors.accentDark.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    )
                    .clipShape(Circle())

                // Level badge — matches .level-badge in mockup
                Text("7")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(LinearGradient(
                            colors: [VitaColors.accent.opacity(0.35), VitaColors.accentDark.opacity(0.25)],
                            startPoint: .top, endPoint: .bottom
                        ))
                    )
                    .overlay(Capsule().stroke(VitaColors.accentLight.opacity(0.30), lineWidth: 1))
                    .offset(y: 18)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Novo Simulado")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                Text("Configure e inicie")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            Spacer()

            // Back button (chevron left on right side — matches mockup)
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.957, blue: 0.886).opacity(0.68))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(LinearGradient(
                            colors: [Color.white.opacity(0.075), Color.white.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom
                        ))
                    )
                    .overlay(
                        Circle().stroke(Color(red: 1.0, green: 0.878, blue: 0.690).opacity(0.16), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("backButton")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.141, green: 0.094, blue: 0.071).opacity(0.60),
                        Color(red: 0.063, green: 0.043, blue: 0.039).opacity(0.68)
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    Capsule().stroke(Color(red: 1.0, green: 0.910, blue: 0.761).opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.20), radius: 21, x: 0, y: 10)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.clear, Color(red: 1.0, green: 0.961, blue: 0.886).opacity(0.11), .clear],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
        )
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    // MARK: - Section label
    // .label class: 11px bold, rgba(255,220,160,0.55), uppercase, letter-spacing 0.5px
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55))
            .kerning(0.5)
    }

    // MARK: - Templates horizontal scroll
    private func templatesScroll(vm: SimuladoViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.state.templates) { template in
                    templateCard(template) {
                        vm.applyTemplate(template)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    private func templateCard(_ template: SimuladoTemplate, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Icon box: 32x32, rounded 10, gold gradient bg
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [
                                Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.22),
                                Color(red: 0.549, green: 0.392, blue: 0.176).opacity(0.10)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.14), lineWidth: 1)
                        )
                    Image(systemName: template.iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.824, blue: 0.549).opacity(0.85))
                }
                .frame(width: 32, height: 32)
                .padding(.bottom, 10)

                // Name: 12px bold, rgba(255,252,248,0.92)
                Text(template.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.92))
                    .lineLimit(1)
                    .padding(.bottom, 5)

                // Meta: 10px, rgba(255,220,160,0.50)
                let metaText = "\(template.count) questões · \(template.timed ? "\(template.timeLimitMinutes ?? 0)min" : "Livre")"
                Text(metaText)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.50))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minWidth: 130, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: [
                                Color(red: 0.047, green: 0.035, blue: 0.027).opacity(0.92),
                                Color(red: 0.055, green: 0.043, blue: 0.031).opacity(0.88)
                            ],
                            startPoint: .init(x: 0.5, y: 0.025),
                            endPoint: .bottom
                        ))
                    // Bottom-left gold glow
                    RadialGradient(
                        colors: [Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.12), .clear],
                        center: .bottomLeading,
                        startRadius: 0, endRadius: 80
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
            .shadow(color: Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.08), radius: 0, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Discipline section (2-column grid)
    private func disciplineSection(vm: SimuladoViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("DISCIPLINA")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55))
                    .kerning(0.5)

                if vm.state.disciplinesLoading {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 42)
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(vm.state.disciplines) { disc in
                            let isSelected = vm.state.selectedDisciplineName == disc.name
                            discCard(disc.name, isSelected: isSelected) {
                                vm.selectSimuladoDiscipline(isSelected ? nil : disc.name)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func discCard(_ name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Dot indicator
                Circle()
                    .fill(isSelected
                          ? Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.70)
                          : Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.20))
                    .overlay(
                        Circle().stroke(
                            isSelected
                            ? Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.60)
                            : Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.20),
                            lineWidth: 1
                        )
                    )
                    .shadow(
                        color: isSelected ? Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.30) : .clear,
                        radius: 4
                    )
                    .frame(width: 8, height: 8)
                    .flexibleFrame(minWidth: 8)

                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected
                                     ? Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.95)
                                     : Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.80))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? LinearGradient(
                              colors: [
                                  Color(red: 0.094, green: 0.063, blue: 0.031).opacity(0.95),
                                  Color(red: 0.063, green: 0.043, blue: 0.027).opacity(0.92)
                              ],
                              startPoint: .init(x: 0.5, y: 0.025), endPoint: .bottom
                          )
                          : LinearGradient(
                              colors: [
                                  Color(red: 0.047, green: 0.035, blue: 0.024).opacity(0.88),
                                  Color(red: 0.039, green: 0.031, blue: 0.024).opacity(0.85)
                              ],
                              startPoint: .init(x: 0.5, y: 0.025), endPoint: .bottom
                          ))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                        ? Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.36)
                        : Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.30), radius: 6, x: 0, y: 2)
            .shadow(
                color: isSelected ? Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.06) : .clear,
                radius: 7
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Count pills section [10, 25, 50]
    private func countSection(vm: SimuladoViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("NÚMERO DE QUESTÕES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55))
                    .kerning(0.5)

                HStack(spacing: 8) {
                    ForEach([10, 25, 50], id: \.self) { count in
                        countPill(count, isSelected: vm.state.selectedQuestionCount == count) {
                            vm.setQuestionCount(count)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func countPill(_ count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected
                                 ? Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.92)
                                 : Color(red: 1.0, green: 0.941, blue: 0.843).opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected
                              ? Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.14)
                              : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected
                            ? Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.28)
                            : Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.10),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected ? Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.06) : .clear,
                    radius: 6
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer toggle section
    private func timerSection(vm: SimuladoViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cronometrado")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.90))
                    Text("Tempo baseado no número de questões")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 1.0, green: 0.941, blue: 0.843).opacity(0.35))
                }
                Spacer()
                vitaToggle(isOn: vm.state.timedMode) {
                    vm.toggleTimedMode()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
    }

    // Toggle: 44x26px, gold when on
    private func vitaToggle(isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(isOn
                          ? Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.40)
                          : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(
                                isOn
                                ? Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.30)
                                : Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.10),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 44, height: 26)

                Circle()
                    .fill(isOn
                          ? Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.92)
                          : Color(red: 1.0, green: 0.941, blue: 0.843).opacity(0.50))
                    .shadow(
                        color: isOn
                               ? Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.30)
                               : Color.black.opacity(0.30),
                        radius: isOn ? 4 : 3
                    )
                    .frame(width: 18, height: 18)
                    .padding(isOn ? .trailing : .leading, 3)
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isOn)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gold CTA button
    @ViewBuilder
    private func ctaButton(vm: SimuladoViewModel) -> some View {
        if vm.state.isGenerating {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(VitaColors.accentLight)
                    .scaleEffect(0.85)
                Text("Gerando simulado...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
            )
        } else {
            Button(action: { vm.generateSimulado() }) {
                Text("Iniciar Simulado")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .kerning(-0.15)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.80),
                                Color(red: 0.627, green: 0.431, blue: 0.157).opacity(0.65)
                            ],
                            startPoint: .init(x: 0.2, y: 0),
                            endPoint: .init(x: 0.8, y: 1)
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 1.0, green: 0.784, blue: 0.392).opacity(0.18), lineWidth: 1)
                    )
                    // inset top highlight
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.922, blue: 0.706).opacity(0.22))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.top, 1)
                    }
                    .shadow(color: Color(red: 0.784, green: 0.608, blue: 0.275).opacity(0.25), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Helper modifier
private extension View {
    func flexibleFrame(minWidth: CGFloat) -> some View {
        self.frame(minWidth: minWidth)
    }
}
