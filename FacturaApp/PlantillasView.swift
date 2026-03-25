// PlantillasView.swift
// FacturaApp — Vista de plantillas de factura (Sprint 2)

import SwiftUI
import SwiftData

struct PlantillasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlantillaFactura.fechaCreacion, order: .reverse) private var plantillas: [PlantillaFactura]
    let onUsarPlantilla: ((PlantillaFactura) -> Void)?

    init(onUsarPlantilla: ((PlantillaFactura) -> Void)? = nil) {
        self.onUsarPlantilla = onUsarPlantilla
    }

    var body: some View {
        Group {
            if plantillas.isEmpty {
                ContentUnavailableView {
                    Label("Sin plantillas", systemImage: "doc.on.doc")
                } description: {
                    Text("Guarda una factura como plantilla desde su vista de detalle.")
                }
            } else {
                List {
                    ForEach(plantillas, id: \.persistentModelID) { plantilla in
                        Button {
                            onUsarPlantilla?(plantilla)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(.purple)
                                        .font(.caption)
                                    Text(plantilla.nombre)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                }
                                Text(plantilla.articulosTexto)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                HStack {
                                    Text("Usada \(plantilla.vecesUsada)x")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Spacer()
                                    Text(plantilla.fechaCreacion, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { modelContext.delete(plantillas[i]) }
                        try? modelContext.save()
                    }
                }
            }
        }
    }
}
