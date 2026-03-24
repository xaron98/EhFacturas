// VeriFactuXMLGenerator.swift
// FacturaApp — Generador de XML VeriFactu conforme al XSD oficial V1.0

import Foundation
import SwiftData

enum VeriFactuXMLGenerator {

    // MARK: - Namespace

    private static let namespace =
        "https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/SuministroInformacion.xsd"

    // MARK: - Generar XML envío completo (SOAP envelope)

    /// Genera el XML SOAP completo con Cabecera + RegistroFactura para un array de registros.
    static func generarXMLEnvio(registros: [RegistroFacturacion], negocio: Negocio) -> String {
        var xml = ""
        xml += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\""
        xml += " xmlns:sf=\"\(namespace)\">\n"
        xml += "  <soapenv:Header/>\n"
        xml += "  <soapenv:Body>\n"
        xml += "    <sf:RegFactuSistemaFacturacion>\n"

        // Cabecera
        xml += "      <sf:Cabecera>\n"
        xml += "        <sf:ObligadoEmision>\n"
        xml += "          <sf:NombreRazon>\(escaparXML(negocio.nombre))</sf:NombreRazon>\n"
        xml += "          <sf:NIF>\(escaparXML(negocio.nif))</sf:NIF>\n"
        xml += "        </sf:ObligadoEmision>\n"
        xml += "      </sf:Cabecera>\n"

        // RegistroFactura (cada uno con RegistroAlta o RegistroAnulacion)
        for registro in registros {
            xml += "      <sf:RegistroFactura>\n"
            switch registro.tipoRegistro {
            case .alta:
                xml += generarRegistroAlta(registro: registro, negocio: negocio)
            case .anulacion:
                xml += generarRegistroAnulacion(registro: registro, negocio: negocio)
            }
            xml += "      </sf:RegistroFactura>\n"
        }

        xml += "    </sf:RegFactuSistemaFacturacion>\n"
        xml += "  </soapenv:Body>\n"
        xml += "</soapenv:Envelope>"

        return xml
    }

    // MARK: - Registro Alta

    /// Genera el bloque XML `<sf:RegistroAlta>` para un registro de facturación de tipo alta.
    static func generarRegistroAlta(registro: RegistroFacturacion, negocio: Negocio) -> String {
        let fechaExp = formatFechaXSD(registro.fechaExpedicion)
        let descripcion = String(registro.descripcionOperacion.prefix(500))

        var xml = ""
        xml += "        <sf:RegistroAlta>\n"

        // IDVersion
        xml += "          <sf:IDVersion>1.0</sf:IDVersion>\n"

        // IDFactura
        xml += "          <sf:IDFactura>\n"
        xml += "            <sf:IDEmisorFactura>\(escaparXML(registro.nifEmisor))</sf:IDEmisorFactura>\n"
        xml += "            <sf:NumSerieFactura>\(escaparXML(registro.numeroFactura))</sf:NumSerieFactura>\n"
        xml += "            <sf:FechaExpedicionFactura>\(fechaExp)</sf:FechaExpedicionFactura>\n"
        xml += "          </sf:IDFactura>\n"

        // NombreRazonEmisor
        let nombreEmisor = String(negocio.nombre.prefix(120))
        xml += "          <sf:NombreRazonEmisor>\(escaparXML(nombreEmisor))</sf:NombreRazonEmisor>\n"

        // TipoFactura
        let tipoFacturaCode = mapTipoFactura(registro.tipoFactura)
        xml += "          <sf:TipoFactura>\(tipoFacturaCode)</sf:TipoFactura>\n"

        // TipoRectificativa + FacturasRectificadas (solo si rectificativa)
        if registro.tipoFactura == .rectificativa {
            xml += "          <sf:TipoRectificativa>I</sf:TipoRectificativa>\n"
            if let numRectificada = registro.facturaRectificadaNumero, !numRectificada.isEmpty {
                let fechaOriginal = registro.factura?.facturaRectificada.map { formatFechaXSD($0.fecha) } ?? fechaExp
                xml += "          <sf:FacturasRectificadas>\n"
                xml += "            <sf:IDFacturaRectificada>\n"
                xml += "              <sf:IDEmisorFactura>\(escaparXML(registro.nifEmisor))</sf:IDEmisorFactura>\n"
                xml += "              <sf:NumSerieFactura>\(escaparXML(numRectificada))</sf:NumSerieFactura>\n"
                xml += "              <sf:FechaExpedicionFactura>\(fechaOriginal)</sf:FechaExpedicionFactura>\n"
                xml += "            </sf:IDFacturaRectificada>\n"
                xml += "          </sf:FacturasRectificadas>\n"
            }
        }

        // DescripcionOperacion
        xml += "          <sf:DescripcionOperacion>\(escaparXML(descripcion))</sf:DescripcionOperacion>\n"

        // Destinatarios (solo si hay NIF del destinatario)
        if !registro.nifDestinatario.isEmpty {
            xml += "          <sf:Destinatarios>\n"
            xml += "            <sf:IDDestinatario>\n"
            xml += "              <sf:NombreRazon>\(escaparXML(registro.nombreDestinatario))</sf:NombreRazon>\n"
            xml += "              <sf:NIF>\(escaparXML(registro.nifDestinatario))</sf:NIF>\n"
            xml += "            </sf:IDDestinatario>\n"
            xml += "          </sf:Destinatarios>\n"
        }

        // Desglose
        xml += generarDesglose(registro: registro)

        // CuotaTotal
        xml += "          <sf:CuotaTotal>\(formatImporte(registro.totalIVA))</sf:CuotaTotal>\n"

        // ImporteTotal
        xml += "          <sf:ImporteTotal>\(formatImporte(registro.importeTotal))</sf:ImporteTotal>\n"

        // Encadenamiento
        xml += generarEncadenamiento(registro: registro)

        // SistemaInformatico
        xml += generarSistemaInformatico(negocio: negocio)

        // FechaHoraHusoGenRegistro
        xml += "          <sf:FechaHoraHusoGenRegistro>\(formatTimestampXSD(registro.fechaHoraGeneracion))</sf:FechaHoraHusoGenRegistro>\n"

        // TipoHuella
        xml += "          <sf:TipoHuella>01</sf:TipoHuella>\n"

        // Huella
        xml += "          <sf:Huella>\(escaparXML(registro.hashRegistro))</sf:Huella>\n"

        xml += "        </sf:RegistroAlta>\n"

        return xml
    }

