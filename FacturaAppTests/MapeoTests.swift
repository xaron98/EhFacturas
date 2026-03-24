// MapeoTests.swift
// Tests del mapeo universal: detección programa, sinónimos, mapeo automático

import XCTest
@testable import FacturaApp

final class MapeoTests: XCTestCase {

    // MARK: - Detección de programa

    func testDetectaSalfon() {
        let cabeceras = ["ref. saltoki", "descripcion corta", "pvp neto", "familia saltoki"]
        let programa = DetectorOrigen.detectar(cabeceras: cabeceras)

        XCTAssertEqual(programa.nombre, "Salfon")
        XCTAssertGreaterThan(programa.confianza, 0.5)
    }

    func testDetectaContaplus() {
        let cabeceras = ["nombre_cuenta", "nif_cuenta", "cod_producto", "precio_venta_iva"]
        let programa = DetectorOrigen.detectar(cabeceras: cabeceras)

        XCTAssertEqual(programa.nombre, "Contaplus")
        XCTAssertGreaterThan(programa.confianza, 0.5)
    }

    func testDetectaHolded() {
        let cabeceras = ["item_name", "unit_price", "tax_rate", "sku"]
        let programa = DetectorOrigen.detectar(cabeceras: cabeceras)

        XCTAssertEqual(programa.nombre, "Holded")
        XCTAssertGreaterThan(programa.confianza, 0.5)
    }

    func testGenericoCuandoNoReconoce() {
        let cabeceras = ["columna_x", "columna_y", "columna_z"]
        let programa = DetectorOrigen.detectar(cabeceras: cabeceras)

        XCTAssertEqual(programa.nombre, "Genérico")
    }

    // MARK: - Mapeo automático artículos

    func testMapeoArticulosBasico() {
        let cabeceras = ["nombre", "referencia", "precio", "proveedor"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .articulos)

        XCTAssertNotNil(mapeo.mapeo["nombre"])
        XCTAssertNotNil(mapeo.mapeo["referencia"])
        XCTAssertNotNil(mapeo.mapeo["precio"])
        XCTAssertNotNil(mapeo.mapeo["proveedor"])
        XCTAssertTrue(mapeo.tieneNombre)
    }

    func testMapeoArticulosSalfon() {
        let cabeceras = ["ref. saltoki", "descripcion corta", "pvp neto", "familia saltoki"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .articulos)

        XCTAssertNotNil(mapeo.mapeo["referencia"])
        XCTAssertNotNil(mapeo.mapeo["nombre"])
        XCTAssertNotNil(mapeo.mapeo["precio"])
        XCTAssertTrue(mapeo.tieneNombre)
    }

    func testMapeoArticulosHolded() {
        let cabeceras = ["item_name", "unit_price", "sku", "category"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .articulos)

        XCTAssertNotNil(mapeo.mapeo["nombre"])
        XCTAssertNotNil(mapeo.mapeo["precio"])
        XCTAssertNotNil(mapeo.mapeo["referencia"])
    }

    // MARK: - Mapeo automático clientes

    func testMapeoClientesBasico() {
        let cabeceras = ["nombre", "nif", "telefono", "email", "direccion"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .clientes)

        XCTAssertNotNil(mapeo.mapeo["nombre"])
        XCTAssertNotNil(mapeo.mapeo["nif"])
        XCTAssertNotNil(mapeo.mapeo["telefono"])
        XCTAssertNotNil(mapeo.mapeo["email"])
        XCTAssertNotNil(mapeo.mapeo["direccion"])
    }

    func testMapeoClientesHolded() {
        let cabeceras = ["company_name", "tax_id", "phone_number", "email_address", "address"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .clientes)

        XCTAssertNotNil(mapeo.mapeo["nombre"])
        XCTAssertNotNil(mapeo.mapeo["nif"])
        XCTAssertNotNil(mapeo.mapeo["telefono"])
    }

    // MARK: - No duplica columnas

    func testNoAsignaMismaColumnaDosVeces() {
        // "nombre" podría matchear tanto nombre como descripción
        let cabeceras = ["nombre", "precio"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .articulos)

        let indicesUsados = Array(mapeo.mapeo.values)
        let unicos = Set(indicesUsados)
        XCTAssertEqual(indicesUsados.count, unicos.count, "Columnas duplicadas en mapeo")
    }

    // MARK: - Acceso a valores

    func testValorExtraeCorrectamente() {
        let cabeceras = ["nombre", "precio"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .articulos)
        let fila = ["Bombilla LED", "3,50"]

        XCTAssertEqual(mapeo.valor("nombre", en: fila), "Bombilla LED")
    }

    func testValorDoubleConComa() {
        let cabeceras = ["nombre", "precio"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .articulos)
        let fila = ["Bombilla", "3,50"]

        XCTAssertEqual(mapeo.valorDouble("precio", en: fila), 3.50, accuracy: 0.01)
    }

    func testValorDoubleConEuros() {
        let cabeceras = ["nombre", "precio"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .articulos)
        let fila = ["Cable", "1,20 €"]

        XCTAssertEqual(mapeo.valorDouble("precio", en: fila), 1.20, accuracy: 0.01)
    }

    func testValorCampoNoMapeado() {
        let cabeceras = ["nombre"]
        let mapeo = MapeoUniversal.detectar(cabeceras: cabeceras, tipo: .articulos)
        let fila = ["Bombilla"]

        XCTAssertEqual(mapeo.valor("precio", en: fila), "")
        XCTAssertEqual(mapeo.valorDouble("precio", en: fila), 0.0)
    }
}
