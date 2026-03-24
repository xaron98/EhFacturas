# VeriFactu Fase 2 — Generación XML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Generate VeriFactu-compliant XML documents from facturas, matching the official AEAT XSD schema (V1.0).

**Architecture:** New `VeriFactuXMLGenerator.swift` that builds XML strings from RegistroFacturacion + Factura + Negocio data. Also update VeriFactuHashService to use the official field order and date format (dd-MM-yyyy).

**Tech Stack:** Foundation (XMLDocument or string-based XML), SwiftData

---

### Task 1: Fix hash calculation to match official XSD format

**Files:**
- Modify: `FacturaApp/VeriFactuHashService.swift`

The official XSD uses `dd-MM-yyyy` for dates (not `yyyyMMdd`). Also the Encadenamiento in the XSD uses the previous invoice's IDFactura fields + Huella, not just the hash. Update the hash calculation to match.

- [ ] **Step 1: Update date format in hash**

Change `formatFecha` to use `dd-MM-yyyy` format:
```swift
private static func formatFecha(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "dd-MM-yyyy"
    return f.string(from: date)
}
```

- [ ] **Step 2: Update formatISO8601 to match XSD timestamp format**

The XSD uses `dd-MM-yyyy HH:mm:ss` not ISO8601:
```swift
private static func formatTimestamp(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "dd-MM-yyyy HH:mm:ss"
    f.locale = Locale(identifier: "es_ES")
    return f.string(from: date)
}
```

Update `calcularHash` to use `formatTimestamp` instead of `formatISO8601`.

- [ ] **Step 3: Build and verify**

---

### Task 2: Create VeriFactuXMLGenerator

**Files:**
- Create: `FacturaApp/VeriFactuXMLGenerator.swift`

- [ ] **Step 1: Create the XML generator**

New file that generates XML strings matching the official XSD:

