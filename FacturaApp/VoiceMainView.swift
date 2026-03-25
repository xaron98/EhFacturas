// VoiceMainView.swift
// FacturaApp — Vista principal controlada por voz
// Layout tipo chat: conversación arriba, micro abajo.

import SwiftUI
import SwiftData

// MARK: - Mensaje de conversación

struct MensajeChat: Identifiable {
    let id = UUID()
    let timestamp: Date
    let tipo: Tipo
    let texto: String
    var accion: ComandoResultado.AccionRealizada?
    var facturaID: PersistentIdentifier?

    enum Tipo {
        case usuario
        case ia
        case error
        case sistema
        case factura
    }
}

// MARK: - Vista principal

struct VoiceMainView: View {

    // Note: modelContext from @Environment is used for UI operations.
    // CommandAIService receives its own context via init for IA operations.
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speech = SpeechService()
    @StateObject private var aiService: CommandAIService

    @Query private var negocios: [Negocio]

    @State private var textoManual = ""
    @State private var mostrarBandeja = false
    @State private var mensajes: [MensajeChat] = []
    @State private var procesando = false
    @State private var permisosComprobados = false
    @State private var facturaParaEditar: Factura?
    @State private var tipoImportacion: TipoImportacion?
    @State private var mostrarImportador = false
    @State private var currentTask: Task<Void, Never>?
    @State private var mostrarScanner = false
    @State private var animateGradient = false

    private var hayNegocio: Bool { !negocios.isEmpty }

    init(modelContext: ModelContext) {
        _aiService = StateObject(wrappedValue: CommandAIService(modelContext: modelContext))
    }

