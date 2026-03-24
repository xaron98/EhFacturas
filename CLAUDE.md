# FacturaApp — Guía para Claude

## Proyecto
App de facturación voice-first para autónomos y pequeñas empresas en España. iOS 26+ / macOS 26+ (Mac Catalyst).
Cumplimiento VeriFactu completo (Real Decreto 1007/2023) — hash chain, XML, SOAP, firma XMLDSig.

## Stack
- SwiftUI, SwiftData, Swift 6 (strict concurrency)
- Apple Foundation Models (`@Generable`, `Tool` protocol)
- Speech framework (es-ES)
- CryptoKit (SHA-256), Security.framework (RSA-SHA256, Keychain)
- PDFKit, CoreImage (QR), UserNotifications, BackgroundTasks, PhotosUI
- UniformTypeIdentifiers (file picker importador)

## Skills obligatorias
- **`axiom-swiftdata`** — cuando trabajes con modelos SwiftData
- **`verifactu`** — cuando trabajes con hashes, registros, inalterabilidad o normativa fiscal
- **`swift-concurrency-6-2`** — cuando haya problemas de @Sendable, @MainActor, data races
- **`swiftui-patterns`** — para patrones de vistas SwiftUI
- Usar `/factura-testing` para verificar flujos después de cambios
- Usar `/swift-build-check` para compilar después de ediciones

## Reglas de código
- Target: iOS 26.0 / macOS 26.0 (Mac Catalyst)
- Swift 6 con `SWIFT_STRICT_CONCURRENCY = complete`
- Todos los archivos SwiftUI deben importar `SwiftUI`
- Enums en @Model: rawValue DEBE coincidir con el nombre del caso (SwiftData los guarda por nombre)
- `try? modelContext.save()` después de cada insert/update
- Formato de moneda: locale `es_ES` (coma decimal, punto miles)
- Idioma de la app y comentarios: español
- Entry point (`@main`): VoiceMainView.swift — no crear otro
- VeriFactu: facturas emitidas NUNCA se modifican. Solo anulación o rectificativa.
- CSV parser: probar UTF-8 → ISO-8859-1 → Windows-1252. Detectar separador automáticamente.

## Estructura
```
FacturaApp/
├── Models.swift              # 9 @Model entities + enums + DataConfig
├── SpeechService.swift       # Speech framework (es-ES)
├── CommandAIService.swift    # 10 Tools IA (Foundation Models)
├── VoiceMainView.swift       # Vista principal chat + @main + Bandeja
├── ClientesView.swift        # CRUD clientes
├── ArticulosView.swift       # CRUD artículos + FlowLayout
├── FacturasListView.swift    # Dashboard + lista + detalle + emit/anular/rectificar
├── FacturaPDFGenerator.swift # PDF A4 + QR + preview + ShareSheet
├── FacturaCardView.swift     # Tarjeta de factura en chat + FacturaChatCard
├── FacturaEditView.swift     # Editor factura fullscreen + LineaEditRow
├── FacturaEditAIService.swift # IA contextual para editar facturas (4 tools)
├── MapeoUniversal.swift      # Sinónimos universales + detector programa + mapeo + perfiles
├── ImportadorService.swift   # Parser CSV + importador + ImportarView
├── VeriFactuHashService.swift # SHA-256 hash chain + verificación
├── VeriFactuXMLGenerator.swift # XML XSD AEAT V1.0
├── VeriFactuSOAPClient.swift # Cliente SOAP + cola offline
├── VeriFactuCertificateManager.swift # Certificado .p12 + Keychain
├── VeriFactuXMLSigner.swift  # Firma XMLDSig (C14N + RSA-SHA256)
├── EventLogService.swift     # Registro de eventos
├── EventLogView.swift        # Vista log de auditoría
├── AjustesView.swift         # Config negocio + certificado + onboarding
├── FacturaVencimientoService.swift # Vencimientos + notificaciones
├── FacturaAIService.swift    # Legacy (referencia)
└── FacturaAIView.swift       # Legacy (referencia)
```

## Tools de IA (10 en CommandAIService + 4 en FacturaEditAIService)
- `configurar_negocio` — datos del negocio (onboarding por voz)
- `crear_cliente` — nuevo cliente
- `buscar_cliente` — buscar por nombre/teléfono/NIF
- `crear_articulo` — nuevo artículo en catálogo
- `buscar_articulo` — buscar por nombre/referencia/etiquetas
- `crear_factura` — factura borrador con líneas resueltas del catálogo
- `marcar_pagada` — cambiar estado a pagada
- `anular_factura` — anular (con registro VeriFactu si emitida)
- `importar_datos` — abrir importador CSV (artículos o clientes)
- `consultar_resumen` — stats del negocio
- `modificar_linea` — editar línea de factura (en FacturaEditAIService)
- `anadir_linea` — añadir línea a factura
- `eliminar_linea` — quitar línea de factura
- `cambiar_descuento` — descuento global de factura

## Errores frecuentes a evitar
- NO usar rawValue abreviado en enums de @Model (SwiftData guarda el nombre del caso)
- NO olvidar `import SwiftUI` en archivos que usan ViewModifier, View, @Environment
- NO usar `#Predicate` con comparaciones de enum (fetch all + filter en memoria)
- NO usar `.id(UUID())` en List dentro de NavigationStack (causa feedback loop)
- NO olvidar `@preconcurrency import` para Speech y AVFoundation
- NO crear `@StateObject` con `ModelContext` externo sin usar `DataConfig.container.mainContext`
- NO olvidar añadir nuevos @Model al schema en DataConfig.container
