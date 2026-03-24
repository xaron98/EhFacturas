// VeriFactuCertificateManager.swift
// FacturaApp — Gestión de certificados digitales X.509 para VeriFactu

import Foundation
import Security

enum VeriFactuCertificateManager {

    private static let keychainTag = "es.facturaapp.verifactu.cert"

    // MARK: - Importar certificado .p12

    static func importarCertificado(data: Data, password: String) -> (success: Bool, error: String?) {
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?

        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &rawItems)

        guard status == errSecSuccess,
              let items = rawItems as? [[String: Any]],
              let firstItem = items.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            let msg: String
            switch status {
            case errSecAuthFailed: msg = "Contraseña incorrecta"
            case errSecDecode: msg = "Archivo de certificado no válido"
            default: msg = "Error importando certificado (código: \(status))"
            }
            return (false, msg)
        }

        // Eliminar certificado anterior si existe
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: keychainTag
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Guardar en Keychain
        let addQuery: [String: Any] = [
            kSecValueRef as String: identity,
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: keychainTag
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            return (false, "Error guardando en Keychain (código: \(addStatus))")
        }

        return (true, nil)
    }

    // MARK: - Obtener identidad del Keychain

    static func obtenerIdentidad() -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: keychainTag,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let ref = result else { return nil }
        return (ref as! SecIdentity)
    }

    // MARK: - Estado

    static var certificadoInstalado: Bool {
        obtenerIdentidad() != nil
    }

    // MARK: - Info del certificado

    static func infoCertificado() -> (nombre: String, caducidad: Date?)? {
        guard let identity = obtenerIdentidad() else { return nil }

        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity, &certificate)
        guard let cert = certificate else { return nil }

        let nombre = SecCertificateCopySubjectSummary(cert) as String? ?? "Certificado"
        return (nombre, nil)
    }

    // MARK: - Eliminar

    static func eliminarCertificado() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: keychainTag
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Crear credencial para URLSession

    static func crearCredencial() -> URLCredential? {
        guard let identity = obtenerIdentidad() else { return nil }
        return URLCredential(identity: identity, certificates: nil, persistence: .forSession)
    }
}
