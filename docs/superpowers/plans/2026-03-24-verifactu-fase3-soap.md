# VeriFactu Fase 3 — SOAP Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Send VeriFactu records to the AEAT via SOAP 1.1 with X.509 client certificates, with offline queue and retry.

**Architecture:** VeriFactuCertificateManager handles .p12 import/Keychain. VeriFactuSOAPClient sends XML via URLSession with client cert. New estadoEnvio on RegistroFacturacion tracks delivery state. Background retry for offline queue.

**Tech Stack:** URLSession, Security.framework (SecPKCS12Import, Keychain), SwiftData

---

### Task 1: Add estadoEnvio to RegistroFacturacion + Negocio fields

**Files:**
- Modify: `FacturaApp/Models.swift`

- [ ] **Step 1: Add EstadoEnvioVF enum**

After TipoFacturaVF enum:
```swift
enum EstadoEnvioVF: String, Codable, CaseIterable {
    case noEnviado
    case pendiente
    case enviado
    case rechazado
    case error
}
```

- [ ] **Step 2: Add fields to RegistroFacturacion**

Add after `factura: Factura?`:
```swift
var estadoEnvio: EstadoEnvioVF = EstadoEnvioVF.noEnviado
var respuestaAEAT: String = ""
var fechaEnvio: Date?
```

- [ ] **Step 3: Add fields to Negocio for certificate config**

Add after `notas`:
```swift
var usarEntornoPruebas: Bool = true
var certificadoInstalado: Bool = false
var certificadoCaducidad: Date?
var envioAutomatico: Bool = false
```

- [ ] **Step 4: Build and verify**

---

### Task 2: Create VeriFactuCertificateManager

**Files:**
- Create: `FacturaApp/VeriFactuCertificateManager.swift`

- [ ] **Step 1: Create certificate manager**

```swift
// VeriFactuCertificateManager.swift
import Foundation
import Security

enum VeriFactuCertificateManager {

    private static let keychainTag = "es.facturaapp.verifactu.cert"

    // MARK: - Import .p12

    static func importarCertificado(data: Data, password: String) -> (success: Bool, error: String?) {
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?

        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &rawItems)

        guard status == errSecSuccess,
              let items = rawItems as? [[String: Any]],
              let firstItem = items.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            return (false, "Error importando certificado: \(status). Verifica la contraseña.")
        }

        // Save identity to Keychain
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: keychainTag
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecValueRef as String: identity,
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: keychainTag
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            return (false, "Error guardando certificado en Keychain: \(addStatus)")
        }

        return (true, nil)
    }

    // MARK: - Load identity for URLSession

    static func obtenerIdentidad() -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: keychainTag,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return (result as! SecIdentity)
    }

    // MARK: - Check if installed

    static var certificadoInstalado: Bool {
        obtenerIdentidad() != nil
    }

    // MARK: - Get certificate info

    static func infoCertificado() -> (nombre: String, caducidad: Date?)? {
        guard let identity = obtenerIdentidad() else { return nil }

        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity, &certificate)

        guard let cert = certificate else { return nil }

        let nombre = SecCertificateCopySubjectSummary(cert) as String? ?? "Desconocido"

        // Get expiry date from certificate
        var error: Unmanaged<CFError>?
        if let values = SecCertificateCopyValues(cert, nil, &error) as? [String: Any],
           let notAfter = values["2.5.29.24"] as? [String: Any],
           let date = notAfter["value"] as? Date {
            return (nombre, date)
        }

        return (nombre, nil)
    }

    // MARK: - Delete

    static func eliminarCertificado() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: keychainTag
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Create URLSession credential

    static func crearCredencial() -> URLCredential? {
        guard let identity = obtenerIdentidad() else { return nil }
        return URLCredential(identity: identity, certificates: nil, persistence: .forSession)
    }
}
```

- [ ] **Step 2: Build and verify**

---

### Task 3: Create VeriFactuSOAPClient

**Files:**
- Create: `FacturaApp/VeriFactuSOAPClient.swift`

- [ ] **Step 1: Create SOAP client with offline queue**

