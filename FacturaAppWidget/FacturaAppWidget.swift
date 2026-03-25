// FacturaAppWidget.swift
// FacturaApp — Widget de facturación

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct FacturaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FacturaWidgetEntry {
        FacturaWidgetEntry(date: .now, pendiente: 1250.00, cobrado: 3400.00, vencido: 200.00, numFacturas: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (FacturaWidgetEntry) -> Void) {
        completion(fetchData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FacturaWidgetEntry>) -> Void) {
        let entry = fetchData()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchData() -> FacturaWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.es.facturaapp") ?? .standard
        return FacturaWidgetEntry(
            date: .now,
            pendiente: defaults.double(forKey: "widget_pendiente"),
            cobrado: defaults.double(forKey: "widget_cobrado"),
            vencido: defaults.double(forKey: "widget_vencido"),
            numFacturas: defaults.integer(forKey: "widget_numFacturas")
        )
    }
}

// MARK: - Entry

struct FacturaWidgetEntry: TimelineEntry {
    let date: Date
    let pendiente: Double
    let cobrado: Double
    let vencido: Double
    let numFacturas: Int
}

// MARK: - Small View

struct FacturaWidgetSmallView: View {
    let entry: FacturaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.blue)
                Text("EhFacturas!")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Pendiente")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatEuros(entry.pendiente))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
            }
            if entry.vencido > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(formatEuros(entry.vencido) + " vencido")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
    }

    private func formatEuros(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f €", v)
    }
}

// MARK: - Medium View

struct FacturaWidgetMediumView: View {
    let entry: FacturaWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                    Text("EhFacturas!")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                Spacer()
                Text("\(entry.numFacturas)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("facturas")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                statRow("Pendiente", entry.pendiente, .orange)
                statRow("Cobrado", entry.cobrado, .green)
                if entry.vencido > 0 {
                    statRow("Vencido", entry.vencido, .red)
                }
            }
        }
        .padding()
    }

    private func statRow(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(formatEuros(value)).font(.caption).fontWeight(.semibold)
        }
    }

    private func formatEuros(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f €", v)
    }
}

// MARK: - Widget

struct FacturaAppWidget: Widget {
    let kind = "FacturaAppWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FacturaWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                FacturaWidgetSmallView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                FacturaWidgetSmallView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("EhFacturas!")
        .description("Resumen de facturas pendientes y cobradas.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    FacturaAppWidget()
} timeline: {
    FacturaWidgetEntry(date: .now, pendiente: 1250, cobrado: 3400, vencido: 200, numFacturas: 12)
}
