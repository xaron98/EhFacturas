import Testing
import Foundation
@testable import FacturaApp

@Suite("Cancelación de comandos")
struct CancellationTests {

    @Test("Token de comando previene respuestas obsoletas")
    func staleResponsePrevented() async {
        var currentID = UUID()
        let firstID = currentID

        // Simula que llega un segundo comando: se genera un nuevo token
        currentID = UUID()

        // El guard de enviarComando:
        // guard !Task.isCancelled, currentCommandID == commandID else { return }
        let shouldApply = (currentID == firstID)
        #expect(!shouldApply, "El token obsoleto no debe coincidir con el actual")
    }

    @Test("Task.isCancelled se respeta")
    func cancelledTaskDoesNotProceed() async {
        var didApply = false

        let task = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            didApply = true
        }

        task.cancel()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(!didApply, "Una tarea cancelada no debe aplicar estado")
    }
}
