// APIKeyManager.swift
// FacturaApp — Backend proxy for AI API calls
// The proxy holds Claude/OpenAI API keys. App authenticates via StoreKit receipt.

import Foundation

@MainActor
final class APIKeyManager: ObservableObject {

    static var shared = APIKeyManager()

    @Published var isAuthenticated = false
    @Published var error: String?

    private var sessionToken: String?
    private let proxyBaseURL = "https://facturaapp-proxy.workers.dev"

    private init() {}

    // MARK: - Authenticate with StoreKit receipt

    func authenticate(receiptData: Data) async {
        let url = URL(string: "\(proxyBaseURL)/auth")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "receipt": receiptData.base64EncodedString(),
            "bundleId": Bundle.main.bundleIdentifier ?? "es.facturaapp.FacturaApp"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            if httpResponse?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                sessionToken = token
                isAuthenticated = true
                error = nil
            } else {
                isAuthenticated = false
                error = "Error de autenticación con el servidor"
            }
        } catch {
            isAuthenticated = false
            self.error = "Error de conexión: \(error.localizedDescription)"
        }
    }

    // MARK: - Send AI request via proxy

    func sendRequest(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let token = sessionToken else {
            throw APIError.notAuthenticated
        }

        let url = URL(string: "\(proxyBaseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse

        guard httpResponse?.statusCode == 200 else {
            if httpResponse?.statusCode == 401 {
                isAuthenticated = false
                sessionToken = nil
                throw APIError.tokenExpired
            }
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse?.statusCode ?? 0, errorText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        return json
    }

    // MARK: - Development mode (direct API key, no proxy)

    /// For development/testing: use a direct API key instead of proxy
    private var directAPIKey: String?

    func setDirectAPIKey(_ key: String) {
        directAPIKey = key
        isAuthenticated = true
    }

    func sendDirectRequest(url: URL, headers: [String: String], body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse

        guard httpResponse?.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(httpResponse?.statusCode ?? 0, errorText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        return json
    }

    var hasDirectKey: Bool { directAPIKey != nil }
    var currentDirectKey: String? { directAPIKey }

    func clearDirectAPIKey() {
        directAPIKey = nil
        if sessionToken == nil {
            isAuthenticated = false
        }
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case notAuthenticated
        case tokenExpired
        case serverError(Int, String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "No autenticado. Inicia sesión con tu suscripción."
            case .tokenExpired: return "Sesión expirada. Vuelve a autenticarte."
            case .serverError(let code, let msg): return "Error del servidor (\(code)): \(msg)"
            case .invalidResponse: return "Respuesta no válida del servidor."
            }
        }
    }
}
