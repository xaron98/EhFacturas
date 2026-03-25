// FormateadoresExtendedTests.swift
// Tests exhaustivos de Formateadores: NIF, precios, euros

import XCTest
@testable import FacturaApp

final class FormateadoresExtendedTests: XCTestCase {

    // MARK: - validarNIF: all valid CIF letters

    func testValidarNIFTodosFormatos() {
        // NIF validos
        XCTAssertTrue(Formateadores.validarNIF("12345678A"))
        XCTAssertTrue(Formateadores.validarNIF("00000000T"))
        XCTAssertTrue(Formateadores.validarNIF("99999999Z"))

        // CIF with all valid first letters: A B C D E F G H J K L M N P Q R S U V W
        let letrasValidasCIF = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K",
                                 "L", "M", "N", "P", "Q", "R", "S", "U", "V", "W"]
        for letra in letrasValidasCIF {
            XCTAssertTrue(Formateadores.validarNIF("\(letra)12345678"),
                          "CIF con letra \(letra) deberia ser valido")
        }

        // CIF last character can be digit
        XCTAssertTrue(Formateadores.validarNIF("B12345670"))
        // CIF last character can be letter A-J
        XCTAssertTrue(Formateadores.validarNIF("B1234567A"))
        XCTAssertTrue(Formateadores.validarNIF("B1234567J"))

