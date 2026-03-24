# VeriFactu Fase 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement VeriFactu hash chain (SHA-256), immutable invoice records, post-emission edit locking, and rectifying invoices.

**Architecture:** New `RegistroFacturacion` SwiftData model for immutable records. New `VeriFactuHashService` for SHA-256 chain. Modify existing views to lock editing after emission and add rectification flow.

**Tech Stack:** SwiftUI, SwiftData, CryptoKit (SHA-256), Swift 6

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Models.swift` | Modify | Add RegistroFacturacion model, TipoRegistro/TipoFacturaVF enums, new Factura fields |
| `VeriFactuHashService.swift` | Create | SHA-256 hash calculation + chain management |
| `FacturaEditView.swift` | Modify | Lock editing when estado != .borrador, show hash info |
| `FacturaEditAIService.swift` | Modify | Reject commands when factura is not borrador |
| `FacturasListView.swift` | Modify | Add "Rectificar" action, lock swipes on emitidas, emit creates hash |
| `CommandAIService.swift` | Modify | Update emitir flow to create RegistroFacturacion |

---

### Task 1: Add VeriFactu models and enums to Models.swift

**Files:**
- Modify: `FacturaApp/Models.swift`

- [ ] **Step 1: Add TipoRegistro and TipoFacturaVF enums**

After the `EstadoFactura` enum (around line 93), add:

```swift
enum TipoRegistro: String, Codable, CaseIterable {
    case alta
    case anulacion
}

enum TipoFacturaVF: String, Codable, CaseIterable {
    case completa
    case simplificada
    case rectificativa
}
```

- [ ] **Step 2: Add new fields to Factura model**

In the Factura class (after `fechaModificacion` around line 278), add:

```swift
var tipoFactura: TipoFacturaVF = TipoFacturaVF.completa
var facturaRectificada: Factura?
@Relationship(deleteRule: .cascade, inverse: \RegistroFacturacion.factura)
var registros: [RegistroFacturacion] = []
```

- [ ] **Step 3: Create RegistroFacturacion model**

After the LineaFactura model (after line 404), add:

```swift
@Model
final class RegistroFacturacion {
    var tipoRegistro: TipoRegistro = TipoRegistro.alta
    var nifEmisor: String = ""
    var numeroFactura: String = ""
    var serieFactura: String = ""
    var fechaExpedicion: Date = Date.now
    var tipoFactura: TipoFacturaVF = TipoFacturaVF.completa
    var facturaRectificadaNumero: String?
    var descripcionOperacion: String = ""
    var baseImponible: Double = 0
    var totalIVA: Double = 0
    var totalIRPF: Double = 0
    var importeTotal: Double = 0
    var nifDestinatario: String = ""
    var nombreDestinatario: String = ""
    var hashRegistro: String = ""
    var hashRegistroAnterior: String = ""
    var fechaHoraGeneracion: Date = Date.now
    var factura: Factura?

    init(tipoRegistro: TipoRegistro, factura: Factura, nifEmisor: String,
         hashAnterior: String, tipoFactura: TipoFacturaVF = .completa,
         facturaRectificadaNumero: String? = nil) {
        self.tipoRegistro = tipoRegistro
        self.nifEmisor = nifEmisor
        self.numeroFactura = factura.numeroFactura
        self.serieFactura = String(factura.numeroFactura.prefix(while: { !$0.isNumber }))
        self.fechaExpedicion = factura.fecha
        self.tipoFactura = tipoFactura
        self.facturaRectificadaNumero = facturaRectificadaNumero
        self.descripcionOperacion = factura.lineasOrdenadas
            .map(\.concepto).joined(separator: ", ")
        self.baseImponible = factura.baseImponible
        self.totalIVA = factura.totalIVA
        self.totalIRPF = factura.totalIRPF
        self.importeTotal = factura.totalFactura
        self.nifDestinatario = factura.clienteNIF
        self.nombreDestinatario = factura.clienteNombre
        self.hashRegistroAnterior = hashAnterior
        self.fechaHoraGeneracion = .now
        self.factura = factura
    }
}
```

- [ ] **Step 4: Add RegistroFacturacion to DataConfig schema**

In `DataConfig.container` (around line 410), add `RegistroFacturacion.self` to the Schema array:

```swift
let schema = Schema([
    Negocio.self,
    Cliente.self,
    Categoria.self,
    Articulo.self,
    Factura.self,
    LineaFactura.self,
    RegistroFacturacion.self  // NEW
])
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -project FacturaApp.xcodeproj -scheme FacturaApp -destination 'generic/platform=iOS' -quiet build 2>&1 | grep "error:"`
Expected: No errors

---

### Task 2: Create VeriFactuHashService

**Files:**
- Create: `FacturaApp/VeriFactuHashService.swift`

- [ ] **Step 1: Create the hash service**

```swift
// VeriFactuHashService.swift
// FacturaApp — Motor de huellas digitales SHA-256 para VeriFactu

