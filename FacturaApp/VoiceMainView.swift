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

    private var hayNegocio: Bool { !negocios.isEmpty }

    init(modelContext: ModelContext) {
        _aiService = StateObject(wrappedValue: CommandAIService(modelContext: modelContext))
    }

    var body: some View {
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
                                Text("Pensando...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
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

            Divider()

            // Zona de entrada (abajo fija)
            entradaView
        }
        .onAppear {
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
        mensajes.append(MensajeChat(
            timestamp: .now,
            tipo: .usuario,
            texto: textoLimpio
        ))

        procesando = true

        Task {
            await aiService.procesarComando(textoLimpio)

            procesando = false

            // Añadir respuesta de la IA
            if let resultado = aiService.ultimaRespuesta {
                if let fID = resultado.facturaID {
                    mensajes.append(MensajeChat(
                        timestamp: .now,
                        tipo: .factura,
                        texto: resultado.mensaje,
                        accion: resultado.accionRealizada,
                        facturaID: fID
                    ))
                } else {
                    mensajes.append(MensajeChat(
                        timestamp: .now,
                        tipo: resultado.accionRealizada == .error ? .error : .ia,
                        texto: resultado.mensaje,
                        accion: resultado.accionRealizada
                    ))
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
                        .foregroundStyle(.secondary)
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
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
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
                    // Outer glow
                    Circle()
                        .fill(.blue.opacity(speech.estaEscuchando ? 0 : 0.06))
                        .frame(width: 80, height: 80)

                    Circle()
                        .stroke(lineWidth: speech.estaEscuchando ? 2.5 : 1.5)
                        .foregroundStyle(speech.estaEscuchando ? .red : .blue.opacity(0.4))
                        .frame(width: 64, height: 64)

                    if speech.estaEscuchando {
                        Circle()
                            .stroke(lineWidth: 1)
                            .foregroundStyle(.red.opacity(0.2))
                            .scaleEffect(1.0 + CGFloat(speech.nivelAudio) * 0.4)
                            .animation(.easeOut(duration: 0.1), value: speech.nivelAudio)
                            .frame(width: 64, height: 64)
                    }

                    Image(systemName: speech.estaEscuchando ? "stop.fill" : "mic.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(speech.estaEscuchando ? .red : .blue)
                }
            }
            .buttonStyle(.plain)

            // Examples
            VStack(spacing: 8) {
                Text(hayNegocio ? "Prueba a decir:" : "Di algo como:")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                ForEach(ejemplos, id: \.self) { ejemplo in
                    Button {
                        enviarComando(ejemplo)
                    } label: {
                        Text(ejemplo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.fill.tertiary)
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
                    .background(
                        LinearGradient(
                            colors: [.blue.opacity(0.15), .blue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue.opacity(0.5))
            }

        case .ia:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple.opacity(0.6))
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.purple.opacity(0.4))
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
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer()
            }

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
        }
    }

    // MARK: - Zona de entrada (abajo)

    private var entradaView: some View {
        HStack(spacing: 12) {
            // Campo de texto
            TextField("Escribe un comando...", text: $textoManual)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.fill.tertiary)
                .clipShape(Capsule())
                .onSubmit {
                    if !textoManual.trimmingCharacters(in: .whitespaces).isEmpty {
                        let cmd = textoManual
                        textoManual = ""
                        enviarComando(cmd)
                    }
                }

            // Botón enviar texto (si hay texto)
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

            // Botón micrófono
            Button {
                if speech.estaEscuchando {
                    speech.detenerEscucha()
                } else if speech.permisoConecido {
                    speech.iniciarEscucha()
                } else {
                    // Primera vez: pide permisos y luego inicia
                    speech.solicitarPermisosYEscuchar()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(speech.estaEscuchando ? .red.opacity(0.15) : .clear)
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(lineWidth: speech.estaEscuchando ? 2 : 1)
                        .foregroundStyle(speech.estaEscuchando ? .red : .secondary.opacity(0.3))
                        .frame(width: 44, height: 44)

                    // Anillo de audio
                    if speech.estaEscuchando {
                        Circle()
                            .stroke(lineWidth: 1)
                            .foregroundStyle(.red.opacity(0.2))
                            .scaleEffect(1.0 + CGFloat(speech.nivelAudio) * 0.3)
                            .animation(.easeOut(duration: 0.1), value: speech.nivelAudio)
                            .frame(width: 44, height: 44)
                    }

                    Image(systemName: speech.estaEscuchando ? "stop.fill" : "mic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(speech.estaEscuchando ? .red : .secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(procesando)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
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

    enum SeccionBandeja: String, CaseIterable {
        case facturas = "Facturas"
        case clientes = "Clientes"
        case articulos = "Artículos"
        case ajustes = "Ajustes"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    case .ajustes:
                        AjustesView()
                    }
                }
            }
            .navigationTitle("Gestión manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
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
            VoiceMainView(modelContext: container.mainContext)
                .modelContainer(container)
                .modifier(RevisionVencimientosModifier())
        }
    }
}
