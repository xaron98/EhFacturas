// FacturasListView.swift
// FacturaApp — Lista de facturas con dashboard, filtros y detalle.

import SwiftUI
import SwiftData

// MARK: - Vista principal de facturas

struct FacturasListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Factura.fecha, order: .reverse)
    private var facturas: [Factura]

    @State private var filtroEstado: EstadoFactura?
    @State private var textoBusqueda = ""
    @State private var facturaDetalle: Factura?

    private var facturasFiltradas: [Factura] {
        var resultado = facturas
        if let estado = filtroEstado {
            resultado = resultado.filter { $0.estado == estado }
        }
        if !textoBusqueda.isEmpty {
            let q = textoBusqueda.lowercased()
            resultado = resultado.filter {
                $0.numeroFactura.lowercased().contains(q) ||
                $0.clienteNombre.lowercased().contains(q)
            }
        }
        return resultado
    }

    // Stats
    private var totalPendiente: Double {
        facturas.filter { $0.estado == .emitida }.reduce(0) { $0 + $1.totalFactura }
    }
    private var totalCobrado: Double {
        facturas.filter { $0.estado == .pagada }.reduce(0) { $0 + $1.totalFactura }
    }
    private var totalVencido: Double {
        facturas.filter { $0.estado == .vencida }.reduce(0) { $0 + $1.totalFactura }
    }
    private var totalEsteMes: Double {
        let cal = Calendar.current
        let inicio = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return facturas.filter { $0.fecha >= inicio }.reduce(0) { $0 + $1.totalFactura }
    }

    private var facturasVencenPronto: [Factura] {
        let tresDias = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        return facturas.filter {
            guard $0.estado == .emitida, let venc = $0.fechaVencimiento else { return false }
            return venc <= tresDias && venc > .now
        }
    }

    var body: some View {
        Group {
            if facturas.isEmpty {
                ContentUnavailableView {
                    Label("Sin facturas", systemImage: "doc.text")
                } description: {
                    Text("Crea tu primera factura con el micrófono")
                }
            } else {
                List {
                    // Dashboard
                    Section {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(titulo: "Pendiente", valor: totalPendiente, color: .blue, icono: "clock")
                            StatCard(titulo: "Cobrado", valor: totalCobrado, color: .green, icono: "checkmark.circle")
                            StatCard(titulo: "Vencido", valor: totalVencido, color: .red, icono: "exclamationmark.triangle")
                            StatCard(titulo: "Este mes", valor: totalEsteMes, color: .purple, icono: "calendar")
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    // Alertas de vencimiento
                    if !facturasVencenPronto.isEmpty {
                        Section {
                            ForEach(facturasVencenPronto) { f in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    VStack(alignment: .leading) {
                                        Text("\(f.numeroFactura) — \(f.clienteNombre)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        if let venc = f.fechaVencimiento {
                                            Text("Vence \(venc, style: .relative)")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Spacer()
                                    Text(Formateadores.formatEuros(f.totalFactura))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        } header: {
                            Label("Próximas a vencer", systemImage: "bell")
                        }
                    }

                    // Filtros de estado
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filtroChip(estado: nil, label: "Todas", count: facturas.count)
                                ForEach(EstadoFactura.allCases) { est in
                                    filtroChip(estado: est, label: est.descripcion, count: facturas.filter { $0.estado == est }.count)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    // Lista de facturas
                    Section("Facturas (\(facturasFiltradas.count))") {
                        ForEach(facturasFiltradas) { factura in
                            Button {
                                facturaDetalle = factura
                            } label: {
                                FacturaRowView(factura: factura)
                            }
                            .swipeActions(edge: .leading) {
                                if factura.estado == .emitida {
                                    Button {
                                        marcarComoCobrada(factura)
                                    } label: {
                                        Label("Cobrada", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if factura.estado == .emitida || factura.estado == .pagada {
                                    Button(role: .destructive) {
                                        anularFacturaDesdeSwipe(factura)
                                    } label: {
                                        Label("Anular", systemImage: "xmark.circle")
                                    }
                                } else if factura.estado == .borrador || factura.estado == .presupuesto {
                                    Button(role: .destructive) {
                                        factura.estado = .anulada
                                        factura.fechaModificacion = .now
                                        try? modelContext.save()
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $textoBusqueda, prompt: "Buscar factura...")
            }
        }
        .sheet(item: $facturaDetalle) { factura in
            NavigationStack {
                FacturaDetalleView(factura: factura)
            }
        }
    }

    private func filtroChip(estado: EstadoFactura?, label: String, count: Int) -> some View {
        let seleccionado = filtroEstado == estado
        return Button {
            filtroEstado = estado
        } label: {
            HStack(spacing: 4) {
                Text(label)
                Text("\(count)")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(seleccionado ? colorEstado(estado) : Color(.systemGray6))
            .foregroundStyle(seleccionado ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func colorEstado(_ estado: EstadoFactura?) -> Color {
        guard let estado else { return .blue }
        switch estado {
        case .presupuesto: return .purple
        case .borrador: return .gray
        case .emitida: return .blue
        case .pagada: return .green
        case .vencida: return .red
        case .anulada: return .orange
        }
    }

    private func marcarComoCobrada(_ factura: Factura) {
        guard factura.estado == .emitida else { return }
        factura.estado = .pagada
        factura.fechaModificacion = .now
        try? modelContext.save()
        FacturaVencimientoService.shared.cancelarRecordatorios(para: factura)
    }

    private func anularFacturaDesdeSwipe(_ factura: Factura) {
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else { return }
        let _ = VeriFactuHashService.crearRegistroAnulacion(factura: factura, negocio: negocio, modelContext: modelContext)
        factura.estado = .anulada
        factura.fechaModificacion = .now
        try? modelContext.save()
    }
}

// MARK: - StatCard

struct StatCard: View {
    let titulo: String
    let valor: Double
    let color: Color
    let icono: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icono)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(titulo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(Formateadores.formatEuros(valor))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Fila de factura

struct FacturaRowView: View {

    let factura: Factura

    var body: some View {
        HStack(spacing: 12) {
            // Icono estado
            ZStack {
                Circle()
                    .fill(colorEstado.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: iconoEstado)
                    .font(.caption)
                    .foregroundStyle(colorEstado)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(factura.numeroFactura)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    EstadoBadge(estado: factura.estado)
                }
                Text(factura.clienteNombre.isEmpty ? "Sin cliente" : factura.clienteNombre)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formateadores.formatEuros(factura.totalFactura))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(factura.fecha, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var colorEstado: Color {
        switch factura.estado {
        case .presupuesto: return .purple
        case .borrador: return .gray
        case .emitida: return .blue
        case .pagada: return .green
        case .vencida: return .red
        case .anulada: return .orange
        }
    }

    private var iconoEstado: String {
        switch factura.estado {
        case .presupuesto: return "doc.text.magnifyingglass"
        case .borrador: return "doc"
        case .emitida: return "paperplane"
        case .pagada: return "checkmark.circle"
        case .vencida: return "exclamationmark.triangle"
        case .anulada: return "xmark.circle"
        }
    }
}

// MARK: - Detalle de factura

struct FacturaDetalleView: View {

    let factura: Factura
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var mostrarPDF = false
    @State private var mostrarShareXML = false
    @State private var xmlData: Data?
    @State private var confirmarEmision = false
    @State private var confirmarAnulacion = false

    var body: some View {
        List {
            // Cabecera
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(factura.numeroFactura)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(factura.clienteNombre.isEmpty ? "Sin cliente" : factura.clienteNombre)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(Formateadores.formatEuros(factura.totalFactura))
                            .font(.title2)
                            .fontWeight(.bold)
                        EstadoBadge(estado: factura.estado)
                    }
                }
            }

            // Barra de acciones
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        accionBoton("PDF", icono: "doc.richtext", color: .blue) {
                            generarYMostrarPDF()
                        }
                        if factura.estado != .borrador && !(factura.registros ?? []).isEmpty {
                            accionBoton("XML", icono: "doc.text", color: .orange) {
                                generarXMLDetalle()
                            }
                        }
                        if factura.estado == .borrador {
                            accionBoton("Emitir", icono: "paperplane", color: .blue) {
                                confirmarEmision = true
                            }
                        }
                        if factura.estado == .emitida {
                            accionBoton("Cobrar", icono: "checkmark.circle", color: .green) {
                                factura.estado = .pagada
                                factura.fechaModificacion = .now
                                try? modelContext.save()
                            }
                        }
                        if factura.estado == .emitida || factura.estado == .pagada {
                            accionBoton("Anular", icono: "xmark.circle", color: .red) {
                                confirmarAnulacion = true
                            }
                        }
                        if factura.estado == .presupuesto {
                            accionBoton("Convertir", icono: "arrow.right.doc", color: .blue) {
                                factura.estado = .borrador
                                factura.fechaModificacion = .now
                                try? modelContext.save()
                            }
                        }
                        if factura.estado == .emitida || factura.estado == .anulada {
                            accionBoton("Rectificar", icono: "doc.on.doc", color: .purple) {
                                crearRectificativa(factura)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Fechas
            Section("Fechas") {
                HStack {
                    Text("Emisión")
                    Spacer()
                    Text(Formateadores.fechaCorta.string(from: factura.fecha))
                }
                if let venc = factura.fechaVencimiento {
                    HStack {
                        Text("Vencimiento")
                        Spacer()
                        Text(Formateadores.fechaCorta.string(from: venc))
                            .foregroundStyle(venc < .now && factura.estado == .emitida ? .red : .primary)
                    }
                }
            }

            // Cliente
            if !factura.clienteNombre.isEmpty {
                Section("Cliente") {
                    Text(factura.clienteNombre)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !factura.clienteNIF.isEmpty {
                        HStack {
                            Text("NIF")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(factura.clienteNIF)
                        }
                        .font(.caption)
                    }
                    if !factura.clienteDireccion.isEmpty {
                        Text(factura.clienteDireccion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Líneas
            Section("Líneas (\(factura.lineasArray.count))") {
                ForEach(factura.lineasOrdenadas) { linea in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(linea.concepto)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(Formateadores.formatEuros(linea.subtotal))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("\(String(format: "%.2f", linea.cantidad)) \(linea.unidad.abreviatura) × \(Formateadores.formatEuros(linea.precioUnitario))")
                            if linea.descuentoPorcentaje > 0 {
                                Text("-\(String(format: "%.0f", linea.descuentoPorcentaje))%")
                                    .foregroundStyle(.red)
                            }
                            Text("IVA \(String(format: "%.0f", linea.porcentajeIVA))%")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            // Totales
            Section("Totales") {
                HStack {
                    Text("Base imponible")
                    Spacer()
                    Text(Formateadores.formatEuros(factura.baseImponible))
                }
                if factura.descuentoGlobalPorcentaje > 0 {
                    HStack {
                        Text("Descuento (\(String(format: "%.0f", factura.descuentoGlobalPorcentaje))%)")
                        Spacer()
                        let descuento = factura.lineasArray.reduce(0) { $0 + $1.subtotal } * factura.descuentoGlobalPorcentaje / 100
                        Text("-\(Formateadores.formatEuros(descuento))")
                            .foregroundStyle(.red)
                    }
                }
                // Desglose IVA
                ForEach(factura.desgloseIVA, id: \.porcentaje) { item in
                    HStack {
                        Text("IVA \(String(format: "%.0f", item.porcentaje))%")
                        Spacer()
                        Text(Formateadores.formatEuros(item.cuota))
                    }
                }
                if factura.totalIRPF > 0 {
                    HStack {
                        Text("IRPF")
                        Spacer()
                        Text("-\(Formateadores.formatEuros(factura.totalIRPF))")
                            .foregroundStyle(.red)
                    }
                }
                HStack {
                    Text("TOTAL")
                        .fontWeight(.bold)
                    Spacer()
                    Text(Formateadores.formatEuros(factura.totalFactura))
                        .fontWeight(.bold)
                        .font(.title3)
                }
            }

            // Observaciones
            if !factura.observaciones.isEmpty {
                Section("Observaciones") {
                    Text(factura.observaciones)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !factura.notasInternas.isEmpty {
                Section("Notas internas") {
                    Text(factura.notasInternas)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Prompt original
            if let prompt = factura.promptOriginal, !prompt.isEmpty {
                Section("Comando de voz original") {
                    Text(prompt)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        }
        .navigationTitle(factura.estado == .presupuesto ? "Presupuesto" : "Factura")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
        .sheet(isPresented: $mostrarPDF) {
            if let data = factura.pdfData {
                FacturaPDFPreviewView(pdfData: data, nombreArchivo: "\(factura.numeroFactura).pdf")
            }
        }
        .sheet(isPresented: $mostrarShareXML) {
            if let data = xmlData {
                ShareSheet(items: [data])
            }
        }
        .confirmationDialog("¿Emitir factura?", isPresented: $confirmarEmision) {
            Button("Emitir") { emitirFactura(factura) }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Una vez emitida, la factura no se podrá modificar. Se generará un registro VeriFactu.")
        }
        .confirmationDialog("¿Anular factura?", isPresented: $confirmarAnulacion) {
            Button("Anular", role: .destructive) { anularFactura(factura) }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se creará un registro de anulación VeriFactu. Esta acción no se puede deshacer.")
        }
    }

    private func accionBoton(_ label: String, icono: String, color: Color, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            VStack(spacing: 4) {
                Image(systemName: icono)
                    .font(.body)
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 60, height: 50)
            .background(color.opacity(0.08))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func generarYMostrarPDF() {
        // Buscar negocio
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else { return }
        let data = FacturaPDFGenerator.generar(factura: factura, negocio: negocio)
        factura.pdfData = data
        mostrarPDF = true
    }

    private func generarXMLDetalle() {
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else { return }
        guard let registro = (factura.registros ?? []).sorted(by: { $0.fechaHoraGeneracion > $1.fechaHoraGeneracion }).first else { return }
        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)
        xmlData = xml.data(using: .utf8)
        mostrarShareXML = true
    }

    private func emitirFactura(_ factura: Factura) {
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else { return }
        let registro = VeriFactuHashService.crearRegistroAlta(factura: factura, negocio: negocio, modelContext: modelContext)
        factura.estado = .emitida
        factura.fechaModificacion = .now
        try? modelContext.save()

        EventLogService.registrar(tipo: EventLogService.FACTURA_EMITIDA, descripcion: "Factura emitida", numeroFactura: factura.numeroFactura, modelContext: modelContext)

        if negocio.envioAutomatico {
            Task {
                await VeriFactuSOAPClient.shared.enviarRegistro(
                    registro: registro,
                    negocio: negocio,
                    modelContext: modelContext
                )
            }
        }
    }

    private func anularFactura(_ factura: Factura) {
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else { return }
        let registro = VeriFactuHashService.crearRegistroAnulacion(factura: factura, negocio: negocio, modelContext: modelContext)
        factura.estado = .anulada
        factura.fechaModificacion = .now
        try? modelContext.save()

        EventLogService.registrar(tipo: EventLogService.FACTURA_ANULADA, descripcion: "Factura anulada", numeroFactura: factura.numeroFactura, modelContext: modelContext)

        if negocio.envioAutomatico {
            Task {
                await VeriFactuSOAPClient.shared.enviarRegistro(
                    registro: registro,
                    negocio: negocio,
                    modelContext: modelContext
                )
            }
        }
    }

    private func crearRectificativa(_ facturaOriginal: Factura) {
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else { return }

        let nueva = Factura(
            numeroFactura: negocio.generarNumeroFactura(),
            cliente: facturaOriginal.cliente,
            estado: .borrador,
            observaciones: "Rectifica a \(facturaOriginal.numeroFactura)"
        )
        nueva.tipoFactura = .rectificativa
        nueva.facturaRectificada = facturaOriginal

        for (i, lineaOrig) in facturaOriginal.lineasOrdenadas.enumerated() {
            let copia = LineaFactura(
                orden: i,
                articulo: lineaOrig.articulo,
                referencia: lineaOrig.referencia,
                concepto: lineaOrig.concepto,
                cantidad: lineaOrig.cantidad,
                unidad: lineaOrig.unidad,
                precioUnitario: lineaOrig.precioUnitario,
                descuentoPorcentaje: lineaOrig.descuentoPorcentaje,
                porcentajeIVA: lineaOrig.porcentajeIVA
            )
            if nueva.lineas == nil { nueva.lineas = [] }
            nueva.lineas!.append(copia)
        }

        nueva.recalcularTotales(irpfPorcentaje: negocio.irpfPorcentaje, aplicarIRPF: negocio.aplicarIRPF)
        modelContext.insert(nueva)
        try? modelContext.save()

        EventLogService.registrar(tipo: EventLogService.FACTURA_RECTIFICADA, descripcion: "Factura rectificativa creada desde \(facturaOriginal.numeroFactura)", numeroFactura: nueva.numeroFactura, modelContext: modelContext)
    }
}
