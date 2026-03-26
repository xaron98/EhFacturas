// AjustesView.swift
// FacturaApp — Configuración del negocio, impuestos, numeración,
// logo y onboarding de primera configuración.

import SwiftUI
import SwiftData
import PhotosUI
import UserNotifications
import UniformTypeIdentifiers

// MARK: - Vista de ajustes

struct AjustesView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var negocios: [Negocio]

    @State private var mostrarOnboarding = false
    @State private var mostrarImportarCertificado = false
    @State private var certificadoPassword = ""
    @State private var certificadoData: Data?
    @State private var certificadoError: String?
    @State private var certificadoExito = false
    @State private var mostrarEventLog = false
    #if DEBUG
    @State private var mostrarAPIKeyInput = false
    @State private var apiKeyTexto = ""
    #endif
    @State private var mostrarSuscripcion = false
    @State private var mostrarShareBackup = false
    @State private var backupData: Data?
    @State private var mostrarWhatsNew = false

    var body: some View {
        if let negocio = negocios.first {
            ajustesContent(negocio: negocio)
        } else {
            ContentUnavailableView {
                Label("Sin configuración", systemImage: "gear")
            } description: {
                Text("Completa la configuración inicial primero.")
            }
            .onAppear {
                mostrarOnboarding = true
            }
            .sheet(isPresented: $mostrarOnboarding) {
                OnboardingView()
            }
        }
    }

    @ViewBuilder
    private func ajustesContent(negocio: Negocio) -> some View {
        List {
            // Cabecera con logo
            Section {
                CabeceraLogoView(negocio: negocio)
            }

            // Identidad fiscal
            Section("Identidad fiscal") {
                CampoTexto("Nombre / Razón social", binding: Binding(
                    get: { negocio.nombre },
                    set: { negocio.nombre = $0 }
                ))
                CampoTexto("NIF / CIF", binding: Binding(
                    get: { negocio.nif },
                    set: { negocio.nif = $0 }
                ))
            }

            // Contacto
            Section("Contacto") {
                CampoTexto("Teléfono", binding: Binding(
                    get: { negocio.telefono },
                    set: { negocio.telefono = $0 }
                ), teclado: .phonePad)
                CampoTexto("Email", binding: Binding(
                    get: { negocio.email },
                    set: { negocio.email = $0 }
                ), teclado: .emailAddress)
            }

            // Dirección
            Section("Dirección") {
                CampoTexto("Dirección", binding: Binding(
                    get: { negocio.direccion },
                    set: { negocio.direccion = $0 }
                ))
                HStack {
                    CampoTexto("C.P.", binding: Binding(
                        get: { negocio.codigoPostal },
                        set: { negocio.codigoPostal = $0 }
                    ), teclado: .numberPad)
                    .frame(width: 80)
                    CampoTexto("Ciudad", binding: Binding(
                        get: { negocio.ciudad },
                        set: { negocio.ciudad = $0 }
                    ))
                }
                CampoTexto("Provincia", binding: Binding(
                    get: { negocio.provincia },
                    set: { negocio.provincia = $0 }
                ))
            }

            // Impuestos
            Section {
                // IVA
                HStack {
                    Text("IVA general")
                    Spacer()
                    Text("\(String(format: "%.0f", negocio.ivaGeneral))%")
                        .foregroundStyle(.secondary)
                }

                // IRPF
                Toggle("Aplicar retención IRPF", isOn: Binding(
                    get: { negocio.aplicarIRPF },
                    set: { negocio.aplicarIRPF = $0 }
                ))

                if negocio.aplicarIRPF {
                    Picker("Porcentaje IRPF", selection: Binding(
                        get: { negocio.irpfPorcentaje },
                        set: { negocio.irpfPorcentaje = $0 }
                    )) {
                        Text("7% (nuevos autónomos)").tag(7.0)
                        Text("15% (general)").tag(15.0)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Impuestos")
            } footer: {
                Text("IRPF: 7% los primeros 3 años de actividad, 15% a partir del 4º año.")
            }

            // Numeración
            Section {
                CampoTexto("Prefijo", binding: Binding(
                    get: { negocio.prefijoFactura },
                    set: { negocio.prefijoFactura = $0 }
                ))

                HStack {
                    Text("Siguiente número")
                    Spacer()
                    Text("\(negocio.siguienteNumero)")
                        .foregroundStyle(.secondary)
                }

                // Preview
                HStack {
                    Text("Vista previa")
                    Spacer()
                    Text("\(negocio.prefijoFactura)\(String(format: "%04d", negocio.siguienteNumero))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            } header: {
                Text("Numeración de facturas")
            } footer: {
                Text("Las facturas deben tener numeración correlativa.")
            }

            // Notas de pago
            Section("Condiciones de pago") {
                TextEditor(text: Binding(
                    get: { negocio.notas },
                    set: { negocio.notas = $0 }
                ))
                .frame(minHeight: 60)
            }

            // Categorías
            Section {
                Button("Crear categorías por defecto") {
                    crearCategoriasDefecto()
                }
            } header: {
                Text("Catálogo")
            } footer: {
                Text("Crea las categorías predefinidas si no existen.")
            }

            // Apariencia
            Section {
                Picker("Tema", selection: Binding(
                    get: { negocio.temaApp },
                    set: { negocio.temaApp = $0; try? modelContext.save() }
                )) {
                    Label("Automático", systemImage: "circle.lefthalf.filled").tag("auto")
                    Label("Claro", systemImage: "sun.max").tag("light")
                    Label("Oscuro", systemImage: "moon").tag("dark")
                }
                .pickerStyle(.inline)
            } header: {
                Text("Apariencia")
            }

            // Voz de la IA
            Section {
                Toggle("Voz activada", isOn: Binding(
                    get: { VozIAService.shared.vozActiva },
                    set: { VozIAService.shared.vozActiva = $0 }
                ))

                if VozIAService.shared.vozActiva {
                    Picker("Tipo de voz", selection: Binding(
                        get: { VozIAService.shared.vozSeleccionada },
                        set: { VozIAService.shared.vozSeleccionada = $0 }
                    )) {
                        ForEach(VozIAService.TipoVoz.allCases, id: \.self) { tipo in
                            Text(tipo.rawValue).tag(tipo)
                        }
                    }

                    Button("Probar voz") {
                        VozIAService.shared.hablar("Hola, soy tu asistente de facturación. ¿En qué puedo ayudarte?")
                    }
                }
            } header: {
                Text("Voz de la IA")
            } footer: {
                Text("La IA leerá las respuestas en voz alta cuando esté activada.")
            }

            // Inteligencia Artificial
            Section {
                // Active provider indicator
                HStack {
                    Image(systemName: providerIcon)
                        .foregroundStyle(providerColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Proveedor activo")
                            .font(.subheadline)
                        Text(providerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Cloud provider picker
                Picker("Proveedor cloud preferido", selection: Binding(
                    get: { negocio.cloudProvider },
                    set: { negocio.cloudProvider = $0; UserDefaults.standard.set($0, forKey: "cloudProvider"); try? modelContext.save() }
                )) {
                    Text("Claude (Anthropic)").tag("claude")
                    Text("OpenAI (GPT-4o-mini)").tag("openai")
                }

                // Dev mode: direct API key
                #if DEBUG
                if !SubscriptionManager.shared.isProSubscriber {
                    Button {
                        mostrarAPIKeyInput = true
                    } label: {
                        Label("Introducir API key (desarrollo)", systemImage: "key")
                    }
                    .font(.subheadline)
                }
                #endif

                // Subscription status
                HStack {
                    Text("Suscripción")
                    Spacer()
                    Text(SubscriptionManager.shared.isProSubscriber ? "Pro activo" : "Gratuito")
                        .font(.subheadline)
                        .foregroundStyle(SubscriptionManager.shared.isProSubscriber ? .green : .secondary)
                }

                if !SubscriptionManager.shared.isProSubscriber {
                    Button {
                        mostrarSuscripcion = true
                    } label: {
                        Label("Obtener Pro", systemImage: "star.fill")
                            .foregroundStyle(.blue)
                    }
                }
            } header: {
                Text("Inteligencia Artificial")
            } footer: {
                Text("Apple Intelligence es gratuito en dispositivos compatibles. Claude y OpenAI requieren suscripción Pro.")
            }

            // VeriFactu
            Section {
                if VeriFactuCertificateManager.certificadoInstalado {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Certificado instalado")
                                .font(.subheadline)
                            if let info = VeriFactuCertificateManager.infoCertificado() {
                                Text(info.nombre)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Eliminar") {
                            VeriFactuCertificateManager.eliminarCertificado()
                            negocio.certificadoInstalado = false
                            try? modelContext.save()
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                } else {
                    Button {
                        mostrarImportarCertificado = true
                    } label: {
                        Label("Importar certificado digital (.p12)", systemImage: "key.fill")
                    }
                }

                Toggle("Entorno de pruebas", isOn: Binding(
                    get: { negocio.usarEntornoPruebas },
                    set: { negocio.usarEntornoPruebas = $0; try? modelContext.save() }
                ))

                Toggle("Envío automático a AEAT", isOn: Binding(
                    get: { negocio.envioAutomatico },
                    set: { negocio.envioAutomatico = $0; try? modelContext.save() }
                ))

                Button {
                    mostrarEventLog = true
                } label: {
                    Label("Ver log de eventos", systemImage: "list.bullet.clipboard")
                }
            } header: {
                Text("VeriFactu — Conexión AEAT")
            } footer: {
                Text("Importa tu certificado digital (.p12) para enviar facturas a la AEAT. Usa el entorno de pruebas durante el desarrollo.")
            }

            // Registro de fabricante de software
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DECLARACIÓN RESPONSABLE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    Text("El presente sistema informático de facturación cumple con los requisitos establecidos en el Reglamento aprobado por el Real Decreto 1007/2023, de 5 de diciembre.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Divider()

                    Group {
                        infoRow("Software", "EhFacturas!")
                        infoRow("Versión", "1.0")
                        infoRow("ID Sistema", "01")
                        infoRow("Desarrollador", "FacturaApp Dev")
                        infoRow("NIF Desarrollador", "—")
                        infoRow("Tipo uso", "Solo VeriFactu")
                        infoRow("Multi-OT", "No")
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Registro de fabricante")
            } footer: {
                Text("Información del sistema informático de facturación conforme al RD 1007/2023.")
            }

            // Copia de seguridad
            Section {
                Button {
                    exportarBackup()
                } label: {
                    Label("Exportar datos (JSON)", systemImage: "square.and.arrow.up")
                }
            } header: {
                Text("Copia de seguridad")
            } footer: {
                Text("Exporta clientes, artículos y gastos como archivo JSON.")
            }

            // Acerca de
            Section {
                Button {
                    mostrarWhatsNew = true
                } label: {
                    Label("Novedades de esta versión", systemImage: "sparkles")
                }
            } header: {
                Text("Acerca de")
            } footer: {
                Text("EhFacturas! v\(WhatsNewView.currentVersion)")
            }
        }
        .fileImporter(
            isPresented: $mostrarImportarCertificado,
            allowedContentTypes: [.init(filenameExtension: "p12")!, .init(filenameExtension: "pfx")!, .pkcs12],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        certificadoData = data
                        certificadoPassword = ""
                        certificadoError = nil
                    }
                }
            }
        }
        .alert("Contraseña del certificado", isPresented: Binding(
            get: { certificadoData != nil },
            set: { if !$0 { certificadoData = nil } }
        )) {
            SecureField("Contraseña", text: $certificadoPassword)
            Button("Importar") {
                if let data = certificadoData {
                    let result = VeriFactuCertificateManager.importarCertificado(data: data, password: certificadoPassword)
                    if result.success {
                        negocio.certificadoInstalado = true
                        try? modelContext.save()
                        certificadoExito = true
                    } else {
                        certificadoError = result.error
                    }
                }
                certificadoData = nil
                certificadoPassword = ""
            }
            Button("Cancelar", role: .cancel) {
                certificadoData = nil
                certificadoPassword = ""
            }
        } message: {
            Text("Introduce la contraseña de tu certificado digital")
        }
        .alert("Certificado importado", isPresented: $certificadoExito) {
            Button("OK") { }
        } message: {
            Text("Tu certificado digital se ha instalado correctamente.")
        }
        .alert("Error", isPresented: Binding(
            get: { certificadoError != nil },
            set: { if !$0 { certificadoError = nil } }
        )) {
            Button("OK") { certificadoError = nil }
        } message: {
            Text(certificadoError ?? "Error desconocido")
        }
        .sheet(isPresented: $mostrarEventLog) {
            EventLogView()
        }
        #if DEBUG
        .alert("API Key (desarrollo)", isPresented: $mostrarAPIKeyInput) {
            SecureField("sk-...", text: $apiKeyTexto)
            Button("Guardar") {
                if !apiKeyTexto.isEmpty {
                    APIKeyManager.shared.setDirectAPIKey(apiKeyTexto)
                    apiKeyTexto = ""
                }
            }
            Button("Cancelar", role: .cancel) { apiKeyTexto = "" }
        } message: {
            Text("Introduce tu API key de Claude o OpenAI para pruebas.")
        }
        #endif
        .sheet(isPresented: $mostrarSuscripcion) {
            SubscriptionView()
        }
        .sheet(isPresented: $mostrarShareBackup) {
            if let data = backupData {
                ShareSheet(items: [data])
            }
        }
        .sheet(isPresented: $mostrarWhatsNew) {
            WhatsNewView()
        }
    }

    private func exportarBackup() {
        if let data = BackupService.exportar(modelContext: modelContext) {
            backupData = data
            mostrarShareBackup = true
        }
    }

    private var providerIcon: String {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return "apple.intelligence"
        }
        #endif
        return "cloud.fill"
    }

    private var providerColor: Color {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return .green
        }
        #endif
        return .blue
    }

    private var providerName: String {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return "Apple Intelligence (on-device)"
        }
        #endif
        return negocios.first?.cloudProvider == "claude" ? "Claude (Anthropic)" : "OpenAI (GPT-4o-mini)"
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }

    private func crearCategoriasDefecto() {
        let desc = FetchDescriptor<Categoria>()
        let existentes = (try? modelContext.fetch(desc)) ?? []
        let nombresExistentes = Set(existentes.map(\.nombre))

        for (i, (nombre, icono)) in Categoria.categoriasDefecto.enumerated() {
            if !nombresExistentes.contains(nombre) {
                let cat = Categoria(nombre: nombre, icono: icono, orden: i)
                modelContext.insert(cat)
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Cabecera con logo

struct CabeceraLogoView: View {

    let negocio: Negocio
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let data = negocio.logoPNG, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue.opacity(0.08))
                            .frame(width: 60, height: 60)
                        Image(systemName: "camera")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, nuevo in
                Task {
                    if let data = try? await nuevo?.loadTransferable(type: Data.self) {
                        if let imagen = UIImage(data: data) {
                            // Redimensionar a max 400px
                            let resized = redimensionar(imagen, maxDimension: 400)
                            negocio.logoPNG = resized.pngData()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(negocio.nombre.isEmpty ? "Tu negocio" : negocio.nombre)
                    .font(.headline)
                if !negocio.nif.isEmpty {
                    Text(negocio.nif)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Toca el logo para cambiarlo")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func redimensionar(_ imagen: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = imagen.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Campo de texto reutilizable

struct CampoTexto: View {
    let placeholder: String
    @Binding var texto: String
    var teclado: UIKeyboardType = .default

    init(_ placeholder: String, binding: Binding<String>, teclado: UIKeyboardType = .default) {
        self.placeholder = placeholder
        self._texto = binding
        self.teclado = teclado
    }

    var body: some View {
        TextField(placeholder, text: $texto)
            .keyboardType(teclado)
    }
}

// MARK: - Onboarding

struct OnboardingView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var paso = 0
    @State private var nombre = ""
    @State private var nif = ""
    @State private var telefono = ""
    @State private var email = ""
    @State private var direccion = ""
    @State private var ciudad = ""
    @State private var provincia = ""
    @State private var codigoPostal = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Indicador de pasos
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i <= paso ? Color.blue : Color(.systemGray5))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                TabView(selection: $paso) {
                    // Paso 1: Datos del negocio
                    Form {
                        Section {
                            VStack(spacing: 8) {
                                Image(systemName: "building.2")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)
                                Text("Datos de tu negocio")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("Esta información aparecerá en tus facturas")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                        }
                        Section {
                            TextField("Nombre / Razón social *", text: $nombre)
                            TextField("NIF / CIF *", text: $nif)
                        }
                    }
                    .tag(0)

                    // Paso 2: Contacto y dirección
                    Form {
                        Section {
                            VStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)
                                Text("Contacto y dirección")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                        }
                        Section {
                            TextField("Teléfono", text: $telefono)
                                .keyboardType(.phonePad)
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }
                        Section {
                            TextField("Dirección", text: $direccion)
                            HStack {
                                TextField("C.P.", text: $codigoPostal)
                                    .keyboardType(.numberPad)
                                    .frame(width: 80)
                                TextField("Ciudad", text: $ciudad)
                            }
                            TextField("Provincia", text: $provincia)
                        }
                    }
                    .tag(1)

                    // Paso 3: Listo
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("Todo listo")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Ya puedes empezar a crear facturas con tu voz.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Botones de navegación
                HStack {
                    if paso > 0 {
                        Button("Atrás") {
                            withAnimation { paso -= 1 }
                        }
                    }
                    Spacer()
                    if paso < 2 {
                        Button("Siguiente") {
                            withAnimation { paso += 1 }
                        }
                        .disabled(paso == 0 && nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Button("Empezar") {
                            guardarYCerrar()
                        }
                        .fontWeight(.semibold)
                    }
                }
                .padding()
            }
            .navigationTitle("Configuración inicial")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }

    private func guardarYCerrar() {
        let negocio = Negocio(
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            nif: nif,
            direccion: direccion,
            codigoPostal: codigoPostal,
            ciudad: ciudad,
            provincia: provincia,
            telefono: telefono,
            email: email
        )
        modelContext.insert(negocio)

        // Crear categorías por defecto
        for (i, (catNombre, icono)) in Categoria.categoriasDefecto.enumerated() {
            let cat = Categoria(nombre: catNombre, icono: icono, orden: i)
            modelContext.insert(cat)
        }

        // Guardar a disco
        try? modelContext.save()

        // Solicitar permisos de notificaciones
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

        dismiss()
    }
}

// MARK: - Suscripción Pro

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)

                Text("EhFacturas! Pro")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Accede a la IA por voz en todos los dispositivos, incluso sin Apple Intelligence.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    if let monthly = SubscriptionManager.shared.monthlyProduct {
                        Button {
                            Task {
                                _ = try? await SubscriptionManager.shared.purchase(monthly)
                            }
                        } label: {
                            HStack {
                                Text("Mensual")
                                Spacer()
                                Text(monthly.displayPrice + "/mes")
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let yearly = SubscriptionManager.shared.yearlyProduct {
                        Button {
                            Task {
                                _ = try? await SubscriptionManager.shared.purchase(yearly)
                            }
                        } label: {
                            HStack {
                                Text("Anual")
                                Spacer()
                                Text(yearly.displayPrice + "/año")
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 30)

                Button("Restaurar compras") {
                    Task { await SubscriptionManager.shared.restorePurchases() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationTitle("Suscripción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task {
                await SubscriptionManager.shared.loadProducts()
            }
        }
    }
}
