# VitaAI iOS — CocoaPods minimal
#
# Único motivo pra existir: Google ML Kit Digital Ink Recognition NÃO tem
# SPM oficial (apenas CocoaPods). Wrappers community estão abandonados desde
# 2023 e não suportam o modulo Digital Ink. CocoaPods é o caminho oficial.
#
# Resto das deps continua via SPM (Sentry, PostHog, GLTFKit2, plcrashreporter)
# — gerenciamento via VitaAI.xcodeproj.
#
# Build via VitaAI.xcworkspace (gerada por `pod install`).
# Scripts atualizados: dev-sim.sh, deploy-testflight.sh, pre-commit hook.

platform :ios, '16.0'
use_frameworks!

target 'VitaAI' do
  # Handwriting → texto digitado (300+ idiomas incl PT-BR, on-device, ~5MB).
  # Substitui Apple Vision VNRecognizeTextRequest que era pra texto impresso.
  pod 'GoogleMLKit/DigitalInkRecognition', '8.0.0'
end

# Recommended para evitar conflitos de min iOS deployment target
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386'
    end
  end
end
