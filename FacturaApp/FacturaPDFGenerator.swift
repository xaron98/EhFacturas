// FacturaPDFGenerator.swift
// FacturaApp — Generador de PDF profesional formato A4
// Colores corporativos, tabla de líneas, desglose IVA, IRPF.

import SwiftUI
import PDFKit
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - Configuración de colores PDF

struct FacturaPDFConfig {
    static let primario = UIColor(red: 38/255, green: 61/255, blue: 115/255, alpha: 1)
    static let secundario = UIColor(red: 102/255, green: 140/255, blue: 191/255, alpha: 1)
    static let acento = UIColor(red: 51/255, green: 166/255, blue: 115/255, alpha: 1)
    static let fondoRecuadro = UIColor(red: 245/255, green: 247/255, blue: 250/255, alpha: 1)
    static let rojo = UIColor.systemRed
}

// MARK: - Generador de PDF

enum FacturaPDFGenerator {

    static let pageWidth: CGFloat = 595.28
    static let pageHeight: CGFloat = 841.89
    static let margin: CGFloat = 40
    static let contentWidth: CGFloat = 595.28 - 80

    static func generar(factura: Factura, negocio: Negocio) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 0

            // Barra de color superior
            let barraRect = CGRect(x: 0, y: 0, width: pageWidth, height: 8)
            FacturaPDFConfig.primario.setFill()
            context.fill(barraRect)
            y = 30

            // Cabecera: Logo + nombre + "FACTURA" / "PRESUPUESTO"
            let tituloDoc = factura.estado == .presupuesto ? "PRESUPUESTO" : "FACTURA"
            y = dibujarCabecera(context: context, negocio: negocio, y: y, tituloDoc: tituloDoc)

            // Datos del emisor (izq) y cliente (der)
            y = dibujarDatosEmisorCliente(context: context, factura: factura, negocio: negocio, y: y)

            // Recuadros de info: nº factura, fecha, vencimiento
            y = dibujarRecuadrosInfo(context: context, factura: factura, y: y)

            // Tabla de líneas
            y = dibujarTablaLineas(context: context, factura: factura, y: y, pdfContext: context)

            // Totales
            y = dibujarTotales(context: context, factura: factura, y: y)

            // Observaciones
            if !factura.observaciones.isEmpty {
                y = dibujarObservaciones(context: context, factura: factura, y: y)
            }

            // Código QR (solo facturas emitidas con registro VeriFactu)
            if factura.estado != .borrador {
                dibujarQR(context: context, factura: factura, negocio: negocio)
            }

