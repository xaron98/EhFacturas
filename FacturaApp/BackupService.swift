// BackupService.swift
import Foundation
import SwiftData

enum BackupService {

    struct BackupData: Codable {
        var version: String = "1.0"
        var fecha: String
        var negocio: NegocioBackup?
        var clientes: [ClienteBackup]
        var articulos: [ArticuloBackup]
        var gastos: [GastoBackup]
    }

    struct NegocioBackup: Codable {
        var nombre: String
        var nif: String
        var direccion: String
        var codigoPostal: String
        var ciudad: String
        var provincia: String
        var telefono: String
        var email: String
    }

    struct ClienteBackup: Codable {
        var nombre: String
        var nif: String
        var direccion: String
        var codigoPostal: String
        var ciudad: String
        var provincia: String
        var telefono: String
        var email: String
    }

    struct ArticuloBackup: Codable {
        var referencia: String
        var nombre: String
        var descripcion: String
        var precioUnitario: Double
        var precioCoste: Double
        var unidad: String
        var proveedor: String
        var etiquetas: [String]
    }

    struct GastoBackup: Codable {
        var concepto: String
        var importe: Double
        var categoria: String
        var proveedor: String
        var fecha: String
    }

    @MainActor
    static func exportar(modelContext: ModelContext) -> Data? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let negocioDesc = FetchDescriptor<Negocio>()
        let negocio = (try? modelContext.fetch(negocioDesc))?.first

        let clienteDesc = FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo == true })
        let clientes = (try? modelContext.fetch(clienteDesc)) ?? []

        let articuloDesc = FetchDescriptor<Articulo>(predicate: #Predicate<Articulo> { $0.activo == true })
        let articulos = (try? modelContext.fetch(articuloDesc)) ?? []

        let gastoDesc = FetchDescriptor<Gasto>()
        let gastos = (try? modelContext.fetch(gastoDesc)) ?? []

        let backup = BackupData(
            fecha: dateFormatter.string(from: .now),
            negocio: negocio.map { NegocioBackup(nombre: $0.nombre, nif: $0.nif, direccion: $0.direccion, codigoPostal: $0.codigoPostal, ciudad: $0.ciudad, provincia: $0.provincia, telefono: $0.telefono, email: $0.email) },
            clientes: clientes.map { ClienteBackup(nombre: $0.nombre, nif: $0.nif, direccion: $0.direccion, codigoPostal: $0.codigoPostal, ciudad: $0.ciudad, provincia: $0.provincia, telefono: $0.telefono, email: $0.email) },
            articulos: articulos.map { ArticuloBackup(referencia: $0.referencia, nombre: $0.nombre, descripcion: $0.descripcion, precioUnitario: $0.precioUnitario, precioCoste: $0.precioCoste, unidad: $0.unidad.abreviatura, proveedor: $0.proveedor, etiquetas: $0.etiquetas) },
            gastos: gastos.map { GastoBackup(concepto: $0.concepto, importe: $0.importe, categoria: $0.categoria, proveedor: $0.proveedor, fecha: dateFormatter.string(from: $0.fecha)) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }
}
