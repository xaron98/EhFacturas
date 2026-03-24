// Models.swift
// FacturaApp — Modelos SwiftData + enums
// Entidades: Negocio, Cliente, Categoria, Articulo, Factura, LineaFactura

import Foundation
import SwiftData

// MARK: - Enums

enum UnidadMedida: String, Codable, CaseIterable, Identifiable {
    case unidad
    case metro
    case metroC
    case hora
    case kilogramo
    case litro
    case rollo
    case caja
    case servicio

    var id: String { rawValue }

    var abreviatura: String {
        switch self {
        case .unidad: return "ud"
        case .metro: return "m"
        case .metroC: return "m²"
        case .hora: return "h"
        case .kilogramo: return "kg"
        case .litro: return "l"
        case .rollo: return "rollo"
        case .caja: return "caja"
        case .servicio: return "servicio"
        }
    }

    var descripcion: String {
        switch self {
        case .unidad: return "Unidad"
        case .metro: return "Metro"
        case .metroC: return "Metro cuadrado"
        case .hora: return "Hora"
        case .kilogramo: return "Kilogramo"
        case .litro: return "Litro"
        case .rollo: return "Rollo"
        case .caja: return "Caja"
        case .servicio: return "Servicio"
        }
    }

    /// Crea desde abreviatura (para compatibilidad con IA y texto)
    init?(abreviatura: String) {
        switch abreviatura {
        case "ud": self = .unidad
        case "m": self = .metro
        case "m²": self = .metroC
        case "h": self = .hora
        case "kg": self = .kilogramo
        case "l": self = .litro
        case "rollo": self = .rollo
        case "caja": self = .caja
        case "servicio": self = .servicio
        default: return nil
        }
    }
}

enum TipoIVA: String, Codable, CaseIterable, Identifiable {
    case general = "general"
    case reducido = "reducido"
    case superReducido = "superReducido"
    case exento = "exento"

    var id: String { rawValue }

    var porcentaje: Double {
        switch self {
        case .general: return 21.0
        case .reducido: return 10.0
        case .superReducido: return 4.0
        case .exento: return 0.0
        }
    }

    var descripcion: String {
        switch self {
        case .general: return "General (21%)"
        case .reducido: return "Reducido (10%)"
        case .superReducido: return "Super reducido (4%)"
        case .exento: return "Exento (0%)"
        }
    }
}

enum EstadoFactura: String, Codable, CaseIterable, Identifiable {
    case borrador
    case emitida
    case pagada
    case vencida
    case anulada

    var id: String { rawValue }

    var descripcion: String {
        switch self {
        case .borrador: return "Borrador"
        case .emitida: return "Emitida"
        case .pagada: return "Pagada"
        case .vencida: return "Vencida"
        case .anulada: return "Anulada"
        }
    }

    var color: String {
        switch self {
        case .borrador: return "gray"
        case .emitida: return "blue"
        case .pagada: return "green"
        case .vencida: return "red"
        case .anulada: return "orange"
        }
    }
}

enum TipoRegistro: String, Codable, CaseIterable {
    case alta
    case anulacion
}

enum TipoFacturaVF: String, Codable, CaseIterable {
    case completa
    case simplificada
    case rectificativa
}

enum EstadoEnvioVF: String, Codable, CaseIterable {
    case noEnviado
    case pendiente
    case enviado
    case rechazado
    case error
}

// MARK: - Negocio

@Model
final class Negocio {
    var nombre: String = ""
    var nif: String = ""
    var direccion: String = ""
    var codigoPostal: String = ""
    var ciudad: String = ""
    var provincia: String = ""
    var telefono: String = ""
    var email: String = ""
    @Attribute(.externalStorage) var logoPNG: Data?
    var ivaGeneral: Double = 21.0
    var ivaReducido: Double = 10.0
    var irpfPorcentaje: Double = 15.0
    var aplicarIRPF: Bool = false
    var prefijoFactura: String = "FAC-"
    var siguienteNumero: Int = 1
    var notas: String = "Pago a 30 días."
    var usarEntornoPruebas: Bool = true
    var certificadoInstalado: Bool = false
    var certificadoCaducidad: Date?
    var envioAutomatico: Bool = false

