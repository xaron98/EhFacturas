// CSVParserTests.swift
// Tests del parser CSV: separadores, encodings, comillas, multilínea

import XCTest
@testable import FacturaApp

final class CSVParserTests: XCTestCase {

    // MARK: - Separador automático

    func testDetectaSeparadorPuntoComa() {
        let csv = "nombre;precio;ref\nBombilla;3.50;REF001"
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertNotNil(resultado)
        XCTAssertEqual(resultado?.separador, ";")
        XCTAssertEqual(resultado?.cabeceras.count, 3)
    }

    func testDetectaSeparadorComa() {
        let csv = "nombre,precio,ref\nBombilla,3.50,REF001"
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.separador, ",")
    }

    func testDetectaSeparadorTab() {
        let csv = "nombre\tprecio\tref\nBombilla\t3.50\tREF001"
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.separador, "\t")
    }

    // MARK: - Parsing básico

    func testParseaFilasCorrectamente() {
        let csv = "nombre;precio\nBombilla LED;3.50\nCable 2.5mm;1.20\nInterruptor;5.00"
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.filas.count, 3)
        XCTAssertEqual(resultado?.filas[0][0], "Bombilla LED")
        XCTAssertEqual(resultado?.filas[0][1], "3.50")
    }

    func testIgnoraLineasVacias() {
        let csv = "nombre;precio\n\nBombilla;3.50\n\n\nCable;1.20\n"
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.filas.count, 2)
    }

    // MARK: - Comillas

    func testCamposEntrecomillados() {
        let csv = "nombre;precio\n\"Bombilla LED E27\";3.50"
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.filas[0][0], "Bombilla LED E27")
    }

    func testComillasEscapadas() {
        let csv = "nombre;desc\n\"Bombilla \"\"LED\"\" 10W\";buena"
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.filas[0][0], "Bombilla \"LED\" 10W")
    }

    func testSeparadorDentroDeComillas() {
        let csv = "nombre;direccion\nJuan;\"Calle Mayor; 15\""
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.filas[0][1], "Calle Mayor; 15")
    }

    // MARK: - Multilínea

    func testCampoMultilinea() {
        let csv = "nombre;notas\nBombilla;\"Nota con\nsalto de linea\""
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.filas.count, 1)
        XCTAssertTrue(resultado?.filas[0][1].contains("\n") ?? false)
    }

    // MARK: - Encodings

    func testEncodingUTF8() {
        let csv = "nombre;precio\nBombilla LED España;3,50"
        let data = csv.data(using: .utf8)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertEqual(resultado?.encoding, "utf8")
        XCTAssertEqual(resultado?.filas[0][0], "Bombilla LED España")
    }

    func testEncodingLatin1() {
        let csv = "nombre;precio\nBombilla LED Espa\u{00F1}a;3,50"
        let data = csv.data(using: .isoLatin1)!
        let resultado = CSVParser.parsear(data: data)

        XCTAssertNotNil(resultado)
        XCTAssertTrue(resultado?.filas[0][0].contains("a") ?? false)
    }

    // MARK: - Edge cases

    func testCSVVacioDevuelveNil() {
        let data = "".data(using: .utf8)!
        XCTAssertNil(CSVParser.parsear(data: data))
    }

    func testCSVSoloCabeceraDevuelveNil() {
        let data = "nombre;precio".data(using: .utf8)!
        XCTAssertNil(CSVParser.parsear(data: data))
    }

    func testCSVUnaColumnaDevuelveNil() {
        let data = "nombre\nBombilla".data(using: .utf8)!
        XCTAssertNil(CSVParser.parsear(data: data))
    }
}
