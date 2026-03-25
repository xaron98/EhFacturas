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
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct FacturaChatCard: View {
    let facturaID: PersistentIdentifier
    let texto: String
    let onEdit: (Factura) -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple.opacity(0.6))
                Text(texto)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            if let factura = modelContext.model(for: facturaID) as? Factura {
                FacturaCardView(factura: factura) {
                    onEdit(factura)
                }
            }
        }
    }
}
