// MapeoUniversal.swift
// FacturaApp — Mapeo universal de columnas CSV
// Compatible con: Salfon, Contaplus, a3factura, Holded, Billin, Quipu,
// Anfix, FacturaDirecta, Debitoor/SumUp, Cegid DiezFAC, Facturas Cloud,
// y cualquier CSV/Excel genérico.
//
// Incluye detección automática, mapeo manual y perfiles guardados.

import Foundation
import SwiftUI
import SwiftData

// MARK: - Tipo de importación

enum TipoImportacion: String, CaseIterable {
    case articulos
    case clientes
}

// MARK: - Diccionario universal de sinónimos

enum SinonimosCampo {

    // MARK: Artículos

    static let nombre: [String] = [
        "nombre", "descripcion", "descripción", "concepto", "denominacion", "denominación",
        "articulo", "artículo", "producto", "servicio", "material",
        "nombre articulo", "nombre artículo", "nombre producto",
        "descripcion articulo", "descripción artículo",
        "descripcion corta", "desc. corta", "texto", "denominacion articulo",
        "nombre_articulo", "desc_articulo", "concepto_linea",
        "item", "item_name", "product_name", "name", "description",
        "product", "service",
        "nombre del producto", "nombre del artículo", "title",
        "denominación artículo", "desc. artículo"
    ]

    static let referencia: [String] = [
        "referencia", "ref", "ref.", "codigo", "código", "cod", "cod.", "sku",
        "codigo articulo", "código artículo", "cod_articulo", "cod articulo",
        "referencia interna", "ref_interna", "id_articulo",
        "ref. saltoki", "codigo saltoki", "cod. saltoki", "referencia saltoki",
        "codigo_producto", "cod_producto",
        "sku", "item_code", "product_code", "code", "reference",
        "ean", "ean13", "codigo barras", "código barras", "gtin"
    ]

    static let precio: [String] = [
        "precio", "pvp", "p.v.p", "p.v.p.", "precio venta", "precio_venta",
        "importe", "tarifa", "precio unitario", "precio_unitario",
        "precio sin iva", "precio neto venta", "base",
        "pvp neto", "precio neto", "precio con dto", "precio dto",
        "tarifa neta", "tarifa pvp",
        "precio_venta_iva", "pvp_articulo",
        "unit_price", "price", "rate", "amount",
        "valor", "coste venta", "€", "eur"
    ]

    static let precioCoste: [String] = [
        "coste", "costo", "precio coste", "precio_coste", "precio compra",
        "precio_compra", "neto", "coste unitario", "coste_unitario",
        "precio proveedor", "coste material",
        "cost", "cost_price", "purchase_price",
        "pcoste", "precio_coste_art"
    ]

    static let unidad: [String] = [
        "unidad", "ud", "uds", "unidades", "um", "u.m.", "u.m",
        "unidad medida", "unidad_medida", "tipo unidad",
        "unit", "unit_type", "uom",
        "ud. medida", "unidad venta"
    ]

    static let proveedor: [String] = [
        "proveedor", "fabricante", "marca", "suministrador",
        "nombre proveedor", "nombre_proveedor", "razon social proveedor",
        "supplier", "vendor", "manufacturer", "brand",
        "proveedor principal", "prov"
    ]

    static let categoria: [String] = [
        "categoria", "categoría", "familia", "grupo", "seccion", "sección",
        "subfamilia", "tipo", "clase", "clasificacion", "clasificación",
        "grupo articulo", "familia articulo", "categoria_articulo",
        "familia saltoki", "seccion saltoki", "grupo saltoki",
        "category", "group", "product_type"
    ]

    static let descripcionLarga: [String] = [
        "descripcion ampliada", "descripción ampliada", "desc. ampliada",
        "descripcion larga", "descripción larga", "detalle", "detalles",
        "observaciones", "notas", "texto largo",
        "long_description", "notes", "details"
    ]

