// WhatsNewView.swift
// EhFacturas! — Novedades de cada version

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""

    static let currentVersion = "1.0.0"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(versions, id: \.version) { version in
                        versionCard(version)
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("whats_new", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("close", comment: "")) { dismiss() }
                }
            }
        }
        .onAppear {
            lastSeenVersion = Self.currentVersion
        }
    }

    private func versionCard(_ version: VersionInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("v\(version.version)")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text(version.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(version.items, id: \.title) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.body)
                        .foregroundStyle(item.color)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Version data

    struct VersionInfo {
        let version: String
        let date: String
        let items: [FeatureItem]
    }

    struct FeatureItem {
        let icon: String
        let color: Color
        let title: String
        let description: String
    }

    private var versions: [VersionInfo] {
        [
            VersionInfo(version: "1.0.0", date: "2026-03-25", items: [
                FeatureItem(icon: "mic.fill", color: .blue, title: "Control por voz", description: "Crea facturas, clientes y articulos hablando. La IA interpreta tus comandos."),
                FeatureItem(icon: "doc.text.fill", color: .purple, title: "Facturas y presupuestos", description: "PDF profesional A4 con codigo QR, desglose IVA/IRPF y logo personalizable."),
                FeatureItem(icon: "shield.checkered", color: .green, title: "VeriFactu", description: "Cumplimiento del RD 1007/2023: hash SHA-256, XML AEAT, firma digital."),
                FeatureItem(icon: "arrow.triangle.2.circlepath", color: .orange, title: "Facturas recurrentes", description: "Programa facturas semanales, mensuales, trimestrales o anuales."),
                FeatureItem(icon: "doc.on.doc", color: .cyan, title: "Plantillas", description: "Guarda combinaciones frecuentes y crea facturas en un toque."),
                FeatureItem(icon: "chart.bar.fill", color: .indigo, title: "Informes financieros", description: "Dashboard con graficos, top clientes, gastos por categoria y exportacion CSV."),
                FeatureItem(icon: "camera.fill", color: .pink, title: "Fotos y firma", description: "Adjunta fotos del trabajo y recoge la firma del cliente en pantalla."),
                FeatureItem(icon: "camera.viewfinder", color: .teal, title: "Escaner OCR", description: "Escanea tickets y documentos con la camara para procesarlos con IA."),
                FeatureItem(icon: "square.and.arrow.down", color: .brown, title: "Importador universal", description: "Importa datos de Salfon, Contaplus, Holded, Billin y mas desde CSV."),
                FeatureItem(icon: "icloud.fill", color: .blue, title: "Sincronizacion", description: "Tus datos en todos tus dispositivos con iCloud."),
                FeatureItem(icon: "globe", color: .green, title: "Multi-idioma", description: "Disponible en espanol, ingles, catalan, euskera y gallego."),
                FeatureItem(icon: "waveform", color: .purple, title: "Voz de la IA", description: "La IA lee las respuestas en voz alta. Elige entre voz femenina o masculina."),
                FeatureItem(icon: "sparkles", color: .orange, title: "Apple Intelligence + Cloud", description: "IA on-device en iOS 26+. Claude y OpenAI como alternativa en iOS 17+."),
            ])
        ]
    }

    static var shouldShowWhatsNew: Bool {
        let last = UserDefaults.standard.string(forKey: "lastSeenVersion") ?? ""
        return last != currentVersion
    }
}
