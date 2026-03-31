import SwiftUI
import WebKit

private let atlasURL = "https://vita-ai.cloud/atlas?embed=1"

// MARK: - AtlasWebViewScreen

struct AtlasWebViewScreen: View {
    var onBack: () -> Void

    @State private var isLoading = true
    @State private var hasError = false

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                topNav

                ZStack {
                    AtlasWebView(
                        urlString: atlasURL,
                        isLoading: $isLoading,
                        hasError: $hasError
                    )

                    if isLoading && !hasError {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(VitaColors.accent)
                    }

                    if hasError {
                        errorState
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")

            VStack(alignment: .leading, spacing: 1) {
                Text("Atlas 3D")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VitaColors.textPrimary)
                Text("Anatomia interativa")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(VitaColors.textSecondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Compartilhar")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(VitaColors.surface)
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(VitaColors.textSecondary)

            Text("Não foi possível carregar o Atlas")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(VitaColors.textPrimary)

            Text("Verifique sua conexão e tente novamente")
                .font(.system(size: 13))
                .foregroundColor(VitaColors.textSecondary)

            Button {
                hasError = false
                isLoading = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Tentar novamente")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(VitaColors.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .strokeBorder(VitaColors.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VitaColors.surface)
    }
}

// MARK: - WKWebView wrapper

private struct AtlasWebView: UIViewRepresentable {
    let urlString: String
    @Binding var isLoading: Bool
    @Binding var hasError: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: AtlasWebView

        init(_ parent: AtlasWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.hasError = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("AtlasWebViewScreen") {
    AtlasWebViewScreen(onBack: {})
        .preferredColorScheme(.dark)
}
#endif
