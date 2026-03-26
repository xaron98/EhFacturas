// ChatTimelineView.swift
// FacturaApp — Extraido de VoiceMainView
// Timeline de chat con mensajes, indicador de procesando y transcripcion en tiempo real.

import SwiftUI
import SwiftData

struct ChatTimelineView: View {
    let mensajes: [MensajeChat]
    let procesando: Bool
    let hayNegocio: Bool
    let estaEscuchando: Bool
    let nivelAudio: Float
    let permisoConecido: Bool
    let textoTranscrito: String
    let estadoDetallado: String

    let onFacturaTap: (Factura) -> Void
    let onMicTap: () -> Void
    let onEjemploTap: (String) -> Void
    let onTapBackground: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Mensaje de bienvenida si no hay mensajes
                    if mensajes.isEmpty && !procesando {
                        WelcomeView(
                            hayNegocio: hayNegocio,
                            estaEscuchando: estaEscuchando,
                            nivelAudio: nivelAudio,
                            permisoConecido: permisoConecido,
                            onMicTap: { onMicTap() },
                            onEjemploTap: { ejemplo in onEjemploTap(ejemplo) }
                        )
                    }

                    // Mensajes
                    ForEach(mensajes) { msg in
                        ChatMessageView(msg: msg) { factura in
                            onFacturaTap(factura)
                        }
                        .id(msg.id)
                    }

                    // Indicador de procesando
                    if procesando {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(estadoDetallado)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .transition(.scale.combined(with: .opacity))
                        .id("procesando")
                    }

                    // Texto transcrito en tiempo real
                    if estaEscuchando {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text(textoTranscrito.isEmpty ? "Escuchando..." : textoTranscrito)
                                .font(.subheadline)
                                .foregroundStyle(textoTranscrito.isEmpty ? .tertiary : .primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("escuchando")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { onTapBackground() }
            .onChange(of: mensajes.count) { _, _ in
                withAnimation {
                    if let ultimo = mensajes.last {
                        proxy.scrollTo(ultimo.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: estaEscuchando) { _, escuchando in
                if escuchando {
                    withAnimation {
                        proxy.scrollTo("escuchando", anchor: .bottom)
                    }
                }
            }
            .onChange(of: procesando) { _, proc in
                if proc {
                    withAnimation {
                        proxy.scrollTo("procesando", anchor: .bottom)
                    }
                }
            }
        }
    }
}
