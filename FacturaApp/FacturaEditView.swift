// FacturaEditView.swift
// FacturaApp — Pantalla completa de edición de factura con IA
// Cabecera, líneas editables, totales, barra de comandos IA.

import SwiftUI
import SwiftData

// MARK: - FacturaEditView

struct FacturaEditView: View {

    let factura: Factura

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var editAI: FacturaEditAIService
    @State private var textoComando = ""
    @State private var mostrarPDF = false
    @State private var mostrarShareXML = false
    @State private var xmlDataParaCompartir: Data?
    @State private var refreshTrigger = 0
    @State private var confirmarEmision = false
    @State private var mostrarErrorNegocio = false
    @State private var generandoPDF = false
    @State private var mostrarEnviarPDF = false
    @State private var pdfParaEnviar: Data?
    @State private var mostrarFotos = false
    @State private var mostrarFirma = false

    private var esEditable: Bool {
        factura.estado == .borrador
    }

    init(factura: Factura) {
        self.factura = factura
        _editAI = StateObject(wrappedValue: FacturaEditAIService(
            factura: factura,
            modelContext: DataConfig.container.mainContext
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    cabeceraSection
                    accionesSection
                    lineasSection
                    totalesSection

                    if let respuesta = editAI.ultimaRespuesta {
                        Section("Respuesta IA") {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                                    .font(.caption)
                                Text(respuesta)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !(factura.registros ?? []).isEmpty {
                        Section("VeriFactu") {
                            ForEach((factura.registros ?? []).sorted(by: { $0.fechaHoraGeneracion < $1.fechaHoraGeneracion }), id: \.persistentModelID) { registro in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(registro.tipoRegistro == .alta ? "Registro de alta" : "Registro de anulación")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(registro.fechaHoraGeneracion, style: .date)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Hash: \(String(registro.hashRegistro.prefix(16)))...")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .monospaced()
                                    HStack {
                                        Image(systemName: estadoEnvioIcono(registro.estadoEnvio))
                                            .font(.caption2)
                                            .foregroundStyle(estadoEnvioColor(registro.estadoEnvio))
                                        Text(estadoEnvioTexto(registro.estadoEnvio))
                                            .font(.caption2)
                                            .foregroundStyle(estadoEnvioColor(registro.estadoEnvio))
                                        Spacer()
                                        if registro.estadoEnvio == .pendiente || registro.estadoEnvio == .error {
                                            Button("Reintentar") {
                                                Task {
                                                    let desc = FetchDescriptor<Negocio>()
                                                    if let negocio = try? modelContext.fetch(desc).first {
                                                        await VeriFactuSOAPClient.shared.enviarRegistro(
                                                            registro: registro,
                                                            negocio: negocio,
                                                            modelContext: modelContext
                                                        )
                                                        refreshTrigger += 1
                                                    }
                                                }
                                            }
                                            .font(.caption2)
                                            .foregroundStyle(.blue)
                                        }
                                    }
                                    if !registro.respuestaAEAT.isEmpty {
                                        Text(registro.respuestaAEAT)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
                .sensoryFeedback(.impact, trigger: refreshTrigger)

                Divider()
                aiInputBar
            }
            .navigationTitle(factura.numeroFactura.isEmpty ? "Nueva factura" : factura.numeroFactura)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear {
                editAI.onFacturaUpdated = { refreshTrigger += 1 }
            }
            .sheet(isPresented: $mostrarPDF) {
                if let data = factura.pdfData {
                    FacturaPDFPreviewView(
                        pdfData: data,
                        nombreArchivo: "\(factura.numeroFactura).pdf"
                    )
                }
            }
            .sheet(isPresented: $mostrarShareXML) {
                if let data = xmlDataParaCompartir {
                    ShareSheet(items: [data])
                }
            }
            .confirmationDialog("¿Emitir factura?", isPresented: $confirmarEmision) {
                Button("Emitir") { emitirFacturaDesdeEditor() }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Una vez emitida, no se podrá modificar.")
            }
            .alert("Datos del negocio", isPresented: $mostrarErrorNegocio) {
                Button("OK") { }
            } message: {
                Text("Configura los datos de tu negocio en Ajustes antes de generar el PDF.")
            }
            .sheet(isPresented: $mostrarEnviarPDF) {
                if let data = pdfParaEnviar {
                    ShareSheet(items: [data])
                }
            }
            .sheet(isPresented: $mostrarFotos) {
                FotosFacturaView(factura: factura)
            }
            .sheet(isPresented: $mostrarFirma) {
                FirmaView(factura: factura)
            }
        }
    }

    // MARK: - Cabecera

    private var cabeceraSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if !factura.numeroFactura.isEmpty {
                        Text(factura.numeroFactura)
                            .font(.headline)
                    }
                    if !factura.clienteNombre.isEmpty {
                        Text(factura.clienteNombre)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    EstadoBadge(estado: factura.estado)
                    Text(Formateadores.formatEuros(factura.totalFactura))
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Acciones

    private var accionesSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if generandoPDF {
                        ProgressView()
                            .frame(width: 60, height: 50)
                    } else {
                        miniBoton(titulo: "PDF", icono: "doc.richtext", color: .blue) {
                            generarPDF()
                        }
                    }

                    if factura.estado != .borrador && !(factura.registros ?? []).isEmpty {
                        miniBoton(titulo: "XML", icono: "doc.text", color: .orange) {
                            generarXML()
                        }
                    }

                    if factura.estado == .borrador {
                        miniBoton(titulo: "Emitir", icono: "paperplane", color: .green) {
                            confirmarEmision = true
                        }
                    }

                    miniBoton(titulo: "Enviar", icono: "paperplane.fill", color: .blue) {
                        enviarPDF()
                    }

                    if factura.estado == .emitida {
                        miniBoton(titulo: "Cobrar", icono: "banknote", color: .orange) {
                            factura.estado = .pagada
                            factura.fechaModificacion = .now
                            try? modelContext.save()
                            refreshTrigger += 1
                        }
                    }

                    miniBoton(titulo: "Fotos", icono: "camera.fill", color: .indigo) {
                        mostrarFotos = true
                    }

                    miniBoton(titulo: "Firma", icono: "pencil.tip", color: .brown) {
                        mostrarFirma = true
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Líneas

    private var lineasSection: some View {
        Section("Líneas") {
            linesList
            if esEditable {
                botonAnadirLinea
            }
        }
    }

    private var linesList: some View {
        ForEach(factura.lineasOrdenadas) { linea in
            lineaRow(linea)
        }
        .onDelete { offsets in
            if esEditable { eliminarLineas(at: offsets) }
        }
    }

    private var botonAnadirLinea: some View {
        Button {
            let siguienteOrden = (factura.lineasArray.map { $0.orden }.max() ?? -1) + 1
            let nueva = LineaFactura(orden: siguienteOrden, concepto: "", cantidad: 1, precioUnitario: 0)
            if factura.lineas == nil { factura.lineas = [] }
            factura.lineas!.append(nueva)
            recalcular()
            refreshTrigger += 1
        } label: {
            Label("Añadir línea", systemImage: "plus.circle")
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func lineaRow(_ linea: LineaFactura) -> some View {
        if esEditable {
            LineaEditRow(linea: linea, onChanged: {
                recalcular()
                refreshTrigger += 1
            })
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(linea.concepto)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack {
                    Text("\(String(format: "%.2f", linea.cantidad)) \(linea.unidad.abreviatura) × \(Formateadores.formatEuros(linea.precioUnitario))")
                    Spacer()
                    Text(Formateadores.formatEuros(linea.subtotal))
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func eliminarLineas(at offsets: IndexSet) {
        let ordenadas = factura.lineasOrdenadas
        for index in offsets {
            let linea = ordenadas[index]
            factura.lineas?.removeAll { $0.persistentModelID == linea.persistentModelID }
            modelContext.delete(linea)
        }
        recalcular()
        refreshTrigger += 1
    }

    // MARK: - Totales

    private var totalesSection: some View {
        Section("Totales") {
            filaTotal("Base imponible", valor: factura.baseImponible)

            if factura.descuentoGlobalPorcentaje > 0 {
                let descuento = factura.lineasArray.reduce(0) { $0 + $1.subtotal } * factura.descuentoGlobalPorcentaje / 100
                HStack {
                    Text("Descuento (\(String(format: "%.0f", factura.descuentoGlobalPorcentaje))%)")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Spacer()
                    Text("-\(Formateadores.formatEuros(descuento))")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            ForEach(factura.desgloseIVA, id: \.porcentaje) { item in
                filaTotal("IVA \(String(format: "%.0f", item.porcentaje))%", valor: item.cuota)
            }

            if factura.totalIRPF > 0 {
                HStack {
                    Text("IRPF")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Spacer()
                    Text("-\(Formateadores.formatEuros(factura.totalIRPF))")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(Formateadores.formatEuros(factura.totalFactura))
                    .font(.headline)
            }
        }
    }

    private func filaTotal(_ etiqueta: String, valor: Double) -> some View {
        HStack {
            Text(etiqueta)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(Formateadores.formatEuros(valor))
                .font(.subheadline)
        }
    }

    // MARK: - Barra de entrada IA

    private var aiInputBar: some View {
        Group {
            if esEditable {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                        .font(.title3)

                    TextField("Ej: Añade 3 bombillas a 12€", text: $textoComando)
                        .textFieldStyle(.plain)
                        .submitLabel(.send)
                        .onSubmit {
                            enviarComandoIA()
                        }

                    Button {
                        enviarComandoIA()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(textoComando.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .purple)
                    }
                    .disabled(textoComando.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editAI.procesando)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Factura emitida — no se puede editar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Helpers

    private func enviarComandoIA() {
        let cmd = textoComando.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        textoComando = ""

        Task {
            await editAI.procesarComando(cmd)
        }
    }

    private func emitirFacturaDesdeEditor() {
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else { return }
        let registro = VeriFactuHashService.crearRegistroAlta(factura: factura, negocio: negocio, modelContext: modelContext)
        factura.estado = .emitida
        factura.fechaModificacion = .now
        try? modelContext.save()
        refreshTrigger += 1

        // Auto-send if enabled
        if negocio.envioAutomatico {
            Task {
                await VeriFactuSOAPClient.shared.enviarRegistro(
                    registro: registro,
                    negocio: negocio,
                    modelContext: modelContext
                )
                refreshTrigger += 1
            }
        }
    }

    private func recalcular() {
        let descriptor = FetchDescriptor<Negocio>()
        let negocio = (try? modelContext.fetch(descriptor))?.first
        factura.recalcularTotales(
            irpfPorcentaje: negocio?.irpfPorcentaje ?? 15.0,
            aplicarIRPF: negocio?.aplicarIRPF ?? false
        )
        try? modelContext.save()
    }

    private func generarPDF() {
        generandoPDF = true
        let descriptor = FetchDescriptor<Negocio>()
        guard let negocio = (try? modelContext.fetch(descriptor))?.first else {
            mostrarErrorNegocio = true
            generandoPDF = false
            return
        }
        let data = FacturaPDFGenerator.generar(factura: factura, negocio: negocio)
        factura.pdfData = data
        try? modelContext.save()
        generandoPDF = false
        mostrarPDF = true
    }

    private func enviarPDF() {
        let descriptor = FetchDescriptor<Negocio>()
        guard let negocio = (try? modelContext.fetch(descriptor))?.first else {
            mostrarErrorNegocio = true
            return
        }
        let data = FacturaPDFGenerator.generar(factura: factura, negocio: negocio)
        factura.pdfData = data
        try? modelContext.save()
        pdfParaEnviar = data
        mostrarEnviarPDF = true
    }

    private func generarXML() {
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else {
            mostrarErrorNegocio = true
            return
        }
        guard let registro = (factura.registros ?? []).sorted(by: { $0.fechaHoraGeneracion > $1.fechaHoraGeneracion }).first else { return }
        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)
        if let data = xml.data(using: .utf8) {
            xmlDataParaCompartir = data
            mostrarShareXML = true
        }
    }

    private func miniBoton(titulo: String, icono: String, color: Color, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Label(titulo, systemImage: icono)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(color.opacity(0.12))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func estadoEnvioTexto(_ estado: EstadoEnvioVF) -> String {
        switch estado {
        case .noEnviado: return "No enviado"
        case .pendiente: return "Pendiente"
        case .enviado: return "Enviado a AEAT"
        case .rechazado: return "Rechazado"
        case .error: return "Error"
        }
    }

    private func estadoEnvioColor(_ estado: EstadoEnvioVF) -> Color {
        switch estado {
        case .noEnviado: return .secondary
        case .pendiente: return .orange
        case .enviado: return .green
        case .rechazado, .error: return .red
        }
    }

    private func estadoEnvioIcono(_ estado: EstadoEnvioVF) -> String {
        switch estado {
        case .noEnviado: return "circle"
        case .pendiente: return "clock"
        case .enviado: return "checkmark.circle.fill"
        case .rechazado: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - LineaEditRow

struct LineaEditRow: View {

    let linea: LineaFactura
    let onChanged: () -> Void

    @State private var conceptoTexto: String = ""
    @State private var cantidadTexto: String = ""
    @State private var precioTexto: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Concepto", text: $conceptoTexto)
                .font(.subheadline)
                .onChange(of: conceptoTexto) {
                    linea.concepto = conceptoTexto
                    onChanged()
                }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Cant:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $cantidadTexto)
                        .font(.caption)
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                        .onChange(of: cantidadTexto) {
                            if let valor = Formateadores.parsearPrecio(cantidadTexto) {
                                linea.cantidad = valor
                                linea.recalcular()
                                onChanged()
                            }
                        }
                }

                HStack(spacing: 4) {
                    Text("Precio:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0,00", text: $precioTexto)
                        .font(.caption)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .onChange(of: precioTexto) {
                            if let valor = Formateadores.parsearPrecio(precioTexto) {
                                linea.precioUnitario = valor
                                linea.recalcular()
                                onChanged()
                            }
                        }
                }

                Spacer()

                Text(Formateadores.formatEuros(linea.subtotal))
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            conceptoTexto = linea.concepto
            cantidadTexto = String(format: "%.2f", linea.cantidad)
                .replacingOccurrences(of: ".", with: ",")
            precioTexto = String(format: "%.2f", linea.precioUnitario)
                .replacingOccurrences(of: ".", with: ",")
        }
    }
}
