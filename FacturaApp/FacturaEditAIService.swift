// FacturaEditAIService.swift
// FacturaApp — Servicio IA para edición contextual de una factura
// 4 herramientas: modificar línea, añadir línea, eliminar línea, cambiar descuento

import Foundation
import Combine
import FoundationModels
import SwiftData

// MARK: - Helpers compartidos

/// Recalcula totales de la factura, guarda en contexto y notifica la actualización.
private func recalcularYGuardar(factura: Factura, modelContext: ModelContext, onUpdate: @Sendable () -> Void) {
    // Obtener datos del negocio para IRPF
    let negocioDesc = FetchDescriptor<Negocio>()
    let negocio = (try? modelContext.fetch(negocioDesc))?.first

    factura.recalcularTotales(
        irpfPorcentaje: negocio?.irpfPorcentaje ?? 15.0,
        aplicarIRPF: negocio?.aplicarIRPF ?? false
    )

    try? modelContext.save()
    onUpdate()
}

// MARK: - ModificarLineaTool

/// Tool: Modifica una línea existente de la factura buscándola por concepto.
struct ModificarLineaTool: Tool, @unchecked Sendable {
    let name = "modificar_linea"
    let description = """
        Modifica una línea existente de la factura. Busca la línea por concepto (nombre del artículo/servicio). \
        Puedes cambiar la cantidad, el precio unitario o el concepto. \
        Ejemplo: "Cambia las bombillas a 10 unidades" o "Pon el precio de la mano de obra a 35 euros"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Texto del concepto para encontrar la línea (búsqueda parcial, no sensible a mayúsculas)")
        var concepto: String
        @Guide(description: "Nueva cantidad. Usa 0 para no cambiar la cantidad.", .minimum(0))
        var cantidad: Double
        @Guide(description: "Nuevo precio unitario sin IVA. Usa -1 para no cambiar el precio.")
        var precioUnitario: Double
        @Guide(description: "Nuevo texto de concepto. Vacío para no cambiar el concepto.")
        var nuevoConcepto: String
    }

    let factura: Factura
    let modelContext: ModelContext
    let onUpdate: @Sendable () -> Void

    func call(arguments: Arguments) async throws -> String {
        let busqueda = arguments.concepto.lowercased()

        guard let linea = factura.lineas.first(where: { $0.concepto.lowercased().contains(busqueda) }) else {
            let conceptos = factura.lineas.map { $0.concepto }.joined(separator: ", ")
            return "No se encontró ninguna línea con '\(arguments.concepto)'. Líneas actuales: \(conceptos)"
        }

        var cambios: [String] = []

        if arguments.cantidad > 0 {
            linea.cantidad = arguments.cantidad
            cambios.append("cantidad: \(String(format: "%.2f", arguments.cantidad))")
        }

        if arguments.precioUnitario >= 0 {
            linea.precioUnitario = arguments.precioUnitario
            cambios.append("precio: \(String(format: "%.2f", arguments.precioUnitario))€")
        }

        if !arguments.nuevoConcepto.isEmpty {
            linea.concepto = arguments.nuevoConcepto
            cambios.append("concepto: \(arguments.nuevoConcepto)")
        }

        recalcularYGuardar(factura: factura, modelContext: modelContext, onUpdate: onUpdate)

        if cambios.isEmpty {
            return "No se realizaron cambios en '\(linea.concepto)'. Especifica cantidad, precio o nuevo concepto."
        }

        return "Línea '\(linea.concepto)' modificada: \(cambios.joined(separator: ", ")). Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
    }
}

// MARK: - AnadirLineaTool

/// Tool: Añade una nueva línea a la factura.
struct AnadirLineaTool: Tool, @unchecked Sendable {
    let name = "anadir_linea"
    let description = """
        Añade una nueva línea (artículo o servicio) a la factura. \
        Ejemplo: "Añade 3 metros de cable eléctrico a 2,50 euros" o "Añade una hora de mano de obra a 30 euros"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Nombre o descripción del artículo/servicio")
        var concepto: String
        @Guide(description: "Cantidad", .minimum(0.01))
        var cantidad: Double
        @Guide(description: "Precio unitario sin IVA en euros", .minimum(0))
        var precioUnitario: Double
        @Guide(description: "Unidad de medida", .anyOf(["ud", "m", "m²", "h", "kg", "l", "rollo", "caja", "servicio"]))
        var unidad: String
    }

    let factura: Factura
    let modelContext: ModelContext
    let onUpdate: @Sendable () -> Void

    func call(arguments: Arguments) async throws -> String {
        let unidad = UnidadMedida(abreviatura: arguments.unidad) ?? .unidad
        let siguienteOrden = (factura.lineas.map { $0.orden }.max() ?? -1) + 1

        let linea = LineaFactura(
            orden: siguienteOrden,
            concepto: arguments.concepto,
            cantidad: arguments.cantidad,
            unidad: unidad,
            precioUnitario: arguments.precioUnitario,
            porcentajeIVA: 21.0
        )

        factura.lineas.append(linea)
        recalcularYGuardar(factura: factura, modelContext: modelContext, onUpdate: onUpdate)

        let subtotal = arguments.cantidad * arguments.precioUnitario
        return "Línea añadida: \(String(format: "%.0f", arguments.cantidad)) \(unidad.abreviatura) × \(arguments.concepto) a \(String(format: "%.2f", arguments.precioUnitario))€ = \(String(format: "%.2f", subtotal))€. Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
    }
}

