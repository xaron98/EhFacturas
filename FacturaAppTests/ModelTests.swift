// ModelTests.swift
// Tests de propiedades computadas y métodos de modelos

import XCTest
import SwiftData
@testable import FacturaApp

final class ModelTests: XCTestCase {

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

    // MARK: - Factura.lineasArray

    func testFacturaLineasArray() {
        let factura = Factura(numeroFactura: "FAC-0001")
        // lineasArray returns [] when lineas is nil
        XCTAssertTrue(factura.lineasArray.isEmpty)

        let linea = LineaFactura(orden: 0, concepto: "Test", cantidad: 1, precioUnitario: 10.0)
        factura.lineas = [linea]
        XCTAssertEqual(factura.lineasArray.count, 1)
        XCTAssertEqual(factura.lineasArray.first?.concepto, "Test")
    }

    // MARK: - Factura.lineasOrdenadas

    func testFacturaLineasOrdenadas() {
        let factura = Factura(numeroFactura: "FAC-0001")
        let linea3 = LineaFactura(orden: 2, concepto: "Tercera", cantidad: 1, precioUnitario: 30.0)
        let linea1 = LineaFactura(orden: 0, concepto: "Primera", cantidad: 1, precioUnitario: 10.0)
        let linea2 = LineaFactura(orden: 1, concepto: "Segunda", cantidad: 1, precioUnitario: 20.0)
        factura.lineas = [linea3, linea1, linea2]

        let ordenadas = factura.lineasOrdenadas
        XCTAssertEqual(ordenadas.count, 3)
        XCTAssertEqual(ordenadas[0].concepto, "Primera")
        XCTAssertEqual(ordenadas[1].concepto, "Segunda")
        XCTAssertEqual(ordenadas[2].concepto, "Tercera")
    }

    // MARK: - Factura.desgloseIVA

