// ImportadorService.swift
// FacturaApp — Importador CSV universal
// Parser CSV + detección encoding + servicio de importación + vista

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - CSV Parser

enum CSVParser {

    struct ResultadoCSV {
        var cabeceras: [String]
        var filas: [[String]]
        var separador: String
        var encoding: String
    }

    static func parsear(data: Data) -> ResultadoCSV? {
        // Probar encodings: UTF-8, ISO-8859-1, Windows-1252
        let encodings: [(String.Encoding, String)] = [
            (.utf8, "utf8"),
            (.isoLatin1, "latin1"),
            (.windowsCP1252, "windows1252")
        ]

        for (encoding, nombre) in encodings {
            if let texto = String(data: data, encoding: encoding) {
                if let resultado = parsearTexto(texto, encoding: nombre) {
                    return resultado
                }
            }
        }
        return nil
    }

    private static func parsearTexto(_ texto: String, encoding: String) -> ResultadoCSV? {
        let lineas = texto.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lineas.count >= 2 else { return nil }

        // Detectar separador
        let separador = detectarSeparador(lineas[0])

        let cabeceras = parsearLinea(lineas[0], separador: separador)
        guard cabeceras.count >= 2 else { return nil }

        var filas: [[String]] = []
        for i in 1..<lineas.count {
            let fila = parsearLinea(lineas[i], separador: separador)
            if fila.count >= 2 {
                filas.append(fila)
            }
        }

        guard !filas.isEmpty else { return nil }

        return ResultadoCSV(
            cabeceras: cabeceras,
            filas: filas,
            separador: String(separador),
            encoding: encoding
        )
    }

    private static func detectarSeparador(_ linea: String) -> Character {
        let candidatos: [(Character, Int)] = [
            (";", linea.filter { $0 == ";" }.count),
            (",", linea.filter { $0 == "," }.count),
            ("\t", linea.filter { $0 == "\t" }.count)
        ]
        return candidatos.max(by: { $0.1 < $1.1 })?.0 ?? ";"
    }

    private static func parsearLinea(_ linea: String, separador: Character) -> [String] {
        var campos: [String] = []
        var campoActual = ""
        var dentroComillas = false

        for char in linea {
            if char == "\"" {
                dentroComillas.toggle()
            } else if char == separador && !dentroComillas {
                campos.append(campoActual.trimmingCharacters(in: .whitespaces))
                campoActual = ""
            } else {
                campoActual.append(char)
            }
        }
        campos.append(campoActual.trimmingCharacters(in: .whitespaces))

        return campos
    }
}

// MARK: - Servicio de importación

@MainActor
final class ImportadorService: ObservableObject {

    @Published var progreso: Double = 0
    @Published var importando = false
    @Published var resultado: ResultadoImportacion?

    struct ResultadoImportacion {
        var importados: Int
        var duplicados: Int
        var errores: Int
        var mensajes: [String]
    }

    func importarArticulos(filas: [[String]], mapeo: MapeoUniversal, modelContext: ModelContext) {
        importando = true
        progreso = 0
        var importados = 0
        var duplicados = 0
        var errores = 0
        var mensajes: [String] = []

        // Cargar artículos existentes para detectar duplicados
        let desc = FetchDescriptor<Articulo>(predicate: #Predicate<Articulo> { $0.activo == true })
        let existentes = (try? modelContext.fetch(desc)) ?? []
        let refsExistentes = Set(existentes.map { $0.referencia.lowercased() }.filter { !$0.isEmpty })
        let nombresExistentes = Set(existentes.map { $0.nombre.lowercased() })

        for (i, fila) in filas.enumerated() {
            progreso = Double(i + 1) / Double(filas.count)

            let nombre = mapeo.valor("nombre", en: fila)
            guard !nombre.isEmpty else {
                errores += 1
                continue
            }

            let ref = mapeo.valor("referencia", en: fila)

            // Detectar duplicado
            if !ref.isEmpty && refsExistentes.contains(ref.lowercased()) {
                duplicados += 1
                continue
            }
            if nombresExistentes.contains(nombre.lowercased()) {
                duplicados += 1
                continue
            }

            let precio = mapeo.valorDouble("precio", en: fila)
            let coste = mapeo.valorDouble("precioCoste", en: fila)
            let proveedorNombre = mapeo.valor("proveedor", en: fila)

            // Generar etiquetas automáticas
            let palabras = nombre.lowercased()
                .components(separatedBy: .whitespaces)
                .filter { $0.count > 2 }
            let etiquetas = Array(Set(palabras).prefix(5))

            let articulo = Articulo(
                referencia: ref,
                nombre: nombre,
                descripcion: mapeo.valor("descripcion", en: fila),
                precioUnitario: precio,
                precioCoste: coste,
                proveedor: proveedorNombre,
                etiquetas: etiquetas
            )

            modelContext.insert(articulo)
            importados += 1
        }

        try? modelContext.save()

        mensajes.append("\(importados) artículos importados")
        if duplicados > 0 { mensajes.append("\(duplicados) duplicados omitidos") }
        if errores > 0 { mensajes.append("\(errores) filas con error") }

        resultado = ResultadoImportacion(
            importados: importados,
            duplicados: duplicados,
            errores: errores,
            mensajes: mensajes
        )
        importando = false

        EventLogService.registrar(
            tipo: "IMPORTACION",
            descripcion: "Importados \(importados) artículos (\(duplicados) duplicados, \(errores) errores)",
            modelContext: modelContext
        )
    }

    func importarClientes(filas: [[String]], mapeo: MapeoUniversal, modelContext: ModelContext) {
        importando = true
        progreso = 0
        var importados = 0
        var duplicados = 0
        var errores = 0
        var mensajes: [String] = []

        let desc = FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo == true })
        let existentes = (try? modelContext.fetch(desc)) ?? []
        let nifsExistentes = Set(existentes.map { $0.nif.lowercased() }.filter { !$0.isEmpty })
        let nombresExistentes = Set(existentes.map { $0.nombre.lowercased() })

