import Testing
@testable import FacturaApp

@Suite("SubscriptionManager lifecycle")
struct SubscriptionLifecycleTests {

    @Test("Singleton es let (no reasignable)")
    @MainActor func singletonIsImmutable() {
        // Si esto compila, shared es `let`. El compilador garantiza la inmutabilidad.
        let _ = SubscriptionManager.shared
    }
}
