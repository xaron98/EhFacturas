// OpenAIProvider.swift
// FacturaApp — OpenAI Chat Completions API provider via backend proxy

import Foundation
import SwiftData

@MainActor
final class OpenAIProvider: AIProvider {
    private let modelContext: ModelContext
    private let factura: Factura?
    private let onUpdate: (@Sendable () -> Void)?
    private var conversationHistory: [[String: Any]] = []
    let providerType: AIProviderType = .openai

    var isAvailable: Bool { APIKeyManager.shared.isAuthenticated }
    var unavailableReason: String { "Configura la suscripción Pro en Ajustes." }

    init(modelContext: ModelContext, factura: Factura? = nil, onUpdate: (@Sendable () -> Void)? = nil) {
        self.modelContext = modelContext
        self.factura = factura
        self.onUpdate = onUpdate
    }

    func processCommand(_ text: String, systemPrompt: String) async throws -> AICommandResult {
        // 1. Add system prompt as first message if history is empty
        if conversationHistory.isEmpty {
            conversationHistory.append(["role": "system", "content": systemPrompt])
        }

        // 2. Add user message to history
        conversationHistory.append(["role": "user", "content": text])

        // 3. Build request body
        let toolMode: CloudToolSchemas.ToolMode = factura != nil ? .edit : .command
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": conversationHistory,
            "tools": CloudToolSchemas.openAITools(mode: toolMode)
        ]

        // 4. Call backend proxy
        let responseData = try await APIKeyManager.shared.sendRequest(
            endpoint: "/openai",
            body: body
        )

        // 5. Parse response -- handle tool_calls loop (max 3 iterations)
        var currentResponse = responseData
        for _ in 0..<3 {
            guard let choices = currentResponse["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any] else {
                break
            }

            // Check for tool_calls
            if let toolCalls = message["tool_calls"] as? [[String: Any]],
               let toolCall = toolCalls.first,
               let function = toolCall["function"] as? [String: Any] {
                let toolName = function["name"] as? String ?? ""
                let toolCallId = toolCall["id"] as? String ?? ""

                // Parse arguments from JSON string
                var toolArguments: [String: Any] = [:]
                if let argumentsString = function["arguments"] as? String,
                   let argumentsData = argumentsString.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] {
                    toolArguments = parsed
                }

                // Execute tool (command tools run on FacturacionStore actor, edit tools on MainActor)
                let toolResult = await CloudToolSchemas.executeTool(
                    name: toolName,
                    arguments: toolArguments,
                    modelContext: modelContext,
                    factura: factura,
                    onUpdate: onUpdate
                )

                // Add assistant message with tool_calls to history
                conversationHistory.append(message)

                // Add tool result to history
                conversationHistory.append([
                    "role": "tool",
                    "tool_call_id": toolCallId,
                    "content": toolResult
                ])

                // Send tool result back for continuation
                let followUpBody: [String: Any] = [
                    "model": "gpt-4o-mini",
                    "messages": conversationHistory,
                    "tools": CloudToolSchemas.openAITools(mode: toolMode)
                ]
                currentResponse = try await APIKeyManager.shared.sendRequest(
                    endpoint: "/openai",
                    body: followUpBody
                )
                continue
            }

            // No tool_calls -- extract text response
            if let responseText = message["content"] as? String {
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