        for (i, fila) in filas.enumerated() {
            progreso = Double(i + 1) / Double(filas.count)

            let nombre = mapeo.valor("nombre", en: fila)
            guard !nombre.isEmpty else {
                errores += 1
                continue
            }

            let nif = mapeo.valor("nif", en: fila)

            if !nif.isEmpty && nifsExistentes.contains(nif.lowercased()) {
                duplicados += 1
                continue
            }
            if nombresExistentes.contains(nombre.lowercased()) {
                duplicados += 1
                continue
            }

            let cliente = Cliente(
                nombre: nombre,
                nif: nif,
                direccion: mapeo.valor("direccion", en: fila),
                codigoPostal: mapeo.valor("codigoPostal", en: fila),
                ciudad: mapeo.valor("ciudad", en: fila),
                provincia: mapeo.valor("provincia", en: fila),
                telefono: mapeo.valor("telefono", en: fila),
                email: mapeo.valor("email", en: fila)
            )

            modelContext.insert(cliente)
            importados += 1
        }

        try? modelContext.save()

        mensajes.append("\(importados) clientes importados")
        if duplicados > 0 { mensajes.append("\(duplicados) duplicados omitidos") }
        if errores > 0 { mensajes.append("\(errores) filas con error") }

        resultado = ResultadoImportacion(
            importados: importados,
            duplicados: duplicados,
            errores: errores,
            mensajes: mensajes
        )
        importando = false

        EventLogService.registrar(
            tipo: "IMPORTACION",
            descripcion: "Importados \(importados) clientes (\(duplicados) duplicados, \(errores) errores)",
            modelContext: modelContext
        )
    }
}

// MARK: - Vista de importación

struct ImportarView: View {

    let tipo: TipoImportacion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var importador = ImportadorService()

    @State private var mostrarFilePicker = true
    @State private var csv: CSVParser.ResultadoCSV?
    @State private var mapeo: MapeoUniversal?
    @State private var mostrarMapeoManual = false
    @State private var mapeoManual: [String: Int] = [:]
    @State private var guardarPerfil = false
    @State private var nombrePerfil = ""

