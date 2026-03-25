// AppleAIProvider.swift
// FacturaApp — Apple Intelligence provider using FoundationModels

#if canImport(FoundationModels)
import Foundation
import FoundationModels
import SwiftData

// MARK: - AppleAIProvider

@available(iOS 26, *)
@MainActor
final class AppleAIProvider: AIProvider {
    private var session: LanguageModelSession?
    private let modelContext: ModelContext
    private let factura: Factura?
    private let onUpdate: (@Sendable () -> Void)?
    let providerType: AIProviderType = .apple

    init(modelContext: ModelContext, factura: Factura? = nil, onUpdate: (@Sendable () -> Void)? = nil) {
        self.modelContext = modelContext
        self.factura = factura
        self.onUpdate = onUpdate
    }

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    var unavailableReason: String {
        switch SystemLanguageModel.default.availability {
        case .available: return ""
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Activa Apple Intelligence en Ajustes."
        case .unavailable(.modelNotReady):
            return "El modelo se está descargando..."
        case .unavailable(.deviceNotEligible):
            return "Dispositivo no compatible con Apple Intelligence."
        default:
            return "Modelo no disponible."
        }
    }

    func processCommand(_ text: String, systemPrompt: String) async throws -> AICommandResult {
        if session == nil {
            createSession(systemPrompt: systemPrompt)
        }
        guard let session else {
            return AICommandResult(text: "Error creando sesión de IA.")
        }
        let response = try await session.respond(to: text)
        return AICommandResult(text: response.content)
    }

    func resetSession() {
        session = nil
    }

    private func createSession(systemPrompt: String) {
        if let factura, let onUpdate {
            // Edit mode — 4 tools
            session = LanguageModelSession(
                tools: [
                    AppleModificarLineaTool(factura: factura, modelContext: modelContext, onUpdate: onUpdate),
                    AppleAnadirLineaTool(factura: factura, modelContext: modelContext, onUpdate: onUpdate),
                    AppleEliminarLineaTool(factura: factura, modelContext: modelContext, onUpdate: onUpdate),
                    AppleCambiarDescuentoTool(factura: factura, modelContext: modelContext, onUpdate: onUpdate)
                ]
            ) { systemPrompt }
        } else {
            // Command mode — 11 tools
            session = LanguageModelSession(
                tools: [
                    AppleConfigurarNegocioTool(modelContext: modelContext),
                    AppleCrearClienteTool(modelContext: modelContext),
                    AppleBuscarClienteTool(modelContext: modelContext),
                    AppleCrearArticuloTool(modelContext: modelContext),
                    AppleBuscarArticuloTool(modelContext: modelContext),
                    AppleCrearFacturaTool(modelContext: modelContext),
                    AppleMarcarPagadaTool(modelContext: modelContext),
                    AppleAnularFacturaTool(modelContext: modelContext),
                    AppleImportarDatosTool(modelContext: modelContext),
                    AppleConsultarResumenTool(modelContext: modelContext),
                    AppleRegistrarGastoTool(modelContext: modelContext),
                    AppleDeshacerTool(modelContext: modelContext)
                ]
            ) { systemPrompt }
        }
    }
}

// MARK: - Command Tools (10)

// MARK: AppleConfigurarNegocioTool

@available(iOS 26, *)
struct AppleConfigurarNegocioTool: Tool, @unchecked Sendable {
    let name = "configurar_negocio"
    let description = """
        Configura los datos del negocio del autónomo. Usa esta herramienta cuando el usuario \
        diga su nombre, NIF, dirección, teléfono o email para configurar el negocio. \
        También cuando diga "me llamo...", "mi NIF es...", "mi empresa se llama...".
        """

