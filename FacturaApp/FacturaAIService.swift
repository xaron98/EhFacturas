// FacturaAIService.swift
// FacturaApp — Servicio IA legacy para interpretar prompts de factura
// NOTA: Este archivo es legacy. El flujo voice-first usa CommandAIService.
// Se mantiene como referencia y posible uso futuro.

import Foundation
import Combine
import FoundationModels
import SwiftData

// MARK: - Petición de factura generada por IA

@Generable
struct PeticionFacturaIA {
    @Guide(description: "Nombre del cliente tal como lo dice el usuario")
    var nombreCliente: String

    @Guide(description: "Lista de artículos con cantidades, separados por comas")
    var articulosTexto: String

    @Guide(description: "Descuento global en porcentaje (0 si no hay)")
    var descuento: Double

    @Guide(description: "Observaciones adicionales")
    var observaciones: String
}

// MARK: - Servicio legacy

@MainActor
final class FacturaAIService: ObservableObject {

    @Published var estado: EstadoIA = .idle
    @Published var ultimaPeticion: PeticionFacturaIA?
    @Published var error: String?

    enum EstadoIA {
        case idle
        case interpretando
        case resuelto
        case errorIA
    }

    func interpretar(prompt: String) async {
        guard SystemLanguageModel.default.isAvailable else {
            error = "Apple Intelligence no disponible."
            estado = .errorIA
            return
        }

        estado = .interpretando
        error = nil

        do {
            let session = LanguageModelSession {
                """
                Interpreta el siguiente texto como una petición de factura de un autónomo en España.
                Extrae: nombre del cliente, artículos con cantidades, descuento si lo menciona, y observaciones.
                """
            }

            let respuesta = try await session.respond(to: prompt, generating: PeticionFacturaIA.self)
            ultimaPeticion = respuesta.content
            estado = .resuelto
        } catch {
            self.error = error.localizedDescription
            estado = .errorIA
        }
    }

    func reset() {
        estado = .idle
        ultimaPeticion = nil
        error = nil
    }
}
