// VeriFactuSOAPClient.swift
// FacturaApp — Cliente SOAP para envío de registros VeriFactu a la AEAT

import Foundation
import SwiftData

@MainActor
final class VeriFactuSOAPClient: NSObject, ObservableObject {

    static let shared = VeriFactuSOAPClient()

    static let endpointProduccion = "https://www1.agenciatributaria.gob.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP"
    static let endpointPruebas = "https://prewww1.aeat.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP"

    @Published var enviando = false

    private var credential: URLCredential?
    private override init() { super.init() }

    // MARK: - Enviar un registro

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
        // Note: XML signing disabled until C14N implementation is validated with AEAT
        // let xml = VeriFactuXMLSigner.firmarXML(xmlSinFirma)
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
            let delegate = SOAPSessionDelegate(credential: credential)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let (data, response) = try await session.data(for: request)

            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let responseText = String(data: data, encoding: .utf8) ?? ""

            if statusCode == 200 {
                let estado = parsearEstadoRespuesta(responseText)
                switch estado {
                case .aceptada:
                    registro.estadoEnvio = .enviado
                    registro.fechaEnvio = .now
                    registro.respuestaAEAT = "Aceptada (HTTP \(statusCode))"
                case .aceptadaConErrores:
                    registro.estadoEnvio = .enviado
                    registro.fechaEnvio = .now
                    registro.respuestaAEAT = "Aceptada con errores (HTTP \(statusCode))"
                case .rechazada(let detalle):
                    registro.estadoEnvio = .rechazado
                    registro.respuestaAEAT = detalle.isEmpty ? "Rechazada" : String(detalle.prefix(500))
                case .desconocido:
                    registro.estadoEnvio = .enviado
                    registro.fechaEnvio = .now
                    registro.respuestaAEAT = "HTTP \(statusCode) — respuesta no reconocida"
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

    // MARK: - Reintentar pendientes

    func reintentarPendientes(modelContext: ModelContext) async {
        let desc = FetchDescriptor<RegistroFacturacion>()
        guard let todos = try? modelContext.fetch(desc) else { return }
        let pendientes = todos.filter { $0.estadoEnvio == .pendiente || $0.estadoEnvio == .error }

        guard !pendientes.isEmpty else { return }

        let negocioDesc = FetchDescriptor<Negocio>()
        guard let negocio = (try? modelContext.fetch(negocioDesc))?.first else { return }

        for registro in pendientes {
            let diasDesdeGeneracion = Calendar.current.dateComponents([.day], from: registro.fechaHoraGeneracion, to: .now).day ?? 0
            if diasDesdeGeneracion >= 4 {
                registro.estadoEnvio = .error
                registro.respuestaAEAT = "Plazo de 4 días superado"
                try? modelContext.save()
                continue
            }

            await enviarRegistro(registro: registro, negocio: negocio, modelContext: modelContext)
        }
    }
}

// MARK: - URLSession Delegate for client certificate

final class SOAPSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let credential: URLCredential?

    init(credential: URLCredential?) {
        self.credential = credential
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let credential {
                return (.useCredential, credential)
            }
            return (.cancelAuthenticationChallenge, nil)
        }

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            // Only accept AEAT domains
            let host = challenge.protectionSpace.host
            if host.hasSuffix("agenciatributaria.gob.es") || host.hasSuffix("aeat.es") {
                var error: CFError?
                let isValid = SecTrustEvaluateWithError(trust, &error)
                if isValid {
                    return (.useCredential, URLCredential(trust: trust))
                }
            }
            return (.performDefaultHandling, nil)
        }

        return (.performDefaultHandling, nil)
    }
}

// MARK: - Parseo de respuesta AEAT

enum EstadoRespuestaAEAT {
    case aceptada
    case aceptadaConErrores
    case rechazada(String)
    case desconocido
}

nonisolated func parsearEstadoRespuesta(_ xml: String) -> EstadoRespuestaAEAT {
    // Parse XML to find EstadoEnvio element
    class SOAPResponseParser: NSObject, XMLParserDelegate {
        var estadoEnvio = ""
        var descripcionError = ""
        var currentElement = ""
        var currentText = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String] = [:]) {
            currentElement = elementName.components(separatedBy: ":").last ?? elementName
            currentText = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            let name = elementName.components(separatedBy: ":").last ?? elementName
            if name == "EstadoEnvio" { estadoEnvio = currentText.trimmingCharacters(in: .whitespacesAndNewlines) }
            if name == "DescripcionErrorRegistro" { descripcionError = currentText.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }

    guard let data = xml.data(using: .utf8) else { return .desconocido }
    let parser = XMLParser(data: data)
    let delegate = SOAPResponseParser()
    parser.delegate = delegate
    parser.parse()

    switch delegate.estadoEnvio {
    case "Correcta": return .aceptada
    case "AceptadaConErrores": return .aceptadaConErrores
    case "Incorrecto", "Rechazada": return .rechazada(delegate.descripcionError)
    default:
        // Fallback for unexpected format
        if xml.contains("Correcta") { return .aceptada }
        return .desconocido
    }
}