// MARK: - EliminarLineaTool

/// Tool: Elimina una línea de la factura buscándola por concepto.
struct EliminarLineaTool: Tool, @unchecked Sendable {
    let name = "eliminar_linea"
    let description = """
        Elimina una línea de la factura buscándola por concepto. \
        Ejemplo: "Quita las bombillas" o "Elimina la mano de obra"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Texto del concepto para encontrar la línea a eliminar (búsqueda parcial, no sensible a mayúsculas)")
        var concepto: String
    }

    let factura: Factura
    let modelContext: ModelContext
    let onUpdate: @Sendable () -> Void

    func call(arguments: Arguments) async throws -> String {
        let busqueda = arguments.concepto.lowercased()

        guard let linea = factura.lineas.first(where: { $0.concepto.lowercased().contains(busqueda) }) else {
            let conceptos = factura.lineas.map { $0.concepto }.joined(separator: ", ")
            return "No se encontró ninguna línea con '\(arguments.concepto)'. Líneas actuales: \(conceptos)"
        }

        let conceptoEliminado = linea.concepto
        factura.lineas.removeAll { $0.persistentModelID == linea.persistentModelID }
        modelContext.delete(linea)

        recalcularYGuardar(factura: factura, modelContext: modelContext, onUpdate: onUpdate)

        return "Línea '\(conceptoEliminado)' eliminada. Quedan \(factura.lineas.count) línea(s). Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
    }
}

// MARK: - CambiarDescuentoTool

/// Tool: Cambia el descuento global de la factura.
struct CambiarDescuentoTool: Tool, @unchecked Sendable {
    let name = "cambiar_descuento"
    let description = """
        Cambia el porcentaje de descuento global de la factura. \
        Ejemplo: "Aplica un 10% de descuento" o "Quita el descuento"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Porcentaje de descuento global (0-100). Usa 0 para quitar el descuento.", .range(0...100))
        var porcentaje: Double
    }

    let factura: Factura
    let modelContext: ModelContext
    let onUpdate: @Sendable () -> Void

    func call(arguments: Arguments) async throws -> String {
        let anterior = factura.descuentoGlobalPorcentaje
        factura.descuentoGlobalPorcentaje = arguments.porcentaje

        recalcularYGuardar(factura: factura, modelContext: modelContext, onUpdate: onUpdate)

        if arguments.porcentaje == 0 {
            return "Descuento eliminado (antes era \(String(format: "%.1f", anterior))%). Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
        }

        return "Descuento global cambiado a \(String(format: "%.1f", arguments.porcentaje))%. Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
    }
}

// MARK: - FacturaEditAIService

@MainActor
final class FacturaEditAIService: ObservableObject {

    @Published var procesando: Bool = false
    @Published var ultimaRespuesta: String?

    let factura: Factura
    let modelContext: ModelContext
    private var session: LanguageModelSession?

    var onFacturaUpdated: (() -> Void)?

    init(factura: Factura, modelContext: ModelContext) {
        self.factura = factura
        self.modelContext = modelContext
        crearSesion()
    }

    private func crearSesion() {
        let updateCallback: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                self?.onFacturaUpdated?()
            }
        }

        session = LanguageModelSession(
            tools: [
                ModificarLineaTool(factura: factura, modelContext: modelContext, onUpdate: updateCallback),
                AnadirLineaTool(factura: factura, modelContext: modelContext, onUpdate: updateCallback),
                EliminarLineaTool(factura: factura, modelContext: modelContext, onUpdate: updateCallback),
                CambiarDescuentoTool(factura: factura, modelContext: modelContext, onUpdate: updateCallback)
            ]
        ) {
            """
            Estás editando la factura \(self.factura.numeroFactura) del cliente \(self.factura.clienteNombre).
            Total actual: \(String(format: "%.2f", self.factura.totalFactura))€

            REGLAS:
            - SIEMPRE usa una herramienta para ejecutar la acción solicitada.
            - NUNCA hagas preguntas. Actúa inmediatamente con la información disponible.
            - Si el usuario pide modificar algo, usa la herramienta correspondiente.
            - Si no especifica unidad, asume "ud" para productos y "h" para servicios.
            - Responde siempre en español con una confirmación breve de lo realizado.
            """
        }
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

        if session == nil {
            crearSesion()
        }

        guard let session else {
            procesando = false
            ultimaRespuesta = "Error: No se pudo crear la sesión de IA."
            return
        }

        do {
            let response = try await session.respond(to: textoLimpio)
            ultimaRespuesta = response.content
        } catch {
            ultimaRespuesta = "Error: \(error.localizedDescription)"
        }

        procesando = false
    }
}