            // Pie de página
            dibujarPie(context: context, negocio: negocio)
        }
    }

    // MARK: - Secciones del PDF

    private static func dibujarCabecera(context: UIGraphicsPDFRendererContext, negocio: Negocio, y: CGFloat, tituloDoc: String = "FACTURA") -> CGFloat {
        var currentY = y

        // Logo si existe
        if let logoData = negocio.logoPNG, let logo = UIImage(data: logoData) {
            let maxLogoH: CGFloat = 50
            let aspect = logo.size.width / logo.size.height
            let logoW = min(maxLogoH * aspect, 120)
            let logoRect = CGRect(x: margin, y: currentY, width: logoW, height: maxLogoH)
            logo.draw(in: logoRect)
        }

        // Nombre del negocio
        let nombreAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: FacturaPDFConfig.primario
        ]
        let nombreStr = negocio.nombre as NSString
        nombreStr.draw(at: CGPoint(x: margin, y: currentY + 55), withAttributes: nombreAttr)

        // "FACTURA" o "PRESUPUESTO" a la derecha
        let facturaAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: FacturaPDFConfig.primario
        ]
        let facturaStr = tituloDoc as NSString
        let facturaSize = facturaStr.size(withAttributes: facturaAttr)
        facturaStr.draw(at: CGPoint(x: pageWidth - margin - facturaSize.width, y: currentY + 10), withAttributes: facturaAttr)

        currentY += 85
        return currentY
    }

    private static func dibujarDatosEmisorCliente(context: UIGraphicsPDFRendererContext, factura: Factura, negocio: Negocio, y: CGFloat) -> CGFloat {
        let colWidth = contentWidth / 2 - 10
        var currentY = y

        // Emisor (izquierda)
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: FacturaPDFConfig.secundario
        ]
        let dataAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]

        ("DE:" as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: labelAttr)
        currentY += 14

        let emisorLineas = [
            negocio.nombre,
            negocio.nif.isEmpty ? "" : "NIF: \(negocio.nif)",
            negocio.direccion,
            [negocio.codigoPostal, negocio.ciudad].filter { !$0.isEmpty }.joined(separator: " "),
            negocio.provincia,
            negocio.telefono.isEmpty ? "" : "Tel: \(negocio.telefono)",
            negocio.email
        ].filter { !$0.isEmpty }

        for linea in emisorLineas {
            (linea as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: dataAttr)
            currentY += 13
        }

        // Cliente (derecha) con fondo y borde
        let clienteX = margin + colWidth + 20
        let clienteBoxY = y
        let clienteBoxH: CGFloat = max(CGFloat(emisorLineas.count) * 13 + 20, 80)

        let clienteRect = CGRect(x: clienteX, y: clienteBoxY, width: colWidth, height: clienteBoxH)
        FacturaPDFConfig.fondoRecuadro.setFill()
        context.fill(clienteRect)
        FacturaPDFConfig.secundario.setStroke()
        context.stroke(clienteRect)

        var cY = clienteBoxY + 8
        ("PARA:" as NSString).draw(at: CGPoint(x: clienteX + 10, y: cY), withAttributes: labelAttr)
        cY += 14

        let clienteLineas = [
            factura.clienteNombre,
            factura.clienteNIF.isEmpty ? "" : "NIF: \(factura.clienteNIF)",
            factura.clienteDireccion
        ].filter { !$0.isEmpty }

        for linea in clienteLineas {
            let rect = CGRect(x: clienteX + 10, y: cY, width: colWidth - 20, height: 30)
            (linea as NSString).draw(in: rect, withAttributes: dataAttr)
            cY += 13
        }

        return max(currentY, clienteBoxY + clienteBoxH) + 15
    }

    private static func dibujarRecuadrosInfo(context: UIGraphicsPDFRendererContext, factura: Factura, y: CGFloat) -> CGFloat {
        let boxW = contentWidth / 3 - 8
        let boxH: CGFloat = 40
        let datos: [(String, String)] = [
            ("Nº FACTURA", factura.numeroFactura),
            ("FECHA", Formateadores.fechaCorta.string(from: factura.fecha)),
            ("VENCIMIENTO", factura.fechaVencimiento.map { Formateadores.fechaCorta.string(from: $0) } ?? "—")
        ]

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .semibold),
            .foregroundColor: FacturaPDFConfig.secundario
        ]
        let valorAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: FacturaPDFConfig.primario
        ]

        for (i, (label, valor)) in datos.enumerated() {
            let x = margin + CGFloat(i) * (boxW + 12)
            let rect = CGRect(x: x, y: y, width: boxW, height: boxH)
            FacturaPDFConfig.fondoRecuadro.setFill()
            context.fill(rect)

            (label as NSString).draw(at: CGPoint(x: x + 8, y: y + 6), withAttributes: labelAttr)
            (valor as NSString).draw(at: CGPoint(x: x + 8, y: y + 20), withAttributes: valorAttr)
        }

        return y + boxH + 20
    }

    private static func dibujarTablaLineas(context: UIGraphicsPDFRendererContext, factura: Factura, y: CGFloat, pdfContext: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = y
        let colWidths: [CGFloat] = [contentWidth * 0.38, contentWidth * 0.10, contentWidth * 0.10, contentWidth * 0.14, contentWidth * 0.12, contentWidth * 0.16]
        let headers = ["Concepto", "Cant.", "Ud.", "P. Unit.", "IVA", "Subtotal"]

        // Cabecera de tabla
        let headerRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 22)
        FacturaPDFConfig.primario.setFill()
        pdfContext.fill(headerRect)

        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: UIColor.white
        ]

        var hx = margin + 4
        for (i, header) in headers.enumerated() {
            (header as NSString).draw(at: CGPoint(x: hx, y: currentY + 5), withAttributes: headerAttr)
            hx += colWidths[i]
        }
        currentY += 22

        // Filas
        let rowAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]

        for (index, linea) in factura.lineasOrdenadas.enumerated() {
            // Verificar si necesitamos nueva página
            if currentY > pageHeight - 150 {
                pdfContext.beginPage()
                currentY = 40
            }

            // Fila alterna
            if index % 2 == 0 {
                let rowRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 20)
                FacturaPDFConfig.fondoRecuadro.setFill()
                pdfContext.fill(rowRect)
            }

            var rx = margin + 4
            let valores = [
                linea.concepto,
                String(format: "%.2f", linea.cantidad),
                linea.unidad.abreviatura,
                formatEurosPDF(linea.precioUnitario),
                String(format: "%.0f%%", linea.porcentajeIVA),
                formatEurosPDF(linea.subtotal)
            ]
            for (i, valor) in valores.enumerated() {
                let drawRect = CGRect(x: rx, y: currentY + 4, width: colWidths[i] - 4, height: 16)
                (valor as NSString).draw(in: drawRect, withAttributes: rowAttr)
                rx += colWidths[i]
            }
            currentY += 20
        }

        // Línea separadora
        FacturaPDFConfig.secundario.setStroke()
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: currentY))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
        linePath.lineWidth = 0.5
        linePath.stroke()

        return currentY + 15
    }

    private static func dibujarTotales(context: UIGraphicsPDFRendererContext, factura: Factura, y: CGFloat) -> CGFloat {
        var currentY = y
        let totalesX = pageWidth - margin - 200
        let totalesW: CGFloat = 200

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]
        let valorAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]

        func addRow(_ label: String, _ valor: String, attrs: [NSAttributedString.Key: Any]? = nil) {
            (label as NSString).draw(at: CGPoint(x: totalesX, y: currentY), withAttributes: labelAttr)
            let vAttrs = attrs ?? valorAttr
            let valorSize = (valor as NSString).size(withAttributes: vAttrs)
            (valor as NSString).draw(at: CGPoint(x: totalesX + totalesW - valorSize.width, y: currentY), withAttributes: vAttrs)
            currentY += 16
        }

        // Base imponible
        addRow("Base imponible", formatEurosPDF(factura.baseImponible))

        // Descuento global
        if factura.descuentoGlobalPorcentaje > 0 {
            let descuento = factura.lineasArray.reduce(0) { $0 + $1.subtotal } * factura.descuentoGlobalPorcentaje / 100
            let redAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: FacturaPDFConfig.rojo
            ]
            addRow("Descuento (\(String(format: "%.0f", factura.descuentoGlobalPorcentaje))%)", "-\(formatEurosPDF(descuento))", attrs: redAttr)
        }

        // Desglose IVA por tipo
        for item in factura.desgloseIVA {
            addRow("IVA \(String(format: "%.0f", item.porcentaje))% (sobre \(formatEurosPDF(item.base)))", formatEurosPDF(item.cuota))
        }

        // IRPF
        if factura.totalIRPF > 0 {
            let redAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: FacturaPDFConfig.rojo
            ]
            addRow("Retención IRPF", "-\(formatEurosPDF(factura.totalIRPF))", attrs: redAttr)
        }

        // Separador
        currentY += 4
        let sepPath = UIBezierPath()
        sepPath.move(to: CGPoint(x: totalesX, y: currentY))
        sepPath.addLine(to: CGPoint(x: totalesX + totalesW, y: currentY))
        sepPath.lineWidth = 1
        FacturaPDFConfig.primario.setStroke()
        sepPath.stroke()
        currentY += 8

        // Total
        let totalLabelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: FacturaPDFConfig.primario
        ]
        let totalValorAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: FacturaPDFConfig.acento
        ]
        ("TOTAL" as NSString).draw(at: CGPoint(x: totalesX, y: currentY), withAttributes: totalLabelAttr)
        let totalStr = formatEurosPDF(factura.totalFactura)
        let totalSize = (totalStr as NSString).size(withAttributes: totalValorAttr)
        (totalStr as NSString).draw(at: CGPoint(x: totalesX + totalesW - totalSize.width, y: currentY), withAttributes: totalValorAttr)

        currentY += 30
        return currentY
    }

    private static func dibujarObservaciones(context: UIGraphicsPDFRendererContext, factura: Factura, y: CGFloat) -> CGFloat {
        var currentY = y

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: FacturaPDFConfig.secundario
        ]
        let textAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]

        ("OBSERVACIONES" as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: labelAttr)
        currentY += 14

        let textRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 60)
        (factura.observaciones as NSString).draw(in: textRect, withAttributes: textAttr)

        return currentY + 60
    }

    private static func dibujarPie(context: UIGraphicsPDFRendererContext, negocio: Negocio) {
        let pieY = pageHeight - 35
        let pieAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7),
            .foregroundColor: UIColor.gray
        ]

        let pieTexto = [negocio.nombre, negocio.nif.isEmpty ? "" : "NIF: \(negocio.nif)", negocio.email]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        let pieSize = (pieTexto as NSString).size(withAttributes: pieAttr)
        (pieTexto as NSString).draw(at: CGPoint(x: (pageWidth - pieSize.width) / 2, y: pieY), withAttributes: pieAttr)
    }

    // MARK: - Código QR

    private static func dibujarQR(context: UIGraphicsPDFRendererContext, factura: Factura, negocio: Negocio) {
        let qrSize: CGFloat = 80
        let qrX = pageWidth - margin - qrSize
        let qrY = pageHeight - 55 - qrSize

        // Construir URL de verificación AEAT
        let fechaStr = formatFechaQR(factura.fecha)
        let importe = String(format: "%.2f", factura.totalFactura)
        var components = URLComponents(string: "https://www2.agenciatributaria.gob.es/wlpl/TIKE-CONT/ValidarQR")
        components?.queryItems = [
            URLQueryItem(name: "nif", value: negocio.nif),
            URLQueryItem(name: "numserie", value: factura.numeroFactura),
            URLQueryItem(name: "fecha", value: fechaStr),
            URLQueryItem(name: "importe", value: importe)
        ]
        let urlString = components?.url?.absoluteString ?? ""

        // Generar QR
        guard let qrImage = generarQRImage(from: urlString, size: qrSize) else { return }

        // Dibujar QR
        let qrRect = CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize)
        qrImage.draw(in: qrRect)

        // Texto debajo del QR
        let tieneHash = !(factura.registros ?? []).isEmpty
        let textoQR = tieneHash ? "Factura verificable" : "Factura"
        let qrTextAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6, weight: .medium),
            .foregroundColor: FacturaPDFConfig.secundario
        ]
        let textSize = (textoQR as NSString).size(withAttributes: qrTextAttr)
        let textX = qrX + (qrSize - textSize.width) / 2
        (textoQR as NSString).draw(at: CGPoint(x: textX, y: qrY + qrSize + 3), withAttributes: qrTextAttr)
    }

    private static func generarQRImage(from string: String, size: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Escalar al tamaño deseado
        let scaleX = size / ciImage.extent.width
        let scaleY = size / ciImage.extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func formatFechaQR(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy"
        return f.string(from: date)
    }

    private static func formatEurosPDF(_ valor: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "es_ES")
        return (formatter.string(from: NSNumber(value: valor)) ?? String(format: "%.2f", valor)) + " €"
    }
}

// MARK: - Vista previa de PDF

struct FacturaPDFPreviewView: View {

    let pdfData: Data
    let nombreArchivo: String
    @Environment(\.dismiss) private var dismiss
    @State private var mostrarShare = false

    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .navigationTitle(nombreArchivo)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            mostrarShare = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $mostrarShare) {
                    ShareSheet(items: [pdfData])
                }
        }
    }
}

// MARK: - PDFKit wrapper

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil {
            uiView.document = PDFDocument(data: data)
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