    static let iva: [String] = [
        "iva", "tipo iva", "tipo_iva", "% iva", "%iva", "porcentaje iva",
        "impuesto", "tasa", "tax", "vat", "tax_rate",
        "iva %", "iva%", "tipo impositivo"
    ]

    // MARK: Clientes

    static let clienteNombre: [String] = [
        "nombre", "razon social", "razón social", "cliente", "denominacion",
        "denominación", "nombre cliente", "nombre_cliente",
        "razon_social", "nombre o razon social",
        "nombre_cuenta", "descripcion_cuenta",
        "company", "company_name", "contact_name", "name", "customer",
        "client_name", "business_name",
        "nombre del cliente", "contacto"
    ]

    static let clienteNIF: [String] = [
        "nif", "cif", "dni", "nif/cif", "cif/nif", "nif_cif",
        "documento", "documento identidad", "identificacion fiscal",
        "identificación fiscal", "numero identificacion",
        "nif_cuenta", "cif_cuenta",
        "tax_id", "vat_number", "fiscal_id", "id_number"
    ]

    static let clienteDireccion: [String] = [
        "direccion", "dirección", "domicilio", "calle", "via", "vía",
        "dir", "dir.", "direccion fiscal", "dirección fiscal",
        "domicilio fiscal", "calle y numero", "domicilio social",
        "address", "street", "address_line1", "billing_address"
    ]

    static let clienteCP: [String] = [
        "cp", "c.p.", "c.p", "codigo postal", "código postal", "postal",
        "cod_postal", "codigo_postal",
        "zip", "zip_code", "postcode", "postal_code"
    ]

    static let clienteCiudad: [String] = [
        "ciudad", "localidad", "poblacion", "población", "municipio",
        "plaza", "loc", "loc.",
        "city", "town", "locality"
    ]

    static let clienteProvincia: [String] = [
        "provincia", "estado", "region", "región", "comunidad",
        "comunidad autonoma", "comunidad autónoma", "prov",
        "state", "province", "region"
    ]

    static let clienteTelefono: [String] = [
        "telefono", "teléfono", "tel", "tlf", "tlf.", "telf", "telf.",
        "tel.", "movil", "móvil", "celular", "fijo", "telefono1",
        "telefono principal", "teléfono principal",
        "telefono movil", "teléfono móvil",
        "phone", "mobile", "phone_number", "contact_phone"
    ]

    static let clienteEmail: [String] = [
        "email", "e-mail", "correo", "mail", "correo electronico",
        "correo electrónico", "email_cliente", "e_mail",
        "direccion email", "dirección email",
        "email_address", "contact_email"
    ]
}

// MARK: - Perfil de importación (guardable)

@Model
final class PerfilImportacion {
    var nombre: String = ""
    var tipo: String = ""
    var separador: String = ";"
    var encoding: String = "utf8"
    var mapeoJSON: String = "{}"
    var cabecerasOriginales: [String] = []
    var fechaCreacion: Date = Date.now
    var ultimoUso: Date = Date.now
    var vecesUsado: Int = 0

    init(nombre: String, tipo: String, separador: String = ";",
         encoding: String = "utf8", mapeo: [String: Int] = [:],
         cabeceras: [String] = []) {
        self.nombre = nombre
        self.tipo = tipo
        self.separador = separador
        self.encoding = encoding
        self.mapeoJSON = (try? JSONEncoder().encode(mapeo)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        self.cabecerasOriginales = cabeceras
        self.fechaCreacion = .now
        self.ultimoUso = .now
        self.vecesUsado = 0
    }

    var mapeo: [String: Int] {
        get {
            guard let data = mapeoJSON.data(using: .utf8) else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            mapeoJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        }
    }
}

// MARK: - Detector de programa de origen

struct DetectorOrigen {

    struct ProgramaDetectado {
        var nombre: String
        var confianza: Double
    }

    static func detectar(cabeceras: [String]) -> ProgramaDetectado {
        let cabecerasLower = Set(cabeceras.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })

