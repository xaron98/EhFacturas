// GastosView.swift
// FacturaApp — Vista de gastos/compras del negocio

import SwiftUI
import SwiftData

struct GastosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gasto.fecha, order: .reverse) private var gastos: [Gasto]
    @State private var mostrarFormulario = false

    private var totalGastos: Double {
        gastos.reduce(0) { $0 + $1.importe }
    }

    var body: some View {
        Group {
            if gastos.isEmpty {
                ContentUnavailableView {
                    Label("Sin gastos", systemImage: "cart")
                } description: {
                    Text("Registra gastos de tu negocio para calcular el beneficio neto.")
                }
            } else {
                List {
                    Section {
                        HStack {
                            Text("Total gastos")
                                .font(.subheadline)
                            Spacer()
                            Text(Formateadores.formatEuros(totalGastos))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                    }

                    Section("Gastos") {
                        ForEach(gastos, id: \.persistentModelID) { gasto in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(gasto.concepto)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(Formateadores.formatEuros(gasto.importe))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                }
                                HStack {
                                    if !gasto.categoria.isEmpty {
                                        Text(gasto.categoria.capitalized)
                                    }
                                    if !gasto.proveedor.isEmpty {
                                        Text("· \(gasto.proveedor)")
                                    }
                                    Spacer()
                                    Text(gasto.fecha, style: .date)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(gastos[i]) }
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    mostrarFormulario = true
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.blue)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $mostrarFormulario) {
            GastoFormularioView()
        }
    }
}

struct GastoFormularioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var concepto = ""
    @State private var importeTexto = ""
    @State private var categoria = "otros"
    @State private var proveedor = ""

    let categorias = ["material", "herramientas", "vehiculo", "oficina", "formacion", "seguros", "otros"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del gasto") {
                    TextField("Concepto *", text: $concepto)
                    HStack {
                        Text("Importe")
                        Spacer()
                        TextField("0,00", text: $importeTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("\u{20AC}")
                    }
                    Picker("Categoria", selection: $categoria) {
                        ForEach(categorias, id: \.self) { cat in
                            Text(cat.capitalized).tag(cat)
                        }
                    }
                    TextField("Proveedor", text: $proveedor)
                }
            }
            .navigationTitle("Nuevo gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let importe = Formateadores.parsearPrecio(importeTexto) ?? 0
                        let gasto = Gasto(concepto: concepto, importe: importe, categoria: categoria, proveedor: proveedor)
                        modelContext.insert(gasto)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(concepto.isEmpty)
                }
            }
        }
    }
}
