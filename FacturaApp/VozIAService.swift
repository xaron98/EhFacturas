// VozIAService.swift
// FacturaApp — Text-to-Speech para respuestas de la IA

import Foundation
import AVFoundation

@MainActor
final class VozIAService: ObservableObject {
    static let shared = VozIAService()

    @Published var vozActiva: Bool {
        didSet { UserDefaults.standard.set(vozActiva, forKey: "vozIA_activa") }
    }
    @Published var vozSeleccionada: TipoVoz {
        didSet { UserDefaults.standard.set(vozSeleccionada.rawValue, forKey: "vozIA_tipo") }
    }
    @Published var hablando = false

    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SpeechDelegate?
    private var cachedVoice: AVSpeechSynthesisVoice?
    private var lastVoiceType: TipoVoz?

    enum TipoVoz: String, CaseIterable {
        case femenina = "Femenina"
        case masculina = "Masculina"
        case desactivada = "Desactivada"
    }

    private init() {
        // Load persisted settings
        self.vozActiva = UserDefaults.standard.bool(forKey: "vozIA_activa")
        let tipoGuardado = UserDefaults.standard.string(forKey: "vozIA_tipo") ?? "Femenina"
        self.vozSeleccionada = TipoVoz(rawValue: tipoGuardado) ?? .femenina

        delegate = SpeechDelegate { [weak self] in
            Task { @MainActor in
                self?.hablando = false
            }
        }
        synthesizer.delegate = delegate
    }

    func hablar(_ texto: String) {
        guard vozActiva, vozSeleccionada != .desactivada else { return }

        // Limpiar texto
        let textoLimpio = texto
            .replacingOccurrences(of: "⚠️", with: "")
            .replacingOccurrences(of: "ℹ️", with: "")
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "##", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !textoLimpio.isEmpty else { return }

        // Detener habla anterior
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Cache voice lookup (expensive filesystem scan)
        if cachedVoice == nil || lastVoiceType != vozSeleccionada {
            cachedVoice = resolverVoz()
            lastVoiceType = vozSeleccionada
        }

        let utterance = AVSpeechUtterance(string: textoLimpio)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        utterance.pitchMultiplier = vozSeleccionada == .femenina ? 1.1 : 0.95
        utterance.voice = cachedVoice

        // Configure audio session and speak
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("TTS audio session error: \(error)")
        }

        hablando = true
        synthesizer.speak(utterance)
    }

    private func resolverVoz() -> AVSpeechSynthesisVoice? {
        let voces = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("es") }
        if vozSeleccionada == .femenina {
            return voces.first(where: { $0.name.contains("Mónica") || $0.name.contains("Monica") || $0.name.contains("Paulina") || $0.name.contains("Helena") })
                ?? voces.first(where: { $0.quality == .enhanced })
                ?? voces.first
                ?? AVSpeechSynthesisVoice(language: "es-ES")
        } else {
            return voces.first(where: { $0.name.contains("Jorge") || $0.name.contains("Diego") || $0.name.contains("Juan") || $0.name.contains("Andrés") })
                ?? voces.last
                ?? AVSpeechSynthesisVoice(language: "es-ES")
        }
    }

    func detener() {
        synthesizer.stopSpeaking(at: .immediate)
        hablando = false
    }
}

// Delegate to detect when speech finishes
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let onFinish: @Sendable () -> Void
    init(onFinish: @escaping @Sendable () -> Void) { self.onFinish = onFinish }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }
}
