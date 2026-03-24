// CommandAIService.swift
// FacturaApp — Servicio de comandos por voz/texto
// IA que controla toda la app: crea clientes, artículos, facturas,
// busca datos, cambia estados — todo por lenguaje natural.

import Foundation
import SwiftData

// MARK: - Resultado de un comando

/// Lo que devuelve la IA después de procesar un comando del usuario.
struct ComandoResultado {
    var mensaje: String                     // Respuesta para mostrar al usuario
    var accionRealizada: AccionRealizada
    var facturaID: PersistentIdentifier?     // ID de factura creada (si aplica)

    enum AccionRealizada {
        case clienteCreado
        case clienteEncontrado
        case articuloCreado
        case articuloEncontrado
        case facturaBorradorCreada
        case facturaEmitida
        case facturaMarcadaPagada
        case listaClientes
        case listaArticulos
        case listaFacturas
        case importarSolicitado
        case informacion
        case error
    }
}

// MARK: - Servicio principal de comandos

@MainActor
final class CommandAIService: ObservableObject {

    @Published var estado: Estado = .listo
    @Published var ultimaRespuesta: ComandoResultado?
    @Published var historial: [EntradaHistorial] = []
    @Published var solicitarImportacion: TipoImportacion?

    enum Estado: Equatable {
        case listo
        case procesando(String)
        case respondido
        case error(String)
    }

    struct EntradaHistorial: Identifiable {
        let id = UUID()
        let timestamp: Date
        let comando: String
        let respuesta: String
        let accion: ComandoResultado.AccionRealizada
    }

