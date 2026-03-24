// FormateadoresTests.swift
// Tests de utilidades: NIF validator, precio parser, formateo euros

import XCTest
@testable import FacturaApp

final class FormateadoresTests: XCTestCase {

    // MARK: - Validar NIF

    func testNIFValido() {
        XCTAssertTrue(Formateadores.validarNIF("12345678A"))
        XCTAssertTrue(Formateadores.validarNIF("00000000T"))
        XCTAssertTrue(Formateadores.validarNIF("99999999Z"))
    }

    func testCIFValido() {
        XCTAssertTrue(Formateadores.validarNIF("B12345678"))
        XCTAssertTrue(Formateadores.validarNIF("A00000001"))
        XCTAssertTrue(Formateadores.validarNIF("H12345670"))
    }

    func testNIEValido() {
        XCTAssertTrue(Formateadores.validarNIF("X1234567A"))
        XCTAssertTrue(Formateadores.validarNIF("Y0000000Z"))
        XCTAssertTrue(Formateadores.validarNIF("Z9999999B"))
    }

    func testNIFInvalido() {
        XCTAssertFalse(Formateadores.validarNIF(""))
        XCTAssertFalse(Formateadores.validarNIF("123"))
        XCTAssertFalse(Formateadores.validarNIF("ABCDEFGHI"))
        XCTAssertFalse(Formateadores.validarNIF("1234567890")) // 10 chars
        XCTAssertFalse(Formateadores.validarNIF("1234567"))    // 7 chars
    }

    func testNIFConEspacios() {
        XCTAssertTrue(Formateadores.validarNIF(" 12345678A "))
        XCTAssertTrue(Formateadores.validarNIF("  B12345678  "))
    }

    func testNIFMinusculas() {
        XCTAssertTrue(Formateadores.validarNIF("12345678a"))
        XCTAssertTrue(Formateadores.validarNIF("b12345678"))
    }

    // MARK: - Parsear precio

    func testParsearPrecioConPunto() {
        XCTAssertEqual(Formateadores.parsearPrecio("3.50"), 3.50)
    }

    func testParsearPrecioConComa() {
        XCTAssertEqual(Formateadores.parsearPrecio("3,50"), 3.50)
    }

    func testParsearPrecioConEuros() {
        XCTAssertEqual(Formateadores.parsearPrecio("3,50€"), 3.50)
    }

    func testParsearPrecioConEspacios() {
        XCTAssertEqual(Formateadores.parsearPrecio(" 3.50 "), 3.50)
    }

    func testParsearPrecioEntero() {
        XCTAssertEqual(Formateadores.parsearPrecio("100"), 100.0)
    }

    func testParsearPrecioInvalido() {
        XCTAssertNil(Formateadores.parsearPrecio("abc"))
        XCTAssertNil(Formateadores.parsearPrecio(""))
    }

    // MARK: - Formato euros

    func testFormatEuros() {
        let resultado = Formateadores.formatEuros(1234.50)
        XCTAssertTrue(resultado.contains("1234") || resultado.contains("1.234"))
        XCTAssertTrue(resultado.contains("50"))
    }

    func testFormatEurosCero() {
        let resultado = Formateadores.formatEuros(0)
        XCTAssertTrue(resultado.contains("0"))
    }

    // MARK: - UnidadMedida

    func testUnidadMedidaAbreviatura() {
        XCTAssertEqual(UnidadMedida.unidad.abreviatura, "ud")
        XCTAssertEqual(UnidadMedida.metro.abreviatura, "m")
        XCTAssertEqual(UnidadMedida.hora.abreviatura, "h")
        XCTAssertEqual(UnidadMedida.kilogramo.abreviatura, "kg")
        XCTAssertEqual(UnidadMedida.servicio.abreviatura, "servicio")
    }

    func testUnidadMedidaDesdeAbreviatura() {
        XCTAssertEqual(UnidadMedida(abreviatura: "ud"), .unidad)
        XCTAssertEqual(UnidadMedida(abreviatura: "m"), .metro)
        XCTAssertEqual(UnidadMedida(abreviatura: "h"), .hora)
        XCTAssertNil(UnidadMedida(abreviatura: "xyz"))
    }

    // MARK: - TipoIVA

    func testTipoIVAPorcentajes() {
        XCTAssertEqual(TipoIVA.general.porcentaje, 21.0)
        XCTAssertEqual(TipoIVA.reducido.porcentaje, 10.0)
        XCTAssertEqual(TipoIVA.superReducido.porcentaje, 4.0)
        XCTAssertEqual(TipoIVA.exento.porcentaje, 0.0)
    }
}
