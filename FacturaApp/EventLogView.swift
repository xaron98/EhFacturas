// EventLogView.swift
// FacturaApp — Vista del log de eventos para auditoría

import SwiftUI
import SwiftData

struct EventLogView: View {
    @Query(sort: \EventoSIF.timestamp, order: .reverse) private var eventos: [EventoSIF]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if eventos.isEmpty {
                    ContentUnavailableView {
                        Label("Sin eventos", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Los eventos del sistema aparecerán aquí.")
                    }
                } else {
                    List(eventos, id: \.persistentModelID) { evento in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: iconoEvento(evento.tipo))
                                    .font(.caption)
                                    .foregroundStyle(colorEvento(evento.tipo))
                                Text(evento.tipo.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(colorEvento(evento.tipo))
                                Spacer()
                                Text(evento.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(evento.descripcion)
                                .font(.subheadline)
                            if !evento.detalles.isEmpty {
                                Text(evento.detalles)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !evento.numeroFactura.isEmpty {
                                Text("Factura: \(evento.numeroFactura)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Log de eventos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func iconoEvento(_ tipo: String) -> String {
        switch tipo {
        case EventLogService.FACTURA_CREADA: return "doc.badge.plus"
        case EventLogService.FACTURA_EMITIDA: return "paperplane.fill"
        case EventLogService.FACTURA_ANULADA: return "xmark.circle.fill"
        case EventLogService.FACTURA_RECTIFICADA: return "doc.on.doc.fill"
        case EventLogService.FACTURA_COBRADA: return "checkmark.circle.fill"
        case EventLogService.HASH_GENERADO: return "number"
        case EventLogService.ENVIO_AEAT_OK: return "arrow.up.circle.fill"
        case EventLogService.ENVIO_AEAT_ERROR: return "exclamationmark.triangle.fill"
        case EventLogService.CERTIFICADO_IMPORTADO: return "key.fill"
        case EventLogService.CERTIFICADO_ELIMINADO: return "key"
        case EventLogService.NEGOCIO_CONFIGURADO: return "building.2.fill"
        case EventLogService.CLIENTE_CREADO: return "person.badge.plus"
        case EventLogService.ARTICULO_CREADO: return "shippingbox.fill"
        case EventLogService.APP_INICIADA: return "power"
        default: return "circle.fill"
        }
    }

    private func colorEvento(_ tipo: String) -> Color {
        switch tipo {
        case _ where tipo.contains("ERROR"): return .red
        case _ where tipo.contains("ANULADA"): return .orange
        case _ where tipo.contains("EMITIDA"), _ where tipo.contains("AEAT_OK"): return .green
        case _ where tipo.contains("HASH"): return .purple
        case _ where tipo.contains("COBRADA"): return .green
        default: return .blue
        }
    }
}
