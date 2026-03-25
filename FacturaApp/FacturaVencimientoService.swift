// FacturaVencimientoService.swift
// FacturaApp — Detector de vencimientos + notificaciones + background tasks.

import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit
@preconcurrency import BackgroundTasks

// MARK: - Servicio de vencimientos

@MainActor
final class FacturaVencimientoService {

    static let shared = FacturaVencimientoService()
    nonisolated static let taskIdentifier = "es.facturaapp.check-vencimientos"

    private init() {}

    // MARK: - Revisar vencimientos

    func revisarVencimientos(modelContext: ModelContext) {
        let ahora = Date.now

        // Buscar facturas emitidas cuya fecha de vencimiento ya pasó
        let descriptor = FetchDescriptor<Factura>()
        guard let facturas = try? modelContext.fetch(descriptor) else { return }

        let emitidas = facturas.filter { $0.estado == .emitida }

        for factura in emitidas {
            if let vencimiento = factura.fechaVencimiento, vencimiento < ahora {
                factura.estado = .vencida
                factura.fechaModificacion = ahora
            }
        }

        // Programar recordatorios para las que vencen pronto
        let tresDias = Calendar.current.date(byAdding: .day, value: 3, to: ahora)!
        let proximas = emitidas.filter {
            guard let v = $0.fechaVencimiento else { return false }
            return v > ahora && v <= tresDias
        }

        for factura in proximas {
            cancelarRecordatorios(para: factura)
            programarRecordatorios(para: factura)
        }

        try? modelContext.save()

        // Update widget data
        actualizarDatosWidget(modelContext: modelContext)
    }

    // MARK: - Widget data

    func actualizarDatosWidget(modelContext: ModelContext) {
        let desc = FetchDescriptor<Factura>()
        guard let facturas = try? modelContext.fetch(desc) else { return }

        let pendiente = facturas.filter { $0.estado == .emitida }.reduce(0) { $0 + $1.totalFactura }
        let cobrado = facturas.filter { $0.estado == .pagada }.reduce(0) { $0 + $1.totalFactura }
        let vencido = facturas.filter { $0.estado == .vencida }.reduce(0) { $0 + $1.totalFactura }
        let numFacturas = facturas.filter { $0.estado != .anulada && $0.estado != .presupuesto }.count

        let defaults = UserDefaults(suiteName: "group.es.facturaapp") ?? .standard
        defaults.set(pendiente, forKey: "widget_pendiente")
        defaults.set(cobrado, forKey: "widget_cobrado")
        defaults.set(vencido, forKey: "widget_vencido")
        defaults.set(numFacturas, forKey: "widget_numFacturas")

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Notificaciones

    func programarRecordatorios(para factura: Factura) {
        guard let vencimiento = factura.fechaVencimiento else { return }
        let center = UNUserNotificationCenter.current()

        // Notificación 3 días antes
        if let tresDiasAntes = Calendar.current.date(byAdding: .day, value: -3, to: vencimiento),
           tresDiasAntes > .now {
            let content = UNMutableNotificationContent()
            content.title = "Factura por vencer"
            content.body = "\(factura.numeroFactura) de \(factura.clienteNombre) vence en 3 días (\(Formateadores.formatEuros(factura.totalFactura)))"
            content.sound = .default

            var components = Calendar.current.dateComponents([.year, .month, .day], from: tresDiasAntes)
            components.hour = 9
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "vencimiento-3d-\(factura.numeroFactura)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        // Notificación el día del vencimiento
        let content = UNMutableNotificationContent()
        content.title = "Factura vence hoy"
        content.body = "\(factura.numeroFactura) de \(factura.clienteNombre) vence hoy (\(Formateadores.formatEuros(factura.totalFactura)))"
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: vencimiento)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "vencimiento-hoy-\(factura.numeroFactura)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelarRecordatorios(para factura: Factura) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "vencimiento-3d-\(factura.numeroFactura)",
            "vencimiento-hoy-\(factura.numeroFactura)"
        ])
    }

    // MARK: - Background task

    nonisolated static func registrarTareaBackground() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let bgTask = task as? BGAppRefreshTask else { return }
            handleBackgroundTask(bgTask)
        }
        programarSiguienteTarea()
    }

    nonisolated static func programarSiguienteTarea() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600) // ~4 horas
        try? BGTaskScheduler.shared.submit(request)
    }

    nonisolated private static func handleBackgroundTask(_ task: BGAppRefreshTask) {
        programarSiguienteTarea()

        let workTask = Task { @MainActor in
            let container = DataConfig.container
            let context = ModelContext(container)
            FacturaVencimientoService.shared.revisarVencimientos(modelContext: context)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// MARK: - ViewModifier para revisar al abrir la app

struct RevisionVencimientosModifier: ViewModifier {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task {
                // Defer vencimiento check to not block first render
                try? await Task.sleep(for: .seconds(2))
                FacturaVencimientoService.shared.revisarVencimientos(modelContext: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    FacturaVencimientoService.shared.revisarVencimientos(modelContext: modelContext)
                }
            }
    }
}

extension View {
    func conRevisionVencimientos() -> some View {
        modifier(RevisionVencimientosModifier())
    }
}
