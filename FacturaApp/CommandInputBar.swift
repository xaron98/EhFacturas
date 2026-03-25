// CommandInputBar.swift
// FacturaApp — Extracted from VoiceMainView
// Bottom input bar with text field, mic, scanner, and send button.

import SwiftUI

struct CommandInputBar: View {
    @Binding var textoManual: String
    @FocusState.Binding var textoFocused: Bool
    let estaEscuchando: Bool
    let procesando: Bool
    let permisoConecido: Bool
    let onEnviar: (String) -> Void
    let onMicTap: () -> Void
    let onScannerTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Text field
            TextField("Escribe un comando...", text: $textoManual)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .focused($textoFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onSubmit {
                    if !textoManual.trimmingCharacters(in: .whitespaces).isEmpty {
                        let cmd = textoManual
                        textoManual = ""
                        onEnviar(cmd)
                    }
                }

            // Dismiss keyboard button (when focused and empty)
            if textoFocused && textoManual.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    textoFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ocultar teclado")
            }

            // Send button
            if !textoManual.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    let cmd = textoManual
                    textoManual = ""
                    onEnviar(cmd)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel("Enviar comando")
            }

            // Scanner button
            Button {
                onScannerTap()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Escanear documento")

            // Mic button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onMicTap()
            } label: {
                Image(systemName: estaEscuchando ? "stop.fill" : "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(estaEscuchando ? .red : .blue)
                    .frame(width: 36, height: 36)
                    .background(estaEscuchando ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(estaEscuchando ? "Detener grabación" : "Activar micrófono")
            .accessibilityHint("Pulsa para hablar un comando")
            .disabled(procesando)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
