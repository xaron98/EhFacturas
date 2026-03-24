// VeriFactuTests.swift
// Tests de VeriFactu: hash chain SHA-256, emisión, anulación, rectificativa

import XCTest
import SwiftData
@testable import FacturaApp

final class VeriFactuTests: XCTestCase {

    var modelContext: ModelContext!
    var negocio: Negocio!

    override func setUp() {
        let schema = Schema([Negocio.self, Cliente.self, Categoria.self,
                             Articulo.self, Factura.self, LineaFactura.self,
                             RegistroFacturacion.self, EventoSIF.self, PerfilImportacion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(container)

        negocio = Negocio(nombre: "Test S.L.", nif: "B12345678")
        modelContext.insert(negocio)
    }

    // MARK: - Hash calculation

    func testHashNoEstaVacio() {
        let factura = crearFacturaTest()
        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        XCTAssertFalse(registro.hashRegistro.isEmpty)
        XCTAssertEqual(registro.hashRegistro.count, 64) // SHA-256 hex = 64 chars
    }

    func testHashEsDeterminista() {
        let factura = crearFacturaTest()
        let registro = RegistroFacturacion(
            tipoRegistro: .alta, factura: factura,
            nifEmisor: negocio.nif, hashAnterior: ""
        )

        let hash1 = VeriFactuHashService.calcularHash(registro: registro)
        let hash2 = VeriFactuHashService.calcularHash(registro: registro)

        XCTAssertEqual(hash1, hash2)
    }

    func testHashCambiaSiDatosCambian() {
        let factura1 = crearFacturaTest(numero: "FAC-0001")
        let factura2 = crearFacturaTest(numero: "FAC-0002")

        let reg1 = RegistroFacturacion(tipoRegistro: .alta, factura: factura1, nifEmisor: negocio.nif, hashAnterior: "")
        let reg2 = RegistroFacturacion(tipoRegistro: .alta, factura: factura2, nifEmisor: negocio.nif, hashAnterior: "")

        let hash1 = VeriFactuHashService.calcularHash(registro: reg1)
        let hash2 = VeriFactuHashService.calcularHash(registro: reg2)

        XCTAssertNotEqual(hash1, hash2)
    }

    // MARK: - Chain

    func testPrimerRegistroCadenaHashAnteriorVacio() {
        let factura = crearFacturaTest()
        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        XCTAssertEqual(registro.hashRegistroAnterior, "")
    }

    func testSegundoRegistroEncadenado() {
        let factura1 = crearFacturaTest(numero: "FAC-0001")
        let reg1 = VeriFactuHashService.crearRegistroAlta(
            factura: factura1, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        let factura2 = crearFacturaTest(numero: "FAC-0002")
        let reg2 = VeriFactuHashService.crearRegistroAlta(
            factura: factura2, negocio: negocio, modelContext: modelContext
        )

        XCTAssertEqual(reg2.hashRegistroAnterior, reg1.hashRegistro)
    }

    func testCadenaIntegra() {
        // Crear 3 registros
        for i in 1...3 {
            let factura = crearFacturaTest(numero: "FAC-\(String(format: "%04d", i))")
            let _ = VeriFactuHashService.crearRegistroAlta(
                factura: factura, negocio: negocio, modelContext: modelContext
            )
            try? modelContext.save()
        }

        let (valida, errores) = VeriFactuHashService.verificarCadena(modelContext: modelContext)
        XCTAssertTrue(valida, "Cadena debería ser válida. Errores: \(errores)")
        XCTAssertTrue(errores.isEmpty)
    }

    // MARK: - Registro de alta

    func testRegistroAltaCamposCorrectos() {
        let factura = crearFacturaTest()
        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        XCTAssertEqual(registro.tipoRegistro, .alta)
        XCTAssertEqual(registro.nifEmisor, "B12345678")
        XCTAssertEqual(registro.numeroFactura, "FAC-0001")
        XCTAssertEqual(registro.importeTotal, factura.totalFactura, accuracy: 0.01)
    }

    // MARK: - Registro de anulación

    func testRegistroAnulacion() {
        let factura = crearFacturaTest()
        let _ = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        let regAnul = VeriFactuHashService.crearRegistroAnulacion(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        XCTAssertEqual(regAnul.tipoRegistro, .anulacion)
        XCTAssertFalse(regAnul.hashRegistroAnterior.isEmpty) // Encadenado al anterior
    }

    // MARK: - XML

    func testXMLRegistroAltaContieneCamposObligatorios() {
        let factura = crearFacturaTest()
        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)

        XCTAssertTrue(xml.contains("RegistroAlta"))
        XCTAssertTrue(xml.contains("IDVersion"))
        XCTAssertTrue(xml.contains("IDFactura"))
        XCTAssertTrue(xml.contains("TipoHuella"))
        XCTAssertTrue(xml.contains("Huella"))
        XCTAssertTrue(xml.contains("SistemaInformatico"))
        XCTAssertTrue(xml.contains("FacturaApp"))
        XCTAssertTrue(xml.contains(negocio.nif))
    }

    func testXMLRegistroAnulacionContieneCampos() {
        let factura = crearFacturaTest()
        let registro = VeriFactuHashService.crearRegistroAnulacion(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)

        XCTAssertTrue(xml.contains("RegistroAnulacion"))
        XCTAssertTrue(xml.contains("IDEmisorFacturaAnulada"))
    }

    // MARK: - Helpers

    private func crearFacturaTest(numero: String = "FAC-0001") -> Factura {
        let factura = Factura(numeroFactura: numero)
        let linea = LineaFactura(orden: 0, concepto: "Test", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        factura.lineas.append(linea)
        factura.recalcularTotales()
        modelContext.insert(factura)
        return factura
    }
}
