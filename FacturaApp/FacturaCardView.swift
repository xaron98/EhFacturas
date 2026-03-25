// FacturaCardView.swift
import SwiftUI
import SwiftData

struct FacturaCardView: View {
    let factura: Factura
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(factura.estado == .borrador ? .blue : .green)
                    .frame(width: 4)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(factura.numeroFactura)
                            .font(.subheadline)
                            .fontWeight(.bold)
                        EstadoBadge(estado: factura.estado)
                        Spacer()
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    if !factura.clienteNombre.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(factura.clienteNombre)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    HStack {
                        Text("\(factura.lineasArray.count) línea(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Formateadores.formatEuros(factura.totalFactura))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }
                .padding(14)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.primary.opacity(0.15), Color.primary.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(factura.numeroFactura), \(factura.clienteNombre), \(Formateadores.formatEuros(factura.totalFactura))")
        .accessibilityHint("Toca para editar la factura")
    }
}

struct FacturaChatCard: View {
    let facturaID: PersistentIdentifier
    let texto: String
    let onEdit: (Factura) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var factura: Factura?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple)
                Text(texto)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            if let factura {
                FacturaCardView(factura: factura) {
                    onEdit(factura)
                }
            }
        }
        .task {
            factura = modelContext.model(for: facturaID) as? Factura
        }
    }
}
