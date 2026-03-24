# Factura Inline Card + Real-Time AI Editing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show created invoices as interactive cards in the chat, with a fullscreen editable sheet where the user can modify lines manually or by voice/text AI commands, with instant visual updates.

**Architecture:** New `FacturaEditView.swift` for the editable sheet with inline AI. New `FacturaCardView` embedded in chat messages. New `FacturaEditAIService.swift` with 4 context-aware tools for modifying invoices. The chat's `MensajeChat` gains a `.factura` type that renders the card. Changes recalculate totals instantly and PDF regenerates on demand.

**Tech Stack:** SwiftUI, SwiftData, FoundationModels (Tool protocol), PDFKit

---

### Task 1: Add factura reference to MensajeChat and ComandoResultado

**Files:**
- Modify: `FacturaApp/VoiceMainView.swift` (MensajeChat struct)
- Modify: `FacturaApp/CommandAIService.swift` (ComandoResultado, CrearFacturaTool)

- [ ] **Step 1: Add `.factura` case to MensajeChat.Tipo**

In `VoiceMainView.swift`, update `MensajeChat`:
```swift
struct MensajeChat: Identifiable {
    let id = UUID()
    let timestamp: Date
    let tipo: Tipo
    let texto: String
    var accion: ComandoResultado.AccionRealizada?
    var facturaID: PersistentIdentifier?  // NEW: reference to factura

    enum Tipo {
        case usuario
        case ia
        case error
        case sistema
        case factura  // NEW
    }
}
```

- [ ] **Step 2: Update ComandoResultado to carry factura ID**

In `CommandAIService.swift`, change `datosExtra: Any?` to a typed field:
```swift
struct ComandoResultado {
    var mensaje: String
    var accionRealizada: AccionRealizada
    var facturaID: PersistentIdentifier?  // NEW: replaces datosExtra
}
```

- [ ] **Step 3: Update CrearFacturaTool to return factura ID**

In `CrearFacturaTool.call()`, after `modelContext.insert(factura)` and `save()`, store the factura's persistentModelID so the service can capture it. Since Tool.call() returns String, encode the ID info in the response text with a marker:
```swift
// At end of call(), after save:
return "##FACTURA_ID##\(factura.numeroFactura)##END##\n" + respuesta
```

- [ ] **Step 4: Update procesarComando to detect factura creation and extract ID**

In `CommandAIService.procesarComando()`, after getting the response, check for the factura marker and look up the factura:
```swift
// After getting respuestaTexto:
var facturaID: PersistentIdentifier?
var textoLimpio = respuestaTexto

if respuestaTexto.contains("##FACTURA_ID##") {
    // Extract numero factura
    if let range = respuestaTexto.range(of: "##FACTURA_ID##(.+?)##END##", options: .regularExpression) {
        let numFactura = String(respuestaTexto[range])
            .replacingOccurrences(of: "##FACTURA_ID##", with: "")
            .replacingOccurrences(of: "##END##", with: "")
        // Look up the factura
        let desc = FetchDescriptor<Factura>()
        if let facturas = try? modelContext.fetch(desc),
           let factura = facturas.first(where: { $0.numeroFactura == numFactura }) {
            facturaID = factura.persistentModelID
        }
        textoLimpio = respuestaTexto.replacingOccurrences(of: "##FACTURA_ID##\(numFactura)##END##\n", with: "")
    }
}

let resultado = ComandoResultado(
    mensaje: textoLimpio,
    accionRealizada: accion,
    facturaID: facturaID
)
```

- [ ] **Step 5: Update enviarComando in VoiceMainView to create .factura message**

In `VoiceMainView.enviarComando()`, when adding the IA response message:
```swift
if let resultado = aiService.ultimaRespuesta {
    if let fID = resultado.facturaID {
        // Factura message with card
        mensajes.append(MensajeChat(
            timestamp: .now,
            tipo: .factura,
            texto: resultado.mensaje,
            accion: resultado.accionRealizada,
            facturaID: fID
        ))
    } else {
        // Normal IA message
        mensajes.append(MensajeChat(
            timestamp: .now,
            tipo: resultado.accionRealizada == .error ? .error : .ia,
            texto: resultado.mensaje,
            accion: resultado.accionRealizada
        ))
    }
}
```

---

### Task 2: Create FacturaCardView (compact card for chat)

**Files:**
- Create: `FacturaApp/FacturaCardView.swift`

- [ ] **Step 1: Create the compact card view**