        // NIE: X, Y, Z
        XCTAssertTrue(Formateadores.validarNIF("X1234567A"))
        XCTAssertTrue(Formateadores.validarNIF("Y0000000Z"))
        XCTAssertTrue(Formateadores.validarNIF("Z9999999B"))
    }

    // MARK: - validarNIF: edge cases

    func testValidarNIFCasosLimite() {
        // Empty
        XCTAssertFalse(Formateadores.validarNIF(""))

        // Too short (8 chars)
        XCTAssertFalse(Formateadores.validarNIF("1234567A"))

        // Too long (10 chars)
        XCTAssertFalse(Formateadores.validarNIF("1234567890"))

        // All letters
        XCTAssertFalse(Formateadores.validarNIF("ABCDEFGHI"))

        // All numbers (9 digits, no letter at end)
        XCTAssertFalse(Formateadores.validarNIF("123456789"))

        // CIF with invalid first letter (I, O, T are not valid for CIF)
        XCTAssertFalse(Formateadores.validarNIF("I12345678"))
        XCTAssertFalse(Formateadores.validarNIF("O12345678"))
        XCTAssertFalse(Formateadores.validarNIF("T12345678"))

        // Only spaces
        XCTAssertFalse(Formateadores.validarNIF("         "))

        // Single character
        XCTAssertFalse(Formateadores.validarNIF("A"))
    }

    func testValidarNIFConEspaciosYMinusculas() {
        // Spaces should be trimmed
        XCTAssertTrue(Formateadores.validarNIF(" 12345678A "))
        XCTAssertTrue(Formateadores.validarNIF("  B12345678  "))

        // Lowercase should be handled (uppercased internally)
        XCTAssertTrue(Formateadores.validarNIF("12345678a"))
        XCTAssertTrue(Formateadores.validarNIF("b12345678"))
        XCTAssertTrue(Formateadores.validarNIF("x1234567a"))
    }

    // MARK: - parsearPrecio: all formats

    func testParsearPrecioFormatos() {
        XCTAssertEqual(Formateadores.parsearPrecio("3.50"), 3.50)
        XCTAssertEqual(Formateadores.parsearPrecio("3,50"), 3.50)
        XCTAssertEqual(Formateadores.parsearPrecio("3,50€"), 3.50)
        XCTAssertEqual(Formateadores.parsearPrecio("3,50 €"), 3.50)
        XCTAssertEqual(Formateadores.parsearPrecio(" 3.50 "), 3.50)
        XCTAssertEqual(Formateadores.parsearPrecio("100"), 100.0)
        XCTAssertEqual(Formateadores.parsearPrecio("0"), 0.0)
        XCTAssertEqual(Formateadores.parsearPrecio("0.00"), 0.0)
        XCTAssertEqual(Formateadores.parsearPrecio("1234.56"), 1234.56)
    }

    // MARK: - parsearPrecio: invalid inputs

    func testParsearPrecioInvalidos() {
        XCTAssertNil(Formateadores.parsearPrecio(""))
        XCTAssertNil(Formateadores.parsearPrecio("abc"))
        XCTAssertNil(Formateadores.parsearPrecio("3.50.20"))
        XCTAssertNil(Formateadores.parsearPrecio("precio"))
        XCTAssertNil(Formateadores.parsearPrecio("   "))
    }

    // MARK: - formatEuros

    func testFormatEurosPositivo() {
        let resultado = Formateadores.formatEuros(1234.50)
        // Should contain the number and euro sign
        XCTAssertTrue(resultado.contains("1234") || resultado.contains("1.234"))
        XCTAssertTrue(resultado.contains("50"))
    }

    func testFormatEurosNegativo() {
        let resultado = Formateadores.formatEuros(-50.0)
        XCTAssertTrue(resultado.contains("50"))
    }

    func testFormatEurosCero() {
        let resultado = Formateadores.formatEuros(0)
        XCTAssertTrue(resultado.contains("0"))
    }

    func testFormatEurosGrande() {
        let resultado = Formateadores.formatEuros(1000000.0)
        // Should contain 1000000 or 1.000.000
        XCTAssertTrue(resultado.contains("000"))
    }

    func testFormatEurosDecimales() {
        let resultado = Formateadores.formatEuros(99.99)
        XCTAssertTrue(resultado.contains("99"))
    }

    // MARK: - DateFormatters

    func testFechaFormatterExists() {
        let fecha = Formateadores.fecha.string(from: Date.now)
        XCTAssertFalse(fecha.isEmpty)
    }

    func testFechaCortaFormatoDDMMYYYY() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 25))!
        let resultado = Formateadores.fechaCorta.string(from: date)
        XCTAssertEqual(resultado, "25/03/2026")
    }

    // MARK: - guardarContexto

    func testGuardarContextoNoFalla() {
        let schema = Schema([Negocio.self, Cliente.self, Categoria.self,
                             Articulo.self, Factura.self, LineaFactura.self,
                             RegistroFacturacion.self, EventoSIF.self,
                             PerfilImportacion.self, FacturaRecurrente.self,
                             PlantillaFactura.self, Gasto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)

        // Should not throw
        Formateadores.guardarContexto(ctx, operacion: "test")
    }

    // MARK: - FacturaActions.extraerCantidadYTermino

    @MainActor
    func testExtraerCantidadNumero() {
        let (cantidad, termino) = FacturaActions.extraerCantidadYTermino("10 bombillas")
        XCTAssertEqual(cantidad, 10.0)
        XCTAssertEqual(termino, "bombillas")
    }

    @MainActor
    func testExtraerCantidadDecimal() {
        let (cantidad, termino) = FacturaActions.extraerCantidadYTermino("2,5 metros")
        XCTAssertEqual(cantidad, 2.5)
        XCTAssertEqual(termino, "metros")
    }

    @MainActor
    func testExtraerCantidadPalabraTexto() {
        let (cantidad, termino) = FacturaActions.extraerCantidadYTermino("tres bombillas")
        XCTAssertEqual(cantidad, 3.0)
        XCTAssertEqual(termino, "bombillas")
    }

    @MainActor
    func testExtraerCantidadSinNumero() {
        let (cantidad, termino) = FacturaActions.extraerCantidadYTermino("bombilla LED")
        XCTAssertEqual(cantidad, 1.0)
        XCTAssertEqual(termino, "bombilla LED")
    }

    @MainActor
    func testExtraerCantidadMedia() {
        let (cantidad, termino) = FacturaActions.extraerCantidadYTermino("media hora")
        XCTAssertEqual(cantidad, 0.5)
        XCTAssertEqual(termino, "hora")
    }

    @MainActor
    func testExtraerCantidadUna() {
        let (cantidad, termino) = FacturaActions.extraerCantidadYTermino("una bombilla")
        XCTAssertEqual(cantidad, 1.0)
        XCTAssertEqual(termino, "bombilla")
    }

    // MARK: - FacturaActions.buscarArticulos fuzzy search

    @MainActor
    func testBuscarArticulosPluralSingular() {
        let articulo = Articulo(nombre: "Bombilla LED E27", precioUnitario: 3.50)
        let resultados = FacturaActions.buscarArticulos(termino: "bombillas", en: [articulo])
        XCTAssertFalse(resultados.isEmpty, "Deberia encontrar 'Bombilla' buscando 'bombillas'")
        XCTAssertEqual(resultados.first?.0.nombre, "Bombilla LED E27")
    }

    @MainActor
    func testBuscarArticulosExacto() {
        let articulo = Articulo(nombre: "Cable 2.5mm", precioUnitario: 1.20)
        let resultados = FacturaActions.buscarArticulos(termino: "cable 2.5mm", en: [articulo])
        XCTAssertFalse(resultados.isEmpty)
        XCTAssertEqual(resultados.first?.0.nombre, "Cable 2.5mm")
    }

    @MainActor
    func testBuscarArticulosPorEtiqueta() {
        let articulo = Articulo(nombre: "Cable flexible", precioUnitario: 1.20, etiquetas: ["electrico", "cobre"])
        let resultados = FacturaActions.buscarArticulos(termino: "electrico", en: [articulo])
        XCTAssertFalse(resultados.isEmpty)
    }

    @MainActor
    func testBuscarArticulosSinResultados() {
        let articulo = Articulo(nombre: "Bombilla LED", precioUnitario: 3.50)
        let resultados = FacturaActions.buscarArticulos(termino: "fontaneria tuberia", en: [articulo])
        XCTAssertTrue(resultados.isEmpty)
    }

    @MainActor
    func testBuscarArticulosPorReferencia() {
        let articulo = Articulo(referencia: "REF-001", nombre: "Interruptor", precioUnitario: 5.0)
        let resultados = FacturaActions.buscarArticulos(termino: "REF-001", en: [articulo])
        XCTAssertFalse(resultados.isEmpty)
    }
}
