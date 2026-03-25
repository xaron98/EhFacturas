import XCTest
import SwiftData
@testable import FacturaApp

final class GastosTests: XCTestCase {
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

    func testRegistrarGasto() {
        let result = FacturaActions.registrarGasto(
            RegistrarGastoParams(concepto: "Material electrico", importe: 150.0, categoria: "material", proveedor: "Saltoki"),
            modelContext: modelContext
        )
        XCTAssertTrue(result.contains("150"))
        XCTAssertTrue(result.contains("Material electrico"))
    }

    func testGastoConCategoria() {
        let gasto = Gasto(concepto: "Gasolina", importe: 50.0, categoria: "vehiculo")
        modelContext.insert(gasto)
        XCTAssertEqual(gasto.categoria, "vehiculo")
        XCTAssertEqual(gasto.importe, 50.0)
    }

    func testGastoSinCategoria() {
        let gasto = Gasto(concepto: "Varios", importe: 20.0)
        XCTAssertEqual(gasto.categoria, "otros")
    }
}
