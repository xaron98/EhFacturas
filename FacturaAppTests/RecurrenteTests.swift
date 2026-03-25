import XCTest
import SwiftData
@testable import FacturaApp

final class RecurrenteTests: XCTestCase {
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

    func testCalcularProximaFechaMensual() {
        let hoy = Date.now
        let proxima = FacturaRecurrente.calcularProximaFecha(desde: hoy, frecuencia: "mensual")
        let diff = Calendar.current.dateComponents([.month], from: hoy, to: proxima).month ?? 0
        XCTAssertEqual(diff, 1)
    }

    func testCalcularProximaFechaTrimestral() {
        let hoy = Date.now
        let proxima = FacturaRecurrente.calcularProximaFecha(desde: hoy, frecuencia: "trimestral")
        let diff = Calendar.current.dateComponents([.month], from: hoy, to: proxima).month ?? 0
        XCTAssertEqual(diff, 3)
    }

    func testCalcularProximaFechaAnual() {
        let hoy = Date.now
        let proxima = FacturaRecurrente.calcularProximaFecha(desde: hoy, frecuencia: "anual")
        let diff = Calendar.current.dateComponents([.year], from: hoy, to: proxima).year ?? 0
        XCTAssertEqual(diff, 1)
    }

    func testCrearRecurrente() {
        let result = FacturaActions.crearRecurrente(
            CrearRecurrenteParams(nombreCliente: "Juan", articulosTexto: "mantenimiento", frecuencia: "mensual", importe: 150),
            modelContext: modelContext
        )
        XCTAssertTrue(result.contains("recurrente"))
        XCTAssertTrue(result.contains("150"))
    }
}
