import XCTest
import SwiftData
@testable import FacturaApp

final class DeshacerTests: XCTestCase {
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
        FacturaActions.ultimaAccion = nil
    }

    func testDeshacerSinAccion() {
        let result = FacturaActions.deshacerUltimaAccion(modelContext: modelContext)
        XCTAssertTrue(result.contains("No hay"))
    }

    func testDeshacerCliente() {
        // Create a client first
        let _ = FacturaActions.crearCliente(
            CrearClienteParams(nombre: "Test Cliente", nif: "", telefono: "", email: "", direccion: "", ciudad: ""),
            modelContext: modelContext
        )
        XCTAssertNotNil(FacturaActions.ultimaAccion)
        XCTAssertEqual(FacturaActions.ultimaAccion?.tipo, "crear_cliente")

        // Undo
        let result = FacturaActions.deshacerUltimaAccion(modelContext: modelContext)
        XCTAssertTrue(result.contains("Deshecho") || result.contains("desactivado"))
        XCTAssertNil(FacturaActions.ultimaAccion)
    }

    func testDeshacerArticulo() {
        let _ = FacturaActions.crearArticulo(
            CrearArticuloParams(nombre: "Test Art", precioUnitario: 10, referencia: "", unidad: "ud", proveedor: "", precioCoste: 0, etiquetas: ""),
            modelContext: modelContext
        )
        XCTAssertEqual(FacturaActions.ultimaAccion?.tipo, "crear_articulo")

        let result = FacturaActions.deshacerUltimaAccion(modelContext: modelContext)
        XCTAssertTrue(result.contains("Deshecho") || result.contains("desactivado"))
    }
}