    init(nombre: String = "", nif: String = "", direccion: String = "",
         codigoPostal: String = "", ciudad: String = "", provincia: String = "",
         telefono: String = "", email: String = "") {
        self.nombre = nombre
        self.nif = nif
        self.direccion = direccion
        self.codigoPostal = codigoPostal
        self.ciudad = ciudad
        self.provincia = provincia
        self.telefono = telefono
        self.email = email
    }

    func generarNumeroFactura() -> String {
        let numero = String(format: "%04d", siguienteNumero)
        siguienteNumero += 1
        return prefijoFactura + numero
    }
}

// MARK: - Cliente

@Model
final class Cliente {
    var nombre: String = ""
    var nif: String = ""
    var direccion: String = ""
    var codigoPostal: String = ""
    var ciudad: String = ""
    var provincia: String = ""
    var telefono: String = ""
    var email: String = ""
    var observaciones: String = ""
    @Relationship(deleteRule: .deny, inverse: \Factura.cliente)
    var facturas: [Factura] = []
    var fechaCreacion: Date = Date.now
    var fechaModificacion: Date = Date.now
    var activo: Bool = true

    init(nombre: String = "", nif: String = "", direccion: String = "",
         codigoPostal: String = "", ciudad: String = "", provincia: String = "",
         telefono: String = "", email: String = "", observaciones: String = "") {
        self.nombre = nombre
        self.nif = nif
        self.direccion = direccion
        self.codigoPostal = codigoPostal
        self.ciudad = ciudad
        self.provincia = provincia
        self.telefono = telefono
        self.email = email
        self.observaciones = observaciones
    }

    var iniciales: String {
        let partes = nombre.split(separator: " ")
        if partes.count >= 2 {
            return String(partes[0].prefix(1) + partes[1].prefix(1)).uppercased()
        }
        return String(nombre.prefix(2)).uppercased()
    }
}

// MARK: - Categoria

@Model
final class Categoria {
    var nombre: String = ""
    var icono: String = "folder"
    var orden: Int = 0
    @Relationship(deleteRule: .nullify, inverse: \Articulo.categoria)
    var articulos: [Articulo] = []

    init(nombre: String = "", icono: String = "folder", orden: Int = 0) {
        self.nombre = nombre
        self.icono = icono
        self.orden = orden
    }

    static let categoriasDefecto: [(String, String)] = [
        ("Iluminación", "lightbulb"),
        ("Cables y conductores", "cable.connector"),
        ("Enchufes y mecanismos", "powerplug"),
        ("Fontanería", "drop"),
        ("Calefacción", "flame"),
        ("Cuadros eléctricos", "bolt"),
        ("Herramientas", "wrench.and.screwdriver"),
        ("Mano de obra", "clock"),
        ("Material general", "shippingbox")
    ]
}

// MARK: - Articulo

@Model
final class Articulo {
    var referencia: String = ""
    var nombre: String = ""
    var descripcion: String = ""
    var precioUnitario: Double = 0
    var precioCoste: Double = 0
    var unidad: UnidadMedida = UnidadMedida.unidad
    var tipoIVA: TipoIVA = TipoIVA.general
    var proveedor: String = ""
    var urlProveedor: String = ""
    var referenciaProveedor: String = ""
    var categoria: Categoria?
    var etiquetas: [String] = []
    var activo: Bool = true
    var fechaCreacion: Date = Date.now
    var fechaModificacion: Date = Date.now
    @Relationship(deleteRule: .deny, inverse: \LineaFactura.articulo)
    var lineasFactura: [LineaFactura] = []

    init(referencia: String = "", nombre: String = "", descripcion: String = "",
         precioUnitario: Double = 0, precioCoste: Double = 0,
         unidad: UnidadMedida = .unidad, tipoIVA: TipoIVA = .general,
         proveedor: String = "", etiquetas: [String] = []) {
        self.referencia = referencia
        self.nombre = nombre
        self.descripcion = descripcion
        self.precioUnitario = precioUnitario
        self.precioCoste = precioCoste
        self.unidad = unidad
        self.tipoIVA = tipoIVA
        self.proveedor = proveedor
        self.etiquetas = etiquetas
    }

    var margen: Double {
        guard precioCoste > 0 else { return 0 }
        return ((precioUnitario - precioCoste) / precioCoste) * 100
    }

    var precioConIVA: Double {
        precioUnitario * (1 + tipoIVA.porcentaje / 100)
    }
}

// MARK: - Factura

