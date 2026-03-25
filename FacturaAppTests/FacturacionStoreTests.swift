// FacturacionStoreTests.swift
// Tests del actor FacturacionStore: toda la lógica de negocio

import XCTest
import SwiftData
@testable import FacturaApp

final class FacturacionStoreTests: XCTestCase {

    var store: FacturacionStore!
    var container: ModelContainer!

    override func setUp() {
        let schema = Schema([Negocio.self, Cliente.self, Categoria.self,
                             Articulo.self, Factura.self, LineaFactura.self,
                             RegistroFacturacion.self, EventoSIF.self,
                             PerfilImportacion.self, FacturaRecurrente.self,
                             PlantillaFactura.self, Gasto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        store = FacturacionStore(container: container)

        // Create a Negocio for tests that need it
        let ctx = ModelContext(container)
        let negocio = Negocio(nombre: "Test SL", nif: "B12345678")
        negocio.prefijoFactura = "T-"
        negocio.siguienteNumero = 1
        ctx.insert(negocio)
        try! ctx.save()
    }

    // MARK: - crearCliente

    func testCrearCliente() async {
        let result = await store.crearCliente(CrearClienteParams(
            nombre: "Juan García", nif: "12345678A",
            telefono: "666111222", email: "juan@test.com",
            direccion: "Calle Mayor 1", ciudad: "Madrid"
        ))

        XCTAssertTrue(result.contains("Juan García"))
        XCTAssertTrue(result.contains("creado"))

        // Verify in database
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<Cliente>()
        let clientes = (try? ctx.fetch(desc)) ?? []
        XCTAssertEqual(clientes.count, 1)
        XCTAssertEqual(clientes.first?.nombre, "Juan García")
        XCTAssertEqual(clientes.first?.nif, "12345678A")
    }

    func testCrearClienteDuplicado() async {
        // Create first client
        let _ = await store.crearCliente(CrearClienteParams(
            nombre: "Juan García", nif: "12345678A",
            telefono: "", email: "", direccion: "", ciudad: ""
        ))

        // Create second client with same name (store allows it)
        let result = await store.crearCliente(CrearClienteParams(
            nombre: "Juan García", nif: "12345678A",
            telefono: "", email: "", direccion: "", ciudad: ""
        ))

        XCTAssertTrue(result.contains("Juan García"))

        // Both should exist in the database
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<Cliente>()
        let clientes = (try? ctx.fetch(desc)) ?? []
        XCTAssertEqual(clientes.count, 2)
    }

    // MARK: - buscarCliente

    func testBuscarClienteExistente() async {
        // Create a client first
        let _ = await store.crearCliente(CrearClienteParams(
            nombre: "María López", nif: "87654321B",
            telefono: "666333444", email: "maria@test.com",
            direccion: "Calle Sol 5", ciudad: "Barcelona"
        ))

        let result = await store.buscarCliente(BuscarClienteParams(consulta: "María"))

        XCTAssertTrue(result.contains("María López"))
        XCTAssertTrue(result.contains("encontrados"))
    }

    func testBuscarClienteNoExiste() async {
        let result = await store.buscarCliente(BuscarClienteParams(consulta: "NoExiste"))

        XCTAssertTrue(result.contains("No se encontr"))
    }

    // MARK: - crearArticulo

    func testCrearArticulo() async {
        let result = await store.crearArticulo(CrearArticuloParams(
            nombre: "Bombilla LED E27", precioUnitario: 3.50,
            referencia: "BOM-001", unidad: "ud",
            proveedor: "Saltoki", precioCoste: 2.0, etiquetas: ""
        ))

        XCTAssertTrue(result.contains("Bombilla LED E27"))
        XCTAssertTrue(result.contains("3.50"))

        // Verify in database
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<Articulo>()
        let articulos = (try? ctx.fetch(desc)) ?? []
        XCTAssertEqual(articulos.count, 1)
        XCTAssertEqual(articulos.first?.nombre, "Bombilla LED E27")
        XCTAssertEqual(articulos.first?.precioUnitario, 3.50, accuracy: 0.01)
    }

    func testCrearArticuloConEtiquetas() async {
        let result = await store.crearArticulo(CrearArticuloParams(
            nombre: "Cable 2.5mm", precioUnitario: 1.20,
            referencia: "CAB-001", unidad: "m",
            proveedor: "", precioCoste: 0.80, etiquetas: "cables, electrico, cobre"
        ))

        XCTAssertTrue(result.contains("Cable 2.5mm"))

        // Verify etiquetas saved
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<Articulo>()
        let articulos = (try? ctx.fetch(desc)) ?? []
        XCTAssertEqual(articulos.first?.etiquetas.count, 3)
        XCTAssertTrue(articulos.first?.etiquetas.contains("cables") ?? false)
        XCTAssertTrue(articulos.first?.etiquetas.contains("electrico") ?? false)
    }

    // MARK: - buscarArticulo

    func testBuscarArticuloFuzzy() async {
        // Create an article
        let _ = await store.crearArticulo(CrearArticuloParams(
            nombre: "Bombilla LED E27", precioUnitario: 3.50,
            referencia: "BOM-001", unidad: "ud",
            proveedor: "", precioCoste: 0, etiquetas: ""
        ))

        let result = await store.buscarArticulo(BuscarArticuloParams(consulta: "bombilla"))

        XCTAssertTrue(result.contains("Bombilla LED E27"))
        XCTAssertTrue(result.contains("encontrados"))
    }

    func testBuscarArticuloPluralSingular() async {
        // "bombillas" should find "bombilla"
        let _ = await store.crearArticulo(CrearArticuloParams(
            nombre: "Bombilla LED E27", precioUnitario: 3.50,
            referencia: "", unidad: "ud",
            proveedor: "", precioCoste: 0, etiquetas: ""
        ))

        let result = await store.buscarArticulo(BuscarArticuloParams(consulta: "bombillas"))

        // fuzzy search should still find it
        XCTAssertTrue(result.contains("Bombilla LED E27"))
    }

    // MARK: - crearFactura

    func testCrearFactura() async {
        let result = await store.crearFactura(CrearFacturaParams(
            nombreCliente: "TestCliente",
            articulosTexto: "1 servicio general",
            descuento: 0,
            observaciones: "Test factura"
        ))

        XCTAssertTrue(result.contains("Factura"))
        XCTAssertTrue(result.contains("T-0001"))
        XCTAssertTrue(result.contains("borrador"))

        // Verify factura in database
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<Factura>()
        let facturas = (try? ctx.fetch(desc)) ?? []
        XCTAssertEqual(facturas.count, 1)
        XCTAssertEqual(facturas.first?.numeroFactura, "T-0001")
        XCTAssertEqual(facturas.first?.estado, .borrador)
    }

    func testCrearFacturaConArticulosCatalogo() async {
        // Create article first
        let _ = await store.crearArticulo(CrearArticuloParams(
            nombre: "Bombilla LED", precioUnitario: 5.0,
            referencia: "BOM-001", unidad: "ud",
            proveedor: "", precioCoste: 3.0, etiquetas: ""
        ))

        // Create invoice with that article
        let result = await store.crearFactura(CrearFacturaParams(
            nombreCliente: "TestCliente",
            articulosTexto: "10 bombilla LED",
            descuento: 0,
            observaciones: ""
        ))

        XCTAssertTrue(result.contains("Factura"))
        XCTAssertTrue(result.contains("T-0001"))
        // Should have found the article and used its price
        XCTAssertTrue(result.contains("Bombilla LED"))

        // Verify total: 10 * 5.0 = 50.0 base + 21% IVA = 60.50
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<Factura>()
        let facturas = (try? ctx.fetch(desc)) ?? []
        let factura = facturas.first
        XCTAssertNotNil(factura)
        XCTAssertEqual(factura?.baseImponible ?? 0, 50.0, accuracy: 0.01)
        XCTAssertEqual(factura?.totalFactura ?? 0, 60.5, accuracy: 0.01)
    }

    // MARK: - crearPresupuesto

    func testCrearPresupuesto() async {
        let result = await store.crearFactura(CrearFacturaParams(
            nombreCliente: "ClienteTest",
            articulosTexto: "1 servicio",
            descuento: 0,
            observaciones: "",
            esPresupuesto: true
        ))

        XCTAssertTrue(result.contains("Presupuesto"))
        XCTAssertTrue(result.contains("presupuesto"))

        let ctx = ModelContext(container)
        let desc = FetchDescriptor<Factura>()
        let facturas = (try? ctx.fetch(desc)) ?? []
        XCTAssertEqual(facturas.first?.estado, .presupuesto)
    }

    // MARK: - marcarPagada

    func testMarcarPagada() async {
        // Create and emit an invoice first
        let ctx = ModelContext(container)
        let factura = Factura(numeroFactura: "T-0001", estado: .emitida)
        factura.clienteNombre = "Juan Test"
        let linea = LineaFactura(orden: 0, concepto: "Servicio", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        factura.lineas = [linea]
        factura.recalcularTotales()
        ctx.insert(factura)
        try! ctx.save()

        let result = await store.marcarPagada(MarcarPagadaParams(identificador: "T-0001"))

        XCTAssertTrue(result.contains("pagada"))
        XCTAssertTrue(result.contains("T-0001"))
    }

    // MARK: - anularFactura

    func testAnularFacturaBorrador() async {
        // Create a draft invoice
        let ctx = ModelContext(container)
        let factura = Factura(numeroFactura: "T-0001", estado: .borrador)
        factura.clienteNombre = "Test"
        ctx.insert(factura)
        try! ctx.save()

        let result = await store.anularFactura(AnularFacturaParams(identificador: "T-0001"))

        XCTAssertTrue(result.contains("anulada"))
        XCTAssertTrue(result.contains("T-0001"))
    }

    func testAnularFacturaEmitida() async {
        // Create an emitted invoice
        let ctx = ModelContext(container)
        let factura = Factura(numeroFactura: "T-0001", estado: .emitida)
        factura.clienteNombre = "Test Cliente"
        let linea = LineaFactura(orden: 0, concepto: "Servicio", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        factura.lineas = [linea]
        factura.recalcularTotales()
        ctx.insert(factura)
        try! ctx.save()

        let result = await store.anularFactura(AnularFacturaParams(identificador: "T-0001"))

        XCTAssertTrue(result.contains("anulada"))
        XCTAssertTrue(result.contains("VeriFactu"))
    }

    // MARK: - consultarResumen

    func testConsultarResumenGeneral() async {
        let result = await store.consultarResumen(ConsultarResumenParams(tipo: "general"))

        XCTAssertTrue(result.contains("Resumen"))
        XCTAssertTrue(result.contains("clientes"))
        XCTAssertTrue(result.contains("facturas"))
    }

    func testConsultarResumenPendientes() async {
        // Create an emitted invoice
        let ctx = ModelContext(container)
        let factura = Factura(numeroFactura: "T-0001", estado: .emitida)
        factura.clienteNombre = "Test"
        factura.totalFactura = 121.0
        ctx.insert(factura)
        try! ctx.save()

        let result = await store.consultarResumen(ConsultarResumenParams(tipo: "pendientes"))

        XCTAssertTrue(result.contains("pendientes"))
        XCTAssertTrue(result.contains("T-0001"))
    }

    // MARK: - crearRecurrente

    func testCrearRecurrente() async {
        let result = await store.crearRecurrente(CrearRecurrenteParams(
            nombreCliente: "Juan",
            articulosTexto: "mantenimiento mensual",
            frecuencia: "mensual",
            importe: 200.0
        ))

        XCTAssertTrue(result.contains("recurrente"))
        XCTAssertTrue(result.contains("200"))

        // Verify in database
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<FacturaRecurrente>()
        let recurrentes = (try? ctx.fetch(desc)) ?? []
        XCTAssertEqual(recurrentes.count, 1)
        XCTAssertEqual(recurrentes.first?.frecuencia, "mensual")
    }

    // MARK: - registrarGasto

    func testRegistrarGasto() async {
        let result = await store.registrarGasto(RegistrarGastoParams(
            concepto: "Material eléctrico",
            importe: 150.0,
            categoria: "material",
            proveedor: "Saltoki"
        ))

        XCTAssertTrue(result.contains("Gasto registrado"))
        XCTAssertTrue(result.contains("Material eléctrico"))
        XCTAssertTrue(result.contains("150"))

        // Verify in database
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<Gasto>()
        let gastos = (try? ctx.fetch(desc)) ?? []
        XCTAssertEqual(gastos.count, 1)
        XCTAssertEqual(gastos.first?.concepto, "Material eléctrico")
        XCTAssertEqual(gastos.first?.importe, 150.0, accuracy: 0.01)
    }

    // MARK: - deshacerUltimaAccion

    func testDeshacerCliente() async {
        // Create a client first
        let _ = await store.crearCliente(CrearClienteParams(
            nombre: "Para Deshacer", nif: "",
            telefono: "", email: "", direccion: "", ciudad: ""
        ))

        let result = await store.deshacerUltimaAccion()

        XCTAssertTrue(result.contains("Deshecho") || result.contains("desactivado"))
    }

    func testDeshacerSinAccion() async {
        let result = await store.deshacerUltimaAccion()

        XCTAssertTrue(result.contains("No hay"))
    }

    // MARK: - configurarNegocio

    func testConfigurarNegocio() async {
        let result = await store.configurarNegocio(ConfigurarNegocioParams(
            nombre: "Test SL", nif: "B99999999",
            direccion: "Calle Nueva 10", ciudad: "Sevilla",
            provincia: "Sevilla", codigoPostal: "41001",
            telefono: "955111222", email: "info@test.com"
        ))

        // Should update the existing negocio since it was created in setUp
        XCTAssertTrue(result.contains("actualizado") || result.contains("configurado"))
    }

    // MARK: - importarDatos

    func testImportarDatos() async {
        let result = await store.importarDatos(ImportarDatosParams(tipo: "clientes"))
        XCTAssertEqual(result, "IMPORTAR_CLIENTES")

        let result2 = await store.importarDatos(ImportarDatosParams(tipo: "articulos"))
        XCTAssertEqual(result2, "IMPORTAR_ARTICULOS")
    }
}
