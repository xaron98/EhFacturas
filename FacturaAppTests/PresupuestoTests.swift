import XCTest
import SwiftData
@testable import FacturaApp

final class PresupuestoTests: XCTestCase {
    var modelContext: ModelContext!
    var negocio: Negocio!

    override func setUp() {
        let schema = Schema([Negocio.self, Cliente.self, Categoria.self,
                             Articulo.self, Factura.self, LineaFactura.self,
                             RegistroFacturacion.self, EventoSIF.self,
                             PerfilImportacion.self, FacturaRecurrente.self,
                             PlantillaFactura.self, Gasto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(container)

        negocio = Negocio(nombre: "Test S.L.", nif: "B12345678")
        negocio.prefijoFactura = "PRE-"
        negocio.siguienteNumero = 1
        modelContext.insert(negocio)
    }

    func testCrearPresupuesto() {
        let result = FacturaActions.crearFactura(
            CrearFacturaParams(nombreCliente: "Juan", articulosTexto: "1 servicio", descuento: 0, observaciones: "", esPresupuesto: true),
            modelContext: modelContext
        )
        XCTAssertTrue(result.contains("Presupuesto"))
        XCTAssertTrue(result.contains("presupuesto"))
    }

    func testCrearFacturaNormal() {
        let result = FacturaActions.crearFactura(
            CrearFacturaParams(nombreCliente: "Juan", articulosTexto: "1 servicio", descuento: 0, observaciones: ""),
            modelContext: modelContext
        )
        XCTAssertTrue(result.contains("Factura"))
        XCTAssertTrue(result.contains("borrador"))
    }

    func testEstadoPresupuesto() {
        XCTAssertEqual(EstadoFactura.presupuesto.descripcion, "Presupuesto")
        XCTAssertEqual(EstadoFactura.presupuesto.color, "purple")
    }
}
