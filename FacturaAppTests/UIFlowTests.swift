import XCTest
import SwiftData
@testable import FacturaApp

final class UIFlowTests: XCTestCase {
    var modelContext: ModelContext!

    override func setUp() {
        let schema = Schema([Negocio.self, Cliente.self, Categoria.self,
                             Articulo.self, Factura.self, LineaFactura.self,
                             RegistroFacturacion.self, EventoSIF.self,
                             PerfilImportacion.self, FacturaRecurrente.self,
                             PlantillaFactura.self, Gasto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(container)
    }

    func testMensajeChatCreation() {
        let msg = MensajeChat(timestamp: .now, tipo: .usuario, texto: "Hola")
        XCTAssertEqual(msg.tipo, .usuario)
        XCTAssertEqual(msg.texto, "Hola")
        XCTAssertNil(msg.facturaID)
    }

    func testMensajeChatFacturaType() {
        let msg = MensajeChat(timestamp: .now, tipo: .factura, texto: "Factura creada", facturaID: nil)
        XCTAssertEqual(msg.tipo, .factura)
    }

    func testComandoResultadoAcciones() {
        let resultado = ComandoResultado(mensaje: "Cliente creado", accionRealizada: .clienteCreado)
        XCTAssertNil(resultado.facturaID)
        XCTAssertEqual(resultado.accionRealizada, .clienteCreado)
    }

    @MainActor
    func testEstadoDetallado() {
        // Test the status detection logic
        let service = CommandAIService(modelContext: modelContext)
        // Verify estadoDetallado property exists and has default
        XCTAssertEqual(service.estadoDetallado, "Pensando...")
    }

    func testFacturacionStoreCreation() async {
        // Test that the store can be created with an in-memory container
        let schema = Schema([Negocio.self, Cliente.self, Categoria.self,
                             Articulo.self, Factura.self, LineaFactura.self,
                             RegistroFacturacion.self, EventoSIF.self,
                             PerfilImportacion.self, FacturaRecurrente.self,
                             PlantillaFactura.self, Gasto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let store = FacturacionStore(container: container)

        // Test creating a client through the store
        let result = await store.crearCliente(CrearClienteParams(
            nombre: "Test", nif: "", telefono: "", email: "", direccion: "", ciudad: ""
        ))
        XCTAssertTrue(result.contains("Test"))
    }
}
