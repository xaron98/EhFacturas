// InformesView.swift
// FacturaApp — Informes financieros con gráficos y exportación CSV

import SwiftUI
import SwiftData
import Charts

struct InformesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Factura.fecha, order: .reverse) private var facturas: [Factura]
    @Query(sort: \Gasto.fecha, order: .reverse) private var todosGastos: [Gasto]
    @State private var periodoSeleccionado: Periodo = .trimestre
    @State private var mostrarExport = false
    @State private var csvData: Data?

    enum Periodo: String, CaseIterable {
        case mes = "Este mes"
        case trimestre = "Trimestre"
        case ano = "Este año"
        case todo = "Todo"
    }

    private var fechaInicio: Date {
        let cal = Calendar.current
        switch periodoSeleccionado {
        case .mes:
            return cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        case .trimestre:
            let month = cal.component(.month, from: .now)
            let quarterStart = ((month - 1) / 3) * 3 + 1
            return cal.date(from: DateComponents(year: cal.component(.year, from: .now), month: quarterStart)) ?? .now
        case .ano:
            return cal.date(from: DateComponents(year: cal.component(.year, from: .now))) ?? .now
        case .todo:
            return .distantPast
        }
    }

    private var facturasFiltradas: [Factura] {
        return facturas.filter { $0.fecha >= fechaInicio && $0.estado != .anulada && $0.estado != .presupuesto }
    }

    private var gastosDelPeriodo: Double {
        todosGastos.filter { $0.fecha >= fechaInicio }.reduce(0) { $0 + $1.importe }
    }

    // MARK: - Computed stats

    private var totalFacturado: Double {
        facturasFiltradas.filter { $0.estado == .emitida || $0.estado == .pagada }.reduce(0) { $0 + $1.totalFactura }
    }
    private var totalCobrado: Double {
        facturasFiltradas.filter { $0.estado == .pagada }.reduce(0) { $0 + $1.totalFactura }
    }
    private var totalPendiente: Double {
        facturasFiltradas.filter { $0.estado == .emitida }.reduce(0) { $0 + $1.totalFactura }
    }
    private var totalIVA: Double {
        facturasFiltradas.filter { $0.estado == .emitida || $0.estado == .pagada }.reduce(0) { $0 + $1.totalIVA }
    }
    private var totalIRPF: Double {
        facturasFiltradas.filter { $0.estado == .emitida || $0.estado == .pagada }.reduce(0) { $0 + $1.totalIRPF }
    }
    private var beneficioNeto: Double {
        totalFacturado - totalIRPF
    }
    private var numFacturas: Int {
        facturasFiltradas.filter { $0.estado != .borrador }.count
    }

    // MARK: - Monthly data for chart

    private var datosMensuales: [(mes: String, facturado: Double, cobrado: Double)] {
        let cal = Calendar.current
        var datos: [Int: (facturado: Double, cobrado: Double)] = [:]

        for factura in facturasFiltradas {
            let month = cal.component(.month, from: factura.fecha)
            let existing = datos[month] ?? (facturado: 0, cobrado: 0)
            if factura.estado == .emitida || factura.estado == .pagada {
                datos[month] = (
                    facturado: existing.facturado + factura.totalFactura,
                    cobrado: existing.cobrado + (factura.estado == .pagada ? factura.totalFactura : 0)
                )
            }
        }

        let meses = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
        return datos.sorted { $0.key < $1.key }.map { (mes: meses[$0.key - 1], facturado: $0.value.facturado, cobrado: $0.value.cobrado) }
    }

    // MARK: - Top clients

    private var topClientes: [(nombre: String, total: Double)] {
        var porCliente: [String: Double] = [:]
        for f in facturasFiltradas where f.estado == .emitida || f.estado == .pagada {
            let nombre = f.clienteNombre.isEmpty ? "Sin cliente" : f.clienteNombre
            porCliente[nombre, default: 0] += f.totalFactura
        }
        return porCliente.sorted { $0.value > $1.value }.prefix(5).map { (nombre: $0.key, total: $0.value) }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Period selector
            Section {
                Picker("Periodo", selection: $periodoSeleccionado) {
                    ForEach(Periodo.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            // Summary stats
            Section("Resumen") {
                statRow("Facturado", totalFacturado, color: .blue)
                statRow("Cobrado", totalCobrado, color: .green)
                statRow("Pendiente", totalPendiente, color: .orange)
                statRow("IVA repercutido", totalIVA, color: .secondary)
                if totalIRPF > 0 {
                    statRow("IRPF retenido", totalIRPF, color: .red)
                }
                statRow("Beneficio neto", beneficioNeto, color: .purple)
                if gastosDelPeriodo > 0 {
                    statRow("Gastos", gastosDelPeriodo, color: .red)
                    statRow("Beneficio real", beneficioNeto - gastosDelPeriodo, color: .mint)
                }
                HStack {
                    Text("Facturas emitidas")
                    Spacer()
                    Text("\(numFacturas)")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }

            // Monthly chart
            if !datosMensuales.isEmpty {
                Section("Facturacion mensual") {
                    Chart {
                        ForEach(datosMensuales, id: \.mes) { dato in
                            BarMark(
                                x: .value("Mes", dato.mes),
                                y: .value("Facturado", dato.facturado)
                            )
                            .foregroundStyle(.blue.opacity(0.7))

                            BarMark(
                                x: .value("Mes", dato.mes),
                                y: .value("Cobrado", dato.cobrado)
                            )
                            .foregroundStyle(.green.opacity(0.7))
                        }
                    }
                    .frame(height: 200)
                    .chartLegend(.visible)
                    .accessibilityLabel("Gráfico de facturación mensual")

                    HStack(spacing: 16) {
                        Label("Facturado", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Label("Cobrado", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            // Top clients
            if !topClientes.isEmpty {
                Section("Top clientes") {
                    ForEach(topClientes, id: \.nombre) { cliente in
                        HStack {
                            Text(cliente.nombre)
                                .font(.subheadline)
                            Spacer()
                            Text(Formateadores.formatEuros(cliente.total))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }

            // Export
            Section {
                Button {
                    exportarCSV()
                } label: {
                    Label("Exportar facturas (CSV)", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $mostrarExport) {
            if let data = csvData {
                ShareSheet(items: [data])
            }
        }
    }

    // MARK: - Helpers

    private func statRow(_ label: String, _ value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(Formateadores.formatEuros(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(Formateadores.formatEuros(value))")
    }

    private func exportarCSV() {
        var csv = "N\u{00BA} Factura;Fecha;Cliente;NIF Cliente;Base Imponible;IVA;IRPF;Total;Estado\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        for f in facturasFiltradas.sorted(by: { $0.fecha < $1.fecha }) {
            let linea = [
                f.numeroFactura,
                dateFormatter.string(from: f.fecha),
                f.clienteNombre,
                f.clienteNIF,
                String(format: "%.2f", f.baseImponible),
                String(format: "%.2f", f.totalIVA),
                String(format: "%.2f", f.totalIRPF),
                String(format: "%.2f", f.totalFactura),
                f.estado.descripcion
            ].joined(separator: ";")
            csv += linea + "\n"
        }

        csvData = csv.data(using: .utf8)
        mostrarExport = true
    }
}
