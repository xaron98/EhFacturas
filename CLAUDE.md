# FacturaApp — Guía para Claude

## Proyecto
App de facturación voice-first para autónomos y pequeñas empresas en España. iOS 26+ / macOS 26+ (Mac Catalyst).
Cumplimiento VeriFactu (Real Decreto 1007/2023) — Fase 1 implementada (hash chain SHA-256, inalterabilidad).

## Stack
- SwiftUI, SwiftData, Swift 6 (strict concurrency)
- Apple Foundation Models (`@Generable`, `Tool` protocol)
- Speech framework (es-ES)
- CryptoKit (SHA-256 para VeriFactu)
- PDFKit, UserNotifications, BackgroundTasks, PhotosUI

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

## Estructura
```
FacturaApp/
├── Models.swift              # @Model entities + enums + DataConfig + RegistroFacturacion
├── SpeechService.swift       # Speech framework (es-ES)
├── CommandAIService.swift    # IA con 7 Tools (Foundation Models)
├── VoiceMainView.swift       # Vista principal chat + @main + Bandeja
├── ClientesView.swift        # CRUD clientes
├── ArticulosView.swift       # CRUD artículos + FlowLayout
├── FacturasListView.swift    # Dashboard + lista + detalle + emit/anular/rectificar
├── FacturaPDFGenerator.swift # PDF A4 + preview + ShareSheet
├── FacturaCardView.swift     # Tarjeta de factura en chat + FacturaChatCard
├── FacturaEditView.swift     # Editor factura fullscreen + LineaEditRow
├── FacturaEditAIService.swift # IA contextual para editar facturas (4 tools)
├── VeriFactuHashService.swift # SHA-256 hash chain + verificación
├── AjustesView.swift         # Config negocio + onboarding
├── FacturaVencimientoService.swift # Vencimientos + notificaciones
├── FacturaAIService.swift    # Legacy (referencia)
└── FacturaAIView.swift       # Legacy (referencia)
```

## Errores frecuentes a evitar
- NO usar rawValue abreviado en enums de @Model (SwiftData guarda el nombre del caso)
- NO olvidar `import SwiftUI` en archivos que usan ViewModifier, View, @Environment
- NO usar `#Predicate` con comparaciones de enum (fetch all + filter en memoria)
- NO usar `.id(UUID())` en List dentro de NavigationStack (causa feedback loop)
- NO olvidar `@preconcurrency import` para Speech y AVFoundation
- NO crear `@StateObject` con `ModelContext` externo sin usar `DataConfig.container.mainContext`
