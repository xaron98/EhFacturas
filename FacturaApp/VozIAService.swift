// VozIAService.swift
// FacturaApp — Text-to-Speech para respuestas de la IA

import Foundation
import AVFoundation

@MainActor
final class VozIAService: ObservableObject {
    static let shared = VozIAService()

    @Published var vozActiva = false
    @Published var vozSeleccionada: TipoVoz = .femenina
    @Published var hablando = false

    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SpeechDelegate?

    enum TipoVoz: String, CaseIterable {
        case femenina = "Femenina"
        case masculina = "Masculina"
        case desactivada = "Desactivada"
    }

    private init() {
        delegate = SpeechDelegate { [weak self] in
            Task { @MainActor in
                self?.hablando = false
            }
        }
        synthesizer.delegate = delegate
    }

    func hablar(_ texto: String) {
        guard vozActiva, vozSeleccionada != .desactivada else { return }

        // Limpiar texto de emojis y símbolos
        let textoLimpio = texto
            .replacingOccurrences(of: "⚠️", with: "")
            .replacingOccurrences(of: "ℹ️", with: "")
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !textoLimpio.isEmpty else { return }

        // Detener habla anterior
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: textoLimpio)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.pitchMultiplier = vozSeleccionada == .femenina ? 1.2 : 0.9
        utterance.volume = 0.9

        // Buscar voz en español
        let voces = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("es") }

        if vozSeleccionada == .femenina {
            // Preferir voces femeninas (Monica, Paulina, etc.)
            if let voz = voces.first(where: { $0.name.contains("Monica") || $0.name.contains("Paulina") || $0.name.contains("Helena") }) {
                utterance.voice = voz
            } else if let voz = voces.first {
                utterance.voice = voz
            }
        } else {
            // Preferir voces masculinas (Jorge, Diego, etc.)
            if let voz = voces.first(where: { $0.name.contains("Jorge") || $0.name.contains("Diego") || $0.name.contains("Juan") }) {
                utterance.voice = voz
            } else if let voz = voces.last {
                utterance.voice = voz
            }
        }

        // Fallback
        if utterance.voice == nil {
            utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
        }

        hablando = true
        synthesizer.speak(utterance)
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
