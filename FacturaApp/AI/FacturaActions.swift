// FacturaActions.swift
// FacturaApp — Business logic extracted from AI tool call() bodies
// 14 actions: one per tool. Pure SwiftData logic, no FoundationModels dependency.

import Foundation
import SwiftData

// MARK: - Params structs (one per tool)

struct ConfigurarNegocioParams {
    var nombre: String
    var nif: String
    var direccion: String
    var ciudad: String
    var provincia: String
    var codigoPostal: String
    var telefono: String
    var email: String
}

struct CrearClienteParams {
    var nombre: String
    var nif: String
    var telefono: String
    var email: String
    var direccion: String
    var ciudad: String
}

struct BuscarClienteParams {
    var consulta: String
}

struct CrearArticuloParams {
    var nombre: String
    var precioUnitario: Double
    var referencia: String
    var unidad: String
    var proveedor: String
    var precioCoste: Double
    var etiquetas: String
}

struct BuscarArticuloParams {
    var consulta: String
}

struct CrearFacturaParams {
    var nombreCliente: String
    var articulosTexto: String
    var descuento: Double
    var observaciones: String
}

struct MarcarPagadaParams {
    var identificador: String
}

struct AnularFacturaParams {
    var identificador: String
}

struct ImportarDatosParams {
    var tipo: String
}

struct ConsultarResumenParams {
    var tipo: String
}

struct ModificarLineaParams {
    var concepto: String
    var cantidad: Double
    var precioUnitario: Double
    var nuevoConcepto: String
}

struct AnadirLineaParams {
    var concepto: String
    var cantidad: Double
    var precioUnitario: Double
    var unidad: String
}

struct EliminarLineaParams {
    var concepto: String
}

struct CambiarDescuentoParams {
    var porcentaje: Double
}

// MARK: - FacturaActions

@MainActor
enum FacturaActions {

    // MARK: - configurarNegocio

    static func configurarNegocio(_ params: ConfigurarNegocioParams, modelContext: ModelContext) -> String {
        // Buscar si ya existe un negocio
        let desc = FetchDescriptor<Negocio>()
        let existente = (try? modelContext.fetch(desc))?.first

        if let negocio = existente {
            // Actualizar datos existentes
            if !params.nombre.isEmpty { negocio.nombre = params.nombre }
            if !params.nif.isEmpty { negocio.nif = params.nif }
            if !params.direccion.isEmpty { negocio.direccion = params.direccion }
            if !params.ciudad.isEmpty { negocio.ciudad = params.ciudad }
            if !params.provincia.isEmpty { negocio.provincia = params.provincia }
            if !params.codigoPostal.isEmpty { negocio.codigoPostal = params.codigoPostal }
            if !params.telefono.isEmpty { negocio.telefono = params.telefono }
            if !params.email.isEmpty { negocio.email = params.email }
            try? modelContext.save()
            return "Datos del negocio actualizados: \(negocio.nombre)."
        } else {
            // Crear nuevo negocio
            let negocio = Negocio(
                nombre: params.nombre,
                nif: params.nif,
                direccion: params.direccion,
                codigoPostal: params.codigoPostal,
                ciudad: params.ciudad,
                provincia: params.provincia,
                telefono: params.telefono,
                email: params.email
            )
            modelContext.insert(negocio)

            // Crear categorías por defecto
            for (i, (catNombre, icono)) in Categoria.categoriasDefecto.enumerated() {
                let cat = Categoria(nombre: catNombre, icono: icono, orden: i)
                modelContext.insert(cat)
            }

            try? modelContext.save()
            return "Negocio '\(params.nombre)' configurado correctamente. Ya puedes crear clientes, artículos y facturas."
        }
    }

    // MARK: - crearCliente

    static func crearCliente(_ params: CrearClienteParams, modelContext: ModelContext) -> String {
        let cliente = Cliente(
            nombre: params.nombre,
            nif: params.nif,
            direccion: params.direccion,
            ciudad: params.ciudad,
            telefono: params.telefono,
            email: params.email
        )
        modelContext.insert(cliente)
        try? modelContext.save()
        return "Cliente '\(params.nombre)' creado correctamente."
    }

