// ChatMessageView.swift
// FacturaApp — Extracted from VoiceMainView
// Displays a single chat message bubble (user, AI, error, factura, sistema).

import SwiftUI
import SwiftData

struct ChatMessageView: View {
    let msg: MensajeChat
    let onEditFactura: (Factura) -> Void

    var body: some View {
        switch msg.tipo {
        case .usuario:
            HStack(alignment: .top, spacing: 10) {
                Spacer()
                Text(msg.texto)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue.opacity(0.5))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tu mensaje: \(msg.texto)")
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))

        case .ia:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.purple.opacity(0.6))
                        .frame(width: 3)
                        .padding(.vertical, 6)
                    VStack(alignment: .leading, spacing: 6) {
                        if let accion = msg.accion {
                            HStack(spacing: 4) {
                                Image(systemName: iconoAccion(accion))
                                    .font(.caption2)
                                Text(tituloAccion(accion))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(colorAccion(accion))
                        }
                        Text(msg.texto)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(12)
                }
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Respuesta de la IA: \(msg.texto)")
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))

        case .error:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(msg.texto)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Error: \(msg.texto)")
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))

        case .factura:
            if let fID = msg.facturaID {
                FacturaChatCard(facturaID: fID, texto: msg.texto) { factura in
                    onEditFactura(factura)
                }
            }

        case .sistema:
            Text(msg.texto)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
        }
    }

    // MARK: - Helpers de estilo

    private func iconoAccion(_ accion: ComandoResultado.AccionRealizada) -> String {
        switch accion {
        case .clienteCreado: return "person.badge.plus"
        case .clienteEncontrado: return "person.crop.circle"
        case .articuloCreado: return "shippingbox.fill"
        case .articuloEncontrado: return "shippingbox"
        case .facturaBorradorCreada: return "doc.badge.plus"
        case .facturaEmitida: return "paperplane.fill"
        case .facturaMarcadaPagada: return "checkmark.circle.fill"
        case .listaClientes: return "person.2"
        case .listaArticulos: return "shippingbox"
        case .listaFacturas: return "doc.text"
        case .importarSolicitado: return "arrow.down.doc"
        case .informacion: return "info.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    private func colorAccion(_ accion: ComandoResultado.AccionRealizada) -> Color {
        switch accion {
        case .clienteCreado, .articuloCreado: return .blue
        case .facturaBorradorCreada: return .purple
        case .facturaMarcadaPagada: return .green
        case .error: return .red
        default: return .secondary
        }
    }

    private func tituloAccion(_ accion: ComandoResultado.AccionRealizada) -> String {
        switch accion {
        case .clienteCreado: return "Cliente creado"
        case .clienteEncontrado: return "Cliente encontrado"
        case .articuloCreado: return "Artículo añadido"
        case .articuloEncontrado: return "Artículo encontrado"
        case .facturaBorradorCreada: return "Factura creada"
        case .facturaEmitida: return "Factura emitida"
        case .facturaMarcadaPagada: return "Factura cobrada"
        case .listaClientes: return "Clientes"
        case .listaArticulos: return "Artículos"
        case .listaFacturas: return "Facturas"
        case .importarSolicitado: return "Importar datos"
        case .informacion: return "Información"
        case .error: return "Error"
        }
    }
}
