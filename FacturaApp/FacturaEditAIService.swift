// FacturaEditAIService.swift
// FacturaApp — Servicio IA para edición contextual de una factura
// Usa AIProvider (Apple Intelligence, Claude o OpenAI) para modificar líneas,
// añadir líneas, eliminar líneas y cambiar descuento.

import Foundation
import SwiftData

// MARK: - FacturaEditAIService

@MainActor
final class FacturaEditAIService: ObservableObject {

    @Published var procesando: Bool = false
    @Published var ultimaRespuesta: String?

    let factura: Factura
    let modelContext: ModelContext
    private var provider: any AIProvider

    var onFacturaUpdated: (() -> Void)?

    init(factura: Factura, modelContext: ModelContext) {
        self.factura = factura
        self.modelContext = modelContext

        let updateCallback: @Sendable () -> Void = { }
        self.provider = AIProviderFactory.makeProvider(
            modelContext: modelContext,
            mode: .edit(factura: factura, onUpdate: updateCallback)
        )
    }

    private func createProvider() {
        let updateCallback: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                self?.onFacturaUpdated?()
            }
        }

        provider = AIProviderFactory.makeProvider(
            modelContext: modelContext,
            mode: .edit(factura: factura, onUpdate: updateCallback)
        )
    }

    private var systemPrompt: String {
        """
        Estás editando la factura \(factura.numeroFactura) del cliente \(factura.clienteNombre).
        Total actual: \(String(format: "%.2f", factura.totalFactura))€

        REGLAS:
        - SIEMPRE usa una herramienta para ejecutar la acción solicitada.
        - NUNCA hagas preguntas. Actúa inmediatamente con la información disponible.
        - Si el usuario pide modificar algo, usa la herramienta correspondiente.
        - Si no especifica unidad, asume "ud" para productos y "h" para servicios.
        - Responde siempre en español con una confirmación breve de lo realizado.
        """
    }

    func procesarComando(_ texto: String) async {
        let textoLimpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textoLimpio.isEmpty else { return }

        guard factura.estado == .borrador else {
            ultimaRespuesta = "Esta factura ya está emitida y no se puede modificar. Puedes crear una factura rectificativa desde la vista de detalle."
            return
        }

        procesando = true
        ultimaRespuesta = nil

        // Recreate provider with proper callback if needed
        if onFacturaUpdated != nil {
            createProvider()
        }

        do {
            let result = try await provider.processCommand(textoLimpio, systemPrompt: systemPrompt)
            ultimaRespuesta = result.text
        } catch {
            ultimaRespuesta = "Error: \(error.localizedDescription)"
        }

        procesando = false
    }
}
