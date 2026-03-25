// FacturacionStore.swift
// FacturaApp — Background actor for domain operations
// Moves SwiftData fetch/parse/save off the main thread.

import Foundation
import SwiftData

actor FacturacionStore {

    private let container: ModelContainer
    static let shared = FacturacionStore(container: DataConfig.container)

    init(container: ModelContainer) {
        self.container = container
    }

    private func makeContext() -> ModelContext {
        ModelContext(container)
    }

    // MARK: - Undo tracking (actor-isolated)

    private var ultimaAccion: UltimaAccion?

    // MARK: - Command actions (background)

    // MARK: configurarNegocio

    func configurarNegocio(_ params: ConfigurarNegocioParams) -> String {
        let ctx = makeContext()
        // Buscar si ya existe un negocio
        let desc = FetchDescriptor<Negocio>()
        let existente = (try? ctx.fetch(desc))?.first

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
            try? ctx.save()
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
            ctx.insert(negocio)

            // Crear categorias por defecto
            for (i, (catNombre, icono)) in Categoria.categoriasDefecto.enumerated() {
                let cat = Categoria(nombre: catNombre, icono: icono, orden: i)
                ctx.insert(cat)
            }

            try? ctx.save()
            return "Negocio '\(params.nombre)' configurado correctamente. Ya puedes crear clientes, articulos y facturas."
        }
    }

    // MARK: crearCliente

    func crearCliente(_ params: CrearClienteParams) -> String {
        let ctx = makeContext()
        let cliente = Cliente(
            nombre: params.nombre,
            nif: params.nif,
            direccion: params.direccion,
            ciudad: params.ciudad,
            telefono: params.telefono,
            email: params.email
        )
        ctx.insert(cliente)
        try? ctx.save()
        ultimaAccion = UltimaAccion(tipo: "crear_cliente", descripcion: "Cliente \(params.nombre)", clienteID: cliente.persistentModelID)
        return "Cliente '\(params.nombre)' creado correctamente."
    }

    // MARK: buscarCliente

    func buscarCliente(_ params: BuscarClienteParams) -> String {
        let ctx = makeContext()
        let consulta = params.consulta.lowercased()
        let descriptor = FetchDescriptor<Cliente>(
            predicate: #Predicate<Cliente> { $0.activo == true }
        )
        let clientes = (try? ctx.fetch(descriptor)) ?? []

        let encontrados = clientes.filter {
            $0.nombre.lowercased().contains(consulta) ||
            $0.telefono.contains(consulta) ||
            $0.nif.lowercased().contains(consulta)
        }

        if encontrados.isEmpty {
            return "No se encontro ningun cliente con '\(params.consulta)'."
        }

        let lineas = encontrados.prefix(5).map { c in
            "- \(c.nombre) | Tel: \(c.telefono.isEmpty ? "—" : c.telefono) | NIF: \(c.nif.isEmpty ? "—" : c.nif)"
        }
        return "Clientes encontrados:\n" + lineas.joined(separator: "\n")
    }

    // MARK: crearArticulo

    func crearArticulo(_ params: CrearArticuloParams) -> String {
        let ctx = makeContext()
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

        ctx.insert(articulo)
        try? ctx.save()
        ultimaAccion = UltimaAccion(tipo: "crear_articulo", descripcion: "Articulo \(params.nombre)", articuloID: articulo.persistentModelID)
        return "Articulo '\(params.nombre)' creado a \(String(format: "%.2f", params.precioUnitario))\u{20AC}/\(unidad.rawValue)."
    }

    // MARK: buscarArticulo

    func buscarArticulo(_ params: BuscarArticuloParams) -> String {
        let ctx = makeContext()
        let descriptor = FetchDescriptor<Articulo>(
            predicate: #Predicate<Articulo> { $0.activo == true }
        )
        let articulos = (try? ctx.fetch(descriptor)) ?? []

        let resultados = buscarArticulos(termino: params.consulta, en: articulos)
        let top = resultados.prefix(5)

        if top.isEmpty {
            return "No se encontraron articulos para '\(params.consulta)'. Hay \(articulos.count) articulos en total."
        }

        let lineas = top.map { (a, _) in
            "- \(a.nombre) | Ref: \(a.referencia.isEmpty ? "—" : a.referencia) | \(String(format: "%.2f", a.precioUnitario))\u{20AC}/\(a.unidad.abreviatura)"
        }
        return "Articulos encontrados:\n" + lineas.joined(separator: "\n")
    }

    // MARK: crearFactura

    func crearFactura(_ params: CrearFacturaParams) -> String {
        let ctx = makeContext()
        // Buscar cliente
        let nombreLower = params.nombreCliente.lowercased()
        let clienteDesc = FetchDescriptor<Cliente>(
            predicate: #Predicate<Cliente> { $0.activo == true }
        )
        let clientes = (try? ctx.fetch(clienteDesc)) ?? []
        let cliente = clientes.first { $0.nombre.lowercased().contains(nombreLower) }

        // Buscar negocio para numeracion
        let negocioDesc = FetchDescriptor<Negocio>()
        guard let negocio = (try? ctx.fetch(negocioDesc))?.first else {
            return "Error: No hay datos de negocio configurados. Ve a Ajustes para configurarlos."
        }

        // Parsear articulos del texto
        let articulosDesc = FetchDescriptor<Articulo>(
            predicate: #Predicate<Articulo> { $0.activo == true }
        )
        let todosArticulos = (try? ctx.fetch(articulosDesc)) ?? []

        // Crear factura
        let numeroFactura = negocio.generarNumeroFactura()
        try? ctx.save()  // Persist incremented number immediately

        let factura = Factura(
            numeroFactura: numeroFactura,
            cliente: cliente,
            estado: params.esPresupuesto ? .presupuesto : .borrador,
            descuentoGlobalPorcentaje: params.descuento,
            observaciones: params.observaciones,
            promptOriginal: params.articulosTexto
        )

        // Intentar parsear lineas del texto
        let partes = params.articulosTexto
            .components(separatedBy: CharacterSet(charactersIn: ",;y"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var lineasCreadas: [String] = []
        var lineasNoEncontradas: [String] = []

        for (i, parte) in partes.enumerated() {
            let (cantidad, termino) = extraerCantidadYTermino(parte)

            // Buscar articulo por scoring fuzzy
            let candidatos = buscarArticulos(termino: termino, en: todosArticulos)
            let mejor = candidatos.first?.0

            // Si hay multiples candidatos con score similar, avisar
            if candidatos.count > 1 {
                let topScore = candidatos[0].1
                let similares = candidatos.filter { Double($0.1) >= Double(topScore) * 0.7 }
                if similares.count > 1 {
                    let opciones = similares.prefix(3).map { $0.0.nombre }.joined(separator: ", ")
                    lineasCreadas.append("\u{2139}\u{FE0F} Varios articulos similares encontrados: \(opciones). Se uso: \(similares[0].0.nombre)")
                }
            }

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
                if factura.lineas == nil { factura.lineas = [] }
                factura.lineas!.append(linea)
                lineasCreadas.append("\(String(format: "%.0f", cantidad)) \(articulo.unidad.abreviatura) \u{00D7} \(articulo.nombre) = \(String(format: "%.2f", linea.subtotal))\u{20AC}")
            } else {
                let linea = LineaFactura(
                    orden: i,
                    concepto: termino,
                    cantidad: cantidad,
                    precioUnitario: 0,
                    porcentajeIVA: 21.0
                )
                if factura.lineas == nil { factura.lineas = [] }
                factura.lineas!.append(linea)
                lineasNoEncontradas.append(termino)
            }
        }

        factura.recalcularTotales(
            irpfPorcentaje: negocio.irpfPorcentaje,
            aplicarIRPF: negocio.aplicarIRPF
        )

        ctx.insert(factura)
        try? ctx.save()
        ultimaAccion = UltimaAccion(tipo: "crear_factura", descripcion: "\(params.esPresupuesto ? "Presupuesto" : "Factura") \(factura.numeroFactura)", facturaID: factura.persistentModelID)

        let tipoDoc = params.esPresupuesto ? "Presupuesto" : "Factura"
        let estadoDoc = params.esPresupuesto ? "presupuesto" : "borrador"
        var respuesta = "\(tipoDoc) \(factura.numeroFactura) creada como \(estadoDoc)"
        respuesta += " para \(cliente?.nombre ?? params.nombreCliente).\n"

        if !lineasCreadas.isEmpty {
            respuesta += "Lineas:\n" + lineasCreadas.map { "  \u{2022} \($0)" }.joined(separator: "\n")
        }
        if !lineasNoEncontradas.isEmpty {
            respuesta += "\n\u{26A0}\u{FE0F} No encontrados en catalogo (precio a 0\u{20AC}): \(lineasNoEncontradas.joined(separator: ", "))"
        }

        respuesta += "\nTotal: \(String(format: "%.2f", factura.totalFactura))\u{20AC}"

        if cliente == nil {
            respuesta += "\n\u{26A0}\u{FE0F} Cliente '\(params.nombreCliente)' no encontrado. La factura se creo sin cliente asociado."
        }

        return respuesta
    }

    // MARK: marcarPagada

    func marcarPagada(_ params: MarcarPagadaParams) -> String {
        let ctx = makeContext()
        let id = params.identificador.lowercased()
        let descriptor = FetchDescriptor<Factura>()
        let todas = (try? ctx.fetch(descriptor)) ?? []
        let facturas = todas.filter { $0.estado == .emitida }

        let factura = facturas.first {
            $0.numeroFactura.lowercased().contains(id) ||
            $0.clienteNombre.lowercased().contains(id)
        }

        guard let factura else {
            return "No se encontro ninguna factura emitida para '\(params.identificador)'."
        }

        factura.estado = .pagada
        factura.fechaModificacion = .now
        try? ctx.save()

        return "Factura \(factura.numeroFactura) de \(factura.clienteNombre) marcada como pagada (\(String(format: "%.2f", factura.totalFactura))\u{20AC})."
    }

    // MARK: anularFactura

    func anularFactura(_ params: AnularFacturaParams) -> String {
        let ctx = makeContext()
        let id = params.identificador.lowercased()
        let descriptor = FetchDescriptor<Factura>()
        let todas = (try? ctx.fetch(descriptor)) ?? []

        let factura = todas.first {
            $0.estado != .anulada && (
                $0.numeroFactura.lowercased().contains(id) ||
                $0.clienteNombre.lowercased().contains(id)
            )
        }

        guard let factura else {
            return "No se encontro ninguna factura activa para '\(params.identificador)'."
        }

        if factura.estado == .borrador || factura.estado == .presupuesto {
            // Borrador/Presupuesto: anular directamente sin registro VeriFactu
            let tipoDoc = factura.estado == .presupuesto ? "Presupuesto" : "Factura borrador"
            factura.estado = .anulada
            factura.fechaModificacion = .now
            try? ctx.save()
            return "\(tipoDoc) \(factura.numeroFactura) anulada."
        } else {
            // Emitida/pagada: crear registro de anulacion VeriFactu
            let negocioDesc = FetchDescriptor<Negocio>()
            guard let negocio = (try? ctx.fetch(negocioDesc))?.first else {
                return "Error: No hay datos de negocio configurados."
            }
            let _ = VeriFactuHashService.crearRegistroAnulacion(
                factura: factura, negocio: negocio, modelContext: ctx
            )
            factura.estado = .anulada
            factura.fechaModificacion = .now
            try? ctx.save()
            return "Factura \(factura.numeroFactura) de \(factura.clienteNombre) anulada con registro VeriFactu."
        }
    }

    // MARK: importarDatos

    func importarDatos(_ params: ImportarDatosParams) -> String {
        let tipo = params.tipo == "clientes" ? "clientes" : "articulos"
        return "IMPORTAR_\(tipo.uppercased())"
    }

    // MARK: consultarResumen

    func consultarResumen(_ params: ConsultarResumenParams) -> String {
        let ctx = makeContext()
        switch params.tipo {
        case "pendientes":
            return resumenFacturas(estado: .emitida, etiqueta: "pendientes de cobro", modelContext: ctx)
        case "cobradas":
            return resumenFacturas(estado: .pagada, etiqueta: "cobradas", modelContext: ctx)
        case "vencidas":
            return resumenFacturas(estado: .vencida, etiqueta: "vencidas", modelContext: ctx)
        case "clientes":
            return resumenClientes(modelContext: ctx)
        case "articulos":
            return resumenArticulos(modelContext: ctx)
        default:
            return resumenGeneral(modelContext: ctx)
        }
    }

    // MARK: crearRecurrente

    func crearRecurrente(_ params: CrearRecurrenteParams) -> String {
        let ctx = makeContext()
        let clienteDesc = FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo == true })
        let clientes = (try? ctx.fetch(clienteDesc)) ?? []
        let cliente = clientes.first { $0.nombre.lowercased().contains(params.nombreCliente.lowercased()) }

        let rec = FacturaRecurrente(
            nombre: "Factura \(params.frecuencia) - \(cliente?.nombre ?? params.nombreCliente)",
            cliente: cliente,
            articulosTexto: params.articulosTexto,
            importeTotal: params.importe,
            frecuencia: params.frecuencia
        )
        ctx.insert(rec)
        try? ctx.save()

        return "Factura recurrente creada: \(rec.nombre) por \(Formateadores.formatEuros(params.importe)) (\(params.frecuencia))."
    }

    // MARK: registrarGasto

    func registrarGasto(_ params: RegistrarGastoParams) -> String {
        let ctx = makeContext()
        let gasto = Gasto(
            concepto: params.concepto,
            importe: params.importe,
            categoria: params.categoria.isEmpty ? "otros" : params.categoria,
            proveedor: params.proveedor
        )
        ctx.insert(gasto)
        try? ctx.save()
        return "Gasto registrado: \(params.concepto) por \(Formateadores.formatEuros(params.importe))."
    }

    // MARK: deshacerUltimaAccion

    func deshacerUltimaAccion() -> String {
        let ctx = makeContext()
        guard let accion = ultimaAccion else {
            return "No hay ninguna accion que deshacer."
        }

        switch accion.tipo {
        case "crear_cliente":
            if let id = accion.clienteID,
               let cliente = ctx.model(for: id) as? Cliente {
                cliente.activo = false
                try? ctx.save()
                ultimaAccion = nil
                return "Deshecho: \(accion.descripcion) desactivado."
            }
        case "crear_articulo":
            if let id = accion.articuloID,
               let articulo = ctx.model(for: id) as? Articulo {
                articulo.activo = false
                try? ctx.save()
                ultimaAccion = nil
                return "Deshecho: \(accion.descripcion) desactivado."
            }
        case "crear_factura":
            if let id = accion.facturaID,
               let factura = ctx.model(for: id) as? Factura {
                if factura.estado == .borrador || factura.estado == .presupuesto {
                    factura.estado = .anulada
                    try? ctx.save()
                    ultimaAccion = nil
                    return "Deshecho: \(accion.descripcion) anulada."
                } else {
                    return "No se puede deshacer: la factura ya fue emitida."
                }
            }
        default:
            break
        }

        ultimaAccion = nil
        return "No se pudo deshacer la ultima accion."
    }

    // MARK: - Helper: extraerCantidadYTermino

    private func extraerCantidadYTermino(_ texto: String) -> (Double, String) {
        let palabras = texto.split(separator: " ").map(String.init)

        // Intentar extraer numero al inicio
        if let primera = palabras.first,
           let cantidad = Double(primera.replacingOccurrences(of: ",", with: ".")) {
            let termino = palabras.dropFirst().joined(separator: " ")
            return (cantidad, termino)
        }

        // Buscar palabras numericas
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

    /// Busca articulos por scoring fuzzy. Devuelve el mejor match o nil.
    /// Si hay multiples matches con score similar, devuelve el mejor.
    private func encontrarMejorArticulo(termino: String, en articulos: [Articulo]) -> Articulo? {
        let resultados = buscarArticulos(termino: termino, en: articulos)
        return resultados.first?.0
    }

    /// Busca articulos y devuelve todos los candidatos ordenados por score.
    /// Usado para sugerir alternativas cuando hay ambiguedad.
    private func buscarArticulos(termino: String, en articulos: [Articulo]) -> [(Articulo, Int)] {
        let terminoLower = termino.lowercased()
        let palabras = terminoLower.split(separator: " ").map(String.init).filter { $0.count > 1 }
        let raices = palabras.map { normalizarPalabra($0) }

        var resultados: [(Articulo, Int)] = []
        for art in articulos {
            var score = 0
            let n = art.nombre.lowercased()
            let palabrasNombre = n.split(separator: " ").map(String.init)
            let raicesNombre = palabrasNombre.map { normalizarPalabra($0) }

            // Match exacto del termino completo en nombre
            if n.contains(terminoLower) { score += 10 }

            for p in palabras {
                let raiz = normalizarPalabra(p)

                // Match exacto de palabra
                if n.contains(p) { score += 4 }

                // Match por raiz (bombillas -> bombill, bombilla -> bombill)
                if raicesNombre.contains(where: { $0 == raiz }) { score += 3 }

                // Match parcial de raiz (al menos 4 chars en comun)
                if raiz.count >= 4 {
                    if raicesNombre.contains(where: { $0.hasPrefix(String(raiz.prefix(4))) || raiz.hasPrefix(String($0.prefix(4))) }) {
                        score += 2
                    }
                }

                // Match en etiquetas
                if art.etiquetas.contains(where: { $0.contains(p) || normalizarPalabra($0) == raiz }) { score += 2 }

                // Match en referencia
                if art.referencia.lowercased().contains(p) { score += 2 }
            }

            // Match inverso: alguna palabra del nombre esta en el termino
            for pn in palabrasNombre where pn.count > 2 {
                if terminoLower.contains(pn) { score += 3 }
            }

            if score > 0 { resultados.append((art, score)) }
        }

        return resultados.sorted { $0.1 > $1.1 }.filter { $0.1 >= 2 }
    }

    /// Normaliza una palabra eliminando sufijos comunes del espanol
    /// (plurales, diminutivos, etc.) para matching fuzzy.
    private func normalizarPalabra(_ palabra: String) -> String {
        var p = palabra.lowercased()
        // Eliminar sufijos comunes de plural/variacion
        let sufijos = ["es", "s", "illas", "illos", "ita", "ito", "itas", "itos"]
        for sufijo in sufijos {
            if p.count > sufijo.count + 3 && p.hasSuffix(sufijo) {
                p = String(p.dropLast(sufijo.count))
                break
            }
        }
        return p
    }

    // MARK: - Private helpers for consultarResumen

    private func resumenGeneral(modelContext ctx: ModelContext) -> String {
        let factDesc = FetchDescriptor<Factura>()
        let facturas = (try? ctx.fetch(factDesc)) ?? []
        let clienteDesc = FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo == true })
        let clientes = (try? ctx.fetch(clienteDesc)) ?? []
        let artDesc = FetchDescriptor<Articulo>(predicate: #Predicate<Articulo> { $0.activo == true })
        let articulos = (try? ctx.fetch(artDesc)) ?? []

        let pendiente = facturas.filter { $0.estado == .emitida }.reduce(0) { $0 + $1.totalFactura }
        let cobrado = facturas.filter { $0.estado == .pagada }.reduce(0) { $0 + $1.totalFactura }
        let vencido = facturas.filter { $0.estado == .vencida }.reduce(0) { $0 + $1.totalFactura }

        return """
        Resumen del negocio:
        - \(clientes.count) clientes activos
        - \(articulos.count) articulos en catalogo
        - \(facturas.count) facturas en total
        - Pendiente de cobro: \(formatEuros(pendiente))
        - Cobrado: \(formatEuros(cobrado))
        - Vencido: \(formatEuros(vencido))
        """
    }

    private func resumenFacturas(estado: EstadoFactura, etiqueta: String, modelContext ctx: ModelContext) -> String {
        let desc = FetchDescriptor<Factura>()
        let todas = (try? ctx.fetch(desc)) ?? []
        let facturas = todas.filter { $0.estado == estado }
        if facturas.isEmpty { return "No hay facturas \(etiqueta)." }

        let total = facturas.reduce(0) { $0 + $1.totalFactura }
        let lineas = facturas.prefix(5).map { f in
            "  \u{2022} \(f.numeroFactura) \u{2014} \(f.clienteNombre) \u{2014} \(formatEuros(f.totalFactura))"
        }
        var r = "\(facturas.count) factura(s) \(etiqueta) por \(formatEuros(total)):\n"
        r += lineas.joined(separator: "\n")
        if facturas.count > 5 { r += "\n  ...y \(facturas.count - 5) mas." }
        return r
    }

    private func resumenClientes(modelContext ctx: ModelContext) -> String {
        let desc = FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo == true })
        let clientes = (try? ctx.fetch(desc)) ?? []
        if clientes.isEmpty { return "No hay clientes dados de alta." }
        let lineas = clientes.prefix(10).map { "  \u{2022} \($0.nombre)" }
        return "\(clientes.count) cliente(s):\n" + lineas.joined(separator: "\n")
    }

    private func resumenArticulos(modelContext ctx: ModelContext) -> String {
        let desc = FetchDescriptor<Articulo>(predicate: #Predicate<Articulo> { $0.activo == true })
        let articulos = (try? ctx.fetch(desc)) ?? []
        if articulos.isEmpty { return "No hay articulos en el catalogo." }
        let lineas = articulos.prefix(10).map { "  \u{2022} \($0.nombre) \u{2014} \(formatEuros($0.precioUnitario))/\($0.unidad.abreviatura)" }
        return "\(articulos.count) articulo(s):\n" + lineas.joined(separator: "\n")
    }

    private func formatEuros(_ v: Double) -> String {
        String(format: "%.2f", v) + " \u{20AC}"
    }
}
