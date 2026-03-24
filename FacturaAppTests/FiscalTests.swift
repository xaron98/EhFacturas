// FiscalTests.swift
// Tests de cálculos fiscales: IVA, IRPF, descuentos, totales

import XCTest
import SwiftData
@testable import FacturaApp

final class FiscalTests: XCTestCase {

    var modelContext: ModelContext!

    override func setUp() {
        let schema = Schema([Negocio.self, Cliente.self, Categoria.self,
                             Articulo.self, Factura.self, LineaFactura.self,
                             RegistroFacturacion.self, EventoSIF.self, PerfilImportacion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(container)
    }

    // MARK: - recalcularTotales

    func testFacturaUnaLineaIVA21() {
        let factura = Factura(numeroFactura: "FAC-0001")
        let linea = LineaFactura(orden: 0, concepto: "Bombilla LED", cantidad: 10, precioUnitario: 5.0, porcentajeIVA: 21)
        factura.lineas.append(linea)

        factura.recalcularTotales()

        XCTAssertEqual(factura.baseImponible, 50.0, accuracy: 0.01)
        XCTAssertEqual(factura.totalIVA, 10.5, accuracy: 0.01)
        XCTAssertEqual(factura.totalIRPF, 0.0, accuracy: 0.01)
        XCTAssertEqual(factura.totalFactura, 60.5, accuracy: 0.01)
    }

    func testFacturaMultiplesIVA() {
        let factura = Factura(numeroFactura: "FAC-0002")
        let linea1 = LineaFactura(orden: 0, concepto: "Material", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        let linea2 = LineaFactura(orden: 1, concepto: "Servicio", cantidad: 1, precioUnitario: 200.0, porcentajeIVA: 10)
        factura.lineas.append(linea1)
        factura.lineas.append(linea2)

        factura.recalcularTotales()

        XCTAssertEqual(factura.baseImponible, 300.0, accuracy: 0.01)
        // IVA: 100*0.21 + 200*0.10 = 21 + 20 = 41
        XCTAssertEqual(factura.totalIVA, 41.0, accuracy: 0.01)
        XCTAssertEqual(factura.totalFactura, 341.0, accuracy: 0.01)
    }

    func testFacturaConIRPF15() {
        let factura = Factura(numeroFactura: "FAC-0003")
        let linea = LineaFactura(orden: 0, concepto: "Servicio", cantidad: 1, precioUnitario: 1000.0, porcentajeIVA: 21)
        factura.lineas.append(linea)

        factura.recalcularTotales(irpfPorcentaje: 15.0, aplicarIRPF: true)

        XCTAssertEqual(factura.baseImponible, 1000.0, accuracy: 0.01)
        XCTAssertEqual(factura.totalIVA, 210.0, accuracy: 0.01)
        XCTAssertEqual(factura.totalIRPF, 150.0, accuracy: 0.01)
        // Total = 1000 + 210 - 150 = 1060
        XCTAssertEqual(factura.totalFactura, 1060.0, accuracy: 0.01)
    }

    func testFacturaConIRPF7NuevoAutonomo() {
        let factura = Factura(numeroFactura: "FAC-0004")
        let linea = LineaFactura(orden: 0, concepto: "Servicio", cantidad: 1, precioUnitario: 500.0, porcentajeIVA: 21)
        factura.lineas.append(linea)

        factura.recalcularTotales(irpfPorcentaje: 7.0, aplicarIRPF: true)

        XCTAssertEqual(factura.totalIRPF, 35.0, accuracy: 0.01)
        // Total = 500 + 105 - 35 = 570
        XCTAssertEqual(factura.totalFactura, 570.0, accuracy: 0.01)
    }

    func testFacturaConDescuentoGlobal() {
        let factura = Factura(numeroFactura: "FAC-0005", descuentoGlobalPorcentaje: 10)
        let linea = LineaFactura(orden: 0, concepto: "Material", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        factura.lineas.append(linea)

        factura.recalcularTotales()

        // Base: 100 - 10% = 90
        XCTAssertEqual(factura.baseImponible, 90.0, accuracy: 0.01)
        // IVA: 90 * 0.21 = 18.9
        XCTAssertEqual(factura.totalIVA, 18.9, accuracy: 0.01)
        XCTAssertEqual(factura.totalFactura, 108.9, accuracy: 0.01)
    }

    func testFacturaConDescuentoPorLinea() {
        let factura = Factura(numeroFactura: "FAC-0006")
        let linea = LineaFactura(orden: 0, concepto: "Material", cantidad: 10, precioUnitario: 20.0, descuentoPorcentaje: 25, porcentajeIVA: 21)
        factura.lineas.append(linea)

        factura.recalcularTotales()

        // Subtotal línea: 10 * 20 * (1 - 0.25) = 150
        XCTAssertEqual(linea.subtotal, 150.0, accuracy: 0.01)
        XCTAssertEqual(factura.baseImponible, 150.0, accuracy: 0.01)
    }

    func testFacturaSinLineas() {
        let factura = Factura(numeroFactura: "FAC-0007")
        factura.recalcularTotales()

        XCTAssertEqual(factura.baseImponible, 0.0)
        XCTAssertEqual(factura.totalIVA, 0.0)
        XCTAssertEqual(factura.totalFactura, 0.0)
    }

    func testFacturaIVAExento() {
        let factura = Factura(numeroFactura: "FAC-0008")
        let linea = LineaFactura(orden: 0, concepto: "Formación", cantidad: 1, precioUnitario: 500.0, porcentajeIVA: 0)
        factura.lineas.append(linea)

        factura.recalcularTotales()

        XCTAssertEqual(factura.totalIVA, 0.0)
        XCTAssertEqual(factura.totalFactura, 500.0, accuracy: 0.01)
    }

    func testFacturaIVASuperReducido() {
        let factura = Factura(numeroFactura: "FAC-0009")
        let linea = LineaFactura(orden: 0, concepto: "Pan", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 4)
        factura.lineas.append(linea)

        factura.recalcularTotales()

        XCTAssertEqual(factura.totalIVA, 4.0, accuracy: 0.01)
        XCTAssertEqual(factura.totalFactura, 104.0, accuracy: 0.01)
    }

    // MARK: - Desglose IVA

    func testDesgloseIVAMultiple() {
        let factura = Factura(numeroFactura: "FAC-0010")
        let linea1 = LineaFactura(orden: 0, concepto: "Material", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        let linea2 = LineaFactura(orden: 1, concepto: "Servicio", cantidad: 1, precioUnitario: 200.0, porcentajeIVA: 10)
        let linea3 = LineaFactura(orden: 2, concepto: "Otro material", cantidad: 1, precioUnitario: 50.0, porcentajeIVA: 21)
        factura.lineas.append(linea1)
        factura.lineas.append(linea2)
        factura.lineas.append(linea3)

        factura.recalcularTotales()

        let desglose = factura.desgloseIVA
        XCTAssertEqual(desglose.count, 2) // 21% y 10%

        let iva21 = desglose.first(where: { $0.porcentaje == 21 })
        let iva10 = desglose.first(where: { $0.porcentaje == 10 })
        XCTAssertEqual(iva21?.base ?? 0, 150.0, accuracy: 0.01)
        XCTAssertEqual(iva21?.cuota ?? 0, 31.5, accuracy: 0.01)
        XCTAssertEqual(iva10?.base ?? 0, 200.0, accuracy: 0.01)
        XCTAssertEqual(iva10?.cuota ?? 0, 20.0, accuracy: 0.01)
    }

    // MARK: - LineaFactura.recalcular

    func testLineaRecalcular() {
        let linea = LineaFactura(orden: 0, concepto: "Test", cantidad: 5, precioUnitario: 10.0, descuentoPorcentaje: 20, porcentajeIVA: 21)
        linea.recalcular()

        // 5 * 10 * (1 - 0.20) = 40
        XCTAssertEqual(linea.subtotal, 40.0, accuracy: 0.01)
    }

    func testLineaSinDescuento() {
        let linea = LineaFactura(orden: 0, concepto: "Test", cantidad: 3, precioUnitario: 7.50)
        linea.recalcular()

        XCTAssertEqual(linea.subtotal, 22.5, accuracy: 0.01)
    }

    // MARK: - Numeración

    func testGenerarNumeroFactura() {
        let negocio = Negocio(nombre: "Test")
        negocio.prefijoFactura = "FAC-"
        negocio.siguienteNumero = 1

        let num1 = negocio.generarNumeroFactura()
        let num2 = negocio.generarNumeroFactura()
        let num3 = negocio.generarNumeroFactura()

        XCTAssertEqual(num1, "FAC-0001")
        XCTAssertEqual(num2, "FAC-0002")
        XCTAssertEqual(num3, "FAC-0003")
        XCTAssertEqual(negocio.siguienteNumero, 4)
    }
}
