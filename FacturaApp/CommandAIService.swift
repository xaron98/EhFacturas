// CommandAIService.swift
// FacturaApp — Servicio de comandos por voz/texto
// IA que controla toda la app: crea clientes, artículos, facturas,
// busca datos, cambia estados — todo por lenguaje natural.

import Foundation
import Combine
import FoundationModels
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

// MARK: - Tools para Foundation Models

/// Tool: Crear un nuevo cliente en la base de datos.
struct CrearClienteTool: Tool, @unchecked Sendable {
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
        let cliente = Cliente(
            nombre: arguments.nombre,
            nif: arguments.nif,
            direccion: arguments.direccion,
            ciudad: arguments.ciudad,
            telefono: arguments.telefono,
            email: arguments.email
        )
        modelContext.insert(cliente)
        try? modelContext.save()
        return "Cliente '\(arguments.nombre)' creado correctamente."
    }
}

/// Tool: Buscar clientes en la base de datos.
struct BuscarClienteTool: Tool, @unchecked Sendable {
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
        let consulta = arguments.consulta.lowercased()
        let descriptor = FetchDescriptor<Cliente>(
            predicate: #Predicate<Cliente> { $0.activo == true }
        )
        let clientes = (try? modelContext.fetch(descriptor)) ?? []

        let encontrados = clientes.filter {
            $0.nombre.lowercased().contains(consulta) ||
            $0.telefono.contains(consulta) ||
            $0.nif.lowercased().contains(consulta)
        }

        if encontrados.isEmpty {
            return "No se encontró ningún cliente con '\(arguments.consulta)'."
        }

        let lineas = encontrados.prefix(5).map { c in
            "- \(c.nombre) | Tel: \(c.telefono.isEmpty ? "—" : c.telefono) | NIF: \(c.nif.isEmpty ? "—" : c.nif)"
        }
        return "Clientes encontrados:\n" + lineas.joined(separator: "\n")
    }
}

/// Tool: Crear un nuevo artículo / producto / servicio.
struct CrearArticuloTool: Tool, @unchecked Sendable {
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
        let unidad = UnidadMedida(abreviatura: arguments.unidad) ?? .unidad
        let tags = arguments.etiquetas
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        let articulo = Articulo(
            referencia: arguments.referencia,
            nombre: arguments.nombre,
            precioUnitario: arguments.precioUnitario,
            precioCoste: arguments.precioCoste,
            unidad: unidad,
            proveedor: arguments.proveedor,
            etiquetas: tags
        )

        modelContext.insert(articulo)
        try? modelContext.save()
        return "Artículo '\(arguments.nombre)' creado a \(String(format: "%.2f", arguments.precioUnitario))€/\(unidad.rawValue)."
    }
}

/// Tool: Buscar artículos en el catálogo.
struct BuscarArticuloCatalogoTool: Tool, @unchecked Sendable {
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
        let consulta = arguments.consulta.lowercased()
        let palabras = consulta.split(separator: " ").map(String.init)
        let descriptor = FetchDescriptor<Articulo>(
            predicate: #Predicate<Articulo> { $0.activo == true }
        )
        let articulos = (try? modelContext.fetch(descriptor)) ?? []

        var resultados: [(Articulo, Int)] = []
        for art in articulos {
            var score = 0
            let n = art.nombre.lowercased()
            for p in palabras {
                if n.contains(p) { score += 3 }
                if art.etiquetas.contains(where: { $0.contains(p) }) { score += 2 }
                if art.referencia.lowercased().contains(p) { score += 2 }
            }
            if n.contains(consulta) { score += 5 }
            if score > 0 { resultados.append((art, score)) }
        }

        resultados.sort { $0.1 > $1.1 }
        let top = resultados.prefix(5)

        if top.isEmpty {
            return "No se encontraron artículos para '\(arguments.consulta)'. Hay \(articulos.count) artículos en total."
        }

        let lineas = top.map { (a, _) in
            "- \(a.nombre) | Ref: \(a.referencia.isEmpty ? "—" : a.referencia) | \(String(format: "%.2f", a.precioUnitario))€/\(a.unidad.abreviatura)"
        }
        return "Artículos encontrados:\n" + lineas.joined(separator: "\n")
    }
}

