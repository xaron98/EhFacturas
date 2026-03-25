// SpeechService.swift
// FacturaApp — Servicio de reconocimiento de voz
// Usa el framework Speech de Apple para transcribir voz a texto en tiempo real.

import Foundation
import Combine
@preconcurrency import Speech
@preconcurrency import AVFoundation

@MainActor
final class SpeechService: ObservableObject {

    // Estado observable
    @Published var textoTranscrito = ""
    @Published var estaEscuchando = false
    @Published var nivelAudio: Float = 0           // 0.0 - 1.0 para animar el micrófono
    @Published var permisoConecido = false
    @Published var errorMensaje: String?

    private var recognizer: SFSpeechRecognizer?
    // SAFETY: recognitionRequest is set/nil'd only from @MainActor.
    // The audio tap captures a local copy before using it.
    // audioEngine is started/stopped only from @MainActor.
    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    nonisolated(unsafe) private var lastLevelUpdate: Date = .distantPast

    // Timer de silencio: si pasan N segundos sin cambios, finaliza automáticamente
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.5

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    }

    // MARK: - Permisos

    func solicitarPermisos() {
        SFSpeechRecognizer.requestAuthorization { @Sendable status in
            Task { @MainActor [weak self] in
                switch status {
                case .authorized:
                    self?.permisoConecido = true
                case .denied:
                    self?.errorMensaje = "Permiso de voz denegado. Ve a Ajustes > Privacidad > Reconocimiento de voz."
                case .restricted:
                    self?.errorMensaje = "El reconocimiento de voz no está disponible en este dispositivo."
                case .notDetermined:
                    self?.errorMensaje = "Permiso de voz pendiente."
                @unknown default:
                    break
                }
            }
        }

        AVAudioApplication.requestRecordPermission { @Sendable granted in
            Task { @MainActor [weak self] in
                if !granted {
                    self?.errorMensaje = "Permiso de micrófono denegado. Ve a Ajustes > Privacidad > Micrófono."
                }
            }
        }
    }

    /// Pide permisos y luego inicia la escucha automáticamente.
    func solicitarPermisosYEscuchar() {
        SFSpeechRecognizer.requestAuthorization { @Sendable status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.permisoConecido = true
                    // Ahora pedir micrófono
                    AVAudioApplication.requestRecordPermission { @Sendable micGranted in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            if micGranted {
                                self.iniciarEscucha()
                            } else {
                                self.errorMensaje = "Permiso de micrófono denegado. Ve a Ajustes > Privacidad > Micrófono."
                            }
                        }
                    }
                case .denied:
                    self.errorMensaje = "Permiso de voz denegado. Ve a Ajustes > Privacidad > Reconocimiento de voz."
                case .restricted:
                    self.errorMensaje = "El reconocimiento de voz no está disponible en este dispositivo."
                case .notDetermined:
                    self.errorMensaje = "Permiso de voz pendiente."
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Iniciar / Detener escucha

    /// Comienza a escuchar y transcribir.
    func iniciarEscucha() {
        guard !estaEscuchando else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMensaje = "El reconocimiento de voz no está disponible."
            return
        }

        // Cancelar tarea anterior si existe
        recognitionTask?.cancel()
        recognitionTask = nil

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMensaje = "Error configurando audio: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Limpiar texto anterior
        textoTranscrito = ""
        estaEscuchando = true
        errorMensaje = nil

        // Iniciar tarea de reconocimiento
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { @Sendable result, error in
            // Extraer valores antes de cruzar frontera de actor
            let transcription = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let errorMsg: String? = {
                guard let error else { return nil }
                let nsError = error as NSError
                // Ignorar errores de cancelación
                if nsError.domain == "kAFAssistantErrorDomain" { return nil }
                let msg = error.localizedDescription.lowercased()
                if msg.contains("cancel") || msg.contains("interrupted") { return nil }
                return error.localizedDescription
            }()
            let hasError = errorMsg != nil

            Task { @MainActor [weak self] in
                guard let self else { return }

                if let transcription {
                    self.textoTranscrito = transcription
                    self.reiniciarTimerSilencio()
                    if isFinal {
                        self.detenerEscuchaInterna()
                    }
                }

                if hasError {
                    if let errorMsg {
                        self.errorMensaje = errorMsg
                    }
                    self.detenerEscuchaInterna()
                }
            }
        }

        // Conectar audio al reconocedor
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let request = recognitionRequest  // Captura local para evitar data race

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable [weak self] buffer, _ in
            request.append(buffer)
            // Throttle UI updates to ~10fps (every 100ms)
            let now = Date()
            guard let self, now.timeIntervalSince(self.lastLevelUpdate) > 0.1 else { return }
            self.lastLevelUpdate = now
            let level = self.calcularNivelAudio(buffer: buffer)
            Task { @MainActor [weak self] in
                self?.nivelAudio = level
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMensaje = "Error iniciando el motor de audio: \(error.localizedDescription)"
            detenerEscuchaInterna()
        }
    }

    /// Detiene la escucha manualmente.
    func detenerEscucha() {
        detenerEscuchaInterna()
    }

    /// Toggle: si está escuchando para, si no empieza.
    func toggleEscucha() {
        if estaEscuchando {
            detenerEscucha()
        } else {
            iniciarEscucha()
        }
    }

    // MARK: - Internos

    private func detenerEscuchaInterna() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        estaEscuchando = false
        nivelAudio = 0

        // Desactivar sesión de audio
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Reinicia el timer de silencio. Si pasan 2.5s sin cambios, se detiene.
    private func reiniciarTimerSilencio() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { @Sendable _ in
            Task { @MainActor [weak self] in
                self?.detenerEscuchaInterna()
            }
        }
    }

    /// Calcula el nivel de audio del buffer (0.0 - 1.0) para la animación.
    nonisolated private func calcularNivelAudio(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelDataValue[$0] }

        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalized = max(0, min(1, (avgPower + 50) / 50))
        return normalized
    }
}