    @Generable
    struct Arguments {
        @Guide(description: "Nombre del negocio o nombre del autónomo")
        var nombre: String
        @Guide(description: "NIF o CIF. Vacío si no se proporciona.")
        var nif: String
        @Guide(description: "Dirección fiscal. Vacía si no se proporciona.")
        var direccion: String
        @Guide(description: "Ciudad. Vacía si no se proporciona.")
        var ciudad: String
        @Guide(description: "Provincia. Vacía si no se proporciona.")
        var provincia: String
        @Guide(description: "Código postal. Vacío si no se proporciona.")
        var codigoPostal: String
        @Guide(description: "Teléfono. Vacío si no se proporciona.")
        var telefono: String
        @Guide(description: "Email. Vacío si no se proporciona.")
        var email: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.configurarNegocio(
            ConfigurarNegocioParams(
                nombre: arguments.nombre,
                nif: arguments.nif,
                direccion: arguments.direccion,
                ciudad: arguments.ciudad,
                provincia: arguments.provincia,
                codigoPostal: arguments.codigoPostal,
                telefono: arguments.telefono,
                email: arguments.email
            ),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleCrearClienteTool

@available(iOS 26, *)
struct AppleCrearClienteTool: Tool, @unchecked Sendable {
    let name = "crear_cliente"
    let description = """
        Crea un nuevo cliente en la base de datos. Usa esta herramienta cuando el usuario \
        quiera añadir, crear o dar de alta un cliente nuevo. \
        Ejemplo: "Añade un cliente que se llama Juan García, teléfono 612345678"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Nombre completo del cliente")
        var nombre: String
        @Guide(description: "NIF o CIF del cliente. Vacío si no se proporciona.")
        var nif: String
        @Guide(description: "Teléfono. Vacío si no se proporciona.")
        var telefono: String
        @Guide(description: "Email. Vacío si no se proporciona.")
        var email: String
        @Guide(description: "Dirección completa. Vacía si no se proporciona.")
        var direccion: String
        @Guide(description: "Ciudad. Vacía si no se proporciona.")
        var ciudad: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.crearCliente(
            CrearClienteParams(
                nombre: arguments.nombre,
                nif: arguments.nif,
                telefono: arguments.telefono,
                email: arguments.email,
                direccion: arguments.direccion,
                ciudad: arguments.ciudad
            ),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleBuscarClienteTool

@available(iOS 26, *)
struct AppleBuscarClienteTool: Tool, @unchecked Sendable {
    let name = "buscar_cliente"
    let description = """
        Busca clientes en la base de datos por nombre o teléfono. \
        Usa esta herramienta cuando el usuario pregunte por un cliente, \
        quiera ver sus datos, o necesites encontrar un cliente para una factura.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Término de búsqueda: nombre, teléfono o parte del nombre")
        var consulta: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.buscarCliente(
            BuscarClienteParams(consulta: arguments.consulta),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleCrearArticuloTool

@available(iOS 26, *)
struct AppleCrearArticuloTool: Tool, @unchecked Sendable {
    let name = "crear_articulo"
    let description = """
        Crea un nuevo artículo, producto o servicio en el catálogo. \
        Usa esta herramienta cuando el usuario quiera añadir un nuevo producto, \
        material o servicio al catálogo. \
        Ejemplo: "Añade bombilla LED E27 a 3,50 euros"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Nombre del artículo o servicio")
        var nombre: String
        @Guide(description: "Precio de venta sin IVA en euros", .minimum(0))
        var precioUnitario: Double
        @Guide(description: "Referencia o código. Vacío si no se proporciona.")
        var referencia: String
        @Guide(description: "Unidad de medida", .anyOf(["ud", "m", "m²", "h", "kg", "l", "rollo", "caja", "servicio"]))
        var unidad: String
        @Guide(description: "Nombre del proveedor. Vacío si no se proporciona.")
        var proveedor: String
        @Guide(description: "Precio de coste en euros. 0 si no se proporciona.", .minimum(0))
        var precioCoste: Double
        @Guide(description: "Etiquetas para búsqueda separadas por comas. Ej: led, iluminación, bajo consumo")
        var etiquetas: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.crearArticulo(
            CrearArticuloParams(
                nombre: arguments.nombre,
                precioUnitario: arguments.precioUnitario,
                referencia: arguments.referencia,
                unidad: arguments.unidad,
                proveedor: arguments.proveedor,
                precioCoste: arguments.precioCoste,
                etiquetas: arguments.etiquetas
            ),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleBuscarArticuloTool

@available(iOS 26, *)
struct AppleBuscarArticuloTool: Tool, @unchecked Sendable {
    let name = "buscar_articulo"
    let description = """
        Busca artículos en el catálogo por nombre, referencia o etiquetas. \
        Usa esta herramienta para encontrar productos cuando el usuario \
        pregunte por precios, stock, o para resolver artículos de una factura.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Término de búsqueda: nombre del producto, referencia o descripción")
        var consulta: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.buscarArticulo(
            BuscarArticuloParams(consulta: arguments.consulta),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleCrearFacturaTool

@available(iOS 26, *)
struct AppleCrearFacturaTool: Tool, @unchecked Sendable {
    let name = "crear_factura"
    let description = """
        Crea una nueva factura borrador o presupuesto con un cliente y artículos. \
        Usa esta herramienta cuando el usuario quiera generar, hacer o crear una factura o presupuesto. \
        Ejemplo: "Hazme una factura para Juan García con 5 bombillas LED y 2 horas de mano de obra" \
        Si el usuario dice "presupuesto para..." usa esPresupuesto=true.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Nombre del cliente")
        var nombreCliente: String
        @Guide(description: "Artículos con cantidad. Formato: 'cantidad nombre'. Ej: '5 bombillas LED, 2 horas mano de obra'")
        var articulosTexto: String
        @Guide(description: "Descuento global en porcentaje. 0 si no hay descuento.", .range(0...100))
        var descuento: Double
        @Guide(description: "Observaciones o notas. Vacío si no hay.")
        var observaciones: String
        @Guide(description: "true si es un presupuesto, false si es una factura")
        var esPresupuesto: Bool
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.crearFactura(
            CrearFacturaParams(
                nombreCliente: arguments.nombreCliente,
                articulosTexto: arguments.articulosTexto,
                descuento: arguments.descuento,
                observaciones: arguments.observaciones,
                esPresupuesto: arguments.esPresupuesto
            ),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleMarcarPagadaTool

@available(iOS 26, *)
struct AppleMarcarPagadaTool: Tool, @unchecked Sendable {
    let name = "marcar_pagada"
    let description = """
        Marca una factura como pagada/cobrada. \
        Usa esta herramienta cuando el usuario diga que ha cobrado una factura. \
        Ejemplo: "La factura de Juan García ya está cobrada"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Número de factura o nombre del cliente para identificar la factura")
        var identificador: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.marcarPagada(
            MarcarPagadaParams(identificador: arguments.identificador),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleAnularFacturaTool

@available(iOS 26, *)
struct AppleAnularFacturaTool: Tool, @unchecked Sendable {
    let name = "anular_factura"
    let description = """
        Anula una factura. Usa esta herramienta cuando el usuario quiera anular, cancelar o borrar una factura. \
        Ejemplo: "Anula la factura de Juan" o "Borra la última factura"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Número de factura o nombre del cliente para identificar la factura")
        var identificador: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.anularFactura(
            AnularFacturaParams(identificador: arguments.identificador),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleImportarDatosTool

@available(iOS 26, *)
struct AppleImportarDatosTool: Tool, @unchecked Sendable {
    let name = "importar_datos"
    let description = """
        Abre el importador de datos CSV/Excel. Usa esta herramienta cuando el usuario \
        quiera importar artículos o clientes desde un archivo, CSV, o desde otro programa \
        como Salfon, Contaplus, Holded, etc. \
        Ejemplo: "Importa artículos de Salfon" o "Carga clientes desde un archivo"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Tipo de datos a importar", .anyOf(["articulos", "clientes"]))
        var tipo: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.importarDatos(
            ImportarDatosParams(tipo: arguments.tipo),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleConsultarResumenTool

@available(iOS 26, *)
struct AppleConsultarResumenTool: Tool, @unchecked Sendable {
    let name = "consultar_resumen"
    let description = """
        Consulta el resumen del estado actual: facturas pendientes, cobradas, vencidas, \
        totales, número de clientes y artículos. \
        Usa esta herramienta cuando el usuario pregunte cómo va el negocio, \
        cuánto tiene pendiente, o pida un resumen.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Tipo de resumen", .anyOf(["general", "pendientes", "cobradas", "vencidas", "clientes", "articulos"]))
        var tipo: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.consultarResumen(
            ConsultarResumenParams(tipo: arguments.tipo),
            modelContext: modelContext
        ) }
    }
}

// MARK: AppleDeshacerTool

@available(iOS 26, *)
struct AppleDeshacerTool: Tool, @unchecked Sendable {
    let name = "deshacer"
    let description = """
        Deshace la última acción (crear cliente, artículo o factura). \
        Usa cuando el usuario diga 'deshaz', 'deshacer', 'anula lo último' o 'no quería eso'.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Motivo del deshacer. Vacío si no se da.")
        var motivo: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.deshacerUltimaAccion(modelContext: modelContext) }
    }
}

// MARK: AppleRegistrarGastoTool

@available(iOS 26, *)
struct AppleRegistrarGastoTool: Tool, @unchecked Sendable {
    let name = "registrar_gasto"
    let description = """
        Registra un gasto o compra del negocio. Usa esta herramienta cuando el usuario diga que ha \
        comprado algo, ha tenido un gasto, o quiera registrar una compra. \
        Ejemplo: "He comprado material por 50 euros" o "Gasto de gasolina 30 euros"
        """

    @Generable
    struct Arguments {
        @Guide(description: "Concepto del gasto")
        var concepto: String
        @Guide(description: "Importe en euros", .minimum(0))
        var importe: Double
        @Guide(description: "Categoria: material, herramientas, vehiculo, oficina, formacion, seguros, otros")
        var categoria: String
        @Guide(description: "Proveedor. Vacio si no se da.")
        var proveedor: String
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { FacturaActions.registrarGasto(
            RegistrarGastoParams(
                concepto: arguments.concepto,
                importe: arguments.importe,
                categoria: arguments.categoria,
                proveedor: arguments.proveedor
            ),
            modelContext: modelContext
        ) }
    }
}

// MARK: - Edit Tools (4)

// MARK: AppleModificarLineaTool

@available(iOS 26, *)
struct AppleModificarLineaTool: Tool, @unchecked Sendable {
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
        await MainActor.run { FacturaActions.modificarLinea(
            ModificarLineaParams(
                concepto: arguments.concepto,
                cantidad: arguments.cantidad,
                precioUnitario: arguments.precioUnitario,
                nuevoConcepto: arguments.nuevoConcepto
            ),
            factura: factura,
            modelContext: modelContext,
            onUpdate: onUpdate
        ) }
    }
}

// MARK: AppleAnadirLineaTool

@available(iOS 26, *)
struct AppleAnadirLineaTool: Tool, @unchecked Sendable {
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
        await MainActor.run { FacturaActions.anadirLinea(
            AnadirLineaParams(
                concepto: arguments.concepto,
                cantidad: arguments.cantidad,
                precioUnitario: arguments.precioUnitario,
                unidad: arguments.unidad
            ),
            factura: factura,
            modelContext: modelContext,
            onUpdate: onUpdate
        ) }
    }
}

// MARK: AppleEliminarLineaTool

@available(iOS 26, *)
struct AppleEliminarLineaTool: Tool, @unchecked Sendable {
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
        await MainActor.run { FacturaActions.eliminarLinea(
            EliminarLineaParams(concepto: arguments.concepto),
            factura: factura,
            modelContext: modelContext,
            onUpdate: onUpdate
        ) }
    }
}

// MARK: AppleCambiarDescuentoTool

@available(iOS 26, *)
struct AppleCambiarDescuentoTool: Tool, @unchecked Sendable {
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
        await MainActor.run { FacturaActions.cambiarDescuento(
            CambiarDescuentoParams(porcentaje: arguments.porcentaje),
            factura: factura,
            modelContext: modelContext,
            onUpdate: onUpdate
        ) }
    }
}

#endif
