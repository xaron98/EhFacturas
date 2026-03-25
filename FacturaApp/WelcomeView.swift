// WelcomeView.swift
// FacturaApp — Extracted from VoiceMainView
// Welcome screen shown when chat is empty: branding, mic button, example commands.

import SwiftUI

struct WelcomeView: View {
    let hayNegocio: Bool
    let estaEscuchando: Bool
    let nivelAudio: Float
    let permisoConecido: Bool
    let onMicTap: () -> Void
    let onEjemploTap: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App branding
            VStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
                    .accessibilityHidden(true)
                Text("FacturaApp")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(hayNegocio ? "Tu asistente de facturación" : "Configura tu negocio para empezar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Mic button
            Button {
                onMicTap()
            } label: {
                ZStack {
                    // Glass background
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 80, height: 80)
                        .shadow(color: estaEscuchando ? .purple.opacity(0.4) : .black.opacity(0.12), radius: estaEscuchando ? 20 : 10)

                    // Border
                    Circle()
                        .stroke(Color(.separator), lineWidth: 1)
                        .frame(width: 80, height: 80)

                    // Audio ring
                    if estaEscuchando {
                        Circle()
                            .stroke(lineWidth: 1.5)
                            .foregroundStyle(.purple.opacity(0.5))
                            .scaleEffect(1.0 + CGFloat(nivelAudio) * 0.4)
                            .animation(.easeOut(duration: 0.1), value: nivelAudio)
                            .frame(width: 80, height: 80)
                    }

                    Image(systemName: estaEscuchando ? "waveform" : "mic.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(estaEscuchando ? .purple : .primary)
                }
            }
            .scaleEffect(estaEscuchando ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: estaEscuchando)
            .buttonStyle(.plain)
            .accessibilityLabel(estaEscuchando ? "Detener grabación" : "Activar micrófono")
            .accessibilityHint("Pulsa para hablar un comando")

            // Examples
            VStack(spacing: 8) {
                Text(hayNegocio ? "Prueba a decir:" : "Di algo como:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(ejemplos, id: \.self) { ejemplo in
                    Button {
                        onEjemploTap(ejemplo)
                    } label: {
                        Text(ejemplo)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Toca para enviar este comando")
                }
            }

            Spacer()
        }
    }

    private var ejemplos: [String] {
        if hayNegocio {
            return [
                "Añade un cliente Juan García, teléfono 612345678",
                "Crea una factura para Juan con 3 bombillas LED",
                "¿Cuánto tengo pendiente de cobrar?"
            ]
        } else {
            return [
                "Me llamo Juan García, NIF 12345678A, teléfono 612345678",
                "Mi negocio es Instalaciones García, estoy en Madrid",
                "Mi email es juan@garcia.es, estoy en la calle Mayor 5"
            ]
        }
    }
}