    // MARK: - Registro Anulación

    /// Genera el bloque XML `<sf:RegistroAnulacion>` para un registro de anulación.
    static func generarRegistroAnulacion(registro: RegistroFacturacion, negocio: Negocio) -> String {
        let fechaExp = formatFechaXSD(registro.fechaExpedicion)

        var xml = ""
        xml += "        <sf:RegistroAnulacion>\n"

        // IDVersion
        xml += "          <sf:IDVersion>1.0</sf:IDVersion>\n"

        // IDFactura
        xml += "          <sf:IDFactura>\n"
        xml += "            <sf:IDEmisorFacturaAnulada>\(escaparXML(registro.nifEmisor))</sf:IDEmisorFacturaAnulada>\n"
        xml += "            <sf:NumSerieFacturaAnulada>\(escaparXML(registro.numeroFactura))</sf:NumSerieFacturaAnulada>\n"
        xml += "            <sf:FechaExpedicionFacturaAnulada>\(fechaExp)</sf:FechaExpedicionFacturaAnulada>\n"
        xml += "          </sf:IDFactura>\n"

        // Encadenamiento
        xml += generarEncadenamiento(registro: registro)

        // SistemaInformatico
        xml += generarSistemaInformatico(negocio: negocio)

        // FechaHoraHusoGenRegistro
        xml += "          <sf:FechaHoraHusoGenRegistro>\(formatTimestampXSD(registro.fechaHoraGeneracion))</sf:FechaHoraHusoGenRegistro>\n"

        // TipoHuella
        xml += "          <sf:TipoHuella>01</sf:TipoHuella>\n"

        // Huella
        xml += "          <sf:Huella>\(escaparXML(registro.hashRegistro))</sf:Huella>\n"

        xml += "        </sf:RegistroAnulacion>\n"

        return xml
    }

    // MARK: - Convenience: XML para un solo registro

    /// Genera el XML de envío completo para un único registro.
    static func generarXMLRegistro(registro: RegistroFacturacion, negocio: Negocio) -> String {
        generarXMLEnvio(registros: [registro], negocio: negocio)
    }

    // MARK: - Desglose IVA

