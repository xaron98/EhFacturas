// OfflineQueueService.swift
// FacturaApp — Cola de comandos offline para cloud AI

import Foundation
import Network

@MainActor
final class OfflineQueueService: ObservableObject {
    static var shared = OfflineQueueService()

    @Published var isOnline = true
    @Published var pendingCommands: [String] = []

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "es.facturaapp.network")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied

                // If we just came online, process pending commands
                if wasOffline && path.status == .satisfied {
                    self?.processPendingCommands()
                }
            }
        }
        monitor.start(queue: queue)
    }

    func enqueueCommand(_ command: String) {
        pendingCommands.append(command)
        // Save to UserDefaults for persistence
        UserDefaults.standard.set(pendingCommands, forKey: "offlineQueue")
    }

    func loadPendingCommands() {
        pendingCommands = UserDefaults.standard.stringArray(forKey: "offlineQueue") ?? []
    }

    private func processPendingCommands() {
        guard !pendingCommands.isEmpty else { return }
        // Notify that pending commands are ready
        // The actual processing is done by CommandAIService when it checks the queue
        NotificationCenter.default.post(name: .offlineCommandsReady, object: nil)
    }

    func clearProcessedCommand(_ command: String) {
        pendingCommands.removeAll { $0 == command }
        UserDefaults.standard.set(pendingCommands, forKey: "offlineQueue")
    }

    func clearAll() {
        pendingCommands = []
        UserDefaults.standard.removeObject(forKey: "offlineQueue")
    }
}

extension Notification.Name {
    static let offlineCommandsReady = Notification.Name("offlineCommandsReady")
}