```swift
// VeriFactuSOAPClient.swift
import Foundation
import SwiftData

@MainActor
final class VeriFactuSOAPClient: NSObject, ObservableObject, URLSessionDelegate {

    static let shared = VeriFactuSOAPClient()

    static let endpointProduccion = "https://www1.agenciatributaria.gob.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP"
    static let endpointPruebas = "https://prewww1.aeat.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP"

    @Published var enviando = false

    private var credential: URLCredential?
    private override init() { super.init() }

    // MARK: - Send single registro

    func enviarRegistro(
        registro: RegistroFacturacion,
        negocio: Negocio,
        modelContext: ModelContext
    ) async {
        guard VeriFactuCertificateManager.certificadoInstalado else {
            registro.estadoEnvio = .pendiente
            registro.respuestaAEAT = "Sin certificado digital instalado"
            try? modelContext.save()
            return
        }

        credential = VeriFactuCertificateManager.crearCredencial()
        guard credential != nil else {
            registro.estadoEnvio = .error
            registro.respuestaAEAT = "Error cargando certificado"
            try? modelContext.save()
            return
        }

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)
        let endpoint = negocio.usarEntornoPruebas ? Self.endpointPruebas : Self.endpointProduccion

        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("RegFactuSistemaFacturacion", forHTTPHeaderField: "SOAPAction")
        request.httpBody = xml.data(using: .utf8)
        request.timeoutInterval = 30

        enviando = true

        do {
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let (data, response) = try await session.data(for: request)

            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let responseText = String(data: data, encoding: .utf8) ?? ""

            if statusCode == 200 {
                if responseText.contains("Correcta") || responseText.contains("AceptadaConErrores") {
                    registro.estadoEnvio = .enviado
                    registro.fechaEnvio = .now
                    registro.respuestaAEAT = "Aceptada (HTTP \(statusCode))"
                } else if responseText.contains("Rechazada") || responseText.contains("Incorrecto") {
                    registro.estadoEnvio = .rechazado
                    registro.respuestaAEAT = String(responseText.prefix(500))
                } else {
                    registro.estadoEnvio = .enviado
                    registro.fechaEnvio = .now
                    registro.respuestaAEAT = "HTTP \(statusCode)"
                }
            } else {
                registro.estadoEnvio = .error
                registro.respuestaAEAT = "HTTP \(statusCode): \(String(responseText.prefix(200)))"
            }
        } catch {
            registro.estadoEnvio = .pendiente
            registro.respuestaAEAT = "Error de conexión: \(error.localizedDescription)"
        }

        try? modelContext.save()
        enviando = false
    }

    // MARK: - Retry pending

    func reintentarPendientes(modelContext: ModelContext) async {
        let desc = FetchDescriptor<RegistroFacturacion>()
        guard let todos = try? modelContext.fetch(desc) else { return }
        let pendientes = todos.filter { $0.estadoEnvio == .pendiente || $0.estadoEnvio == .error }

        guard !pendientes.isEmpty else { return }

        let negocioDesc = FetchDescriptor<Negocio>()
        guard let negocio = (try? modelContext.fetch(negocioDesc))?.first else { return }

        for registro in pendientes {
            // Max 4 días desde generación
            let diasDesdeGeneracion = Calendar.current.dateComponents([.day], from: registro.fechaHoraGeneracion, to: .now).day ?? 0
            if diasDesdeGeneracion > 4 {
                registro.estadoEnvio = .error
                registro.respuestaAEAT = "Plazo de 4 días superado"
                continue
            }

            await enviarRegistro(registro: registro, negocio: negocio, modelContext: modelContext)
        }
    }

    // MARK: - URLSessionDelegate (client certificate)

    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            let cred = await MainActor.run { self.credential }
            if let cred {
                return (.useCredential, cred)
            }
            return (.cancelAuthenticationChallenge, nil)
        }

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }

        return (.performDefaultHandling, nil)
    }
}
```

- [ ] **Step 2: Build and verify**

---

### Task 4: Add certificate section to AjustesView

