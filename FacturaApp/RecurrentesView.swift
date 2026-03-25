// RecurrentesView.swift
// FacturaApp — Vista de facturas recurrentes (Sprint 2)

import SwiftUI
import SwiftData

struct RecurrentesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FacturaRecurrente.proximaFecha) private var recurrentes: [FacturaRecurrente]

    var body: some View {
        Group {
            if recurrentes.isEmpty {
                ContentUnavailableView {
                    Label("Sin facturas recurrentes", systemImage: "arrow.clockwise")
                } description: {
                    Text("Crea una factura recurrente desde el detalle de una factura existente.")
                }
            } else {
                List {
                    ForEach(recurrentes, id: \.persistentModelID) { rec in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(rec.nombre)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(Formateadores.formatEuros(rec.importeTotal))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            HStack {
                                Text(rec.clienteNombre)
                                Text("\u{00B7}")
                                Text(rec.frecuencia.capitalized)
                                Text("\u{00B7}")
                                Text("Proxima: \(rec.proximaFecha, style: .date)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            HStack {
                                Text("Generada \(rec.vecesGenerada)x")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { rec.activo },
                                    set: { rec.activo = $0; try? modelContext.save() }
                                ))
                                .labelsHidden()
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        for i in offsets { modelContext.delete(recurrentes[i]) }
                        try? modelContext.save()
                    }
                }
            }
        }
    }
}