import Foundation
import CryptoKit
import SwiftData

enum VeriFactuHashService {

    // MARK: - Calcular hash SHA-256

    /// Calcula el hash SHA-256 de un registro de facturación.
    /// Concatena campos en orden fijo separados por "|" y aplica SHA-256.
    static func calcularHash(registro: RegistroFacturacion) -> String {
        let fechaExpedicion = formatFecha(registro.fechaExpedicion)
        let fechaGeneracion = formatISO8601(registro.fechaHoraGeneracion)
        let importe = String(format: "%.2f", registro.importeTotal)

        let cadena = [
            registro.nifEmisor,
            registro.numeroFactura,
            registro.serieFactura,
            fechaExpedicion,
            registro.tipoFactura.rawValue,
            importe,
            registro.hashRegistroAnterior,
            fechaGeneracion
        ].joined(separator: "|")

        let data = Data(cadena.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Obtener hash anterior

    /// Busca el último registro de facturación para obtener el hash anterior de la cadena.
    static func obtenerHashAnterior(modelContext: ModelContext) -> String {
        var descriptor = FetchDescriptor<RegistroFacturacion>(
            sortBy: [SortDescriptor(\.fechaHoraGeneracion, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let ultimo = (try? modelContext.fetch(descriptor))?.first {
            return ultimo.hashRegistro
        }
        return ""  // Primer registro de la cadena
    }

    // MARK: - Crear registro de alta

    /// Crea un RegistroFacturacion de alta, calcula su hash,
    /// y lo inserta en el contexto.
    static func crearRegistroAlta(
        factura: Factura,
        negocio: Negocio,
        modelContext: ModelContext
    ) -> RegistroFacturacion {
        let hashAnterior = obtenerHashAnterior(modelContext: modelContext)

        let registro = RegistroFacturacion(
            tipoRegistro: .alta,
            factura: factura,
            nifEmisor: negocio.nif,
            hashAnterior: hashAnterior,
            tipoFactura: factura.tipoFactura,
            facturaRectificadaNumero: factura.facturaRectificada?.numeroFactura
        )

        registro.hashRegistro = calcularHash(registro: registro)
        modelContext.insert(registro)
        return registro
    }

    // MARK: - Crear registro de anulación

    /// Crea un RegistroFacturacion de anulación para una factura emitida.
    static func crearRegistroAnulacion(
        factura: Factura,
        negocio: Negocio,
        modelContext: ModelContext
    ) -> RegistroFacturacion {
        let hashAnterior = obtenerHashAnterior(modelContext: modelContext)

        let registro = RegistroFacturacion(
            tipoRegistro: .anulacion,
            factura: factura,
            nifEmisor: negocio.nif,
            hashAnterior: hashAnterior
        )

        registro.hashRegistro = calcularHash(registro: registro)
        modelContext.insert(registro)
        return registro
    }

    // MARK: - Verificar cadena

    /// Verifica la integridad de toda la cadena de hashes.
    /// Devuelve true si todos los hashes son correctos y están encadenados.
    static func verificarCadena(modelContext: ModelContext) -> (valida: Bool, errores: [String]) {
        let descriptor = FetchDescriptor<RegistroFacturacion>(
            sortBy: [SortDescriptor(\.fechaHoraGeneracion, order: .forward)]
        )
        guard let registros = try? modelContext.fetch(descriptor) else {
            return (true, [])
        }

        var errores: [String] = []
        var hashAnterior = ""

        for (i, registro) in registros.enumerated() {
            // Verificar que el hashAnterior coincide
            if registro.hashRegistroAnterior != hashAnterior {
                errores.append("Registro \(i + 1) (\(registro.numeroFactura)): hashAnterior no coincide")
            }

            // Verificar que el hash es correcto
            let hashCalculado = calcularHash(registro: registro)
            if registro.hashRegistro != hashCalculado {
                errores.append("Registro \(i + 1) (\(registro.numeroFactura)): hash incorrecto")
            }

            hashAnterior = registro.hashRegistro
        }

        return (errores.isEmpty, errores)
    }

    // MARK: - Formateo de fechas

    private static func formatFecha(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }

    private static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project FacturaApp.xcodeproj -scheme FacturaApp -destination 'generic/platform=iOS' -quiet build 2>&1 | grep "error:"`
Expected: No errors

---

### Task 3: Lock editing in FacturaEditView when not borrador

**Files:**
- Modify: `FacturaApp/FacturaEditView.swift`

- [ ] **Step 1: Add computed property for editability**

In `FacturaEditView`, add a computed property:

```swift
private var esEditable: Bool {
    factura.estado == .borrador
}
```

- [ ] **Step 2: Disable LineaEditRow when not editable**

In the `lineasSection`, wrap the ForEach content conditionally. Replace the current `LineaEditRow` usage with:

```swift
if esEditable {
    LineaEditRow(linea: linea, onChanged: {
        recalcular()
        refreshTrigger += 1
    })
} else {
    // Read-only line display
    VStack(alignment: .leading, spacing: 4) {
        Text(linea.concepto)
            .font(.subheadline)
            .fontWeight(.medium)
        HStack {
            Text("\(String(format: "%.2f", linea.cantidad)) \(linea.unidad.rawValue) × \(Formateadores.formatEuros(linea.precioUnitario))")
            Spacer()
            Text(Formateadores.formatEuros(linea.subtotal))
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 3: Hide add/delete line buttons when not editable**

Wrap the "Añadir línea" button and the `.onDelete` with `if esEditable`.

- [ ] **Step 4: Disable AI input bar when not editable**

In `aiInputBar`, replace with:

```swift
if esEditable {
    // existing AI input bar content
} else {
    HStack(spacing: 8) {
        Image(systemName: "lock.fill")
            .foregroundStyle(.secondary)
        Text("Factura emitida — no se puede editar")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.bar)
}
```

- [ ] **Step 5: Show hash info section when factura has registros**

After the totales section, add:

```swift
if !factura.registros.isEmpty {
    Section("VeriFactu") {
        ForEach(factura.registros.sorted(by: { $0.fechaHoraGeneracion < $1.fechaHoraGeneracion }), id: \.persistentModelID) { registro in
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
            }
        }
    }
}
```

- [ ] **Step 6: Build and verify**

Run: `xcodebuild -project FacturaApp.xcodeproj -scheme FacturaApp -destination 'generic/platform=iOS' -quiet build 2>&1 | grep "error:"`

---

### Task 4: Reject AI commands in FacturaEditAIService when not borrador

**Files:**
- Modify: `FacturaApp/FacturaEditAIService.swift`

- [ ] **Step 1: Add borrador check at start of procesarComando**

In `procesarComando()` (around line 257), add at the beginning after the `guard !textoLimpio.isEmpty` check:

```swift
guard factura.estado == .borrador else {
    ultimaRespuesta = "Esta factura ya está emitida y no se puede modificar. Puedes crear una factura rectificativa desde la vista de detalle."
    return
}
```

- [ ] **Step 2: Build and verify**

---

### Task 5: Update FacturasListView — emit creates hash, add rectify action

**Files:**
- Modify: `FacturaApp/FacturasListView.swift`

- [ ] **Step 1: Update "Emitir" in FacturaDetalleView to create RegistroFacturacion**

Replace the "Emitir" action button (around line 338) with:

```swift
if factura.estado == .borrador {
    miniBoton("Emitir", icono: "paperplane", color: .blue) {
        emitirFactura(factura)
    }
}
```

Add a private method:

```swift
private func emitirFactura(_ factura: Factura) {
    let desc = FetchDescriptor<Negocio>()
    guard let negocio = try? modelContext.fetch(desc).first else { return }

    // Crear registro VeriFactu con hash
    let _ = VeriFactuHashService.crearRegistroAlta(
        factura: factura,
        negocio: negocio,
        modelContext: modelContext
    )

    factura.estado = .emitida
    factura.fechaModificacion = .now
    try? modelContext.save()
}
```

- [ ] **Step 2: Update "Anular" to create registro de anulación**

Replace the anular action (around line 352) with:

```swift
if factura.estado != .anulada && factura.estado != .borrador {
    miniBoton("Anular", icono: "xmark.circle", color: .red) {
        anularFactura(factura)
    }
}
```

Add method:

```swift
private func anularFactura(_ factura: Factura) {
    let desc = FetchDescriptor<Negocio>()
    guard let negocio = try? modelContext.fetch(desc).first else { return }

    let _ = VeriFactuHashService.crearRegistroAnulacion(
        factura: factura,
        negocio: negocio,
        modelContext: modelContext
    )

    factura.estado = .anulada
    factura.fechaModificacion = .now
    try? modelContext.save()
}
```

- [ ] **Step 3: Add "Rectificar" action button**

After the anular button, add:

```swift
if factura.estado == .emitida || factura.estado == .anulada {
    miniBoton("Rectificar", icono: "doc.on.doc", color: .purple) {
        crearRectificativa(factura)
    }
}
```

Add method:

```swift
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

    // Copiar líneas
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
        nueva.lineas.append(copia)
    }

    nueva.recalcularTotales(
        irpfPorcentaje: negocio.irpfPorcentaje,
        aplicarIRPF: negocio.aplicarIRPF
    )

    modelContext.insert(nueva)
    try? modelContext.save()
}
```

- [ ] **Step 4: Update swipe actions to prevent editing emitidas**

In the swipe actions for the list, update the anular swipe to also create a registro:

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    if factura.estado == .emitida {
        Button(role: .destructive) {
            anularFacturaEnLista(factura)
        } label: {
            Label("Anular", systemImage: "xmark.circle")
        }
    }
    if factura.estado == .borrador {
        Button(role: .destructive) {
            factura.estado = .anulada
            factura.fechaModificacion = .now
            try? modelContext.save()
        } label: {
            Label("Eliminar", systemImage: "trash")
        }
    }
}
```

Add helper:

```swift
private func anularFacturaEnLista(_ factura: Factura) {
    let desc = FetchDescriptor<Negocio>()
    guard let negocio = try? modelContext.fetch(desc).first else { return }
    let _ = VeriFactuHashService.crearRegistroAnulacion(factura: factura, negocio: negocio, modelContext: modelContext)
    factura.estado = .anulada
    factura.fechaModificacion = .now
    try? modelContext.save()
}
```

- [ ] **Step 5: Build and verify**

---

### Task 6: Update CommandAIService — emitir creates hash

**Files:**
- Modify: `FacturaApp/CommandAIService.swift`

- [ ] **Step 1: Update the system prompt to mention rectificativas**

In `crearSesion()`, add to the instructions:

```
- Si el usuario quiere emitir una factura borrador, cambia su estado a emitida. Las facturas emitidas no se pueden editar.
- Si el usuario quiere rectificar una factura, dile que use el botón "Rectificar" en la vista de la factura.
```

- [ ] **Step 2: Update MarcarPagadaTool — only pagada, not estado changes that need hashes**

No changes needed — MarcarPagadaTool only changes emitida→pagada, which doesn't create a new registro (pago no es un evento VeriFactu).

- [ ] **Step 3: Build and verify full project**

Run: `xcodebuild -project FacturaApp.xcodeproj -scheme FacturaApp -destination 'generic/platform=iOS' -quiet build 2>&1 | grep "error:"`
Expected: No errors