**Files:**
- Modify: `FacturaApp/AjustesView.swift`

- [ ] **Step 1: Add certificate import section**

In `ajustesContent(negocio:)`, add a new section after "Condiciones de pago":

```swift
Section {
    // Certificate status
    if VeriFactuCertificateManager.certificadoInstalado {
        HStack {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("Certificado instalado")
                    .font(.subheadline)
                if let info = VeriFactuCertificateManager.infoCertificado() {
                    Text(info.nombre)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Eliminar") {
                VeriFactuCertificateManager.eliminarCertificado()
                negocio.certificadoInstalado = false
                try? modelContext.save()
            }
            .font(.caption)
            .foregroundStyle(.red)
        }
    } else {
        Button {
            mostrarImportarCertificado = true
        } label: {
            Label("Importar certificado digital (.p12)", systemImage: "key")
        }
    }

    // Environment toggle
    Toggle("Entorno de pruebas", isOn: Binding(
        get: { negocio.usarEntornoPruebas },
        set: { negocio.usarEntornoPruebas = $0; try? modelContext.save() }
    ))

    // Auto send toggle
    Toggle("Envío automático a AEAT", isOn: Binding(
        get: { negocio.envioAutomatico },
        set: { negocio.envioAutomatico = $0; try? modelContext.save() }
    ))
} header: {
    Text("VeriFactu — Conexión AEAT")
} footer: {
    Text("El certificado digital (.p12) es necesario para enviar facturas a la AEAT. Usa el entorno de pruebas durante el desarrollo.")
}
```

- [ ] **Step 2: Add certificate import sheet**

Add state: `@State private var mostrarImportarCertificado = false`

Add a simple sheet with a file importer for .p12 files and a password field.

- [ ] **Step 3: Build and verify**

---

### Task 5: Wire auto-send on emit + show status

**Files:**
- Modify: `FacturaApp/FacturasListView.swift`
- Modify: `FacturaApp/FacturaEditView.swift`

- [ ] **Step 1: Update emitirFactura in FacturasListView**

After creating the registro and saving, if auto-send is enabled:

```swift
private func emitirFactura(_ factura: Factura) {
    let desc = FetchDescriptor<Negocio>()
    guard let negocio = try? modelContext.fetch(desc).first else { return }
    let registro = VeriFactuHashService.crearRegistroAlta(factura: factura, negocio: negocio, modelContext: modelContext)
    factura.estado = .emitida
    factura.fechaModificacion = .now
    try? modelContext.save()

    // Auto-send if enabled
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
```

Same for anularFactura.

- [ ] **Step 2: Show estadoEnvio in FacturaEditView VeriFactu section**

In the VeriFactu section where registros are listed, add the envio status:

```swift
HStack {
    Text(estadoEnvioTexto(registro.estadoEnvio))
        .font(.caption2)
        .foregroundStyle(estadoEnvioColor(registro.estadoEnvio))
    if registro.estadoEnvio == .pendiente || registro.estadoEnvio == .error {
        Button("Reintentar") {
            Task {
                let desc = FetchDescriptor<Negocio>()
                if let negocio = try? modelContext.fetch(desc).first {
                    await VeriFactuSOAPClient.shared.enviarRegistro(
                        registro: registro, negocio: negocio, modelContext: modelContext
                    )
                    refreshTrigger += 1
                }
            }
        }
        .font(.caption2)
    }
}
```

Add helpers:
```swift
private func estadoEnvioTexto(_ estado: EstadoEnvioVF) -> String {
    switch estado {
    case .noEnviado: return "No enviado"
    case .pendiente: return "Pendiente de envío"
    case .enviado: return "Enviado a AEAT"
    case .rechazado: return "Rechazado por AEAT"
    case .error: return "Error de envío"
    }
}

private func estadoEnvioColor(_ estado: EstadoEnvioVF) -> Color {
    switch estado {
    case .noEnviado: return .secondary
    case .pendiente: return .orange
    case .enviado: return .green
    case .rechazado: return .red
    case .error: return .red
    }
}
```

- [ ] **Step 3: Build and verify**