/// Tool: Crear una factura completa.
struct CrearFacturaTool: Tool, @unchecked Sendable {
    let name = "crear_factura"
    let description = """
        Crea una nueva factura borrador con un cliente y artículos. \
        Usa esta herramienta cuando el usuario quiera generar, hacer o crear una factura. \
        Ejemplo: "Hazme una factura para Juan García con 5 bombillas LED y 2 horas de mano de obra"
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
    }

    let modelContext: ModelContext

    func call(arguments: Arguments) async throws -> String {
        // Buscar cliente
        let nombreLower = arguments.nombreCliente.lowercased()
        let clienteDesc = FetchDescriptor<Cliente>(
            predicate: #Predicate<Cliente> { $0.activo == true }
        )
        let clientes = (try? modelContext.fetch(clienteDesc)) ?? []
        let cliente = clientes.first { $0.nombre.lowercased().contains(nombreLower) }

        // Buscar negocio para numeración
        let negocioDesc = FetchDescriptor<Negocio>()
        guard let negocio = (try? modelContext.fetch(negocioDesc))?.first else {
            return "Error: No hay datos de negocio configurados. Ve a Ajustes para configurarlos."
        }

        // Parsear artículos del texto
        let articulosDesc = FetchDescriptor<Articulo>(
            predicate: #Predicate<Articulo> { $0.activo == true }
        )
        let todosArticulos = (try? modelContext.fetch(articulosDesc)) ?? []

        // Crear factura
        let numeroFactura = negocio.generarNumeroFactura()
        try? modelContext.save()  // Persist incremented number immediately

        let factura = Factura(
            numeroFactura: numeroFactura,
            cliente: cliente,
            estado: .borrador,
            descuentoGlobalPorcentaje: arguments.descuento,
            observaciones: arguments.observaciones,
            promptOriginal: arguments.articulosTexto
        )

        // Intentar parsear líneas del texto
        let partes = arguments.articulosTexto
            .components(separatedBy: CharacterSet(charactersIn: ",;y"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var lineasCreadas: [String] = []
        var lineasNoEncontradas: [String] = []

        for (i, parte) in partes.enumerated() {
            let (cantidad, termino) = extraerCantidadYTermino(parte)

            // Buscar artículo por scoring
            let mejor = encontrarMejorArticulo(termino: termino, en: todosArticulos)

            if let articulo = mejor {
                let linea = LineaFactura(
                    orden: i,
                    articulo: articulo,
                    referencia: articulo.referencia,
                    concepto: articulo.nombre,
                    cantidad: cantidad,
                    unidad: articulo.unidad,
                    precioUnitario: articulo.precioUnitario,
                    porcentajeIVA: articulo.tipoIVA.porcentaje
                )
                factura.lineas.append(linea)
                lineasCreadas.append("\(String(format: "%.0f", cantidad)) \(articulo.unidad.abreviatura) × \(articulo.nombre) = \(String(format: "%.2f", linea.subtotal))€")
            } else {
                let linea = LineaFactura(
                    orden: i,
                    concepto: termino,
                    cantidad: cantidad,
                    precioUnitario: 0,
                    porcentajeIVA: 21.0
                )
                factura.lineas.append(linea)
                lineasNoEncontradas.append(termino)
            }
        }

        factura.recalcularTotales(
            irpfPorcentaje: negocio.irpfPorcentaje,
            aplicarIRPF: negocio.aplicarIRPF
        )

        modelContext.insert(factura)
        try? modelContext.save()

        var respuesta = "Factura \(factura.numeroFactura) creada como borrador"
        respuesta += " para \(cliente?.nombre ?? arguments.nombreCliente).\n"

        if !lineasCreadas.isEmpty {
            respuesta += "Líneas:\n" + lineasCreadas.map { "  • \($0)" }.joined(separator: "\n")
        }
        if !lineasNoEncontradas.isEmpty {
            respuesta += "\n⚠️ No encontrados en catálogo (precio a 0€): \(lineasNoEncontradas.joined(separator: ", "))"
        }

        respuesta += "\nTotal: \(String(format: "%.2f", factura.totalFactura))€"

        if cliente == nil {
            respuesta += "\n⚠️ Cliente '\(arguments.nombreCliente)' no encontrado. La factura se creó sin cliente asociado."
        }

        return respuesta
    }

    private func extraerCantidadYTermino(_ texto: String) -> (Double, String) {
        let palabras = texto.split(separator: " ").map(String.init)

        // Intentar extraer número al inicio
        if let primera = palabras.first,
           let cantidad = Double(primera.replacingOccurrences(of: ",", with: ".")) {
            let termino = palabras.dropFirst().joined(separator: " ")
            return (cantidad, termino)
        }

        // Buscar palabras numéricas
        let numerosTexto: [String: Double] = [
            "un": 1, "una": 1, "uno": 1, "dos": 2, "tres": 3,
            "cuatro": 4, "cinco": 5, "seis": 6, "siete": 7,
            "ocho": 8, "nueve": 9, "diez": 10, "media": 0.5
        ]

        if let primera = palabras.first?.lowercased(),
           let cantidad = numerosTexto[primera] {
            let termino = palabras.dropFirst().joined(separator: " ")
            return (cantidad, termino)
        }

        return (1, texto)
    }

    private func encontrarMejorArticulo(termino: String, en articulos: [Articulo]) -> Articulo? {
        let terminoLower = termino.lowercased()
        let palabras = terminoLower.split(separator: " ").map(String.init).filter { $0.count > 1 }

        var mejor: (Articulo, Int)?
        for art in articulos {
            var score = 0
            let n = art.nombre.lowercased()
            for p in palabras {
                if n.contains(p) { score += 3 }
                if art.etiquetas.contains(where: { $0.contains(p) }) { score += 2 }
            }
            if n.contains(terminoLower) { score += 5 }
            if score > (mejor?.1 ?? 0) { mejor = (art, score) }
        }

        return (mejor?.1 ?? 0) >= 2 ? mejor?.0 : nil
    }
}

/// Tool: Marcar factura como pagada.
struct MarcarPagadaTool: Tool, @unchecked Sendable {
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
        let id = arguments.identificador.lowercased()
        let descriptor = FetchDescriptor<Factura>()
        let todas = (try? modelContext.fetch(descriptor)) ?? []
        let facturas = todas.filter { $0.estado == .emitida }

        let factura = facturas.first {
            $0.numeroFactura.lowercased().contains(id) ||
            $0.clienteNombre.lowercased().contains(id)
        }

        guard let factura else {
            return "No se encontró ninguna factura emitida para '\(arguments.identificador)'."
        }

        factura.estado = .pagada
        factura.fechaModificacion = .now
        try? modelContext.save()

        return "Factura \(factura.numeroFactura) de \(factura.clienteNombre) marcada como pagada (\(String(format: "%.2f", factura.totalFactura))€)."
    }
}

/// Tool: Anular una factura.
struct AnularFacturaTool: Tool, @unchecked Sendable {
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
        let id = arguments.identificador.lowercased()
        let descriptor = FetchDescriptor<Factura>()
        let todas = (try? modelContext.fetch(descriptor)) ?? []

        let factura = todas.first {
            $0.estado != .anulada && (
                $0.numeroFactura.lowercased().contains(id) ||
                $0.clienteNombre.lowercased().contains(id)
            )
        }

        guard let factura else {
            return "No se encontró ninguna factura activa para '\(arguments.identificador)'."
        }

        if factura.estado == .borrador {
            // Borrador: anular directamente sin registro VeriFactu
            factura.estado = .anulada
            factura.fechaModificacion = .now
            try? modelContext.save()
            return "Factura borrador \(factura.numeroFactura) anulada."
        } else {
            // Emitida/pagada: crear registro de anulación VeriFactu
            let negocioDesc = FetchDescriptor<Negocio>()
            guard let negocio = (try? modelContext.fetch(negocioDesc))?.first else {
                return "Error: No hay datos de negocio configurados."
            }
            let _ = VeriFactuHashService.crearRegistroAnulacion(
                factura: factura, negocio: negocio, modelContext: modelContext
            )
            factura.estado = .anulada
            factura.fechaModificacion = .now
            try? modelContext.save()
            return "Factura \(factura.numeroFactura) de \(factura.clienteNombre) anulada con registro VeriFactu."
        }
    }
}

/// Tool: Consultar resumen / estado general.
struct ConsultarResumenTool: Tool, @unchecked Sendable {
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
        switch arguments.tipo {
        case "pendientes":
            return resumenFacturas(estado: .emitida, etiqueta: "pendientes de cobro")
        case "cobradas":
            return resumenFacturas(estado: .pagada, etiqueta: "cobradas")
        case "vencidas":
            return resumenFacturas(estado: .vencida, etiqueta: "vencidas")
        case "clientes":
            return resumenClientes()
        case "articulos":
            return resumenArticulos()
        default:
            return resumenGeneral()
        }
    }

    private func resumenGeneral() -> String {
        let factDesc = FetchDescriptor<Factura>()
        let facturas = (try? modelContext.fetch(factDesc)) ?? []
        let clienteDesc = FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo == true })
        let clientes = (try? modelContext.fetch(clienteDesc)) ?? []
        let artDesc = FetchDescriptor<Articulo>(predicate: #Predicate<Articulo> { $0.activo == true })
        let articulos = (try? modelContext.fetch(artDesc)) ?? []

        let pendiente = facturas.filter { $0.estado == .emitida }.reduce(0) { $0 + $1.totalFactura }
        let cobrado = facturas.filter { $0.estado == .pagada }.reduce(0) { $0 + $1.totalFactura }
        let vencido = facturas.filter { $0.estado == .vencida }.reduce(0) { $0 + $1.totalFactura }

        return """
        Resumen del negocio:
        - \(clientes.count) clientes activos
        - \(articulos.count) artículos en catálogo
        - \(facturas.count) facturas en total
        - Pendiente de cobro: \(formatEuros(pendiente))
        - Cobrado: \(formatEuros(cobrado))
        - Vencido: \(formatEuros(vencido))
        """
    }

    private func resumenFacturas(estado: EstadoFactura, etiqueta: String) -> String {
        let desc = FetchDescriptor<Factura>()
        let todas = (try? modelContext.fetch(desc)) ?? []
        let facturas = todas.filter { $0.estado == estado }
        if facturas.isEmpty { return "No hay facturas \(etiqueta)." }

        let total = facturas.reduce(0) { $0 + $1.totalFactura }
        let lineas = facturas.prefix(5).map { f in
            "  • \(f.numeroFactura) — \(f.clienteNombre) — \(formatEuros(f.totalFactura))"
        }
        var r = "\(facturas.count) factura(s) \(etiqueta) por \(formatEuros(total)):\n"
        r += lineas.joined(separator: "\n")
        if facturas.count > 5 { r += "\n  ...y \(facturas.count - 5) más." }
        return r
    }

    private func resumenClientes() -> String {
        let desc = FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo == true })
        let clientes = (try? modelContext.fetch(desc)) ?? []
        if clientes.isEmpty { return "No hay clientes dados de alta." }
        let lineas = clientes.prefix(10).map { "  • \($0.nombre)" }
        return "\(clientes.count) cliente(s):\n" + lineas.joined(separator: "\n")
    }

    private func resumenArticulos() -> String {
        let desc = FetchDescriptor<Articulo>(predicate: #Predicate<Articulo> { $0.activo == true })
        let articulos = (try? modelContext.fetch(desc)) ?? []
        if articulos.isEmpty { return "No hay artículos en el catálogo." }
        let lineas = articulos.prefix(10).map { "  • \($0.nombre) — \(formatEuros($0.precioUnitario))/\($0.unidad.abreviatura)" }
        return "\(articulos.count) artículo(s):\n" + lineas.joined(separator: "\n")
    }

    private func formatEuros(_ v: Double) -> String {
        String(format: "%.2f", v) + " €"
    }
}

/// Tool: Solicitar importación de datos CSV.
struct ImportarDatosTool: Tool, @unchecked Sendable {
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
        let tipo = arguments.tipo == "clientes" ? "clientes" : "articulos"
        return "IMPORTAR_\(tipo.uppercased())"
    }
}

/// Tool: Configurar datos del negocio (onboarding por voz).
struct ConfigurarNegocioTool: Tool, @unchecked Sendable {
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
        // Buscar si ya existe un negocio
        let desc = FetchDescriptor<Negocio>()
        let existente = (try? modelContext.fetch(desc))?.first

        if let negocio = existente {
            // Actualizar datos existentes
            if !arguments.nombre.isEmpty { negocio.nombre = arguments.nombre }
            if !arguments.nif.isEmpty { negocio.nif = arguments.nif }
            if !arguments.direccion.isEmpty { negocio.direccion = arguments.direccion }
            if !arguments.ciudad.isEmpty { negocio.ciudad = arguments.ciudad }
            if !arguments.provincia.isEmpty { negocio.provincia = arguments.provincia }
            if !arguments.codigoPostal.isEmpty { negocio.codigoPostal = arguments.codigoPostal }
            if !arguments.telefono.isEmpty { negocio.telefono = arguments.telefono }
            if !arguments.email.isEmpty { negocio.email = arguments.email }
            try? modelContext.save()
            return "Datos del negocio actualizados: \(negocio.nombre)."
        } else {
            // Crear nuevo negocio
            let negocio = Negocio(
                nombre: arguments.nombre,
                nif: arguments.nif,
                direccion: arguments.direccion,
                codigoPostal: arguments.codigoPostal,
                ciudad: arguments.ciudad,
                provincia: arguments.provincia,
                telefono: arguments.telefono,
                email: arguments.email
            )
            modelContext.insert(negocio)

            // Crear categorías por defecto
            for (i, (catNombre, icono)) in Categoria.categoriasDefecto.enumerated() {
                let cat = Categoria(nombre: catNombre, icono: icono, orden: i)
                modelContext.insert(cat)
            }

            try? modelContext.save()
            return "Negocio '\(arguments.nombre)' configurado correctamente. Ya puedes crear clientes, artículos y facturas."
        }
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
    private var session: LanguageModelSession?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        crearSesion()
    }

    private func crearSesion() {
        session = LanguageModelSession(
            tools: [
                ConfigurarNegocioTool(modelContext: modelContext),
                CrearClienteTool(modelContext: modelContext),
                BuscarClienteTool(modelContext: modelContext),
                CrearArticuloTool(modelContext: modelContext),
                BuscarArticuloCatalogoTool(modelContext: modelContext),
                CrearFacturaTool(modelContext: modelContext),
                MarcarPagadaTool(modelContext: modelContext),
                AnularFacturaTool(modelContext: modelContext),
                ImportarDatosTool(modelContext: modelContext),
                ConsultarResumenTool(modelContext: modelContext)
            ]
        ) {
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
    }

    // MARK: - Verificar disponibilidad

    var iaDisponible: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var razonNoDisponible: String {
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

    // MARK: - Procesar comando

    func procesarComando(_ texto: String) async {
        let textoLimpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textoLimpio.isEmpty else { return }

        estado = .procesando("Pensando...")

        // Recrear sesión si no existe
        if session == nil {
            crearSesion()
        }

        guard let session else {
            estado = .error("No se pudo crear la sesión de IA.")
            return
        }

        do {
            let response = try await session.respond(to: textoLimpio)
            let respuestaTexto = response.content

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

            // Si se configuró el negocio, recrear sesión para salir del modo onboarding
            if respuestaTexto.lowercased().contains("configurado") {
                self.session = nil
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

        } catch let error as LanguageModelSession.GenerationError {
            let msg: String
            switch error {
            case .guardrailViolation:
                msg = "No puedo procesar esa petición. Intenta reformularla."
            case .exceededContextWindowSize:
                msg = "El mensaje es demasiado largo. Sé más breve."
            default:
                msg = "Error del modelo: \(error.localizedDescription)"
            }
            estado = .error(msg)
            ultimaRespuesta = ComandoResultado(mensaje: msg, accionRealizada: .error)
        } catch {
            let msg = "Error: \(error.localizedDescription)"
            estado = .error(msg)
            ultimaRespuesta = ComandoResultado(mensaje: msg, accionRealizada: .error)
        }
    }

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