    var body: some View {
        NavigationStack {
            Group {
                if let resultado = importador.resultado {
                    resultadoView(resultado)
                } else if importador.importando {
                    importandoView
                } else if let csv, let mapeo {
                    previsualizacionView(csv: csv, mapeo: mapeo)
                } else {
                    esperandoArchivoView
                }
            }
            .navigationTitle("Importar \(tipo == .articulos ? "artículos" : "clientes")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $mostrarFilePicker,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText,
                                      UTType(filenameExtension: "csv") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    cargarArchivo(url)
                }
            }
            .sheet(isPresented: $mostrarMapeoManual) {
                MapeoManualView(
                    cabeceras: csv?.cabeceras ?? [],
                    tipo: tipo,
                    mapeo: $mapeoManual
                )
            }
            .onChange(of: mostrarMapeoManual) { _, showing in
                if !showing && !mapeoManual.isEmpty {
                    // Aplicar mapeo manual
                    mapeo = MapeoUniversal(
                        columnas: csv?.cabeceras ?? [],
                        mapeo: mapeoManual,
                        programaDetectado: mapeo?.programaDetectado ?? .init(nombre: "Manual", confianza: 1.0)
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private var esperandoArchivoView: some View {
        ContentUnavailableView {
            Label("Selecciona un archivo", systemImage: "doc.badge.arrow.up")
        } description: {
            Text("CSV o texto separado por comas, punto y coma, o tabuladores")
        } actions: {
            Button("Seleccionar archivo") {
                mostrarFilePicker = true
            }
        }
    }

    private func previsualizacionView(csv: CSVParser.ResultadoCSV, mapeo: MapeoUniversal) -> some View {
        List {
            // Detección
            Section {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Programa detectado: \(mapeo.programaDetectado.nombre)")
                            .font(.subheadline).fontWeight(.medium)
                        Text("Confianza: \(String(format: "%.0f", mapeo.programaDetectado.confianza * 100))% — \(csv.filas.count) filas")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // Campos mapeados
            Section("Campos detectados (\(mapeo.camposMapeados))") {
                let campos = tipo == .articulos ? MapeoUniversal.camposArticulo : MapeoUniversal.camposCliente
                ForEach(campos, id: \.id) { campo in
                    HStack {
                        Image(systemName: mapeo.mapeo[campo.id] != nil ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(mapeo.mapeo[campo.id] != nil ? Color.green : Color.gray)
                            .font(.caption)
                        Text(campo.label)
                            .font(.subheadline)
                        if campo.obligatorio {
                            Text("*").foregroundStyle(.red).font(.caption)
                        }
                        Spacer()
                        if let idx = mapeo.mapeo[campo.id], idx < csv.cabeceras.count {
                            Text(csv.cabeceras[idx])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                Button {
                    mapeoManual = mapeo.mapeo
                    mostrarMapeoManual = true
                } label: {
                    Label("Mapear manualmente", systemImage: "slider.horizontal.3")
                }
            }

            // Preview de filas
            Section("Vista previa (primeras 3 filas)") {
                ForEach(Array(csv.filas.prefix(3).enumerated()), id: \.offset) { _, fila in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mapeo.valor("nombre", en: fila))
                            .font(.subheadline).fontWeight(.medium)
                        HStack(spacing: 8) {
                            if tipo == .articulos {
                                let precio = mapeo.valorDouble("precio", en: fila)
                                if precio > 0 {
                                    Text(Formateadores.formatEuros(precio))
                                }
                                let ref = mapeo.valor("referencia", en: fila)
                                if !ref.isEmpty { Text("Ref: \(ref)") }
                            } else {
                                let nif = mapeo.valor("nif", en: fila)
                                if !nif.isEmpty { Text("NIF: \(nif)") }
                                let tel = mapeo.valor("telefono", en: fila)
                                if !tel.isEmpty { Text("Tel: \(tel)") }
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // Botón importar
            Section {
                Button {
                    ejecutarImportacion(csv: csv, mapeo: mapeo)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Importar \(csv.filas.count) \(tipo == .articulos ? "artículos" : "clientes")")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                }
                .disabled(!mapeo.tieneNombre)
            }
        }
    }

    private var importandoView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView(value: importador.progreso) {
                Text("Importando...")
                    .font(.subheadline)
            }
            .padding(.horizontal, 40)
            Text("\(String(format: "%.0f", importador.progreso * 100))%")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func resultadoView(_ resultado: ImportadorService.ResultadoImportacion) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: resultado.errores == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(resultado.errores == 0 ? .green : .orange)

            Text("Importación completada")
                .font(.title3).fontWeight(.bold)

            VStack(spacing: 6) {
                ForEach(resultado.mensajes, id: \.self) { msg in
                    Text(msg).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            // Guardar perfil
            if !guardarPerfil {
                Button("Guardar como perfil") {
                    nombrePerfil = mapeo?.programaDetectado.nombre ?? "Perfil"
                    guardarPerfil = true
                }
                .font(.subheadline)
            } else {
                HStack {
                    TextField("Nombre del perfil", text: $nombrePerfil)
                        .textFieldStyle(.roundedBorder)
                    Button("Guardar") {
                        guardarPerfilImportacion()
                        guardarPerfil = false
                    }
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            Button("Cerrar") { dismiss() }
                .fontWeight(.semibold)
                .padding(.bottom)
        }
    }

    // MARK: - Lógica

    private func cargarArchivo(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return }
        guard let parsed = CSVParser.parsear(data: data) else { return }

        csv = parsed
        let detected = MapeoUniversal.detectar(cabeceras: parsed.cabeceras, tipo: tipo)
        mapeo = detected
        mapeoManual = detected.mapeo
    }

    private func ejecutarImportacion(csv: CSVParser.ResultadoCSV, mapeo: MapeoUniversal) {
        switch tipo {
        case .articulos:
            importador.importarArticulos(filas: csv.filas, mapeo: mapeo, modelContext: modelContext)
        case .clientes:
            importador.importarClientes(filas: csv.filas, mapeo: mapeo, modelContext: modelContext)
        }
    }

    private func guardarPerfilImportacion() {
        guard let mapeo, let csv else { return }
        let perfil = PerfilImportacion(
            nombre: nombrePerfil,
            tipo: tipo.rawValue,
            separador: csv.separador,
            encoding: csv.encoding,
            mapeo: mapeo.mapeo,
            cabeceras: csv.cabeceras
        )
        modelContext.insert(perfil)
        try? modelContext.save()
    }
}