    // MARK: - buscarCliente

    static func buscarCliente(_ params: BuscarClienteParams, modelContext: ModelContext) -> String {
        let consulta = params.consulta.lowercased()
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
            return "No se encontró ningún cliente con '\(params.consulta)'."
        }

        let lineas = encontrados.prefix(5).map { c in
            "- \(c.nombre) | Tel: \(c.telefono.isEmpty ? "—" : c.telefono) | NIF: \(c.nif.isEmpty ? "—" : c.nif)"
        }
        return "Clientes encontrados:\n" + lineas.joined(separator: "\n")
    }

    // MARK: - crearArticulo

    static func crearArticulo(_ params: CrearArticuloParams, modelContext: ModelContext) -> String {
        let unidad = UnidadMedida(abreviatura: params.unidad) ?? .unidad
        let tags = params.etiquetas
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        let articulo = Articulo(
            referencia: params.referencia,
            nombre: params.nombre,
            precioUnitario: params.precioUnitario,
            precioCoste: params.precioCoste,
            unidad: unidad,
            proveedor: params.proveedor,
            etiquetas: tags
        )

        modelContext.insert(articulo)
        try? modelContext.save()
        return "Artículo '\(params.nombre)' creado a \(String(format: "%.2f", params.precioUnitario))€/\(unidad.rawValue)."
    }

    // MARK: - buscarArticulo

    static func buscarArticulo(_ params: BuscarArticuloParams, modelContext: ModelContext) -> String {
        let consulta = params.consulta.lowercased()
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
            return "No se encontraron artículos para '\(params.consulta)'. Hay \(articulos.count) artículos en total."
        }

        let lineas = top.map { (a, _) in
            "- \(a.nombre) | Ref: \(a.referencia.isEmpty ? "—" : a.referencia) | \(String(format: "%.2f", a.precioUnitario))€/\(a.unidad.abreviatura)"
        }
        return "Artículos encontrados:\n" + lineas.joined(separator: "\n")
    }

    // MARK: - crearFactura

    static func crearFactura(_ params: CrearFacturaParams, modelContext: ModelContext) -> String {
        // Buscar cliente
        let nombreLower = params.nombreCliente.lowercased()
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
            descuentoGlobalPorcentaje: params.descuento,
            observaciones: params.observaciones,
            promptOriginal: params.articulosTexto
        )

        // Intentar parsear líneas del texto
        let partes = params.articulosTexto
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
        respuesta += " para \(cliente?.nombre ?? params.nombreCliente).\n"

        if !lineasCreadas.isEmpty {
            respuesta += "Líneas:\n" + lineasCreadas.map { "  • \($0)" }.joined(separator: "\n")
        }
        if !lineasNoEncontradas.isEmpty {
            respuesta += "\n⚠️ No encontrados en catálogo (precio a 0€): \(lineasNoEncontradas.joined(separator: ", "))"
        }

        respuesta += "\nTotal: \(String(format: "%.2f", factura.totalFactura))€"

        if cliente == nil {
            respuesta += "\n⚠️ Cliente '\(params.nombreCliente)' no encontrado. La factura se creó sin cliente asociado."
        }

        return respuesta
    }

    // MARK: - marcarPagada

    static func marcarPagada(_ params: MarcarPagadaParams, modelContext: ModelContext) -> String {
        let id = params.identificador.lowercased()
        let descriptor = FetchDescriptor<Factura>()
        let todas = (try? modelContext.fetch(descriptor)) ?? []
        let facturas = todas.filter { $0.estado == .emitida }

        let factura = facturas.first {
            $0.numeroFactura.lowercased().contains(id) ||
            $0.clienteNombre.lowercased().contains(id)
        }

        guard let factura else {
            return "No se encontró ninguna factura emitida para '\(params.identificador)'."
        }

        factura.estado = .pagada
        factura.fechaModificacion = .now
        try? modelContext.save()

        return "Factura \(factura.numeroFactura) de \(factura.clienteNombre) marcada como pagada (\(String(format: "%.2f", factura.totalFactura))€)."
    }

    // MARK: - anularFactura

    static func anularFactura(_ params: AnularFacturaParams, modelContext: ModelContext) -> String {
        let id = params.identificador.lowercased()
        let descriptor = FetchDescriptor<Factura>()
        let todas = (try? modelContext.fetch(descriptor)) ?? []

        let factura = todas.first {
            $0.estado != .anulada && (
                $0.numeroFactura.lowercased().contains(id) ||
                $0.clienteNombre.lowercased().contains(id)
            )
        }

        guard let factura else {
            return "No se encontró ninguna factura activa para '\(params.identificador)'."
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

    // MARK: - importarDatos

    static func importarDatos(_ params: ImportarDatosParams, modelContext: ModelContext) -> String {
        let tipo = params.tipo == "clientes" ? "clientes" : "articulos"
        return "IMPORTAR_\(tipo.uppercased())"
    }

    // MARK: - consultarResumen

    static func consultarResumen(_ params: ConsultarResumenParams, modelContext: ModelContext) -> String {
        switch params.tipo {
        case "pendientes":
            return resumenFacturas(estado: .emitida, etiqueta: "pendientes de cobro", modelContext: modelContext)
        case "cobradas":
            return resumenFacturas(estado: .pagada, etiqueta: "cobradas", modelContext: modelContext)
        case "vencidas":
            return resumenFacturas(estado: .vencida, etiqueta: "vencidas", modelContext: modelContext)
        case "clientes":
            return resumenClientes(modelContext: modelContext)
        case "articulos":
            return resumenArticulos(modelContext: modelContext)
        default:
            return resumenGeneral(modelContext: modelContext)
        }
    }

    // MARK: - modificarLinea (edit tool)

    static func modificarLinea(_ params: ModificarLineaParams, factura: Factura, modelContext: ModelContext, onUpdate: @Sendable () -> Void) -> String {
        let busqueda = params.concepto.lowercased()

        guard let linea = factura.lineas.first(where: { $0.concepto.lowercased().contains(busqueda) }) else {
            let conceptos = factura.lineas.map { $0.concepto }.joined(separator: ", ")
            return "No se encontró ninguna línea con '\(params.concepto)'. Líneas actuales: \(conceptos)"
        }

        var cambios: [String] = []

        if params.cantidad > 0 {
            linea.cantidad = params.cantidad
            cambios.append("cantidad: \(String(format: "%.2f", params.cantidad))")
        }

        if params.precioUnitario >= 0 {
            linea.precioUnitario = params.precioUnitario
            cambios.append("precio: \(String(format: "%.2f", params.precioUnitario))€")
        }

        if !params.nuevoConcepto.isEmpty {
            linea.concepto = params.nuevoConcepto
            cambios.append("concepto: \(params.nuevoConcepto)")
        }

        recalcularYGuardar(factura: factura, modelContext: modelContext, onUpdate: onUpdate)

        if cambios.isEmpty {
            return "No se realizaron cambios en '\(linea.concepto)'. Especifica cantidad, precio o nuevo concepto."
        }

        return "Línea '\(linea.concepto)' modificada: \(cambios.joined(separator: ", ")). Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
    }

    // MARK: - anadirLinea (edit tool)

    static func anadirLinea(_ params: AnadirLineaParams, factura: Factura, modelContext: ModelContext, onUpdate: @Sendable () -> Void) -> String {
        let unidad = UnidadMedida(abreviatura: params.unidad) ?? .unidad
        let siguienteOrden = (factura.lineas.map { $0.orden }.max() ?? -1) + 1

        let linea = LineaFactura(
            orden: siguienteOrden,
            concepto: params.concepto,
            cantidad: params.cantidad,
            unidad: unidad,
            precioUnitario: params.precioUnitario,
            porcentajeIVA: 21.0
        )

        factura.lineas.append(linea)
        recalcularYGuardar(factura: factura, modelContext: modelContext, onUpdate: onUpdate)

        let subtotal = params.cantidad * params.precioUnitario
        return "Línea añadida: \(String(format: "%.0f", params.cantidad)) \(unidad.abreviatura) × \(params.concepto) a \(String(format: "%.2f", params.precioUnitario))€ = \(String(format: "%.2f", subtotal))€. Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
    }

    // MARK: - eliminarLinea (edit tool)

    static func eliminarLinea(_ params: EliminarLineaParams, factura: Factura, modelContext: ModelContext, onUpdate: @Sendable () -> Void) -> String {
        let busqueda = params.concepto.lowercased()

        guard let linea = factura.lineas.first(where: { $0.concepto.lowercased().contains(busqueda) }) else {
            let conceptos = factura.lineas.map { $0.concepto }.joined(separator: ", ")
            return "No se encontró ninguna línea con '\(params.concepto)'. Líneas actuales: \(conceptos)"
        }

        let conceptoEliminado = linea.concepto
        factura.lineas.removeAll { $0.persistentModelID == linea.persistentModelID }
        modelContext.delete(linea)

        recalcularYGuardar(factura: factura, modelContext: modelContext, onUpdate: onUpdate)

        return "Línea '\(conceptoEliminado)' eliminada. Quedan \(factura.lineas.count) línea(s). Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
    }

    // MARK: - cambiarDescuento (edit tool)

    static func cambiarDescuento(_ params: CambiarDescuentoParams, factura: Factura, modelContext: ModelContext, onUpdate: @Sendable () -> Void) -> String {
        let anterior = factura.descuentoGlobalPorcentaje
        factura.descuentoGlobalPorcentaje = params.porcentaje

        recalcularYGuardar(factura: factura, modelContext: modelContext, onUpdate: onUpdate)

        if params.porcentaje == 0 {
            return "Descuento eliminado (antes era \(String(format: "%.1f", anterior))%). Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
        }

        return "Descuento global cambiado a \(String(format: "%.1f", params.porcentaje))%. Nuevo total factura: \(String(format: "%.2f", factura.totalFactura))€."
    }

    // MARK: - Helper: extraerCantidadYTermino

    static func extraerCantidadYTermino(_ texto: String) -> (Double, String) {
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

    // MARK: - Helper: encontrarMejorArticulo

    static func encontrarMejorArticulo(termino: String, en articulos: [Articulo]) -> Articulo? {
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

    // MARK: - Helper: recalcularYGuardar

    static func recalcularYGuardar(factura: Factura, modelContext: ModelContext, onUpdate: @Sendable () -> Void) {
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

    // MARK: - Private helpers for consultarResumen

    private static func resumenGeneral(modelContext: ModelContext) -> String {
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

    private static func resumenFacturas(estado: EstadoFactura, etiqueta: String, modelContext: ModelContext) -> String {
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

    private static func resumenClientes(modelContext: ModelContext) -> String {
        let desc = FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo == true })
        let clientes = (try? modelContext.fetch(desc)) ?? []
        if clientes.isEmpty { return "No hay clientes dados de alta." }
        let lineas = clientes.prefix(10).map { "  • \($0.nombre)" }
        return "\(clientes.count) cliente(s):\n" + lineas.joined(separator: "\n")
    }

    private static func resumenArticulos(modelContext: ModelContext) -> String {
        let desc = FetchDescriptor<Articulo>(predicate: #Predicate<Articulo> { $0.activo == true })
        let articulos = (try? modelContext.fetch(desc)) ?? []
        if articulos.isEmpty { return "No hay artículos en el catálogo." }
        let lineas = articulos.prefix(10).map { "  • \($0.nombre) — \(formatEuros($0.precioUnitario))/\($0.unidad.abreviatura)" }
        return "\(articulos.count) artículo(s):\n" + lineas.joined(separator: "\n")
    }

    private static func formatEuros(_ v: Double) -> String {
        String(format: "%.2f", v) + " €"
    }
}
