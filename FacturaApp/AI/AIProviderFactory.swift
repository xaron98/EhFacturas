// AIProviderFactory.swift
// FacturaApp — Factory for selecting the best available AI provider

import Foundation
import SwiftData

@MainActor
enum AIProviderFactory {

    enum Mode {
        case command
        case edit(factura: Factura, onUpdate: @Sendable () -> Void)
    }

    // Cache provider choice to avoid repeated checks
    private static var cachedAppleAvailable: Bool?

    static func makeProvider(modelContext: ModelContext, mode: Mode) -> any AIProvider {
        // 1. Try Apple Intelligence (free, preferred)
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            // Cache the availability check (expensive first time)
            if cachedAppleAvailable == nil {
                let apple = AppleAIProvider(modelContext: modelContext)
                cachedAppleAvailable = apple.isAvailable
            }

            if cachedAppleAvailable == true {
                switch mode {
                case .command:
                    return AppleAIProvider(modelContext: modelContext)
                case .edit(let factura, let onUpdate):
                    return AppleAIProvider(modelContext: modelContext, factura: factura, onUpdate: onUpdate)
                }
            }
        }
        #endif

        // 2. Cloud provider (requires subscription or dev mode)
        let isAuthed = APIKeyManager.shared.isAuthenticated
        let isSubscribed = SubscriptionManager.shared.isProSubscriber
        let hasDevKey = APIKeyManager.shared.hasDirectKey

        if isAuthed || isSubscribed || hasDevKey {
            let preferredProvider = getPreferredProvider()

            switch mode {
            case .command:
                if preferredProvider == "openai" {
                    return OpenAIProvider(modelContext: modelContext)
                }
                return ClaudeAIProvider(modelContext: modelContext)
            case .edit(let factura, let onUpdate):
                if preferredProvider == "openai" {
                    return OpenAIProvider(modelContext: modelContext, factura: factura, onUpdate: onUpdate)
                }
                return ClaudeAIProvider(modelContext: modelContext, factura: factura, onUpdate: onUpdate)
            }
        }

        // 3. No AI available
        return UnavailableAIProvider()
    }

    // Read from UserDefaults (instant) instead of SwiftData fetch
    private static func getPreferredProvider() -> String {
        UserDefaults.standard.string(forKey: "cloudProvider") ?? "claude"
    }
}
