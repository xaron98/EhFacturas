// VeriFactuHashService.swift
// FacturaApp — Motor de huellas digitales SHA-256 para VeriFactu

import Foundation
import CryptoKit
import SwiftData

enum VeriFactuHashService {

    // MARK: - Calcular hash SHA-256

    static func calcularHash(registro: RegistroFacturacion) -> String {
        let fechaExp = formatFecha(registro.fechaExpedicion)
        let fechaGen = formatTimestamp(registro.fechaHoraGeneracion)
        let importe = String(format: "%.2f", registro.importeTotal)

        let cadena = [
            registro.nifEmisor,
            registro.numeroFactura,
            registro.serieFactura,
            fechaExp,
            registro.tipoFactura.rawValue,
            importe,
            registro.hashRegistroAnterior,
            fechaGen
        ].joined(separator: "|")

        let data = Data(cadena.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Obtener hash anterior

    static func obtenerHashAnterior(modelContext: ModelContext) -> String {
        var descriptor = FetchDescriptor<RegistroFacturacion>(
            sortBy: [SortDescriptor(\.fechaHoraGeneracion, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let ultimo = (try? modelContext.fetch(descriptor))?.first {
            return ultimo.hashRegistro
        }
        return ""
    }

    // MARK: - Crear registro de alta

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
            if registro.hashRegistroAnterior != hashAnterior {
                errores.append("Registro \(i + 1) (\(registro.numeroFactura)): hashAnterior no coincide")
            }
            let hashCalculado = calcularHash(registro: registro)
            if registro.hashRegistro != hashCalculado {
                errores.append("Registro \(i + 1) (\(registro.numeroFactura)): hash incorrecto")
            }
            hashAnterior = registro.hashRegistro
        }

        return (errores.isEmpty, errores)
    }

    // MARK: - Formateo

    private static func formatFecha(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy"
        return f.string(from: date)
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy HH:mm:ssZZZZZ"
        f.locale = Locale(identifier: "es_ES")
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }
}
