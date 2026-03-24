// EventLogService.swift
// FacturaApp — Servicio de log de eventos para auditoría VeriFactu

import Foundation
import SwiftData

enum EventLogService {

    // Tipos de evento
    static let FACTURA_CREADA = "FACTURA_CREADA"
    static let FACTURA_EMITIDA = "FACTURA_EMITIDA"
    static let FACTURA_ANULADA = "FACTURA_ANULADA"
    static let FACTURA_RECTIFICADA = "FACTURA_RECTIFICADA"
    static let FACTURA_COBRADA = "FACTURA_COBRADA"
    static let HASH_GENERADO = "HASH_GENERADO"
    static let ENVIO_AEAT_OK = "ENVIO_AEAT_OK"
    static let ENVIO_AEAT_ERROR = "ENVIO_AEAT_ERROR"
    static let CERTIFICADO_IMPORTADO = "CERTIFICADO_IMPORTADO"
    static let CERTIFICADO_ELIMINADO = "CERTIFICADO_ELIMINADO"
    static let NEGOCIO_CONFIGURADO = "NEGOCIO_CONFIGURADO"
    static let CLIENTE_CREADO = "CLIENTE_CREADO"
    static let ARTICULO_CREADO = "ARTICULO_CREADO"
    static let APP_INICIADA = "APP_INICIADA"

    static func registrar(
        tipo: String,
        descripcion: String,
        detalles: String = "",
        numeroFactura: String = "",
        modelContext: ModelContext
    ) {
        let evento = EventoSIF(
            tipo: tipo,
            descripcion: descripcion,
            detalles: detalles,
            numeroFactura: numeroFactura
        )
        modelContext.insert(evento)
        try? modelContext.save()
    }
}
