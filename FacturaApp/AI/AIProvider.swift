// AIProvider.swift
// FacturaApp — Abstract AI provider protocol and types

import Foundation
import SwiftData

/// Result of an AI command processing
struct AICommandResult: Sendable {
    var text: String
    var toolUsed: String?
}

/// Abstract AI provider protocol
@MainActor
protocol AIProvider {
    var isAvailable: Bool { get }
    var unavailableReason: String { get }
    func processCommand(_ text: String, systemPrompt: String) async throws -> AICommandResult
    func resetSession()
}

/// Provider type for display
enum AIProviderType: String, Sendable {
    case apple = "Apple Intelligence"
    case claude = "Claude"
    case openai = "OpenAI"
    case none = "No disponible"
}

/// Stub provider for when no AI is available
@MainActor
final class UnavailableAIProvider: AIProvider {
    let reason: String
    init(reason: String = "Suscripción Pro necesaria para usar IA en este dispositivo.") {
        self.reason = reason
    }
    var isAvailable: Bool { false }
    var unavailableReason: String { reason }
    func processCommand(_ text: String, systemPrompt: String) async throws -> AICommandResult {
        AICommandResult(text: unavailableReason)
    }
    func resetSession() {}
}
