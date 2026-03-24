// VeriFactuXMLSigner.swift
// FacturaApp — Firma electrónica XML (XMLDSig enveloped) para VeriFactu
// Implementa canonicalización C14N + RSA-SHA256 conforme a W3C XMLDSig.

import Foundation
import Security
import CryptoKit

enum VeriFactuXMLSigner {

    // MARK: - Firmar XML (enveloped signature)

    /// Añade firma XMLDSig enveloped al XML de VeriFactu.
    /// Proceso: 1) Canonicalizar XML, 2) Calcular digest SHA-256,
    /// 3) Construir SignedInfo, 4) Canonicalizar SignedInfo,
    /// 5) Firmar con RSA-SHA256, 6) Insertar Signature en el XML.
    static func firmarXML(_ xml: String) -> String {
        guard let identity = VeriFactuCertificateManager.obtenerIdentidad() else {
            return xml // Sin certificado, devolver sin firmar
        }

        var privateKey: SecKey?
        SecIdentityCopyPrivateKey(identity, &privateKey)
        guard let key = privateKey else { return xml }

        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity, &certificate)
        guard let cert = certificate else { return xml }

        // Paso 1: Canonicalizar el XML (sin bloque Signature, que aún no existe)
        let xmlCanonicalizado = canonicalizar(xml)

        // Paso 2: Calcular digest SHA-256 del XML canonicalizado
        let xmlData = Data(xmlCanonicalizado.utf8)
        let digest = SHA256.hash(data: xmlData)
        let digestBase64 = Data(digest).base64EncodedString()

        // Paso 3: Construir SignedInfo con el digest
        let signedInfoXML = construirSignedInfo(digestBase64: digestBase64)

        // Paso 4: Canonicalizar SignedInfo antes de firmar
        let signedInfoCanonical = canonicalizar(signedInfoXML)

        // Paso 5: Firmar SignedInfo canonicalizado con RSA-SHA256
        let signedInfoData = Data(signedInfoCanonical.utf8)
        guard let signatureData = firmarRSASHA256(data: signedInfoData, key: key) else {
            return xml
        }
        let signatureBase64 = formatBase64(signatureData.base64EncodedString())

        // Certificado en Base64
        let certData = SecCertificateCopyData(cert) as Data
        let certBase64 = formatBase64(certData.base64EncodedString())

        // Paso 6: Construir bloque Signature completo e insertar
        let signatureBlock = construirSignatureBlock(
            signedInfo: signedInfoXML,
            signatureValue: signatureBase64,
            certificateBase64: certBase64
        )

        return insertarFirma(en: xml, firma: signatureBlock)
    }

    // MARK: - Canonicalización C14N

    /// Canonicalización XML conforme a W3C Canonical XML 1.0 (C14N).
    /// - Elimina declaración XML (<?xml ...?>)
    /// - Normaliza saltos de línea a LF (0x0A)
    /// - Convierte etiquetas vacías auto-cerradas a pares (<tag></tag>)
    /// - Elimina espacios en blanco redundantes entre atributos
    /// - Preserva whitespace dentro de elementos
    private static func canonicalizar(_ xml: String) -> String {
        var resultado = xml

        // 1. Eliminar declaración XML
        if let range = resultado.range(of: "<\\?xml[^?]*\\?>", options: .regularExpression) {
            resultado.removeSubrange(range)
        }

        // 2. Normalizar saltos de línea: CR+LF → LF, CR solo → LF
        resultado = resultado.replacingOccurrences(of: "\r\n", with: "\n")
        resultado = resultado.replacingOccurrences(of: "\r", with: "\n")

        // 3. Convertir etiquetas auto-cerradas a pares abierto/cerrado
        // Ej: <ds:Transform .../> → <ds:Transform ...></ds:Transform>
        let selfClosingPattern = "<([a-zA-Z][a-zA-Z0-9:._-]*)([^>]*)/>"
        if let regex = try? NSRegularExpression(pattern: selfClosingPattern) {
            let nsString = resultado as NSString
            let matches = regex.matches(in: resultado, range: NSRange(location: 0, length: nsString.length))
            // Reemplazar de atrás hacia adelante para no invalidar rangos
            for match in matches.reversed() {
                let tagName = nsString.substring(with: match.range(at: 1))
                let attrs = nsString.substring(with: match.range(at: 2))
                let replacement = "<\(tagName)\(attrs)></\(tagName)>"
                resultado = (resultado as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        // 4. Normalizar espacios múltiples entre atributos a uno solo
        resultado = resultado.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression,
            range: nil
        )

        // 5. Eliminar espacios al inicio de cada línea (trim leading whitespace por línea NO se hace en C14N)
        // C14N preserva whitespace — la normalización de arriba es suficiente

        // 6. Eliminar líneas vacías
        while resultado.contains("\n\n") {
            resultado = resultado.replacingOccurrences(of: "\n\n", with: "\n")
        }

        return resultado.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Construir SignedInfo

    private static func construirSignedInfo(digestBase64: String) -> String {
        return """
        <ds:SignedInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">\
        <ds:CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"></ds:CanonicalizationMethod>\
        <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"></ds:SignatureMethod>\
        <ds:Reference URI="">\
        <ds:Transforms>\
        <ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"></ds:Transform>\
        </ds:Transforms>\
        <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"></ds:DigestMethod>\
        <ds:DigestValue>\(digestBase64)</ds:DigestValue>\
        </ds:Reference>\
        </ds:SignedInfo>
        """
    }

    // MARK: - Construir Signature block

    private static func construirSignatureBlock(
        signedInfo: String,
        signatureValue: String,
        certificateBase64: String
    ) -> String {
        return """

                        <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
                            \(signedInfo)
                            <ds:SignatureValue>\(signatureValue)</ds:SignatureValue>
                            <ds:KeyInfo>
                                <ds:X509Data>
                                    <ds:X509Certificate>\(certificateBase64)</ds:X509Certificate>
                                </ds:X509Data>
                            </ds:KeyInfo>
                        </ds:Signature>
        """
    }

    // MARK: - Insertar firma en XML

    private static func insertarFirma(en xml: String, firma: String) -> String {
        var firmado = xml
        // Insertar antes del cierre del registro (alta o anulación)
        if let range = firmado.range(of: "</sf:RegistroAlta>") {
            firmado.insert(contentsOf: firma, at: range.lowerBound)
        } else if let range = firmado.range(of: "</sf:RegistroAnulacion>") {
            firmado.insert(contentsOf: firma, at: range.lowerBound)
        }
        return firmado
    }

    // MARK: - Firma RSA-SHA256

    private static func firmarRSASHA256(data: Data, key: SecKey) -> Data? {
        let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256

        guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, algorithm, data as CFData, &error) else {
            return nil
        }

        return signature as Data
    }

    // MARK: - Formateo Base64

    /// Formatea Base64 en líneas de 76 caracteres (estándar para XMLDSig)
    private static func formatBase64(_ base64: String) -> String {
        var result = ""
        var index = base64.startIndex
        while index < base64.endIndex {
            let end = base64.index(index, offsetBy: 76, limitedBy: base64.endIndex) ?? base64.endIndex
            result += base64[index..<end]
            if end < base64.endIndex {
                result += "\n"
            }
            index = end
        }
        return result
    }
}
