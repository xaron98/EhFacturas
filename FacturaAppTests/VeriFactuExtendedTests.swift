// VeriFactuExtendedTests.swift
// Tests exhaustivos de VeriFactu: hash chain, XML, formatos

import XCTest
import SwiftData
@testable import FacturaApp

final class VeriFactuExtendedTests: XCTestCase {

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
        modelContext.insert(negocio)
    }

    // MARK: - Hash chain larga

    func testHashCadenaLarga() {
        // Create 10+ records and verify the chain
        for i in 1...12 {
            let factura = crearFacturaTest(numero: "FAC-\(String(format: "%04d", i))")
            let _ = VeriFactuHashService.crearRegistroAlta(
                factura: factura, negocio: negocio, modelContext: modelContext
            )
            try? modelContext.save()
        }

        let (valida, errores) = VeriFactuHashService.verificarCadena(modelContext: modelContext)
        XCTAssertTrue(valida, "Cadena de 12 registros deberia ser valida. Errores: \(errores)")
        XCTAssertTrue(errores.isEmpty)

        // Verify total count
        let desc = FetchDescriptor<RegistroFacturacion>()
        let registros = (try? modelContext.fetch(desc)) ?? []
        XCTAssertEqual(registros.count, 12)
    }

    // MARK: - Hash diferente para alta vs anulacion

    func testHashDiferenteParaAlta() {
        let factura = crearFacturaTest(numero: "FAC-0001")
        let regAlta = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        XCTAssertEqual(regAlta.tipoRegistro, .alta)
        XCTAssertFalse(regAlta.hashRegistro.isEmpty)
        XCTAssertEqual(regAlta.hashRegistro.count, 64) // SHA-256 hex
    }

    func testHashDiferenteParaAnulacion() {
        let factura = crearFacturaTest(numero: "FAC-0001")
        let regAlta = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        let regAnul = VeriFactuHashService.crearRegistroAnulacion(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        XCTAssertEqual(regAnul.tipoRegistro, .anulacion)
        XCTAssertNotEqual(regAlta.hashRegistro, regAnul.hashRegistro)
    }

    // MARK: - XML: Destinatarios

    func testXMLContieneDestinatario() {
        let cliente = Cliente(nombre: "Juan Garcia", nif: "12345678A")
        modelContext.insert(cliente)

        let factura = Factura(numeroFactura: "FAC-0001", cliente: cliente)
        let linea = LineaFactura(orden: 0, concepto: "Test", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        factura.lineas = [linea]
        factura.recalcularTotales()
        modelContext.insert(factura)

        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)

        XCTAssertTrue(xml.contains("Destinatarios"))
        XCTAssertTrue(xml.contains("IDDestinatario"))
        XCTAssertTrue(xml.contains("12345678A"))
        XCTAssertTrue(xml.contains("Juan Garcia"))
    }

    func testXMLSinDestinatario() {
        let factura = crearFacturaTest(numero: "FAC-0001")
        // No client -> no NIF -> no Destinatarios section
        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)

        XCTAssertFalse(xml.contains("Destinatarios"))
    }

    // MARK: - XML: Rectificativa

    func testXMLRectificativa() {
        let factura = Factura(numeroFactura: "FAC-0002")
        factura.tipoFactura = .rectificativa
        let linea = LineaFactura(orden: 0, concepto: "Correccion", cantidad: 1, precioUnitario: 50.0, porcentajeIVA: 21)
        factura.lineas = [linea]
        factura.recalcularTotales()
        modelContext.insert(factura)

        let registro = RegistroFacturacion(
            tipoRegistro: .alta, factura: factura,
            nifEmisor: negocio.nif, hashAnterior: "",
            tipoFactura: .rectificativa,
            facturaRectificadaNumero: "FAC-0001"
        )
        registro.hashRegistro = VeriFactuHashService.calcularHash(registro: registro)
        modelContext.insert(registro)

        let xml = VeriFactuXMLGenerator.generarRegistroAlta(registro: registro, negocio: negocio)

        XCTAssertTrue(xml.contains("TipoRectificativa"))
        XCTAssertTrue(xml.contains("FacturasRectificadas"))
        XCTAssertTrue(xml.contains("R1")) // rectificativa type code
        XCTAssertTrue(xml.contains("FAC-0001"))
    }

    // MARK: - XML: Encadenamiento

    func testXMLEncadenamientoPrimerRegistro() {
        let factura = crearFacturaTest(numero: "FAC-0001")
        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)

        XCTAssertTrue(xml.contains("PrimerRegistro"))
        XCTAssertTrue(xml.contains(">S<"))
    }

    func testXMLEncadenamientoSegundoRegistro() {
        // Create first record
        let factura1 = crearFacturaTest(numero: "FAC-0001")
        let reg1 = VeriFactuHashService.crearRegistroAlta(
            factura: factura1, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        // Create second record
        let factura2 = crearFacturaTest(numero: "FAC-0002")
        let reg2 = VeriFactuHashService.crearRegistroAlta(
            factura: factura2, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: reg2, negocio: negocio)

        XCTAssertTrue(xml.contains("RegistroAnterior"))
        XCTAssertTrue(xml.contains(reg1.hashRegistro))
        XCTAssertFalse(xml.contains("PrimerRegistro"))
    }

    // MARK: - Fecha formato XSD

    func testFechaFormatoXSD() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 25))!
        let resultado = VeriFactuXMLGenerator.formatFechaXSD(date)
        XCTAssertEqual(resultado, "25-03-2026")
    }

    func testFechaFormatoXSDPrimerDia() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let resultado = VeriFactuXMLGenerator.formatFechaXSD(date)
        XCTAssertEqual(resultado, "01-01-2026")
    }

    // MARK: - Timestamp formato XSD

    func testTimestampFormatoXSD() {
        let date = Date.now
        let resultado = VeriFactuXMLGenerator.formatTimestampXSD(date)

        // Format: dd-MM-yyyy HH:mm:ss+xx:xx
        XCTAssertTrue(resultado.contains("-"))
        XCTAssertTrue(resultado.contains(":"))
        // Should have timezone offset like +01:00 or +02:00
        let parts = resultado.split(separator: " ")
        XCTAssertEqual(parts.count, 2)
        // Date part should be dd-MM-yyyy
        let dateParts = parts[0].split(separator: "-")
        XCTAssertEqual(dateParts.count, 3)
    }

    // MARK: - formatImporte

    func testFormatImporte() {
        XCTAssertEqual(VeriFactuXMLGenerator.formatImporte(100.0), "100.00")
        XCTAssertEqual(VeriFactuXMLGenerator.formatImporte(0), "0.00")
        XCTAssertEqual(VeriFactuXMLGenerator.formatImporte(1234.56), "1234.56")
        XCTAssertEqual(VeriFactuXMLGenerator.formatImporte(-50.0), "-50.00")
    }

    // MARK: - escaparXML

    func testEscaparXML() {
        XCTAssertEqual(VeriFactuXMLGenerator.escaparXML("Test & Co."), "Test &amp; Co.")
        XCTAssertEqual(VeriFactuXMLGenerator.escaparXML("<tag>"), "&lt;tag&gt;")
        XCTAssertEqual(VeriFactuXMLGenerator.escaparXML("\"quoted\""), "&quot;quoted&quot;")
        XCTAssertEqual(VeriFactuXMLGenerator.escaparXML("it's"), "it&apos;s")
        XCTAssertEqual(VeriFactuXMLGenerator.escaparXML("normal text"), "normal text")
    }

    // MARK: - mapTipoFactura

    func testMapTipoFactura() {
        XCTAssertEqual(VeriFactuXMLGenerator.mapTipoFactura(.completa), "F1")
        XCTAssertEqual(VeriFactuXMLGenerator.mapTipoFactura(.simplificada), "F2")
        XCTAssertEqual(VeriFactuXMLGenerator.mapTipoFactura(.rectificativa), "R1")
    }

    // MARK: - XML contiene campos obligatorios

    func testXMLRegistroAltaCamposObligatorios() {
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
        XCTAssertTrue(xml.contains("Desglose"))
        XCTAssertTrue(xml.contains("CuotaTotal"))
        XCTAssertTrue(xml.contains("ImporteTotal"))
        XCTAssertTrue(xml.contains("FechaHoraHusoGenRegistro"))
        XCTAssertTrue(xml.contains("DescripcionOperacion"))
        XCTAssertTrue(xml.contains("NombreRazonEmisor"))
        XCTAssertTrue(xml.contains("TipoFactura"))
    }

    func testXMLRegistroAnulacionCampos() {
        let factura = crearFacturaTest()
        let registro = VeriFactuHashService.crearRegistroAnulacion(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)

        XCTAssertTrue(xml.contains("RegistroAnulacion"))
        XCTAssertTrue(xml.contains("IDEmisorFacturaAnulada"))
        XCTAssertTrue(xml.contains("NumSerieFacturaAnulada"))
        XCTAssertTrue(xml.contains("FechaExpedicionFacturaAnulada"))
        XCTAssertTrue(xml.contains("SistemaInformatico"))
        XCTAssertTrue(xml.contains("TipoHuella"))
        XCTAssertTrue(xml.contains("Huella"))
    }

    // MARK: - XML SOAP envelope

    func testXMLSOAPEnvelope() {
        let factura = crearFacturaTest()
        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLRegistro(registro: registro, negocio: negocio)

        XCTAssertTrue(xml.contains("<?xml version"))
        XCTAssertTrue(xml.contains("soapenv:Envelope"))
        XCTAssertTrue(xml.contains("soapenv:Header"))
        XCTAssertTrue(xml.contains("soapenv:Body"))
        XCTAssertTrue(xml.contains("RegFactuSistemaFacturacion"))
        XCTAssertTrue(xml.contains("Cabecera"))
        XCTAssertTrue(xml.contains("ObligadoEmision"))
        XCTAssertTrue(xml.contains("RegistroFactura"))
    }

    // MARK: - Hash: cadena mixta alta + anulacion

    func testCadenaMixtaAltaYAnulacion() {
        // Create alta
        let factura1 = crearFacturaTest(numero: "FAC-0001")
        let _ = VeriFactuHashService.crearRegistroAlta(
            factura: factura1, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        // Create anulacion
        let _ = VeriFactuHashService.crearRegistroAnulacion(
            factura: factura1, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        // Create another alta
        let factura2 = crearFacturaTest(numero: "FAC-0002")
        let _ = VeriFactuHashService.crearRegistroAlta(
            factura: factura2, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        let (valida, errores) = VeriFactuHashService.verificarCadena(modelContext: modelContext)
        XCTAssertTrue(valida, "Cadena mixta deberia ser valida. Errores: \(errores)")
    }

    // MARK: - Hash: obtenerHashAnterior

    func testObtenerHashAnteriorVacio() {
        let hash = VeriFactuHashService.obtenerHashAnterior(modelContext: modelContext)
        XCTAssertEqual(hash, "")
    }

    func testObtenerHashAnteriorConRegistros() {
        let factura = crearFacturaTest()
        let registro = VeriFactuHashService.crearRegistroAlta(
            factura: factura, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        let hash = VeriFactuHashService.obtenerHashAnterior(modelContext: modelContext)
        XCTAssertEqual(hash, registro.hashRegistro)
        XCTAssertFalse(hash.isEmpty)
    }

    // MARK: - XML: multiple registros

    func testXMLEnvioMultiplesRegistros() {
        let factura1 = crearFacturaTest(numero: "FAC-0001")
        let reg1 = VeriFactuHashService.crearRegistroAlta(
            factura: factura1, negocio: negocio, modelContext: modelContext
        )
        try? modelContext.save()

        let factura2 = crearFacturaTest(numero: "FAC-0002")
        let reg2 = VeriFactuHashService.crearRegistroAlta(
            factura: factura2, negocio: negocio, modelContext: modelContext
        )

        let xml = VeriFactuXMLGenerator.generarXMLEnvio(registros: [reg1, reg2], negocio: negocio)

        // Should contain two RegistroFactura blocks
        let count = xml.components(separatedBy: "<sf:RegistroFactura>").count - 1
        XCTAssertEqual(count, 2)

        XCTAssertTrue(xml.contains("FAC-0001"))
        XCTAssertTrue(xml.contains("FAC-0002"))
    }

    // MARK: - Helpers

    private func crearFacturaTest(numero: String = "FAC-0001") -> Factura {
        let factura = Factura(numeroFactura: numero)
        let linea = LineaFactura(orden: 0, concepto: "Test", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        factura.lineas = [linea]
        factura.recalcularTotales()
        modelContext.insert(factura)
        return factura
    }
}