@Model
final class Factura {
    var numeroFactura: String = ""
    var fecha: Date = Date.now
    var fechaVencimiento: Date?
    var estado: EstadoFactura = EstadoFactura.borrador
    var cliente: Cliente?
    var clienteNombre: String = ""
    var clienteNIF: String = ""
    var clienteDireccion: String = ""
    @Relationship(deleteRule: .cascade, inverse: \LineaFactura.factura)
    var lineas: [LineaFactura] = []
    var baseImponible: Double = 0
    var totalIVA: Double = 0
    var totalIRPF: Double = 0
    var totalFactura: Double = 0
    var descuentoGlobalPorcentaje: Double = 0
    var observaciones: String = ""
    var notasInternas: String = ""
    var promptOriginal: String?
    @Attribute(.externalStorage) var pdfData: Data?
    var fechaCreacion: Date = Date.now
    var fechaModificacion: Date = Date.now
    var tipoFactura: TipoFacturaVF = TipoFacturaVF.completa
    var facturaRectificada: Factura?
    @Relationship(deleteRule: .cascade, inverse: \RegistroFacturacion.factura)
    var registros: [RegistroFacturacion] = []

    init(numeroFactura: String = "", cliente: Cliente? = nil,
         estado: EstadoFactura = .borrador,
         descuentoGlobalPorcentaje: Double = 0,
         observaciones: String = "", promptOriginal: String? = nil) {
        self.numeroFactura = numeroFactura
        self.cliente = cliente
        self.estado = estado
        self.descuentoGlobalPorcentaje = descuentoGlobalPorcentaje
        self.observaciones = observaciones
        self.promptOriginal = promptOriginal
        self.fecha = .now
        self.fechaVencimiento = Calendar.current.date(byAdding: .day, value: 30, to: .now)

        // Snapshot del cliente
        if let cliente {
            self.clienteNombre = cliente.nombre
            self.clienteNIF = cliente.nif
            self.clienteDireccion = [cliente.direccion, cliente.codigoPostal, cliente.ciudad, cliente.provincia]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
    }

    func recalcularTotales(irpfPorcentaje: Double = 15.0, aplicarIRPF: Bool = false) {
        // Recalcular subtotales de cada línea
        for linea in lineas {
            linea.recalcular()
        }

        // Base imponible = suma de subtotales
        let sumaSubtotales = lineas.reduce(0) { $0 + $1.subtotal }

        // Aplicar descuento global
        let descuento = sumaSubtotales * descuentoGlobalPorcentaje / 100
        baseImponible = sumaSubtotales - descuento

        // Calcular IVA por línea (respetando porcentaje individual)
        if descuentoGlobalPorcentaje > 0 {
            // Distribuir proporcionalmente el descuento
            let factor = baseImponible / max(sumaSubtotales, 0.01)
            totalIVA = lineas.reduce(0) { total, linea in
                total + (linea.subtotal * factor * linea.porcentajeIVA / 100)
            }
        } else {
            totalIVA = lineas.reduce(0) { total, linea in
                total + (linea.subtotal * linea.porcentajeIVA / 100)
            }
        }

        // IRPF
        totalIRPF = aplicarIRPF ? baseImponible * irpfPorcentaje / 100 : 0

        // Total
        totalFactura = baseImponible + totalIVA - totalIRPF
        fechaModificacion = .now
    }

    /// Desglose de IVA por tipo para el PDF
    var desgloseIVA: [(porcentaje: Double, base: Double, cuota: Double)] {
        var desglose: [Double: (base: Double, cuota: Double)] = [:]
        let factor = descuentoGlobalPorcentaje > 0
            ? baseImponible / max(lineas.reduce(0) { $0 + $1.subtotal }, 0.01)
            : 1.0

        for linea in lineas {
            let baseLinea = linea.subtotal * factor
            let cuotaLinea = baseLinea * linea.porcentajeIVA / 100
            let existing = desglose[linea.porcentajeIVA] ?? (base: 0, cuota: 0)
            desglose[linea.porcentajeIVA] = (base: existing.base + baseLinea, cuota: existing.cuota + cuotaLinea)
        }

        return desglose
            .map { (porcentaje: $0.key, base: $0.value.base, cuota: $0.value.cuota) }
            .sorted { $0.porcentaje > $1.porcentaje }
    }

    var lineasOrdenadas: [LineaFactura] {
        lineas.sorted { $0.orden < $1.orden }
    }
}

extension Factura: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}