    func testFacturaDesgloseIVAMultiple() {
        let factura = Factura(numeroFactura: "FAC-0001")
        let linea1 = LineaFactura(orden: 0, concepto: "Material", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        let linea2 = LineaFactura(orden: 1, concepto: "Servicio", cantidad: 1, precioUnitario: 200.0, porcentajeIVA: 10)
        let linea3 = LineaFactura(orden: 2, concepto: "Pan", cantidad: 1, precioUnitario: 50.0, porcentajeIVA: 4)
        factura.lineas = []
        factura.lineas!.append(linea1)
        factura.lineas!.append(linea2)
        factura.lineas!.append(linea3)
        factura.recalcularTotales()

        let desglose = factura.desgloseIVA
        XCTAssertEqual(desglose.count, 3) // 21%, 10%, 4%

        let iva21 = desglose.first(where: { $0.porcentaje == 21 })
        XCTAssertEqual(iva21?.base ?? 0, 100.0, accuracy: 0.01)
        XCTAssertEqual(iva21?.cuota ?? 0, 21.0, accuracy: 0.01)

        let iva10 = desglose.first(where: { $0.porcentaje == 10 })
        XCTAssertEqual(iva10?.base ?? 0, 200.0, accuracy: 0.01)
        XCTAssertEqual(iva10?.cuota ?? 0, 20.0, accuracy: 0.01)

        let iva4 = desglose.first(where: { $0.porcentaje == 4 })
        XCTAssertEqual(iva4?.base ?? 0, 50.0, accuracy: 0.01)
        XCTAssertEqual(iva4?.cuota ?? 0, 2.0, accuracy: 0.01)
    }

    // MARK: - Cliente.iniciales

    func testClienteIniciales() {
        let cliente = Cliente(nombre: "Juan García")
        XCTAssertEqual(cliente.iniciales, "JG")
    }

    func testClienteInicialesUnNombre() {
        let cliente = Cliente(nombre: "Juan")
        XCTAssertEqual(cliente.iniciales, "JU")
    }

    func testClienteInicialesTresNombres() {
        let cliente = Cliente(nombre: "Juan García López")
        XCTAssertEqual(cliente.iniciales, "JG")
    }

    func testClienteInicialesVacio() {
        let cliente = Cliente(nombre: "")
        XCTAssertEqual(cliente.iniciales, "")
    }

    func testClienteInicialesMinusculas() {
        let cliente = Cliente(nombre: "ana martínez")
        XCTAssertEqual(cliente.iniciales, "AM")
    }

    // MARK: - Articulo.margen

    func testArticuloMargen() {
        let articulo = Articulo(nombre: "Test", precioUnitario: 10.0, precioCoste: 5.0)
        // (10 - 5) / 5 * 100 = 100%
        XCTAssertEqual(articulo.margen, 100.0, accuracy: 0.01)
    }

    func testArticuloMargenSinCoste() {
        let articulo = Articulo(nombre: "Test", precioUnitario: 10.0, precioCoste: 0)
        XCTAssertEqual(articulo.margen, 0.0)
    }

    func testArticuloMargenNegativo() {
        let articulo = Articulo(nombre: "Test", precioUnitario: 3.0, precioCoste: 5.0)
        // (3 - 5) / 5 * 100 = -40%
        XCTAssertEqual(articulo.margen, -40.0, accuracy: 0.01)
    }

    // MARK: - Articulo.precioConIVA

    func testArticuloPrecioConIVA() {
        let articulo = Articulo(nombre: "Test", precioUnitario: 100.0)
        articulo.tipoIVA = .general
        // 100 * (1 + 21/100) = 121
        XCTAssertEqual(articulo.precioConIVA, 121.0, accuracy: 0.01)
    }

    func testArticuloPrecioConIVAReducido() {
        let articulo = Articulo(nombre: "Test", precioUnitario: 100.0)
        articulo.tipoIVA = .reducido
        // 100 * (1 + 10/100) = 110
        XCTAssertEqual(articulo.precioConIVA, 110.0, accuracy: 0.01)
    }

    func testArticuloPrecioConIVAExento() {
        let articulo = Articulo(nombre: "Test", precioUnitario: 100.0)
        articulo.tipoIVA = .exento
        XCTAssertEqual(articulo.precioConIVA, 100.0, accuracy: 0.01)
    }

    func testArticuloPrecioConIVASuperReducido() {
        let articulo = Articulo(nombre: "Test", precioUnitario: 100.0)
        articulo.tipoIVA = .superReducido
        // 100 * (1 + 4/100) = 104
        XCTAssertEqual(articulo.precioConIVA, 104.0, accuracy: 0.01)
    }

    // MARK: - UnidadMedida.abreviatura (all cases)

    func testUnidadMedidaAbreviatura() {
        XCTAssertEqual(UnidadMedida.unidad.abreviatura, "ud")
        XCTAssertEqual(UnidadMedida.metro.abreviatura, "m")
        XCTAssertEqual(UnidadMedida.metroC.abreviatura, "m²")
        XCTAssertEqual(UnidadMedida.hora.abreviatura, "h")
        XCTAssertEqual(UnidadMedida.kilogramo.abreviatura, "kg")
        XCTAssertEqual(UnidadMedida.litro.abreviatura, "l")
        XCTAssertEqual(UnidadMedida.rollo.abreviatura, "rollo")
        XCTAssertEqual(UnidadMedida.caja.abreviatura, "caja")
        XCTAssertEqual(UnidadMedida.servicio.abreviatura, "servicio")
    }

    // MARK: - UnidadMedida(abreviatura:)

    func testUnidadMedidaDesdeAbreviatura() {
        XCTAssertEqual(UnidadMedida(abreviatura: "ud"), .unidad)
        XCTAssertEqual(UnidadMedida(abreviatura: "m"), .metro)
        XCTAssertEqual(UnidadMedida(abreviatura: "m²"), .metroC)
        XCTAssertEqual(UnidadMedida(abreviatura: "h"), .hora)
        XCTAssertEqual(UnidadMedida(abreviatura: "kg"), .kilogramo)
        XCTAssertEqual(UnidadMedida(abreviatura: "l"), .litro)
        XCTAssertEqual(UnidadMedida(abreviatura: "rollo"), .rollo)
        XCTAssertEqual(UnidadMedida(abreviatura: "caja"), .caja)
        XCTAssertEqual(UnidadMedida(abreviatura: "servicio"), .servicio)
    }

    func testUnidadMedidaAbreviaturaInvalida() {
        XCTAssertNil(UnidadMedida(abreviatura: "xyz"))
        XCTAssertNil(UnidadMedida(abreviatura: ""))
        XCTAssertNil(UnidadMedida(abreviatura: "metros"))
    }

    // MARK: - TipoIVA.porcentaje

    func testTipoIVAPorcentajes() {
        XCTAssertEqual(TipoIVA.general.porcentaje, 21.0)
        XCTAssertEqual(TipoIVA.reducido.porcentaje, 10.0)
        XCTAssertEqual(TipoIVA.superReducido.porcentaje, 4.0)
        XCTAssertEqual(TipoIVA.exento.porcentaje, 0.0)
    }

    func testTipoIVADescripciones() {
        XCTAssertTrue(TipoIVA.general.descripcion.contains("21"))
        XCTAssertTrue(TipoIVA.reducido.descripcion.contains("10"))
        XCTAssertTrue(TipoIVA.superReducido.descripcion.contains("4"))
        XCTAssertTrue(TipoIVA.exento.descripcion.contains("0"))
    }

    // MARK: - EstadoFactura.descripcion

    func testEstadoFacturaDescripciones() {
        XCTAssertEqual(EstadoFactura.presupuesto.descripcion, "Presupuesto")
        XCTAssertEqual(EstadoFactura.borrador.descripcion, "Borrador")
        XCTAssertEqual(EstadoFactura.emitida.descripcion, "Emitida")
        XCTAssertEqual(EstadoFactura.pagada.descripcion, "Pagada")
        XCTAssertEqual(EstadoFactura.vencida.descripcion, "Vencida")
        XCTAssertEqual(EstadoFactura.anulada.descripcion, "Anulada")
    }

    func testEstadoFacturaColores() {
        XCTAssertEqual(EstadoFactura.presupuesto.color, "purple")
        XCTAssertEqual(EstadoFactura.borrador.color, "gray")
        XCTAssertEqual(EstadoFactura.emitida.color, "blue")
        XCTAssertEqual(EstadoFactura.pagada.color, "green")
        XCTAssertEqual(EstadoFactura.vencida.color, "red")
        XCTAssertEqual(EstadoFactura.anulada.color, "orange")
    }

    // MARK: - Negocio.generarNumeroFactura

    func testNegocioGenerarNumeroFactura() {
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

    func testNegocioGenerarNumeroFacturaFormato() {
        let negocio = Negocio(nombre: "Test")
        negocio.prefijoFactura = "PRE-"
        negocio.siguienteNumero = 42

        let num = negocio.generarNumeroFactura()
        XCTAssertEqual(num, "PRE-0042")
    }

    func testNegocioGenerarNumeroFacturaGrande() {
        let negocio = Negocio(nombre: "Test")
        negocio.prefijoFactura = "FAC-"
        negocio.siguienteNumero = 9999

        let num = negocio.generarNumeroFactura()
        XCTAssertEqual(num, "FAC-9999")
    }

    func testNegocioGenerarNumeroFacturaCincoDigitos() {
        let negocio = Negocio(nombre: "Test")
        negocio.prefijoFactura = "FAC-"
        negocio.siguienteNumero = 10000

        let num = negocio.generarNumeroFactura()
        XCTAssertEqual(num, "FAC-10000")
    }

    // MARK: - FacturaRecurrente.proximaFecha

    func testFacturaRecurrenteProximaFechaSemanal() {
        let hoy = Date.now
        let proxima = FacturaRecurrente.calcularProximaFecha(desde: hoy, frecuencia: "semanal")
        let diff = Calendar.current.dateComponents([.day], from: hoy, to: proxima).day ?? 0
        XCTAssertEqual(diff, 7)
    }

    func testFacturaRecurrenteProximaFechaMensual() {
        let hoy = Date.now
        let proxima = FacturaRecurrente.calcularProximaFecha(desde: hoy, frecuencia: "mensual")
        let diff = Calendar.current.dateComponents([.month], from: hoy, to: proxima).month ?? 0
        XCTAssertEqual(diff, 1)
    }

    func testFacturaRecurrenteProximaFechaTrimestral() {
        let hoy = Date.now
        let proxima = FacturaRecurrente.calcularProximaFecha(desde: hoy, frecuencia: "trimestral")
        let diff = Calendar.current.dateComponents([.month], from: hoy, to: proxima).month ?? 0
        XCTAssertEqual(diff, 3)
    }

    func testFacturaRecurrenteProximaFechaAnual() {
        let hoy = Date.now
        let proxima = FacturaRecurrente.calcularProximaFecha(desde: hoy, frecuencia: "anual")
        let diff = Calendar.current.dateComponents([.year], from: hoy, to: proxima).year ?? 0
        XCTAssertEqual(diff, 1)
    }

    func testFacturaRecurrenteProximaFechaDefault() {
        // Unknown frequency falls back to monthly
        let hoy = Date.now
        let proxima = FacturaRecurrente.calcularProximaFecha(desde: hoy, frecuencia: "desconocido")
        let diff = Calendar.current.dateComponents([.month], from: hoy, to: proxima).month ?? 0
        XCTAssertEqual(diff, 1)
    }

    // MARK: - Gasto

    func testGastoCategoriaPorDefecto() {
        let gasto = Gasto(concepto: "Test", importe: 10.0)
        XCTAssertEqual(gasto.categoria, "otros")
    }

    func testGastoConCategoria() {
        let gasto = Gasto(concepto: "Gasolina", importe: 50.0, categoria: "vehiculo")
        XCTAssertEqual(gasto.categoria, "vehiculo")
        XCTAssertEqual(gasto.importe, 50.0)
        XCTAssertTrue(gasto.deducibleIVA)
    }

    func testGastoNoDeducible() {
        let gasto = Gasto(concepto: "Multa", importe: 100.0, deducibleIVA: false)
        XCTAssertFalse(gasto.deducibleIVA)
    }

    // MARK: - RegistroFacturacion.init

    func testRegistroFacturacionInit() {
        let factura = Factura(numeroFactura: "FAC-0001")
        let linea = LineaFactura(orden: 0, concepto: "Servicio", cantidad: 1, precioUnitario: 100.0, porcentajeIVA: 21)
        factura.lineas = [linea]
        factura.recalcularTotales()
        factura.clienteNombre = "Test Cliente"
        factura.clienteNIF = "12345678A"

        let registro = RegistroFacturacion(
            tipoRegistro: .alta, factura: factura,
            nifEmisor: "B12345678", hashAnterior: ""
        )

        XCTAssertEqual(registro.tipoRegistro, .alta)
        XCTAssertEqual(registro.nifEmisor, "B12345678")
        XCTAssertEqual(registro.numeroFactura, "FAC-0001")
        XCTAssertEqual(registro.serieFactura, "FAC-")
        XCTAssertEqual(registro.baseImponible, 100.0, accuracy: 0.01)
        XCTAssertEqual(registro.totalIVA, 21.0, accuracy: 0.01)
        XCTAssertEqual(registro.importeTotal, 121.0, accuracy: 0.01)
        XCTAssertEqual(registro.nifDestinatario, "12345678A")
        XCTAssertEqual(registro.nombreDestinatario, "Test Cliente")
        XCTAssertEqual(registro.hashRegistroAnterior, "")
        XCTAssertEqual(registro.tipoFactura, .completa)
    }

    func testRegistroFacturacionAnulacion() {
        let factura = Factura(numeroFactura: "FAC-0001")
        let registro = RegistroFacturacion(
            tipoRegistro: .anulacion, factura: factura,
            nifEmisor: "B12345678", hashAnterior: "abc123"
        )

        XCTAssertEqual(registro.tipoRegistro, .anulacion)
        XCTAssertEqual(registro.hashRegistroAnterior, "abc123")
    }

    func testRegistroFacturacionRectificativa() {
        let factura = Factura(numeroFactura: "FAC-0002")
        let registro = RegistroFacturacion(
            tipoRegistro: .alta, factura: factura,
            nifEmisor: "B12345678", hashAnterior: "",
            tipoFactura: .rectificativa,
            facturaRectificadaNumero: "FAC-0001"
        )

        XCTAssertEqual(registro.tipoFactura, .rectificativa)
        XCTAssertEqual(registro.facturaRectificadaNumero, "FAC-0001")
    }

    // MARK: - Negocio defaults

    func testNegocioDefaults() {
        let negocio = Negocio(nombre: "Test")
        XCTAssertEqual(negocio.prefijoFactura, "FAC-")
        XCTAssertEqual(negocio.siguienteNumero, 1)
        XCTAssertEqual(negocio.ivaGeneral, 21.0)
        XCTAssertEqual(negocio.ivaReducido, 10.0)
        XCTAssertEqual(negocio.irpfPorcentaje, 15.0)
        XCTAssertFalse(negocio.aplicarIRPF)
        XCTAssertTrue(negocio.usarEntornoPruebas)
    }

    // MARK: - Cliente defaults

    func testClienteDefaults() {
        let cliente = Cliente(nombre: "Test")
        XCTAssertTrue(cliente.activo)
        XCTAssertEqual(cliente.nombre, "Test")
        XCTAssertEqual(cliente.nif, "")
        XCTAssertEqual(cliente.telefono, "")
    }

    // MARK: - Articulo defaults

    func testArticuloDefaults() {
        let articulo = Articulo(nombre: "Test")
        XCTAssertTrue(articulo.activo)
        XCTAssertEqual(articulo.unidad, .unidad)
        XCTAssertEqual(articulo.tipoIVA, .general)
        XCTAssertEqual(articulo.precioUnitario, 0)
        XCTAssertEqual(articulo.precioCoste, 0)
        XCTAssertTrue(articulo.etiquetas.isEmpty)
    }

    // MARK: - Factura defaults

    func testFacturaDefaults() {
        let factura = Factura(numeroFactura: "FAC-0001")
        XCTAssertEqual(factura.estado, .borrador)
        XCTAssertEqual(factura.descuentoGlobalPorcentaje, 0)
        XCTAssertEqual(factura.baseImponible, 0)
        XCTAssertEqual(factura.totalIVA, 0)
        XCTAssertEqual(factura.totalIRPF, 0)
        XCTAssertEqual(factura.totalFactura, 0)
        XCTAssertNil(factura.cliente)
        XCTAssertNotNil(factura.fechaVencimiento)
    }

    func testFacturaConCliente() {
        let cliente = Cliente(nombre: "Juan", nif: "12345678A",
                             direccion: "Calle Mayor 1", codigoPostal: "28001",
                             ciudad: "Madrid", provincia: "Madrid")
        let factura = Factura(numeroFactura: "FAC-0001", cliente: cliente)

        XCTAssertEqual(factura.clienteNombre, "Juan")
        XCTAssertEqual(factura.clienteNIF, "12345678A")
        XCTAssertTrue(factura.clienteDireccion.contains("Madrid"))
    }

    // MARK: - Categoria

    func testCategoriaDefectoCount() {
        XCTAssertEqual(Categoria.categoriasDefecto.count, 9)
    }

    func testCategoriaDefectoNombres() {
        let nombres = Categoria.categoriasDefecto.map { $0.0 }
        XCTAssertTrue(nombres.contains("Iluminación"))
        XCTAssertTrue(nombres.contains("Fontanería"))
        XCTAssertTrue(nombres.contains("Herramientas"))
    }

    // MARK: - PlantillaFactura

    func testPlantillaFacturaInit() {
        let plantilla = PlantillaFactura(nombre: "Mantenimiento", articulosTexto: "1 hora mano de obra")
        XCTAssertEqual(plantilla.nombre, "Mantenimiento")
        XCTAssertEqual(plantilla.articulosTexto, "1 hora mano de obra")
        XCTAssertEqual(plantilla.vecesUsada, 0)
    }

    // MARK: - EventoSIF

    func testEventoSIFInit() {
        let evento = EventoSIF(tipo: "envio", descripcion: "Factura enviada", detalles: "OK", numeroFactura: "FAC-0001")
        XCTAssertEqual(evento.tipo, "envio")
        XCTAssertEqual(evento.descripcion, "Factura enviada")
        XCTAssertEqual(evento.detalles, "OK")
        XCTAssertEqual(evento.numeroFactura, "FAC-0001")
        XCTAssertEqual(evento.usuario, "Sistema")
    }

    // MARK: - TipoFacturaVF

    func testTipoFacturaVFRawValues() {
        XCTAssertEqual(TipoFacturaVF.completa.rawValue, "completa")
        XCTAssertEqual(TipoFacturaVF.simplificada.rawValue, "simplificada")
        XCTAssertEqual(TipoFacturaVF.rectificativa.rawValue, "rectificativa")
    }

    // MARK: - EstadoEnvioVF

    func testEstadoEnvioVFRawValues() {
        XCTAssertEqual(EstadoEnvioVF.noEnviado.rawValue, "noEnviado")
        XCTAssertEqual(EstadoEnvioVF.pendiente.rawValue, "pendiente")
        XCTAssertEqual(EstadoEnvioVF.enviado.rawValue, "enviado")
        XCTAssertEqual(EstadoEnvioVF.rechazado.rawValue, "rechazado")
        XCTAssertEqual(EstadoEnvioVF.error.rawValue, "error")
    }

    // MARK: - TipoRegistro

    func testTipoRegistroRawValues() {
        XCTAssertEqual(TipoRegistro.alta.rawValue, "alta")
        XCTAssertEqual(TipoRegistro.anulacion.rawValue, "anulacion")
    }
}
