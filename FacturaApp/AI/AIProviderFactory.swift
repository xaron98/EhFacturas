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

    static func makeProvider(modelContext: ModelContext, mode: Mode) -> any AIProvider {
        // 1. Try Apple Intelligence (free, preferred)
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch mode {
            case .command:
                let apple = AppleAIProvider(modelContext: modelContext)
                if apple.isAvailable { return apple }
            case .edit(let factura, let onUpdate):
                let apple = AppleAIProvider(modelContext: modelContext, factura: factura, onUpdate: onUpdate)
                if apple.isAvailable { return apple }
            }
        }
        #endif

        // 2. Cloud provider (requires subscription or dev mode)
        let isAuthed = APIKeyManager.shared.isAuthenticated
        let isSubscribed = SubscriptionManager.shared.isProSubscriber
        let hasDevKey = APIKeyManager.shared.hasDirectKey

        if isAuthed || isSubscribed || hasDevKey {
            // Get preferred provider from Negocio
            let preferredProvider = getPreferredProvider(modelContext: modelContext)

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

    private static func getPreferredProvider(modelContext: ModelContext) -> String {
        let desc = FetchDescriptor<Negocio>()
        return (try? modelContext.fetch(desc))?.first?.cloudProvider ?? "claude"
    }
}