    var body: some View {
        ZStack {
            // Animated gradient background (RadialGradient — GPU efficient, no blur)
            Color(.systemBackground)
                .ignoresSafeArea()
                .overlay {
                    ZStack {
                        RadialGradient(colors: [Color.blue.opacity(0.15), .clear],
                                       center: .center, startRadius: 0, endRadius: 150)
                            .frame(width: 300, height: 300)
                            .offset(x: animateGradient ? 50 : -50, y: animateGradient ? -80 : 80)

                        RadialGradient(colors: [Color.purple.opacity(0.12), .clear],
                                       center: .center, startRadius: 0, endRadius: 125)
                            .frame(width: 250, height: 250)
                            .offset(x: animateGradient ? -60 : 60, y: animateGradient ? 60 : -60)

                        RadialGradient(colors: [Color.cyan.opacity(0.08), .clear],
                                       center: .center, startRadius: 0, endRadius: 100)
                            .frame(width: 200, height: 200)
                            .offset(x: animateGradient ? 30 : -30, y: animateGradient ? 100 : -20)
                    }
                    .drawingGroup()
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateGradient)
                }

            VStack(spacing: 0) {
                // Toolbar superior
                toolbarView

                // Zona de chat (scrollable)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Mensaje de bienvenida si no hay mensajes
                            if mensajes.isEmpty && !procesando {
                                bienvenidaView
                            }

                            // Mensajes
                            ForEach(mensajes) { msg in
                                mensajeView(msg)
                                    .id(msg.id)
                            }

                            // Indicador de procesando
                            if procesando {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(aiService.estadoDetallado)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                                .transition(.scale.combined(with: .opacity))
                                .id("procesando")
                            }

                            // Texto transcrito en tiempo real
                            if speech.estaEscuchando {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                    Text(speech.textoTranscrito.isEmpty ? "Escuchando..." : speech.textoTranscrito)
                                        .font(.subheadline)
                                        .foregroundStyle(speech.textoTranscrito.isEmpty ? .tertiary : .primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("escuchando")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: mensajes.count) { _, _ in
                        withAnimation {
                            if let ultimo = mensajes.last {
                                proxy.scrollTo(ultimo.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: speech.estaEscuchando) { _, escuchando in
                        if escuchando {
                            withAnimation {
                                proxy.scrollTo("escuchando", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: procesando) { _, proc in
                        if proc {
                            withAnimation {
                                proxy.scrollTo("procesando", anchor: .bottom)
                            }
                        }
                    }
                }

                // Zona de entrada (abajo fija)
                entradaView
            }
        }
        .task {
            animateGradient = true
            // Esperar un momento para que CloudKit sincronice datos
            try? await Task.sleep(for: .milliseconds(500))
            // Si no hay negocio, iniciar onboarding conversacional
            if !hayNegocio && mensajes.isEmpty {
                mensajes.append(MensajeChat(
                    timestamp: .now,
                    tipo: .ia,
                    texto: "¡Hola! Soy tu asistente de facturación. Antes de empezar, necesito configurar los datos de tu negocio. ¿Cómo te llamas o cómo se llama tu negocio?",
                    accion: .informacion
                ))
            }
        }
        .onChange(of: speech.estaEscuchando) { _, escuchando in
            if !escuchando && !speech.textoTranscrito.isEmpty {
                let comando = speech.textoTranscrito
                enviarComando(comando)
            }
        }
        .onChange(of: speech.errorMensaje) { _, error in
            if let error,
               !error.lowercased().contains("cancel"),
               !error.lowercased().contains("interrupted"),
               !error.lowercased().contains("kafassistant") {
                mensajes.append(MensajeChat(
                    timestamp: .now,
                    tipo: .error,
                    texto: error
                ))
            }
        }
        .sheet(isPresented: $mostrarBandeja) {
            BandejaManualView()
        }
        .sheet(item: $facturaParaEditar) { factura in
            FacturaEditView(factura: factura)
        }
        .sheet(isPresented: $mostrarImportador) {
            ImportarView(tipo: tipoImportacion ?? .articulos)
        }
        .sheet(isPresented: $mostrarScanner) {
            ScannerView { texto in
                enviarComando(texto)
            }
        }
        .onChange(of: aiService.solicitarImportacion) { _, tipo in
            if let tipo {
                tipoImportacion = tipo
                mostrarImportador = true
                aiService.solicitarImportacion = nil
            }
        }
    }

    // MARK: - Enviar comando

    private func enviarComando(_ texto: String) {
        let textoLimpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textoLimpio.isEmpty else { return }

        // Añadir mensaje del usuario
        withAnimation(.spring(response: 0.4)) {
            mensajes.append(MensajeChat(
                timestamp: .now,
                tipo: .usuario,
                texto: textoLimpio
            ))
        }

        procesando = true

        currentTask?.cancel()
        currentTask = Task {
            await aiService.procesarComando(textoLimpio)

            procesando = false

            // Añadir respuesta de la IA
            if let resultado = aiService.ultimaRespuesta {
                if let fID = resultado.facturaID {
                    withAnimation(.spring(response: 0.4)) {
                        mensajes.append(MensajeChat(
                            timestamp: .now,
                            tipo: .factura,
                            texto: resultado.mensaje,
                            accion: resultado.accionRealizada,
                            facturaID: fID
                        ))
                    }
                    VozIAService.shared.hablar(resultado.mensaje)
                } else {
                    withAnimation(.spring(response: 0.4)) {
                        mensajes.append(MensajeChat(
                            timestamp: .now,
                            tipo: resultado.accionRealizada == .error ? .error : .ia,
                            texto: resultado.mensaje,
                            accion: resultado.accionRealizada
                        ))
                    }
                    VozIAService.shared.hablar(resultado.mensaje)
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack {
            // Indicador de IA
            if aiService.iaDisponible {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("IA lista")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text(aiService.razonNoDisponible)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Botón bandeja
            Button {
                mostrarBandeja = true
            } label: {
                Image(systemName: "tray.full")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }
            .accessibilityLabel("Gestión manual")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Bienvenida

    private var bienvenidaView: some View {
        VStack(spacing: 20) {
            Spacer()

            // App branding
            VStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
                Text("FacturaApp")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(hayNegocio ? "Tu asistente de facturación" : "Configura tu negocio para empezar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Mic button
            Button {
                if speech.estaEscuchando {
                    speech.detenerEscucha()
                } else if speech.permisoConecido {
                    speech.iniciarEscucha()
                } else {
                    speech.solicitarPermisosYEscuchar()
                }
            } label: {
                ZStack {
                    // Glass background
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 80, height: 80)
                        .shadow(color: speech.estaEscuchando ? .purple.opacity(0.4) : .black.opacity(0.12), radius: speech.estaEscuchando ? 20 : 10)

                    // Border
                    Circle()
                        .stroke(Color(.separator), lineWidth: 1)
                        .frame(width: 80, height: 80)

                    // Audio ring
                    if speech.estaEscuchando {
                        Circle()
                            .stroke(lineWidth: 1.5)
                            .foregroundStyle(.purple.opacity(0.5))
                            .scaleEffect(1.0 + CGFloat(speech.nivelAudio) * 0.4)
                            .animation(.easeOut(duration: 0.1), value: speech.nivelAudio)
                            .frame(width: 80, height: 80)
                    }

                    Image(systemName: speech.estaEscuchando ? "waveform" : "mic.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(speech.estaEscuchando ? .purple : .primary)
                }
            }
            .scaleEffect(speech.estaEscuchando ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: speech.estaEscuchando)
            .buttonStyle(.plain)
            .accessibilityLabel(speech.estaEscuchando ? "Detener grabación" : "Activar micrófono")
            .accessibilityHint("Pulsa para hablar un comando")

            // Examples
            VStack(spacing: 8) {
                Text(hayNegocio ? "Prueba a decir:" : "Di algo como:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(ejemplos, id: \.self) { ejemplo in
                    Button {
                        enviarComando(ejemplo)
                    } label: {
                        Text(ejemplo)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }

    private var ejemplos: [String] {
        if hayNegocio {
            return [
                "Añade un cliente Juan García, teléfono 612345678",
                "Crea una factura para Juan con 3 bombillas LED",
                "¿Cuánto tengo pendiente de cobrar?"
            ]
        } else {
            return [
                "Me llamo Juan García, NIF 12345678A, teléfono 612345678",
                "Mi negocio es Instalaciones García, estoy en Madrid",
                "Mi email es juan@garcia.es, estoy en la calle Mayor 5"
            ]
        }
    }

    // MARK: - Mensaje individual

    @ViewBuilder
    private func mensajeView(_ msg: MensajeChat) -> some View {
        switch msg.tipo {
        case .usuario:
            HStack(alignment: .top, spacing: 10) {
                Spacer()
                Text(msg.texto)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue.opacity(0.5))
            }
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))

        case .ia:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.purple.opacity(0.6))
                        .frame(width: 3)
                        .padding(.vertical, 6)
                    VStack(alignment: .leading, spacing: 6) {
                        if let accion = msg.accion {
                            HStack(spacing: 4) {
                                Image(systemName: iconoAccion(accion))
                                    .font(.caption2)
                                Text(tituloAccion(accion))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(colorAccion(accion))
                        }
                        Text(msg.texto)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(12)
                }
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer()
            }
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))

        case .error:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(msg.texto)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer()
            }
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))

        case .factura:
            if let fID = msg.facturaID {
                FacturaChatCard(facturaID: fID, texto: msg.texto) { factura in
                    facturaParaEditar = factura
                }
            }

        case .sistema:
            Text(msg.texto)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
        }
    }

    // MARK: - Zona de entrada (abajo)

    private var entradaView: some View {
        HStack(spacing: 10) {
            // Text field
            TextField("Escribe un comando...", text: $textoManual)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onSubmit {
                    if !textoManual.trimmingCharacters(in: .whitespaces).isEmpty {
                        let cmd = textoManual
                        textoManual = ""
                        enviarComando(cmd)
                    }
                }

            // Send button
            if !textoManual.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    let cmd = textoManual
                    textoManual = ""
                    enviarComando(cmd)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }

            // Scanner button
            Button {
                mostrarScanner = true
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Escanear documento")

            // Mic button
            Button {
                if speech.estaEscuchando {
                    speech.detenerEscucha()
                } else if speech.permisoConecido {
                    speech.iniciarEscucha()
                } else {
                    speech.solicitarPermisosYEscuchar()
                }
            } label: {
                Image(systemName: speech.estaEscuchando ? "stop.fill" : "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(speech.estaEscuchando ? .red : .blue)
                    .frame(width: 36, height: 36)
                    .background(speech.estaEscuchando ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speech.estaEscuchando ? "Detener grabación" : "Activar micrófono")
            .accessibilityHint("Pulsa para hablar un comando")
            .disabled(procesando)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers de estilo

    private func iconoAccion(_ accion: ComandoResultado.AccionRealizada) -> String {
        switch accion {
        case .clienteCreado: return "person.badge.plus"
        case .clienteEncontrado: return "person.crop.circle"
        case .articuloCreado: return "shippingbox.fill"
        case .articuloEncontrado: return "shippingbox"
        case .facturaBorradorCreada: return "doc.badge.plus"
        case .facturaEmitida: return "paperplane.fill"
        case .facturaMarcadaPagada: return "checkmark.circle.fill"
        case .listaClientes: return "person.2"
        case .listaArticulos: return "shippingbox"
        case .listaFacturas: return "doc.text"
        case .importarSolicitado: return "arrow.down.doc"
        case .informacion: return "info.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    private func colorAccion(_ accion: ComandoResultado.AccionRealizada) -> Color {
        switch accion {
        case .clienteCreado, .articuloCreado: return .blue
        case .facturaBorradorCreada: return .purple
        case .facturaMarcadaPagada: return .green
        case .error: return .red
        default: return .secondary
        }
    }

    private func tituloAccion(_ accion: ComandoResultado.AccionRealizada) -> String {
        switch accion {
        case .clienteCreado: return "Cliente creado"
        case .clienteEncontrado: return "Cliente encontrado"
        case .articuloCreado: return "Artículo añadido"
        case .articuloEncontrado: return "Artículo encontrado"
        case .facturaBorradorCreada: return "Factura creada"
        case .facturaEmitida: return "Factura emitida"
        case .facturaMarcadaPagada: return "Factura cobrada"
        case .listaClientes: return "Clientes"
        case .listaArticulos: return "Artículos"
        case .listaFacturas: return "Facturas"
        case .importarSolicitado: return "Importar datos"
        case .informacion: return "Información"
        case .error: return "Error"
        }
    }
}

// MARK: - Bandeja manual (drawer)

struct BandejaManualView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var seccionSeleccionada: SeccionBandeja = .facturas
    @State private var mostrarFormularioNuevo = false

    enum SeccionBandeja: String, CaseIterable {
        case facturas = "Facturas"
        case clientes = "Clientes"
        case articulos = "Artículos"
        case gastos = "Gastos"
        case informes = "Informes"
        case ajustes = "Ajustes"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom toolbar — Liquid Glass style
                HStack {
                    Text("Gestión manual")
                        .font(.headline)

                    Spacer()

                    if seccionSeleccionada == .clientes || seccionSeleccionada == .articulos || seccionSeleccionada == .gastos {
                        Button {
                            mostrarFormularioNuevo = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .frame(width: 34, height: 34)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Cerrar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Picker("Sección", selection: $seccionSeleccionada) {
                    ForEach(SeccionBandeja.allCases, id: \.self) { sec in
                        Text(sec.rawValue).tag(sec)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Group {
                    switch seccionSeleccionada {
                    case .facturas:
                        FacturasListView()
                    case .clientes:
                        ClientesListView()
                    case .articulos:
                        ArticulosListView()
                    case .gastos:
                        GastosView()
                    case .informes:
                        InformesView()
                    case .ajustes:
                        AjustesView()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $mostrarFormularioNuevo) {
                NavigationStack {
                    switch seccionSeleccionada {
                    case .clientes:
                        ClienteFormularioView(cliente: nil)
                    case .articulos:
                        ArticuloFormularioView(articulo: nil)
                    case .gastos:
                        GastoFormularioView()
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
}

// MARK: - App entry point

@main
struct FacturaApp: App {

    let container = DataConfig.container

    init() {
        FacturaVencimientoService.registrarTareaBackground()
    }

    var body: some Scene {
        WindowGroup {
            ThemeWrapper {
                VoiceMainView(modelContext: container.mainContext)
                    .modifier(RevisionVencimientosModifier())
            }
            .modelContainer(container)
        }
    }
}

/// Wrapper that reactively applies the theme from Negocio settings
struct ThemeWrapper<Content: View>: View {
    @Query private var negocios: [Negocio]
    @ViewBuilder let content: () -> Content

    private var colorScheme: ColorScheme? {
        switch negocios.first?.temaApp ?? "auto" {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        content()
            .preferredColorScheme(colorScheme)
    }
}
