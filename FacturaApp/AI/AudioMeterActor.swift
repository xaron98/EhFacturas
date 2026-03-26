// AudioMeterActor.swift
// FacturaApp — Actor para medición de nivel de audio sin data races

import Foundation

/// Actor que encapsula el estado de medición de audio,
/// eliminando data races en el callback de installTap.
actor AudioMeterActor {
    private var lastUpdate: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.1  // ~10fps

    /// Devuelve true si ha pasado suficiente tiempo desde la última actualización.
    func shouldUpdate() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastUpdate) > throttleInterval else {
            return false
        }
        lastUpdate = now
        return true
    }

    func reset() {
        lastUpdate = .distantPast
    }
}