    private let modelContext: ModelContext
    private var provider: any AIProvider

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.provider = AIProviderFactory.makeProvider(modelContext: modelContext, mode: .command)
    }

    // MARK: - Verificar disponibilidad

    var iaDisponible: Bool {
        provider.isAvailable
    }

    var razonNoDisponible: String {
        provider.unavailableReason
    }

    // MARK: - Procesar comando

    func procesarComando(_ texto: String) async {
        let textoLimpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textoLimpio.isEmpty else { return }

        estado = .procesando("Pensando...")

        do {
            let result = try await provider.processCommand(textoLimpio, systemPrompt: systemPrompt)
            let respuestaTexto = result.text

            // Determinar qué tipo de acción se realizó
            let accion = determinarAccion(respuesta: respuestaTexto, comando: textoLimpio)

            // Si se creó una factura, buscar la más reciente
            var facturaID: PersistentIdentifier?
            if accion == .facturaBorradorCreada {
                var desc = FetchDescriptor<Factura>(
                    sortBy: [SortDescriptor(\.fechaCreacion, order: .reverse)]
                )
                desc.fetchLimit = 1
                if let factura = (try? modelContext.fetch(desc))?.first {
                    facturaID = factura.persistentModelID
                }
            }

            let resultado = ComandoResultado(
                mensaje: respuestaTexto,
                accionRealizada: accion,
                facturaID: facturaID
            )

            ultimaRespuesta = resultado
            estado = .respondido

            // Si se configuró el negocio, recrear provider para salir del modo onboarding
            if respuestaTexto.lowercased().contains("configurado") {
                provider.resetSession()
            }

            // Añadir al historial
            historial.insert(EntradaHistorial(
                timestamp: .now,
                comando: textoLimpio,
                respuesta: respuestaTexto,
                accion: accion
            ), at: 0)

            // Limitar historial a 50 entradas
            if historial.count > 50 {
                historial = Array(historial.prefix(50))
            }

        } catch {
            let msg = "Error: \(error.localizedDescription)"
            estado = .error(msg)
            ultimaRespuesta = ComandoResultado(mensaje: msg, accionRealizada: .error)
        }
    }

    // MARK: - System prompt

    var systemPrompt: String {
        """
        Eres el asistente de facturación para autónomos y pequeñas empresas en España.
        Responde siempre en español, de forma breve y cercana.

        === MODO ONBOARDING (configuración inicial) ===
        Si el negocio NO está configurado aún, guía al usuario paso a paso preguntando UN dato cada vez:
        1. Primero pregunta: nombre del negocio o del autónomo
        2. Cuando responda, pregunta: NIF o CIF
        3. Luego: teléfono
        4. Luego: email
        5. Luego: dirección fiscal (calle, número)
        6. Luego: código postal y ciudad
        7. Luego: provincia

        Cuando el usuario responda a cada pregunta, recuerda los datos. Cuando tengas al menos nombre y NIF, puedes usar configurar_negocio con todos los datos recopilados hasta ese momento. Si el usuario da varios datos de golpe ("me llamo Juan, NIF 12345678A, estoy en Madrid"), usa configurar_negocio inmediatamente con todo.

        Después de configurar, di: "¡Listo! Tu negocio está configurado. Ya puedes crear clientes, artículos y facturas. ¿Qué quieres hacer?"

        === MODO NORMAL (negocio ya configurado) ===
        REGLA ABSOLUTA: EJECUTA LA HERRAMIENTA INMEDIATAMENTE. NUNCA preguntes nada. NUNCA pidas confirmación. NUNCA preguntes por descuentos, observaciones ni datos opcionales. Si no se mencionan, déjalos vacíos o a 0.

        - "créame una factura para Juan con 43 bombillas" → usa crear_factura YA con descuento=0 y observaciones="".
        - "añade un cliente Pedro" → usa crear_cliente YA. Campos que falten, vacíos.
        - "añade bombilla LED a 3,50" → usa crear_articulo YA.
        - "3 con 50" o "tres con cincuenta" → interpreta como 3.50€.
        - Si no especifica cantidad, asume 1. Unidad: "ud" para productos, "h" para servicios.
        - Si no especifica precio, usa 0.
        - Si no especifica descuento, usa 0. NO preguntes.
        - Si no especifica observaciones, deja vacío. NO preguntes.
        - "mi NIF es..." o "mi teléfono es..." → usa configurar_negocio para actualizar.
        - "anula la factura de Juan" o "borra la última factura" → usa anular_factura.
        - "importa artículos de Salfon" o "carga clientes desde CSV" → usa importar_datos con tipo "articulos" o "clientes".
        - Las facturas emitidas NO se pueden modificar → "Rectificar" en la vista de factura.
        - Después de ejecutar, confirma en UNA frase corta. No preguntes si quiere algo más.
        """
    }

    // MARK: - Determinar acción

    private func determinarAccion(respuesta: String, comando: String) -> ComandoResultado.AccionRealizada {
        let r = respuesta.lowercased()
        let c = comando.lowercased()

        // Detectar importación
        if respuesta.contains("IMPORTAR_ARTICULOS") {
            solicitarImportacion = .articulos
            return .importarSolicitado
        }
        if respuesta.contains("IMPORTAR_CLIENTES") {
            solicitarImportacion = .clientes
            return .importarSolicitado
        }

        if r.contains("cliente") && (r.contains("creado") || r.contains("añadido") || r.contains("dado de alta")) {
            return .clienteCreado
        }
        if r.contains("artículo") && (r.contains("creado") || r.contains("añadido")) {
            return .articuloCreado
        }
        if r.contains("factura") && (r.contains("creada") || r.contains("generada")) {
            return .facturaBorradorCreada
        }
        if r.contains("pagada") || r.contains("cobrada") {
            return .facturaMarcadaPagada
        }
        if r.contains("encontrado") && c.contains("cliente") {
            return .clienteEncontrado
        }
        if r.contains("encontrado") && (c.contains("artículo") || c.contains("producto")) {
            return .articuloEncontrado
        }
        if r.contains("resumen") || r.contains("pendiente") || r.contains("factura(s)") {
            return .listaFacturas
        }

        return .informacion
    }
}