        let programas: [(nombre: String, indicadores: [String], peso: Double)] = [
            ("Salfon", ["ref. saltoki", "familia saltoki", "pvp neto", "cod. saltoki",
                        "tarifa neta", "seccion saltoki", "desc. corta"], 1.0),
            ("Contaplus", ["nombre_cuenta", "nif_cuenta", "cod_producto",
                           "precio_venta_iva", "desc_articulo", "codigo_producto"], 1.0),
            ("a3factura", ["nombre_articulo", "precio_venta", "concepto_linea"], 0.8),
            ("Holded", ["item_name", "unit_price", "tax_rate", "sku",
                        "product_code", "company_name", "vat_number"], 1.0),
            ("Billin", ["company", "tax_id", "billing_address", "product_name"], 0.8),
            ("Quipu", ["contact_name", "fiscal_id", "contact_email", "phone_number"], 0.8),
            ("FacturaDirecta", ["nombre del producto", "nombre del cliente",
                                "nombre del artículo"], 0.7),
            ("Debitoor/SumUp", ["title", "unit_price", "vat_number", "description"], 0.6)
        ]

        var mejorMatch = ProgramaDetectado(nombre: "Genérico", confianza: 0)

        for (nombre, indicadores, peso) in programas {
            let matches = indicadores.filter { ind in
                cabecerasLower.contains(where: { $0.contains(ind) })
            }
            let confianza = Double(matches.count) / Double(indicadores.count) * peso
            if confianza > mejorMatch.confianza {
                mejorMatch = ProgramaDetectado(nombre: nombre, confianza: confianza)
            }
        }

        return mejorMatch
    }
}

// MARK: - Mapeo universal

struct MapeoUniversal {

    var columnas: [String]
    var mapeo: [String: Int]
    var programaDetectado: DetectorOrigen.ProgramaDetectado

    static let camposArticulo: [(id: String, label: String, obligatorio: Bool)] = [
        ("nombre", "Nombre / Descripción", true),
        ("referencia", "Referencia / Código", false),
        ("precio", "Precio venta (sin IVA)", false),
        ("precioCoste", "Precio coste", false),
        ("unidad", "Unidad de medida", false),
        ("proveedor", "Proveedor / Fabricante", false),
        ("categoria", "Categoría / Familia", false),
        ("descripcion", "Descripción ampliada", false),
        ("iva", "Tipo de IVA (%)", false)
    ]

    static let camposCliente: [(id: String, label: String, obligatorio: Bool)] = [
        ("nombre", "Nombre / Razón social", true),
        ("nif", "NIF / CIF", false),
        ("direccion", "Dirección", false),
        ("codigoPostal", "Código postal", false),
        ("ciudad", "Ciudad / Localidad", false),
        ("provincia", "Provincia", false),
        ("telefono", "Teléfono", false),
        ("email", "Email", false)
    ]

    static func detectar(cabeceras: [String], tipo: TipoImportacion) -> MapeoUniversal {
        let cabecerasLower = cabeceras.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        var mapeo: [String: Int] = [:]
        let programa = DetectorOrigen.detectar(cabeceras: cabeceras)

        let patrones: [(campo: String, sinonimos: [String])]

        switch tipo {
        case .articulos:
            patrones = [
                ("nombre", SinonimosCampo.nombre),
                ("referencia", SinonimosCampo.referencia),
                ("precio", SinonimosCampo.precio),
                ("precioCoste", SinonimosCampo.precioCoste),
                ("unidad", SinonimosCampo.unidad),
                ("proveedor", SinonimosCampo.proveedor),
                ("categoria", SinonimosCampo.categoria),
                ("descripcion", SinonimosCampo.descripcionLarga),
                ("iva", SinonimosCampo.iva)
            ]
        case .clientes:
            patrones = [
                ("nombre", SinonimosCampo.clienteNombre),
                ("nif", SinonimosCampo.clienteNIF),
                ("direccion", SinonimosCampo.clienteDireccion),
                ("codigoPostal", SinonimosCampo.clienteCP),
                ("ciudad", SinonimosCampo.clienteCiudad),
                ("provincia", SinonimosCampo.clienteProvincia),
                ("telefono", SinonimosCampo.clienteTelefono),
                ("email", SinonimosCampo.clienteEmail)
            ]
        }

        for (campo, sinonimos) in patrones {
            for (i, cab) in cabecerasLower.enumerated() {
                if sinonimos.contains(cab) && !mapeo.values.contains(i) {
                    mapeo[campo] = i
                    break
                }
            }
            if mapeo[campo] == nil {
                for (i, cab) in cabecerasLower.enumerated() {
                    if sinonimos.contains(where: { cab.contains($0) || $0.contains(cab) })
                        && !mapeo.values.contains(i) {
                        mapeo[campo] = i
                        break
                    }
                }
            }
        }

        return MapeoUniversal(columnas: cabeceras, mapeo: mapeo, programaDetectado: programa)
    }