// MARK: - LineaFactura

@Model
final class LineaFactura {
    var orden: Int = 0
    var articulo: Articulo?
    var referencia: String = ""
    var concepto: String = ""
    var cantidad: Double = 1
    var unidad: UnidadMedida = UnidadMedida.unidad
    var precioUnitario: Double = 0
    var descuentoPorcentaje: Double = 0
    var porcentajeIVA: Double = 21
    var subtotal: Double = 0
    var factura: Factura?

    init(orden: Int = 0, articulo: Articulo? = nil, referencia: String = "",
         concepto: String = "", cantidad: Double = 1, unidad: UnidadMedida = .unidad,
         precioUnitario: Double = 0, descuentoPorcentaje: Double = 0,
         porcentajeIVA: Double = 21) {
        self.orden = orden
        self.articulo = articulo
        self.referencia = referencia
        self.concepto = concepto
        self.cantidad = cantidad
        self.unidad = unidad
        self.precioUnitario = precioUnitario
        self.descuentoPorcentaje = descuentoPorcentaje
        self.porcentajeIVA = porcentajeIVA
        recalcular()
    }

    func recalcular() {
        subtotal = cantidad * precioUnitario * (1 - descuentoPorcentaje / 100)
    }
}

extension LineaFactura: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}

// MARK: - RegistroFacturacion (VeriFactu)

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
    var estadoEnvio: EstadoEnvioVF = EstadoEnvioVF.noEnviado
    var respuestaAEAT: String = ""
    var fechaEnvio: Date?

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

// MARK: - EventoSIF (Log de eventos VeriFactu)

@Model
final class EventoSIF {
    var timestamp: Date = Date.now
    var tipo: String = ""
    var descripcion: String = ""
    var detalles: String = ""
    var numeroFactura: String = ""
    var usuario: String = ""

    init(tipo: String, descripcion: String, detalles: String = "", numeroFactura: String = "") {
        self.timestamp = .now
        self.tipo = tipo
        self.descripcion = descripcion
        self.detalles = detalles
        self.numeroFactura = numeroFactura
        self.usuario = "Sistema"
    }
}

// MARK: - DataConfig (ModelContainer)

enum DataConfig {
    static let container: ModelContainer = {
        let schema = Schema([
            Negocio.self,
            Cliente.self,
            Categoria.self,
            Articulo.self,
            Factura.self,
            LineaFactura.self,
            RegistroFacturacion.self,
            EventoSIF.self,
            PerfilImportacion.self
        ])
        let config = ModelConfiguration("FacturaApp", isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Error creando ModelContainer: \(error)")
        }
    }()
}

// MARK: - Formateadores

enum Formateadores {
    static let euros: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    static func formatEuros(_ valor: Double) -> String {
        euros.string(from: NSNumber(value: valor)) ?? String(format: "%.2f €", valor)
    }

    static let fecha: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    static let fechaCorta: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    /// Guarda el contexto con logging de errores.
    static func guardarContexto(_ context: ModelContext, operacion: String = "") {
        do {
            try context.save()
        } catch {
            print("ERROR guardando \(operacion): \(error.localizedDescription)")
        }
    }

    /// Valida formato de NIF/CIF español.
    /// NIF: 8 dígitos + letra. CIF: letra + 7 dígitos + dígito/letra. NIE: X/Y/Z + 7 dígitos + letra.
    static func validarNIF(_ nif: String) -> Bool {
        let trimmed = nif.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count == 9 else { return false }

        // NIF: 8 dígitos + letra
        let nifPattern = "^[0-9]{8}[A-Z]$"
        // CIF: letra + 7 dígitos + dígito/letra
        let cifPattern = "^[ABCDEFGHJKLMNPQRSUVW][0-9]{7}[0-9A-J]$"
        // NIE: X/Y/Z + 7 dígitos + letra
        let niePattern = "^[XYZ][0-9]{7}[A-Z]$"

        let patterns = [nifPattern, cifPattern, niePattern]
        for pattern in patterns {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    /// Parsea un texto de precio aceptando coma o punto como separador decimal
    static func parsearPrecio(_ texto: String) -> Double? {
        let limpio = texto
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "€", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(limpio)
    }
}
