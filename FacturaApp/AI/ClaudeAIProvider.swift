// ClaudeAIProvider.swift
// FacturaApp — Anthropic Claude API provider via backend proxy

import Foundation
import SwiftData

@MainActor
final class ClaudeAIProvider: AIProvider {
    private let modelContext: ModelContext
    private let factura: Factura?
    private let onUpdate: (@Sendable () -> Void)?
    private var conversationHistory: [[String: Any]] = []
    let providerType: AIProviderType = .claude

    var isAvailable: Bool { APIKeyManager.shared.isAuthenticated }
    var unavailableReason: String { "Configura la suscripción Pro en Ajustes." }

    init(modelContext: ModelContext, factura: Factura? = nil, onUpdate: (@Sendable () -> Void)? = nil) {
        self.modelContext = modelContext
        self.factura = factura
        self.onUpdate = onUpdate
    }

    func processCommand(_ text: String, systemPrompt: String) async throws -> AICommandResult {
        // 1. Add user message to history
        conversationHistory.append(["role": "user", "content": text])

        // 2. Build request body
        let toolMode: CloudToolSchemas.ToolMode = factura != nil ? .edit : .command
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "system": systemPrompt,
            "tools": CloudToolSchemas.claudeTools(mode: toolMode),
            "messages": conversationHistory
        ]

        // 3. Call backend proxy
        let responseData = try await APIKeyManager.shared.sendRequest(
            endpoint: "/claude",
            body: body
        )

        // 4. Parse response -- handle tool_use loop (max 3 iterations)
        var currentResponse = responseData
        for _ in 0..<3 {
            guard let content = currentResponse["content"] as? [[String: Any]] else { break }

            // Check for tool_use blocks
            if let toolUse = content.first(where: { ($0["type"] as? String) == "tool_use" }) {
                let toolName = toolUse["name"] as? String ?? ""
                let toolInput = toolUse["input"] as? [String: Any] ?? [:]
                let toolUseId = toolUse["id"] as? String ?? ""

                // Execute tool on MainActor
                let toolResult = CloudToolSchemas.executeTool(
                    name: toolName,
                    arguments: toolInput,
                    modelContext: modelContext,
                    factura: factura,
                    onUpdate: onUpdate
                )

                // Add assistant response + tool result to conversation history
                conversationHistory.append(["role": "assistant", "content": content])
                conversationHistory.append([
                    "role": "user",
                    "content": [
                        ["type": "tool_result", "tool_use_id": toolUseId, "content": toolResult]
                    ] as [[String: Any]]
                ])

                // Send tool result back for continuation
                let followUpBody: [String: Any] = [
                    "model": "claude-haiku-4-5-20251001",
                    "max_tokens": 1024,
                    "system": systemPrompt,
                    "tools": CloudToolSchemas.claudeTools(mode: toolMode),
                    "messages": conversationHistory
                ]
                currentResponse = try await APIKeyManager.shared.sendRequest(
                    endpoint: "/claude",
                    body: followUpBody
                )
                continue
            }

            // No tool_use -- extract text response
            if let textBlock = content.first(where: { ($0["type"] as? String) == "text" }),
               let responseText = textBlock["text"] as? String {
                conversationHistory.append(["role": "assistant", "content": responseText])
                return AICommandResult(text: responseText)
            }

            break
        }

        return AICommandResult(text: "No se pudo procesar el comando.")
    }

    func resetSession() {
        conversationHistory = []
    }
}
