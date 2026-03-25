// VoiceMainView.swift
// FacturaApp — Vista principal controlada por voz
// Layout tipo chat: conversación arriba, micro abajo.
// Sub-views extracted to ChatMessageView, CommandInputBar, WelcomeView.

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
    @State private var currentCommandID = UUID()
    @State private var mostrarScanner = false
    @State private var animateGradient = false
    @FocusState private var textoFocused: Bool

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
                                WelcomeView(
                                    hayNegocio: hayNegocio,
                                    estaEscuchando: speech.estaEscuchando,
                                    nivelAudio: speech.nivelAudio,
                                    permisoConecido: speech.permisoConecido,
                                    onMicTap: { toggleMic() },
                                    onEjemploTap: { ejemplo in enviarComando(ejemplo) }
                                )
                            }

                            // Mensajes
                            ForEach(mensajes) { msg in
                                ChatMessageView(msg: msg) { factura in
                                    facturaParaEditar = factura
                                }
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
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture { textoFocused = false }
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
                CommandInputBar(
                    textoManual: $textoManual,
                    textoFocused: $textoFocused,
                    estaEscuchando: speech.estaEscuchando,
                    procesando: procesando,
                    permisoConecido: speech.permisoConecido,
                    onEnviar: { cmd in enviarComando(cmd) },
                    onMicTap: { toggleMic() },
                    onScannerTap: { mostrarScanner = true }
                )
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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

    // MARK: - Toggle microphone

    private func toggleMic() {
        if speech.estaEscuchando {
            speech.detenerEscucha()
        } else if speech.permisoConecido {
            speech.iniciarEscucha()
        } else {
            speech.solicitarPermisosYEscuchar()
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

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        procesando = true

        let commandID = UUID()
        currentCommandID = commandID

        currentTask?.cancel()
        currentTask = Task {
            await aiService.procesarComando(textoLimpio)

            // Guard against stale response (command was superseded)
            guard !Task.isCancelled, currentCommandID == commandID else { return }

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
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                    if resultado.accionRealizada == .error {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
}

// MARK: - Bandeja manual (drawer)

struct BandejaManualView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
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
            Group {
                if sizeClass == .regular {
                    // iPad layout: sidebar + content
                    HStack(spacing: 0) {
                        // Sidebar
                        VStack(spacing: 0) {
                            HStack {
                                Text("FacturaApp")
                                    .font(.headline)
                                Spacer()
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

                            List(SeccionBandeja.allCases, id: \.self, selection: Binding(
                                get: { seccionSeleccionada },
                                set: { if let v = $0 { seccionSeleccionada = v } }
                            )) { sec in
                                Label(sec.rawValue, systemImage: iconoSeccion(sec))
                            }
                            .listStyle(.sidebar)
                        }
                        .frame(width: 220)

                        Divider()

                        // Content
                        VStack(spacing: 0) {
                            if seccionSeleccionada == .clientes || seccionSeleccionada == .articulos || seccionSeleccionada == .gastos {
                                HStack {
                                    Spacer()
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
                                    .accessibilityLabel("Nuevo \(seccionSeleccionada.rawValue)")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }

                            contenidoSeccion
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    // iPhone layout: existing tabs
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
                                .accessibilityLabel("Nuevo \(seccionSeleccionada.rawValue)")
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

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(SeccionBandeja.allCases, id: \.self) { sec in
                                    Button {
                                        seccionSeleccionada = sec
                                    } label: {
                                        Text(sec.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(seccionSeleccionada == sec ? .semibold : .regular)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(seccionSeleccionada == sec ? Color.blue : Color(.systemGray5))
                                            .foregroundStyle(seccionSeleccionada == sec ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }

                        contenidoSeccion
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

    // MARK: - Content for selected section

    @ViewBuilder
    private var contenidoSeccion: some View {
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

    // MARK: - Section icons for iPad sidebar

    private func iconoSeccion(_ sec: SeccionBandeja) -> String {
        switch sec {
        case .facturas: return "doc.text"
        case .clientes: return "person.2"
        case .articulos: return "shippingbox"
        case .gastos: return "cart"
        case .informes: return "chart.bar"
        case .ajustes: return "gear"
        }
    }
}

// MARK: - App entry point

@main
struct FacturaApp: App {

    let container = DataConfig.container

    var body: some Scene {
        WindowGroup {
            ThemeWrapper {
                VoiceMainView(modelContext: container.mainContext)
                    .modifier(RevisionVencimientosModifier())
                    .task {
                        FacturaVencimientoService.registrarTareaBackground()
                    }
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