    static func aplicarPerfil(_ perfil: PerfilImportacion, cabeceras: [String]) -> MapeoUniversal {
        let programa = DetectorOrigen.ProgramaDetectado(nombre: perfil.nombre, confianza: 1.0)
        if perfil.cabecerasOriginales == cabeceras {
            return MapeoUniversal(columnas: cabeceras, mapeo: perfil.mapeo, programaDetectado: programa)
        }
        var mapeo: [String: Int] = [:]
        for (campo, idx) in perfil.mapeo {
            if idx < cabeceras.count { mapeo[campo] = idx }
        }
        return MapeoUniversal(columnas: cabeceras, mapeo: mapeo, programaDetectado: programa)
    }

    func valor(_ campo: String, en fila: [String]) -> String {
        guard let idx = mapeo[campo], idx < fila.count else { return "" }
        return fila[idx].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func valorDouble(_ campo: String, en fila: [String]) -> Double {
        let str = valor(campo, en: fila)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
        return Double(str) ?? 0
    }

    var tieneNombre: Bool { mapeo["nombre"] != nil }
    var camposMapeados: Int { mapeo.count }

    var columnasSinUsar: [(indice: Int, nombre: String)] {
        let usados = Set(mapeo.values)
        return columnas.enumerated()
            .filter { !usados.contains($0.offset) }
            .map { (indice: $0.offset, nombre: $0.element) }
    }
}

// MARK: - Vista de mapeo manual

struct MapeoManualView: View {

    let cabeceras: [String]
    let tipo: TipoImportacion
    @Binding var mapeo: [String: Int]
    @Environment(\.dismiss) private var dismiss

    var campos: [(id: String, label: String, obligatorio: Bool)] {
        tipo == .articulos ? MapeoUniversal.camposArticulo : MapeoUniversal.camposCliente
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Asigna cada campo a una columna del archivo. Los campos con * son obligatorios.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Campos") {
                    ForEach(campos, id: \.id) { campo in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(campo.label).font(.subheadline)
                                    if campo.obligatorio {
                                        Text("*").foregroundStyle(.red).font(.subheadline)
                                    }
                                }
                                if let idx = mapeo[campo.id], idx < cabeceras.count {
                                    Text("→ \"\(cabeceras[idx])\"")
                                        .font(.caption).foregroundStyle(.green)
                                }
                            }
                            Spacer()
                            Picker("", selection: Binding(
                                get: { mapeo[campo.id] ?? -1 },
                                set: { if $0 == -1 { mapeo.removeValue(forKey: campo.id) } else { mapeo[campo.id] = $0 } }
                            )) {
                                Text("No asignado").tag(-1)
                                ForEach(Array(cabeceras.enumerated()), id: \.offset) { idx, cab in
                                    Text(cab).tag(idx)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 180)
                        }
                    }
                }
            }
            .navigationTitle("Mapear columnas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { dismiss() }
                        .disabled(mapeo["nombre"] == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