```swift
// VeriFactuXMLGenerator.swift
import Foundation
import SwiftData

enum VeriFactuXMLGenerator {

    static let namespace = "https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/SuministroInformacion.xsd"
    static let version = "1.0"

    // MARK: - Generar XML completo de envío

    static func generarXMLEnvio(
        registros: [RegistroFacturacion],
        negocio: Negocio
    ) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
            xmlns:sf="\(namespace)">
            <soapenv:Body>
                <sf:RegFactuSistemaFacturacion>
                    <sf:Cabecera>
                        <sf:ObligadoEmision>
                            <sf:NombreRazon>\(escaparXML(negocio.nombre))</sf:NombreRazon>
                            <sf:NIF>\(negocio.nif)</sf:NIF>
                        </sf:ObligadoEmision>
                    </sf:Cabecera>
        """

        for registro in registros {
            xml += "\n            <sf:RegistroFactura>"
            if registro.tipoRegistro == .alta {
                xml += generarRegistroAlta(registro: registro, negocio: negocio)
            } else {
                xml += generarRegistroAnulacion(registro: registro, negocio: negocio)
            }
            xml += "\n            </sf:RegistroFactura>"
        }

        xml += """

                </sf:RegFactuSistemaFacturacion>
            </soapenv:Body>
        </soapenv:Envelope>
        """

        return xml
    }

    // MARK: - Registro de Alta

    private static func generarRegistroAlta(
        registro: RegistroFacturacion,
        negocio: Negocio
    ) -> String {
        let tipoFacturaXSD = mapTipoFactura(registro.tipoFactura)
        let fechaExp = formatFechaXSD(registro.fechaExpedicion)
        let timestamp = formatTimestampXSD(registro.fechaHoraGeneracion)

        var xml = """

                    <sf:RegistroAlta>
                        <sf:IDVersion>\(version)</sf:IDVersion>
                        <sf:IDFactura>
                            <sf:IDEmisorFactura>\(registro.nifEmisor)</sf:IDEmisorFactura>
                            <sf:NumSerieFactura>\(escaparXML(registro.numeroFactura))</sf:NumSerieFactura>
                            <sf:FechaExpedicionFactura>\(fechaExp)</sf:FechaExpedicionFactura>
                        </sf:IDFactura>
                        <sf:NombreRazonEmisor>\(escaparXML(negocio.nombre))</sf:NombreRazonEmisor>
                        <sf:TipoFactura>\(tipoFacturaXSD)</sf:TipoFactura>
        """

        // Rectificativa
        if registro.tipoFactura == .rectificativa, let numRect = registro.facturaRectificadaNumero {
            xml += """

                        <sf:TipoRectificativa>S</sf:TipoRectificativa>
                        <sf:FacturasRectificadas>
                            <sf:IDFacturaRectificada>
                                <sf:IDEmisorFactura>\(registro.nifEmisor)</sf:IDEmisorFactura>
                                <sf:NumSerieFactura>\(escaparXML(numRect))</sf:NumSerieFactura>
                            </sf:IDFacturaRectificada>
                        </sf:FacturasRectificadas>
            """
        }

        xml += """

                        <sf:DescripcionOperacion>\(escaparXML(String(registro.descripcionOperacion.prefix(500))))</sf:DescripcionOperacion>
        """

        // Destinatario
        if !registro.nifDestinatario.isEmpty {
            xml += """

                        <sf:Destinatarios>
                            <sf:IDDestinatario>
                                <sf:NombreRazon>\(escaparXML(registro.nombreDestinatario))</sf:NombreRazon>
                                <sf:NIF>\(registro.nifDestinatario)</sf:NIF>
                            </sf:IDDestinatario>
                        </sf:Destinatarios>
            """
        }

        // Desglose IVA
        xml += generarDesgloseIVA(registro: registro)

        // Totales
        xml += """

                        <sf:CuotaTotal>\(formatImporte(registro.totalIVA))</sf:CuotaTotal>
                        <sf:ImporteTotal>\(formatImporte(registro.importeTotal))</sf:ImporteTotal>
        """

        // Encadenamiento
        xml += generarEncadenamiento(registro: registro)

        // Sistema informático
        xml += generarSistemaInformatico(negocio: negocio)

        xml += """

                        <sf:FechaHoraHusoGenRegistro>\(timestamp)</sf:FechaHoraHusoGenRegistro>
                        <sf:TipoHuella>01</sf:TipoHuella>
                        <sf:Huella>\(registro.hashRegistro)</sf:Huella>
                    </sf:RegistroAlta>
        """

        return xml
    }

    // MARK: - Registro de Anulación

    private static func generarRegistroAnulacion(
        registro: RegistroFacturacion,
        negocio: Negocio
    ) -> String {
        let fechaExp = formatFechaXSD(registro.fechaExpedicion)
        let timestamp = formatTimestampXSD(registro.fechaHoraGeneracion)

        var xml = """

                    <sf:RegistroAnulacion>
                        <sf:IDVersion>\(version)</sf:IDVersion>
                        <sf:IDFactura>
                            <sf:IDEmisorFacturaAnulada>\(registro.nifEmisor)</sf:IDEmisorFacturaAnulada>
                            <sf:NumSerieFacturaAnulada>\(escaparXML(registro.numeroFactura))</sf:NumSerieFacturaAnulada>
                            <sf:FechaExpedicionFacturaAnulada>\(fechaExp)</sf:FechaExpedicionFacturaAnulada>
                        </sf:IDFactura>
        """

        xml += generarEncadenamiento(registro: registro)
        xml += generarSistemaInformatico(negocio: negocio)

        xml += """

                        <sf:FechaHoraHusoGenRegistro>\(timestamp)</sf:FechaHoraHusoGenRegistro>
                        <sf:TipoHuella>01</sf:TipoHuella>
                        <sf:Huella>\(registro.hashRegistro)</sf:Huella>
                    </sf:RegistroAnulacion>
        """

        return xml
    }

    // MARK: - Helpers

    private static func generarDesgloseIVA(registro: RegistroFacturacion) -> String {
        // Desglose simplificado: una línea con IVA general sobre la base
        let tipoIVA = registro.totalIVA > 0
            ? String(format: "%.2f", (registro.totalIVA / max(registro.baseImponible, 0.01)) * 100)
            : "21.00"

        return """

                        <sf:Desglose>
                            <sf:DetalleDesglose>
                                <sf:Impuesto>01</sf:Impuesto>
                                <sf:ClaveRegimen>01</sf:ClaveRegimen>
                                <sf:CalificacionOperacion>S1</sf:CalificacionOperacion>
                                <sf:TipoImpositivo>\(tipoIVA)</sf:TipoImpositivo>
                                <sf:BaseImponibleOimporteNoSujeto>\(formatImporte(registro.baseImponible))</sf:BaseImponibleOimporteNoSujeto>
                                <sf:CuotaRepercutida>\(formatImporte(registro.totalIVA))</sf:CuotaRepercutida>
                            </sf:DetalleDesglose>
                        </sf:Desglose>
        """
    }

    private static func generarEncadenamiento(registro: RegistroFacturacion) -> String {
        if registro.hashRegistroAnterior.isEmpty {
            return """

                        <sf:Encadenamiento>
                            <sf:PrimerRegistro>S</sf:PrimerRegistro>
                        </sf:Encadenamiento>
            """
        } else {
            return """

                        <sf:Encadenamiento>
                            <sf:RegistroAnterior>
                                <sf:Huella>\(registro.hashRegistroAnterior)</sf:Huella>
                            </sf:RegistroAnterior>
                        </sf:Encadenamiento>
            """
        }
    }

    private static func generarSistemaInformatico(negocio: Negocio) -> String {
        return """

                        <sf:SistemaInformatico>
                            <sf:NombreRazon>\(escaparXML(negocio.nombre))</sf:NombreRazon>
                            <sf:NIF>\(negocio.nif)</sf:NIF>
                            <sf:NombreSistemaInformatico>FacturaApp</sf:NombreSistemaInformatico>
                            <sf:IdSistemaInformatico>01</sf:IdSistemaInformatico>
                            <sf:Version>1.0</sf:Version>
                            <sf:NumeroInstalacion>01</sf:NumeroInstalacion>
                            <sf:TipoUsoPosibleSoloVerifactu>S</sf:TipoUsoPosibleSoloVerifactu>
                            <sf:TipoUsoPosibleMultiOT>N</sf:TipoUsoPosibleMultiOT>
                            <sf:IndicadorMultiplesOT>N</sf:IndicadorMultiplesOT>
                        </sf:SistemaInformatico>
        """
    }

    // MARK: - Formateo

    private static func formatFechaXSD(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy"
        return f.string(from: date)
    }

    private static func formatTimestampXSD(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy HH:mm:ss"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: date)
    }

    private static func formatImporte(_ valor: Double) -> String {
        String(format: "%.2f", valor)
    }

    private static func escaparXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - Generar XML individual

    static func generarXMLRegistro(
        registro: RegistroFacturacion,
        negocio: Negocio
    ) -> String {
        generarXMLEnvio(registros: [registro], negocio: negocio)
    }
}
```

- [ ] **Step 2: Build and verify**

---

### Task 3: Add XML export to FacturaEditView and FacturasListView

**Files:**
- Modify: `FacturaApp/FacturaEditView.swift`
- Modify: `FacturaApp/FacturasListView.swift`

- [ ] **Step 1: Add "XML" action button in FacturaEditView acciones section**

Next to the PDF button, add an XML button that generates and shares the XML:
```swift
if factura.estado != .borrador && !factura.registros.isEmpty {
    miniBoton("XML", icono: "doc.text", color: .orange) {
        generarXML()
    }
}
```

Add method:
```swift
private func generarXML() {
    let desc = FetchDescriptor<Negocio>()
    guard let negocio = try? modelContext.fetch(desc).first else { return }
    guard let registro = factura.registros.sorted(by: { $0.fechaHoraGeneracion > $1.fechaHoraGeneracion }).first else { return }
    let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)
    // Store as data for sharing
    xmlDataParaCompartir = xml.data(using: .utf8)
    mostrarShareXML = true
}
```

Add states and sheet for sharing.

- [ ] **Step 2: Same in FacturaDetalleView**

Add XML button in the detail view action bar too.

- [ ] **Step 3: Build and verify**
