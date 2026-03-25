// ClientesView.swift
// FacturaApp — CRUD de clientes
// Lista con buscador, detalle, formulario de edición/creación.

import SwiftUI
import SwiftData

// MARK: - Lista de clientes

struct ClientesListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Cliente> { $0.activo == true },
           sort: \Cliente.nombre)
    private var clientes: [Cliente]

    @State private var textoBusqueda = ""
    @State private var clienteSeleccionado: Cliente?
    @State private var mostrarFormulario = false
    @State private var clienteEditar: Cliente?

    private var clientesFiltrados: [Cliente] {
        if textoBusqueda.isEmpty { return clientes }
        let q = textoBusqueda.lowercased()
        return clientes.filter {
            $0.nombre.lowercased().contains(q) ||
            $0.telefono.contains(q) ||
            $0.nif.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if clientes.isEmpty {
                ContentUnavailableView {
                    Label("Sin clientes", systemImage: "person.2")
                } description: {
                    Text("Añade tu primer cliente con el micrófono o pulsando +")
                }
            } else {
                List {
                    ForEach(clientesFiltrados) { cliente in
                        Button {
                            clienteSeleccionado = cliente
                        } label: {
                            ClienteRowView(cliente: cliente)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                desactivarCliente(cliente)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            Button {
                                clienteEditar = cliente
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            if !cliente.telefono.isEmpty {
                                Button {
                                    if let tel = URL(string: "tel:\(cliente.telefono)") {
                                        UIApplication.shared.open(tel)
                                    }
                                } label: {
                                    Label("Llamar", systemImage: "phone")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
                .searchable(text: $textoBusqueda, prompt: "Buscar cliente...")
            }
        }
        .sheet(item: $clienteSeleccionado) { cliente in
            NavigationStack {
                ClienteDetalleView(cliente: cliente)
            }
        }
        .sheet(isPresented: $mostrarFormulario) {
            NavigationStack {
                ClienteFormularioView(cliente: nil)
            }
        }
        .sheet(item: $clienteEditar) { cliente in
            NavigationStack {
                ClienteFormularioView(cliente: cliente)
            }
        }
    }

    private func desactivarCliente(_ cliente: Cliente) {
        cliente.activo = false
        cliente.fechaModificacion = .now
        try? modelContext.save()
    }
}

// MARK: - Fila de cliente

struct ClienteRowView: View {

    let cliente: Cliente

    var body: some View {
        HStack(spacing: 12) {
            // Avatar con iniciales
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(cliente.iniciales)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cliente.nombre)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if !cliente.telefono.isEmpty {
                        Label(cliente.telefono, systemImage: "phone")
                    }
                    if !cliente.nif.isEmpty {
                        Label(cliente.nif, systemImage: "doc.text")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Badge con número de facturas
            if !(cliente.facturas ?? []).isEmpty {
                Text("\((cliente.facturas ?? []).count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detalle del cliente

struct ClienteDetalleView: View {

    let cliente: Cliente
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Cabecera
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.12))
                            .frame(width: 60, height: 60)
                        Text(cliente.iniciales)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cliente.nombre)
                            .font(.title3)
                            .fontWeight(.semibold)
                        if !cliente.nif.isEmpty {
                            Text("NIF: \(cliente.nif)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Contacto
            if !cliente.telefono.isEmpty || !cliente.email.isEmpty {
                Section("Contacto") {
                    if !cliente.telefono.isEmpty {
                        HStack {
                            Label(cliente.telefono, systemImage: "phone")
                            Spacer()
                            if let url = URL(string: "tel:\(cliente.telefono)") {
                                Link("Llamar", destination: url)
                                    .font(.caption)
                            }
                        }
                    }
                    if !cliente.email.isEmpty {
                        HStack {
                            Label(cliente.email, systemImage: "envelope")
                            Spacer()
                            if let url = URL(string: "mailto:\(cliente.email)") {
                                Link("Email", destination: url)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            // Dirección
            if !cliente.direccion.isEmpty || !cliente.ciudad.isEmpty {
                Section("Dirección") {
                    VStack(alignment: .leading, spacing: 4) {
                        if !cliente.direccion.isEmpty { Text(cliente.direccion) }
                        HStack {
                            if !cliente.codigoPostal.isEmpty { Text(cliente.codigoPostal) }
                            if !cliente.ciudad.isEmpty { Text(cliente.ciudad) }
                        }
                        if !cliente.provincia.isEmpty { Text(cliente.provincia) }
                    }
                    .font(.subheadline)
                }
            }

            // Últimas facturas
            if !(cliente.facturas ?? []).isEmpty {
                Section("Facturas (\((cliente.facturas ?? []).count))") {
                    ForEach((cliente.facturas ?? []).sorted(by: { $0.fecha > $1.fecha }).prefix(5), id: \.persistentModelID) { factura in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(factura.numeroFactura)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(factura.fecha, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Formateadores.formatEuros(factura.totalFactura))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                EstadoBadge(estado: factura.estado)
                            }
                        }
                    }
                }
            }

            // Observaciones
            if !cliente.observaciones.isEmpty {
                Section("Observaciones") {
                    Text(cliente.observaciones)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Cliente")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
    }
}

// MARK: - Formulario de cliente

struct ClienteFormularioView: View {

    let cliente: Cliente?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var nombre = ""
    @State private var nif = ""
    @State private var telefono = ""
    @State private var email = ""
    @State private var direccion = ""
    @State private var codigoPostal = ""
    @State private var ciudad = ""
    @State private var provincia = ""
    @State private var observaciones = ""

    var esNuevo: Bool { cliente == nil }

    var body: some View {
        Form {
            Section("Datos básicos") {
                TextField("Nombre *", text: $nombre)
                    .textContentType(.name)
                TextField("NIF / CIF", text: $nif)
                TextField("Teléfono", text: $telefono)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            Section("Dirección") {
                TextField("Dirección", text: $direccion)
                    .textContentType(.streetAddressLine1)
                HStack {
                    TextField("C.P.", text: $codigoPostal)
                        .textContentType(.postalCode)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                    TextField("Ciudad", text: $ciudad)
                        .textContentType(.addressCity)
                }
                TextField("Provincia", text: $provincia)
                    .textContentType(.addressState)
            }

            Section("Notas") {
                TextEditor(text: $observaciones)
                    .frame(minHeight: 60)
            }
        }
        .navigationTitle(esNuevo ? "Nuevo cliente" : "Editar cliente")
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
            if let c = cliente {
                nombre = c.nombre
                nif = c.nif
                telefono = c.telefono
                email = c.email
                direccion = c.direccion
                codigoPostal = c.codigoPostal
                ciudad = c.ciudad
                provincia = c.provincia
                observaciones = c.observaciones
            }
        }
    }

    private func guardar() {
        if let c = cliente {
            c.nombre = nombre.trimmingCharacters(in: .whitespaces)
            c.nif = nif
            c.telefono = telefono
            c.email = email
            c.direccion = direccion
            c.codigoPostal = codigoPostal
            c.ciudad = ciudad
            c.provincia = provincia
            c.observaciones = observaciones
            c.fechaModificacion = .now
        } else {
            let nuevo = Cliente(
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                nif: nif,
                direccion: direccion,
                codigoPostal: codigoPostal,
                ciudad: ciudad,
                provincia: provincia,
                telefono: telefono,
                email: email,
                observaciones: observaciones
            )
            modelContext.insert(nuevo)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Badge de estado

struct EstadoBadge: View {
    let estado: EstadoFactura

    var body: some View {
        Text(estado.descripcion)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch estado {
        case .presupuesto: return .purple
        case .borrador: return .gray
        case .emitida: return .blue
        case .pagada: return .green
        case .vencida: return .red
        case .anulada: return .orange
        }
    }
}

extension Cliente: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}