    private static func generarDesglose(registro: RegistroFacturacion) -> String {
        var xml = ""
        xml += "          <sf:Desglose>\n"

        // Obtener desglose de la factura asociada si existe
        if let factura = registro.factura {
            let desgloseIVA = factura.desgloseIVA
            for item in desgloseIVA {
                xml += "            <sf:DetalleDesglose>\n"
                xml += "              <sf:Impuesto>01</sf:Impuesto>\n"
                xml += "              <sf:ClaveRegimen>01</sf:ClaveRegimen>\n"
                xml += "              <sf:CalificacionOperacion>S1</sf:CalificacionOperacion>\n"
                xml += "              <sf:TipoImpositivo>\(formatImporte(item.porcentaje))</sf:TipoImpositivo>\n"
                xml += "              <sf:BaseImponible>\(formatImporte(item.base))</sf:BaseImponible>\n"
                xml += "              <sf:CuotaRepercutida>\(formatImporte(item.cuota))</sf:CuotaRepercutida>\n"
                xml += "            </sf:DetalleDesglose>\n"
            }
        } else {
            // Fallback: un solo desglose con los totales del registro
            let porcentaje: Double = registro.baseImponible > 0
                ? (registro.totalIVA / registro.baseImponible) * 100
                : 21.0
            xml += "            <sf:DetalleDesglose>\n"
            xml += "              <sf:Impuesto>01</sf:Impuesto>\n"
            xml += "              <sf:ClaveRegimen>01</sf:ClaveRegimen>\n"
            xml += "              <sf:CalificacionOperacion>S1</sf:CalificacionOperacion>\n"
            xml += "              <sf:TipoImpositivo>\(formatImporte(porcentaje))</sf:TipoImpositivo>\n"
            xml += "              <sf:BaseImponible>\(formatImporte(registro.baseImponible))</sf:BaseImponible>\n"
            xml += "              <sf:CuotaRepercutida>\(formatImporte(registro.totalIVA))</sf:CuotaRepercutida>\n"
            xml += "            </sf:DetalleDesglose>\n"
        }

        xml += "          </sf:Desglose>\n"
        return xml
    }

    // MARK: - Encadenamiento

    private static func generarEncadenamiento(registro: RegistroFacturacion) -> String {
        var xml = ""
        xml += "          <sf:Encadenamiento>\n"

        if registro.hashRegistroAnterior.isEmpty {
            // Primer registro de la cadena
            xml += "            <sf:PrimerRegistro>S</sf:PrimerRegistro>\n"
        } else {
            // Registro posterior: referencia al anterior
            xml += "            <sf:RegistroAnterior>\n"
            xml += "              <sf:Huella>\(escaparXML(registro.hashRegistroAnterior))</sf:Huella>\n"
            xml += "            </sf:RegistroAnterior>\n"
        }

        xml += "          </sf:Encadenamiento>\n"
        return xml
    }

    // MARK: - SistemaInformatico

    private static func generarSistemaInformatico(negocio: Negocio) -> String {
        var xml = ""
        xml += "          <sf:SistemaInformatico>\n"
        xml += "            <sf:NombreRazon>\(escaparXML(negocio.nombre))</sf:NombreRazon>\n"
        xml += "            <sf:NIF>\(escaparXML(negocio.nif))</sf:NIF>\n"
        xml += "            <sf:NombreSistemaInformatico>FacturaApp</sf:NombreSistemaInformatico>\n"
        xml += "            <sf:IdSistemaInformatico>01</sf:IdSistemaInformatico>\n"
        xml += "            <sf:Version>1.0</sf:Version>\n"
        xml += "            <sf:NumeroInstalacion>01</sf:NumeroInstalacion>\n"
        xml += "            <sf:TipoUsoPosibleSoloVerifactu>S</sf:TipoUsoPosibleSoloVerifactu>\n"
        xml += "            <sf:TipoUsoPosibleMultiOT>N</sf:TipoUsoPosibleMultiOT>\n"
        xml += "            <sf:IndicadorMultiplesOT>N</sf:IndicadorMultiplesOT>\n"
        xml += "          </sf:SistemaInformatico>\n"
        return xml
    }

    // MARK: - Helpers

    private static let fechaXSDFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    private static let timestampXSDFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy HH:mm:ssZZZZZ"
        f.locale = Locale(identifier: "es_ES")
        f.timeZone = TimeZone.current
        return f
    }()

    /// Formatea una fecha en formato dd-MM-yyyy (formato VeriFactu XSD).
    static func formatFechaXSD(_ date: Date) -> String {
        fechaXSDFormatter.string(from: date)
    }

    /// Formatea una fecha con hora y huso horario en formato dd-MM-yyyy HH:mm:ss±HH:MM (formato VeriFactu XSD).
    static func formatTimestampXSD(_ date: Date) -> String {
        timestampXSDFormatter.string(from: date)
    }

    /// Formatea un importe con 2 decimales, sin símbolo de moneda.
    static func formatImporte(_ valor: Double) -> String {
        String(format: "%.2f", valor)
    }

    /// Escapa caracteres especiales XML (&, <, >, ", ').
    static func escaparXML(_ texto: String) -> String {
        texto
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// Mapea TipoFacturaVF del modelo al código XSD oficial.
    static func mapTipoFactura(_ tipo: TipoFacturaVF) -> String {
        switch tipo {
        case .completa: return "F1"
        case .simplificada: return "F2"
        case .rectificativa: return "R1"
        }
    }
}
