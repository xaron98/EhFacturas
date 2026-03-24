// FacturaAIView.swift
// FacturaApp — Vista IA legacy para interpretar y resolver facturas
// NOTA: Este archivo es legacy. El flujo voice-first usa VoiceMainView.
// Se mantiene como referencia y posible uso futuro.

import SwiftUI
import SwiftData

struct FacturaAIView: View {

    @Environment(\.modelContext) private var modelContext
    @StateObject private var aiService = FacturaAIService()
    @State private var promptTexto = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Campo de entrada
                VStack(alignment: .leading, spacing: 8) {
                    Text("Describe la factura")
                        .font(.headline)

                    TextEditor(text: $promptTexto)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Ejemplo: \"Factura para Juan García con 5 bombillas LED y 2 horas de mano de obra\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Botón interpretar
                Button {
                    Task {
                        await aiService.interpretar(prompt: promptTexto)
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Interpretar con IA")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(promptTexto.trimmingCharacters(in: .whitespaces).isEmpty || aiService.estado == .interpretando)
                .padding(.horizontal)

                // Estado
                switch aiService.estado {
                case .idle:
                    EmptyView()

                case .interpretando:
                    ProgressView("Interpretando...")

                case .resuelto:
                    if let peticion = aiService.ultimaPeticion {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Interpretación", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)

                            Group {
                                HStack {
                                    Text("Cliente:")
                                        .fontWeight(.medium)
                                    Text(peticion.nombreCliente)
                                }
                                HStack {
                                    Text("Artículos:")
                                        .fontWeight(.medium)
                                    Text(peticion.articulosTexto)
                                }
                                if peticion.descuento > 0 {
                                    HStack {
                                        Text("Descuento:")
                                            .fontWeight(.medium)
                                        Text("\(String(format: "%.0f", peticion.descuento))%")
                                    }
                                }
                                if !peticion.observaciones.isEmpty {
                                    HStack {
                                        Text("Notas:")
                                            .fontWeight(.medium)
                                        Text(peticion.observaciones)
                                    }
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                case .errorIA:
                    if let error = aiService.error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .padding()
                    }
                }

                Spacer()
            }
            .navigationTitle("Factura IA")
        }
    }
}
