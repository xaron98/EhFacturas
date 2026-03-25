// ArticulosView.swift
// FacturaApp — CRUD de artículos con categorías y FlowLayout.
// Lista con filtro de categorías, buscador, detalle y formulario.

import SwiftUI
import SwiftData

// MARK: - Lista de artículos

struct ArticulosListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Articulo> { $0.activo == true },
           sort: \Articulo.nombre)
    private var articulos: [Articulo]

    @Query(sort: \Categoria.orden)
    private var categorias: [Categoria]

    @State private var textoBusqueda = ""
    @State private var categoriaFiltro: Categoria?
    @State private var mostrarFormulario = false
    @State private var articuloDetalle: Articulo?
    @State private var articuloEditar: Articulo?

    private var articulosFiltrados: [Articulo] {
        var resultado = articulos

        if let cat = categoriaFiltro {
            resultado = resultado.filter { $0.categoria?.persistentModelID == cat.persistentModelID }
        }

        if !textoBusqueda.isEmpty {
            let q = textoBusqueda.lowercased()
            resultado = resultado.filter {
                $0.nombre.lowercased().contains(q) ||
                $0.referencia.lowercased().contains(q) ||
                $0.etiquetas.contains(where: { $0.contains(q) }) ||
                $0.proveedor.lowercased().contains(q)
            }
        }

        return resultado
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filtro de categorías horizontal
            if !categorias.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chipCategoria(nombre: "Todos", icono: "square.grid.2x2", seleccionado: categoriaFiltro == nil) {
                            categoriaFiltro = nil
                        }
                        ForEach(categorias, id: \.persistentModelID) { cat in
                            chipCategoria(nombre: cat.nombre, icono: cat.icono, seleccionado: categoriaFiltro?.persistentModelID == cat.persistentModelID) {
                                categoriaFiltro = (categoriaFiltro?.persistentModelID == cat.persistentModelID) ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }

            // Lista
            if articulos.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("Sin artículos", systemImage: "shippingbox")
                } description: {
                    Text("Añade productos y servicios a tu catálogo")
                }
                Spacer()
            } else if articulosFiltrados.isEmpty {
                Spacer()
                ContentUnavailableView.search(text: textoBusqueda)
                Spacer()
            } else {
                List {
                    ForEach(articulosFiltrados, id: \.persistentModelID) { art in
                        Button {
                            articuloDetalle = art
                        } label: {
                            ArticuloRowView(articulo: art)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                art.activo = false
                                art.fechaModificacion = .now
                                try? modelContext.save()
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            Button {
                                articuloEditar = art
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                duplicarArticulo(art)
                            } label: {
                                Label("Duplicar", systemImage: "doc.on.doc")
                            }
                            .tint(.purple)
                        }
                    }
                }
                .searchable(text: $textoBusqueda, prompt: "Buscar artículo...")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    mostrarFormulario = true
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.blue)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $mostrarFormulario) {
            NavigationStack {
                ArticuloFormularioView(articulo: nil)
            }
        }
        .sheet(item: $articuloDetalle) { art in
            NavigationStack {
                ArticuloDetalleView(articulo: art)
            }
        }
        .sheet(item: $articuloEditar) { art in
            NavigationStack {
                ArticuloFormularioView(articulo: art)
            }
        }
    }

    private func chipCategoria(nombre: String, icono: String, seleccionado: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 4) {
                Image(systemName: icono)
                    .font(.caption2)
                Text(nombre)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(seleccionado ? Color.blue : Color(.systemGray6))
            .foregroundStyle(seleccionado ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func duplicarArticulo(_ original: Articulo) {
        let copia = Articulo(
            referencia: original.referencia + "-copia",
            nombre: original.nombre + " (copia)",
            descripcion: original.descripcion,
            precioUnitario: original.precioUnitario,
            precioCoste: original.precioCoste,
            unidad: original.unidad,
            tipoIVA: original.tipoIVA,
            proveedor: original.proveedor,
            etiquetas: original.etiquetas
        )
        copia.categoria = original.categoria
        modelContext.insert(copia)
        try? modelContext.save()
    }
}

// MARK: - Fila de artículo

struct ArticuloRowView: View {

    let articulo: Articulo

    var body: some View {
        HStack(spacing: 12) {
            // Icono de categoría
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: articulo.categoria?.icono ?? "shippingbox")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(articulo.nombre)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if !articulo.referencia.isEmpty {
                        Text(articulo.referencia)
                            .foregroundStyle(.secondary)
                    }
                    if let cat = articulo.categoria {
                        Text(cat.nombre)
                            .foregroundStyle(.blue)
                    }
                }
                .font(.caption)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formateadores.formatEuros(articulo.precioUnitario))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text("/\(articulo.unidad.abreviatura)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detalle del artículo

struct ArticuloDetalleView: View {

    let articulo: Articulo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Cabecera
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: articulo.categoria?.icono ?? "shippingbox")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text(articulo.nombre)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    if !articulo.referencia.isEmpty {
                        Text("Ref: \(articulo.referencia)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !articulo.descripcion.isEmpty {
                        Text(articulo.descripcion)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Precios
            Section("Precios") {
                HStack {
                    Text("Precio venta (sin IVA)")
                    Spacer()
                    Text(Formateadores.formatEuros(articulo.precioUnitario))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Precio con IVA (\(articulo.tipoIVA.descripcion))")
                    Spacer()
                    Text(Formateadores.formatEuros(articulo.precioConIVA))
                }
                if articulo.precioCoste > 0 {
                    HStack {
                        Text("Precio coste")
                        Spacer()
                        Text(Formateadores.formatEuros(articulo.precioCoste))
                    }
                    HStack {
                        Text("Margen")
                        Spacer()
                        Text(String(format: "%.1f%%", articulo.margen))
                            .foregroundStyle(articulo.margen > 0 ? .green : .red)
                    }
                }
                HStack {
                    Text("Unidad")
                    Spacer()
                    Text(articulo.unidad.descripcion)
                }
            }

            // Etiquetas
            if !articulo.etiquetas.isEmpty {
                Section("Etiquetas") {
                    FlowLayout(spacing: 6) {
                        ForEach(articulo.etiquetas, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Proveedor
            if !articulo.proveedor.isEmpty {
                Section("Proveedor") {
                    Text(articulo.proveedor)
                    if !articulo.referenciaProveedor.isEmpty {
                        HStack {
                            Text("Ref. proveedor")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(articulo.referenciaProveedor)
                        }
                    }
                }
            }
        }
        .navigationTitle("Artículo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
    }
}

// MARK: - Formulario de artículo

struct ArticuloFormularioView: View {

    let articulo: Articulo?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Categoria.orden) private var categorias: [Categoria]

    @State private var nombre = ""
    @State private var referencia = ""
    @State private var descripcion = ""
    @State private var precioTexto = ""
    @State private var precioCosteTexto = ""
    @State private var unidad: UnidadMedida = .unidad
    @State private var tipoIVA: TipoIVA = .general
    @State private var proveedor = ""
    @State private var referenciaProveedor = ""
    @State private var categoriaSeleccionada: Categoria?
    @State private var etiquetasTexto = ""

    var esNuevo: Bool { articulo == nil }

    private var precioConIVA: Double {
        let precio = Formateadores.parsearPrecio(precioTexto) ?? 0
        return precio * (1 + tipoIVA.porcentaje / 100)
    }

    var body: some View {
        Form {
            Section("Datos básicos") {
                TextField("Nombre *", text: $nombre)
                TextField("Referencia / código", text: $referencia)
                TextField("Descripción", text: $descripcion)
            }

            Section("Precio y unidad") {
                HStack {
                    Text("Precio sin IVA")
                    Spacer()
                    TextField("0,00", text: $precioTexto)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text("€")
                }
                HStack {
                    Text("Precio coste")
                    Spacer()
                    TextField("0,00", text: $precioCosteTexto)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text("€")
                }
                Picker("Unidad", selection: $unidad) {
                    ForEach(UnidadMedida.allCases) { u in
                        Text("\(u.descripcion) (\(u.rawValue))").tag(u)
                    }
                }
            }

            Section {
                Picker("Tipo de IVA", selection: $tipoIVA) {
                    ForEach(TipoIVA.allCases) { t in
                        Text(t.descripcion).tag(t)
                    }
                }
                HStack {
                    Text("Precio con IVA")
                    Spacer()
                    Text(Formateadores.formatEuros(precioConIVA))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("IVA")
            } footer: {
                Text("El precio con IVA se calcula automáticamente")
            }

            Section("Categoría") {
                Picker("Categoría", selection: $categoriaSeleccionada) {
                    Text("Sin categoría").tag(nil as Categoria?)
                    ForEach(categorias, id: \.persistentModelID) { cat in
                        Label(cat.nombre, systemImage: cat.icono).tag(cat as Categoria?)
                    }
                }
            }

            Section {
                TextField("led, iluminación, bajo consumo", text: $etiquetasTexto)
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Etiquetas")
            } footer: {
                Text("Separadas por comas. Ayudan a la IA a encontrar el artículo.")
            }

            Section("Proveedor") {
                TextField("Nombre del proveedor", text: $proveedor)
                TextField("Referencia del proveedor", text: $referenciaProveedor)
            }
        }
        .navigationTitle(esNuevo ? "Nuevo artículo" : "Editar artículo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { guardar() }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let a = articulo {
                nombre = a.nombre
                referencia = a.referencia
                descripcion = a.descripcion
                precioTexto = String(format: "%.2f", a.precioUnitario).replacingOccurrences(of: ".", with: ",")
                precioCosteTexto = a.precioCoste > 0 ? String(format: "%.2f", a.precioCoste).replacingOccurrences(of: ".", with: ",") : ""
                unidad = a.unidad
                tipoIVA = a.tipoIVA
                proveedor = a.proveedor
                referenciaProveedor = a.referenciaProveedor
                categoriaSeleccionada = a.categoria
                etiquetasTexto = a.etiquetas.joined(separator: ", ")
            }
        }
    }

    private func guardar() {
        let tags = etiquetasTexto
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        let precio = Formateadores.parsearPrecio(precioTexto) ?? 0
        let coste = Formateadores.parsearPrecio(precioCosteTexto) ?? 0

        if let a = articulo {
            a.nombre = nombre.trimmingCharacters(in: .whitespaces)
            a.referencia = referencia
            a.descripcion = descripcion
            a.precioUnitario = precio
            a.precioCoste = coste
            a.unidad = unidad
            a.tipoIVA = tipoIVA
            a.proveedor = proveedor
            a.referenciaProveedor = referenciaProveedor
            a.categoria = categoriaSeleccionada
            a.etiquetas = tags
            a.fechaModificacion = .now
        } else {
            let nuevo = Articulo(
                referencia: referencia,
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                descripcion: descripcion,
                precioUnitario: precio,
                precioCoste: coste,
                unidad: unidad,
                tipoIVA: tipoIVA,
                proveedor: proveedor,
                etiquetas: tags
            )
            nuevo.referenciaProveedor = referenciaProveedor
            nuevo.categoria = categoriaSeleccionada
            modelContext.insert(nuevo)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
        var sizes: [CGSize]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return LayoutResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions,
            sizes: sizes
        )
    }
}

extension Articulo: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}