```swift
// FacturaCardView.swift
import SwiftUI
import SwiftData

struct FacturaCardView: View {
    let factura: Factura
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Row 1: Number + Status
                HStack {
                    Text(factura.numeroFactura)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    EstadoBadge(estado: factura.estado)
                    Spacer()
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }

                // Row 2: Client
                if !factura.clienteNombre.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(factura.clienteNombre)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Row 3: Lines summary + Total
                HStack {
                    Text("\(factura.lineas.count) línea(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Formateadores.formatEuros(factura.totalFactura))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
            }
            .padding(14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Add .factura case rendering in VoiceMainView.mensajeView()**

In `VoiceMainView.swift`, add the case inside `mensajeView()`:
```swift
case .factura:
    if let fID = msg.facturaID {
        FacturaChatCard(facturaID: fID, texto: msg.texto) { factura in
            facturaParaEditar = factura
        }
    }
```

Create a helper view that fetches the factura by ID:
```swift
struct FacturaChatCard: View {
    let facturaID: PersistentIdentifier
    let texto: String
    let onEdit: (Factura) -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // IA response text
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple.opacity(0.6))
                Text(texto)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            // Card
            if let factura = modelContext.model(for: facturaID) as? Factura {
                FacturaCardView(factura: factura) {
                    onEdit(factura)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add state and sheet binding in VoiceMainView**

Add to VoiceMainView:
```swift
@State private var facturaParaEditar: Factura?
```

Add sheet:
```swift
.sheet(item: $facturaParaEditar) { factura in
    FacturaEditView(factura: factura)
}
```

---

### Task 3: Create FacturaEditAIService with contextual tools

**Files:**
- Create: `FacturaApp/FacturaEditAIService.swift`

- [ ] **Step 1: Create the 4 tools for invoice editing**

```swift
// FacturaEditAIService.swift
import Foundation
import Combine
import FoundationModels
import SwiftData

// Tool: Modify an existing line
struct ModificarLineaTool: Tool, @unchecked Sendable {
    let name = "modificar_linea"
    let description = "Modifica una línea existente de la factura. Usa para cambiar cantidad, precio o concepto."

    @Generable
    struct Arguments {
        @Guide(description: "Nombre o parte del concepto de la línea a modificar")
        var concepto: String
        @Guide(description: "Nueva cantidad. 0 si no cambia.", .minimum(0))
        var cantidad: Double
        @Guide(description: "Nuevo precio unitario sin IVA. -1 si no cambia.")
        var precioUnitario: Double
        @Guide(description: "Nuevo concepto. Vacío si no cambia.")
        var nuevoConcepto: String
    }

    let factura: Factura
    let modelContext: ModelContext
    let onUpdate: () -> Void

    func call(arguments: Arguments) async throws -> String {
        let busqueda = arguments.concepto.lowercased()
        guard let linea = factura.lineas.first(where: {
            $0.concepto.lowercased().contains(busqueda)
        }) else {
            return "No encontré la línea '\(arguments.concepto)' en la factura."
        }

        if arguments.cantidad > 0 { linea.cantidad = arguments.cantidad }
        if arguments.precioUnitario >= 0 { linea.precioUnitario = arguments.precioUnitario }
        if !arguments.nuevoConcepto.isEmpty { linea.concepto = arguments.nuevoConcepto }

        recalcularYGuardar()
        return "Línea '\(linea.concepto)' actualizada: \(String(format: "%.0f", linea.cantidad)) × \(String(format: "%.2f", linea.precioUnitario))€ = \(String(format: "%.2f", linea.subtotal))€"
    }

    private func recalcularYGuardar() {
        let desc = FetchDescriptor<Negocio>()
        let negocio = (try? modelContext.fetch(desc))?.first
        factura.recalcularTotales(
            irpfPorcentaje: negocio?.irpfPorcentaje ?? 15.0,
            aplicarIRPF: negocio?.aplicarIRPF ?? false
        )
        try? modelContext.save()
        onUpdate()
    }
}

// Tool: Add a new line
struct AnadirLineaTool: Tool, @unchecked Sendable {
    let name = "anadir_linea"
    let description = "Añade una nueva línea a la factura."

    @Generable
    struct Arguments {
        @Guide(description: "Concepto o nombre del producto/servicio")
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
    let onUpdate: () -> Void

    func call(arguments: Arguments) async throws -> String {
        let unidad = UnidadMedida(rawValue: arguments.unidad) ?? .unidad
        let orden = (factura.lineas.map(\.orden).max() ?? -1) + 1

        let linea = LineaFactura(
            orden: orden,
            concepto: arguments.concepto,
            cantidad: arguments.cantidad,
            unidad: unidad,
            precioUnitario: arguments.precioUnitario,
            porcentajeIVA: 21.0
        )
        factura.lineas.append(linea)

        recalcularYGuardar()
        return "Añadida: \(String(format: "%.0f", arguments.cantidad)) \(unidad.rawValue) × \(arguments.concepto) a \(String(format: "%.2f", arguments.precioUnitario))€"
    }

    private func recalcularYGuardar() {
        let desc = FetchDescriptor<Negocio>()
        let negocio = (try? modelContext.fetch(desc))?.first
        factura.recalcularTotales(
            irpfPorcentaje: negocio?.irpfPorcentaje ?? 15.0,
            aplicarIRPF: negocio?.aplicarIRPF ?? false
        )
        try? modelContext.save()
        onUpdate()
    }
}

// Tool: Remove a line
struct EliminarLineaTool: Tool, @unchecked Sendable {
    let name = "eliminar_linea"
    let description = "Elimina una línea de la factura."

    @Generable
    struct Arguments {
        @Guide(description: "Nombre o parte del concepto de la línea a eliminar")
        var concepto: String
    }

    let factura: Factura
    let modelContext: ModelContext
    let onUpdate: () -> Void

    func call(arguments: Arguments) async throws -> String {
        let busqueda = arguments.concepto.lowercased()
        guard let linea = factura.lineas.first(where: {
            $0.concepto.lowercased().contains(busqueda)
        }) else {
            return "No encontré la línea '\(arguments.concepto)' en la factura."
        }
        let nombre = linea.concepto
        factura.lineas.removeAll { $0.persistentModelID == linea.persistentModelID }
        modelContext.delete(linea)

        recalcularYGuardar()
        return "Eliminada la línea '\(nombre)'."
    }

    private func recalcularYGuardar() {
        let desc = FetchDescriptor<Negocio>()
        let negocio = (try? modelContext.fetch(desc))?.first
        factura.recalcularTotales(
            irpfPorcentaje: negocio?.irpfPorcentaje ?? 15.0,
            aplicarIRPF: negocio?.aplicarIRPF ?? false
        )
        try? modelContext.save()
        onUpdate()
    }
}

// Tool: Change global discount
struct CambiarDescuentoTool: Tool, @unchecked Sendable {
    let name = "cambiar_descuento"
    let description = "Cambia el descuento global de la factura."

    @Generable
    struct Arguments {
        @Guide(description: "Porcentaje de descuento (0-100)", .range(0...100))
        var porcentaje: Double
    }

    let factura: Factura
    let modelContext: ModelContext
    let onUpdate: () -> Void

    func call(arguments: Arguments) async throws -> String {
        factura.descuentoGlobalPorcentaje = arguments.porcentaje

        let desc = FetchDescriptor<Negocio>()
        let negocio = (try? modelContext.fetch(desc))?.first
        factura.recalcularTotales(
            irpfPorcentaje: negocio?.irpfPorcentaje ?? 15.0,
            aplicarIRPF: negocio?.aplicarIRPF ?? false
        )
        try? modelContext.save()
        onUpdate()
        return "Descuento global cambiado a \(String(format: "%.0f", arguments.porcentaje))%. Nuevo total: \(String(format: "%.2f", factura.totalFactura))€"
    }
}

// MARK: - Servicio de edición IA

@MainActor
final class FacturaEditAIService: ObservableObject {
    @Published var procesando = false
    @Published var ultimaRespuesta: String?

    private let factura: Factura
    private let modelContext: ModelContext
    private var session: LanguageModelSession?
    var onFacturaUpdated: (() -> Void)?

    init(factura: Factura, modelContext: ModelContext) {
        self.factura = factura
        self.modelContext = modelContext
        crearSesion()
    }

    private func crearSesion() {
        let updateHandler: () -> Void = { [weak self] in
            self?.onFacturaUpdated?()
        }

        session = LanguageModelSession(
            tools: [
                ModificarLineaTool(factura: factura, modelContext: modelContext, onUpdate: updateHandler),
                AnadirLineaTool(factura: factura, modelContext: modelContext, onUpdate: updateHandler),
                EliminarLineaTool(factura: factura, modelContext: modelContext, onUpdate: updateHandler),
                CambiarDescuentoTool(factura: factura, modelContext: modelContext, onUpdate: updateHandler)
            ]
        ) {
            """
            Estás editando la factura \(self.factura.numeroFactura) de \(self.factura.clienteNombre).
            Líneas actuales:
            \(self.factura.lineasOrdenadas.map { "- \(String(format: "%.0f", $0.cantidad)) \($0.unidad.rawValue) × \($0.concepto) a \(String(format: "%.2f", $0.precioUnitario))€" }.joined(separator: "\n"))
            Total: \(String(format: "%.2f", self.factura.totalFactura))€

            REGLAS:
            - SIEMPRE usa una herramienta. NUNCA preguntes, actúa directamente.
            - Si dicen "cambia X a Y" → usa modificar_linea.
            - Si dicen "añade X" → usa anadir_linea.
            - Si dicen "quita/elimina X" → usa eliminar_linea.
            - Si dicen "descuento X%" → usa cambiar_descuento.
            - Responde en español, una frase corta.
            """
        }
    }

    func procesarComando(_ texto: String) async {
        guard let session else { return }
        procesando = true
        ultimaRespuesta = nil

        do {
            let response = try await session.respond(to: texto)
            ultimaRespuesta = response.content
        } catch {
            ultimaRespuesta = "Error: \(error.localizedDescription)"
        }

        procesando = false
    }
}
```

---

### Task 4: Create FacturaEditView (fullscreen editable sheet)

**Files:**
- Create: `FacturaApp/FacturaEditView.swift`

- [ ] **Step 1: Create the main editable view**

```swift
// FacturaEditView.swift
import SwiftUI
import SwiftData

struct FacturaEditView: View {
    @Bindable var factura: Factura
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editAI: FacturaEditAIService
    @State private var textoComando = ""
    @State private var mostrarPDF = false
    @State private var refreshID = UUID()

    init(factura: Factura) {
        self.factura = factura
        // Note: modelContext will be injected by environment
        _editAI = StateObject(wrappedValue: FacturaEditAIService(
            factura: factura,
            modelContext: DataConfig.container.mainContext
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Factura content (scrollable)
                List {
                    // Header
                    cabeceraSection

                    // Action buttons
                    accionesSection

                    // Editable lines
                    lineasSection

                    // Totals
                    totalesSection

                    // AI response
                    if let respuesta = editAI.ultimaRespuesta {
                        Section {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                                Text(respuesta)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .id(refreshID)

                Divider()

                // AI input bar (bottom)
                aiInputBar
            }
            .navigationTitle(factura.numeroFactura)
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
            .onAppear {
                editAI.onFacturaUpdated = {
                    refreshID = UUID()
                }
            }
        }
    }

    // MARK: - Sections

    private var cabeceraSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(factura.numeroFactura)
                            .font(.headline)
                        EstadoBadge(estado: factura.estado)
                    }
                    Text(factura.clienteNombre.isEmpty ? "Sin cliente" : factura.clienteNombre)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Formateadores.formatEuros(factura.totalFactura))
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
    }

    private var accionesSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    miniBoton("PDF", icono: "doc.richtext", color: .blue) {
                        generarPDF()
                    }
                    if factura.estado == .borrador {
                        miniBoton("Emitir", icono: "paperplane", color: .blue) {
                            factura.estado = .emitida
                            factura.fechaModificacion = .now
                            try? modelContext.save()
                            refreshID = UUID()
                        }
                    }
                    if factura.estado == .emitida || factura.estado == .borrador {
                        miniBoton("Cobrar", icono: "checkmark.circle", color: .green) {
                            factura.estado = .pagada
                            factura.fechaModificacion = .now
                            try? modelContext.save()
                            refreshID = UUID()
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var lineasSection: some View {
        Section("Líneas") {
            ForEach(factura.lineasOrdenadas) { linea in
                LineaEditRow(linea: linea, onChanged: {
                    recalcular()
                    refreshID = UUID()
                })
            }
            .onDelete { offsets in
                let ordenadas = factura.lineasOrdenadas
                for offset in offsets {
                    let linea = ordenadas[offset]
                    factura.lineas.removeAll { $0.persistentModelID == linea.persistentModelID }
                    modelContext.delete(linea)
                }
                recalcular()
                refreshID = UUID()
            }

            Button {
                let orden = (factura.lineas.map(\.orden).max() ?? -1) + 1
                let nueva = LineaFactura(orden: orden, concepto: "Nuevo concepto", cantidad: 1, precioUnitario: 0)
                factura.lineas.append(nueva)
                recalcular()
                refreshID = UUID()
            } label: {
                Label("Añadir línea", systemImage: "plus.circle")
                    .font(.subheadline)
            }
        }
    }

    private var totalesSection: some View {
        Section("Totales") {
            HStack {
                Text("Base imponible")
                Spacer()
                Text(Formateadores.formatEuros(factura.baseImponible))
            }
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
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
    }

    // MARK: - AI Input Bar

    private var aiInputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .font(.caption)

            TextField("Ej: cambia bombillas a 10...", text: $textoComando)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .onSubmit { enviarComandoIA() }

            if editAI.procesando {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !textoComando.trimmingCharacters(in: .whitespaces).isEmpty {
                Button { enviarComandoIA() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Helpers

    private func enviarComandoIA() {
        let cmd = textoComando.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        textoComando = ""
        Task { await editAI.procesarComando(cmd) }
    }

    private func recalcular() {
        let desc = FetchDescriptor<Negocio>()
        let negocio = (try? modelContext.fetch(desc))?.first
        factura.recalcularTotales(
            irpfPorcentaje: negocio?.irpfPorcentaje ?? 15.0,
            aplicarIRPF: negocio?.aplicarIRPF ?? false
        )
        try? modelContext.save()
    }

    private func generarPDF() {
        let desc = FetchDescriptor<Negocio>()
        guard let negocio = try? modelContext.fetch(desc).first else { return }
        factura.pdfData = FacturaPDFGenerator.generar(factura: factura, negocio: negocio)
        try? modelContext.save()
        mostrarPDF = true
    }

    private func miniBoton(_ label: String, icono: String, color: Color, accion: @escaping () -> Void) -> some View {
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
}

// MARK: - Editable line row

struct LineaEditRow: View {
    @Bindable var linea: LineaFactura
    var onChanged: () -> Void

    @State private var cantidadTexto: String = ""
    @State private var precioTexto: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Concepto editable
            TextField("Concepto", text: $linea.concepto)
                .font(.subheadline)
                .fontWeight(.medium)
                .onChange(of: linea.concepto) { _, _ in onChanged() }

            HStack(spacing: 12) {
                // Cantidad
                HStack(spacing: 4) {
                    Text("Cant:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("1", text: $cantidadTexto)
                        .font(.caption)
                        .frame(width: 50)
                        .keyboardType(.decimalPad)
                        .onChange(of: cantidadTexto) { _, nuevo in
                            if let val = Formateadores.parsearPrecio(nuevo) {
                                linea.cantidad = val
                                linea.recalcular()
                                onChanged()
                            }
                        }
                }

                // Precio
                HStack(spacing: 4) {
                    Text("Precio:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0,00", text: $precioTexto)
                        .font(.caption)
                        .frame(width: 60)
                        .keyboardType(.decimalPad)
                        .onChange(of: precioTexto) { _, nuevo in
                            if let val = Formateadores.parsearPrecio(nuevo) {
                                linea.precioUnitario = val
                                linea.recalcular()
                                onChanged()
                            }
                        }
                    Text("€")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Subtotal
                Text(Formateadores.formatEuros(linea.subtotal))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            cantidadTexto = String(format: "%.2f", linea.cantidad).replacingOccurrences(of: ".", with: ",")
            precioTexto = String(format: "%.2f", linea.precioUnitario).replacingOccurrences(of: ".", with: ",")
        }
    }
}
```

---

### Task 5: Wire everything together and test

**Files:**
- Modify: `FacturaApp/VoiceMainView.swift`

- [ ] **Step 1: Add facturaParaEditar state and sheet**

Add to VoiceMainView properties:
```swift
@State private var facturaParaEditar: Factura?
```

Add sheet after the bandeja sheet:
```swift
.sheet(item: $facturaParaEditar) { factura in
    FacturaEditView(factura: factura)
}
```

- [ ] **Step 2: Verify complete flow**

Test sequence:
1. Type "Añade un cliente Juan García" → client created
2. Type "Factura para Juan con 5 bombillas LED" → card appears in chat
3. Tap card → edit sheet opens with lines
4. Type "cambia las bombillas a 10" in AI bar → line updates instantly
5. Type "añade 2 horas de mano de obra" → new line appears
6. Tap PDF → preview generated
7. Close sheet → back to chat
