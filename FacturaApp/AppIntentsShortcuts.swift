// AppIntentsShortcuts.swift
// FacturaApp — Siri Shortcuts y App Intents

import AppIntents

struct CrearFacturaIntent: AppIntent {
    static let title: LocalizedStringResource = "Crear factura"
    static let description: IntentDescription = "Crea una nueva factura borrador"
    static let openAppWhenRun = true

    @Parameter(title: "Cliente")
    var clienteNombre: String

    @Parameter(title: "Descripcion de articulos")
    var articulosTexto: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Abriendo FacturaApp para crear la factura...")
    }
}

struct ConsultarResumenIntent: AppIntent {
    static let title: LocalizedStringResource = "Resumen de facturacion"
    static let description: IntentDescription = "Consulta cuanto tienes pendiente de cobro"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Abriendo FacturaApp...")
    }
}

struct FacturaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CrearFacturaIntent(),
            phrases: [
                "Crea una factura en \(.applicationName)",
                "Nueva factura en \(.applicationName)",
                "Factura para cliente en \(.applicationName)"
            ],
            shortTitle: "Crear factura",
            systemImageName: "doc.badge.plus"
        )
        AppShortcut(
            intent: ConsultarResumenIntent(),
            phrases: [
                "Resumen de facturacion en \(.applicationName)",
                "Cuanto tengo pendiente en \(.applicationName)"
            ],
            shortTitle: "Resumen",
            systemImageName: "chart.bar"
        )
    }
}
