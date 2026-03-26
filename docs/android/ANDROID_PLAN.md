# EhFacturas! Android — Plan de implementación completo

## Resumen

Versión Android nativa de EhFacturas! con paridad total de features.
Kotlin + Jetpack Compose + Room + Gemini (on-device/cloud).

## Stack tecnológico

| Componente | iOS (actual) | Android (nuevo) |
|---|---|---|
| Lenguaje | Swift 6 | Kotlin 2.0 |
| UI | SwiftUI | Jetpack Compose + Material 3 |
| Base de datos | SwiftData + CloudKit | Room + Firebase Firestore |
| IA on-device | Apple Foundation Models | Gemini Nano (AICore) |
| IA cloud | Claude API + OpenAI API | Mismos (compartidos) |
| Voz → texto | Speech framework | SpeechRecognizer (Android) |
| Texto → voz | AVSpeechSynthesizer | Android TextToSpeech |
| PDF | UIGraphicsPDFRenderer | Android Canvas + PdfDocument |
| QR | CoreImage CIQRCodeGenerator | ZXing / ML Kit Barcode |
| OCR | VisionKit DataScanner | ML Kit Text Recognition |
| Hashes | CryptoKit SHA-256 | java.security MessageDigest |
| Firma digital | Security.framework RSA | Java Security / Bouncy Castle |
| Certificados | Keychain | Android KeyStore |
| SOAP | URLSession | OkHttp / Retrofit |
| Suscripciones | StoreKit 2 | Google Play Billing Library |
| Notificaciones | UserNotifications | NotificationManager + WorkManager |
| Background | BackgroundTasks | WorkManager |
| Fotos | PhotosUI PhotosPicker | ActivityResultContracts |
| Escáner | VisionKit | CameraX + ML Kit |
| Conectividad | NWPathMonitor | ConnectivityManager |
| Shortcuts | App Intents | App Actions / Shortcuts |
| Widget | WidgetKit | Glance (Jetpack) |
| Sync | CloudKit | Firebase Firestore |

## Estructura del proyecto Android

```
EhFacturas-Android/
├── app/
│   ├── src/main/
│   │   ├── java/es/ehfacturas/
│   │   │   ├── EhFacturasApp.kt                    # Application class
│   │   │   ├── MainActivity.kt                     # Single activity
│   │   │   │
│   │   │   ├── data/                                # Capa de datos
│   │   │   │   ├── db/
│   │   │   │   │   ├── AppDatabase.kt               # Room database
│   │   │   │   │   ├── dao/
│   │   │   │   │   │   ├── NegocioDao.kt
│   │   │   │   │   │   ├── ClienteDao.kt
│   │   │   │   │   │   ├── ArticuloDao.kt
│   │   │   │   │   │   ├── FacturaDao.kt
│   │   │   │   │   │   ├── LineaFacturaDao.kt
│   │   │   │   │   │   ├── GastoDao.kt
│   │   │   │   │   │   ├── RegistroFacturacionDao.kt
│   │   │   │   │   │   └── PlantillaDao.kt
│   │   │   │   │   └── entity/
│   │   │   │   │       ├── Negocio.kt
│   │   │   │   │       ├── Cliente.kt
│   │   │   │   │       ├── Categoria.kt
│   │   │   │   │       ├── Articulo.kt
│   │   │   │   │       ├── Factura.kt
│   │   │   │   │       ├── LineaFactura.kt
│   │   │   │   │       ├── Gasto.kt
│   │   │   │   │       ├── RegistroFacturacion.kt
│   │   │   │   │       ├── FacturaRecurrente.kt
│   │   │   │   │       ├── PlantillaFactura.kt
│   │   │   │   │       ├── EventoSIF.kt
│   │   │   │   │       └── PerfilImportacion.kt
│   │   │   │   ├── repository/
│   │   │   │   │   ├── NegocioRepository.kt
│   │   │   │   │   ├── ClienteRepository.kt
│   │   │   │   │   ├── ArticuloRepository.kt
│   │   │   │   │   ├── FacturaRepository.kt
│   │   │   │   │   ├── GastoRepository.kt
│   │   │   │   │   └── VeriFactuRepository.kt
│   │   │   │   └── preferences/
│   │   │   │       └── AppPreferences.kt            # DataStore
│   │   │   │
│   │   │   ├── domain/                              # Lógica de negocio
│   │   │   │   ├── actions/
│   │   │   │   │   ├── FacturaActions.kt            # ≡ FacturaActions.swift
│   │   │   │   │   ├── FiscalCalculator.kt          # IVA, IRPF, totales
│   │   │   │   │   └── FuzzyMatcher.kt              # Búsqueda fuzzy artículos
│   │   │   │   ├── verifactu/
│   │   │   │   │   ├── VeriFactuHashService.kt      # SHA-256 chain
│   │   │   │   │   ├── VeriFactuXMLGenerator.kt     # XML XSD AEAT
│   │   │   │   │   ├── VeriFactuSOAPClient.kt       # SOAP + certificado
│   │   │   │   │   ├── VeriFactuXMLSigner.kt        # XMLDSig
│   │   │   │   │   └── CertificateManager.kt        # KeyStore
│   │   │   │   ├── importador/
│   │   │   │   │   ├── CSVParser.kt
│   │   │   │   │   ├── MapeoUniversal.kt
│   │   │   │   │   └── DetectorOrigen.kt
│   │   │   │   └── pdf/
│   │   │   │       └── FacturaPDFGenerator.kt       # PDF A4 + QR
│   │   │   │
│   │   │   ├── ai/                                  # Capa de IA
│   │   │   │   ├── AIProvider.kt                    # Interface
│   │   │   │   ├── AIProviderFactory.kt
│   │   │   │   ├── GeminiAIProvider.kt              # Gemini Nano on-device
│   │   │   │   ├── ClaudeAIProvider.kt              # Claude API
│   │   │   │   ├── OpenAIProvider.kt                # OpenAI API
│   │   │   │   ├── CloudToolSchemas.kt              # JSON schemas
│   │   │   │   └── ToolExecutor.kt                  # Route tool calls
│   │   │   │
│   │   │   ├── speech/                              # Voz
│   │   │   │   ├── SpeechService.kt                 # SpeechRecognizer
│   │   │   │   └── TTSService.kt                    # TextToSpeech
│   │   │   │
│   │   │   ├── ui/                                  # Presentación
│   │   │   │   ├── theme/
│   │   │   │   │   ├── Theme.kt                     # Material 3 theme
│   │   │   │   │   ├── Color.kt
│   │   │   │   │   └── Type.kt
│   │   │   │   ├── main/
│   │   │   │   │   ├── MainScreen.kt                # ≡ VoiceMainView
│   │   │   │   │   ├── WelcomeSection.kt            # ≡ WelcomeView
│   │   │   │   │   ├── ChatMessageItem.kt           # ≡ ChatMessageView
│   │   │   │   │   └── CommandInputBar.kt           # ≡ CommandInputBar
│   │   │   │   ├── bandeja/
│   │   │   │   │   ├── BandejaScreen.kt             # ≡ BandejaManualView
│   │   │   │   │   ├── FacturasScreen.kt
│   │   │   │   │   ├── ClientesScreen.kt
│   │   │   │   │   ├── ArticulosScreen.kt
│   │   │   │   │   ├── GastosScreen.kt
│   │   │   │   │   ├── InformesScreen.kt
│   │   │   │   │   └── AjustesScreen.kt
│   │   │   │   ├── factura/
│   │   │   │   │   ├── FacturaDetalleScreen.kt
│   │   │   │   │   ├── FacturaEditScreen.kt         # ≡ FacturaEditView
│   │   │   │   │   ├── FacturaCardComposable.kt     # ≡ FacturaCardView
│   │   │   │   │   ├── FotosScreen.kt
│   │   │   │   │   ├── FirmaScreen.kt               # Canvas signature
│   │   │   │   │   └── PDFPreviewScreen.kt
│   │   │   │   ├── importador/
│   │   │   │   │   ├── ImportarScreen.kt
│   │   │   │   │   └── MapeoManualScreen.kt
│   │   │   │   ├── scanner/
│   │   │   │   │   └── ScannerScreen.kt             # CameraX + ML Kit
│   │   │   │   ├── subscription/
│   │   │   │   │   └── SubscriptionScreen.kt
│   │   │   │   └── whatsnew/
│   │   │   │       └── WhatsNewScreen.kt
│   │   │   │
│   │   │   ├── service/                             # Servicios
│   │   │   │   ├── VencimientoWorker.kt             # WorkManager
│   │   │   │   ├── OfflineQueueService.kt
│   │   │   │   ├── BackupService.kt
│   │   │   │   └── EventLogService.kt
│   │   │   │
│   │   │   ├── widget/                              # Widget
│   │   │   │   └── FacturaWidget.kt                 # Glance widget
│   │   │   │
│   │   │   └── di/                                  # Dependency Injection
│   │   │       └── AppModule.kt                     # Hilt/Koin modules
│   │   │
│   │   └── res/
│   │       ├── values/strings.xml                   # Español
│   │       ├── values-en/strings.xml                # English
│   │       ├── values-ca/strings.xml                # Català
│   │       ├── values-eu/strings.xml                # Euskera
│   │       └── values-gl/strings.xml                # Galego
│   │
│   ├── build.gradle.kts
│   └── proguard-rules.pro
│
├── build.gradle.kts                                 # Root
├── settings.gradle.kts
├── gradle.properties
└── README.md
```

## Dependencias (build.gradle.kts)

```kotlin
dependencies {
    // Compose
    implementation(platform("androidx.compose:compose-bom:2025.01.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.navigation:navigation-compose:2.7.7")

    // Room (SQLite)
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    // Gemini AI (on-device)
    implementation("com.google.ai.client.generativeai:generativeai:0.9.0")
    // Gemini Nano (AICore) when available
    implementation("com.google.android.gms:play-services-ai-generativeai:17.0.0")

    // OkHttp + Retrofit (SOAP + API calls)
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")

    // ML Kit (OCR + Barcode/QR)
    implementation("com.google.mlkit:text-recognition:16.0.0")
    implementation("com.google.mlkit:barcode-scanning:17.2.0")

    // CameraX
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")
    implementation("androidx.camera:camera-view:1.3.1")

    // WorkManager (background tasks)
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // DataStore (preferences)
    implementation("androidx.datastore:datastore-preferences:1.0.0")

    // Billing (subscriptions)
    implementation("com.android.billingclient:billing-ktx:6.2.0")

    // Firebase (sync)
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")

    // Charts
    implementation("com.patrykandpatrick.vico:compose-m3:2.0.0-alpha.12")

    // ZXing (QR generation)
    implementation("com.google.zxing:core:3.5.3")

    // Glance (widgets)
    implementation("androidx.glance:glance-appwidget:1.1.0")

    // Hilt (DI)
    implementation("com.google.dagger:hilt-android:2.50")
    ksp("com.google.dagger:hilt-compiler:2.50")

    // Tests
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.0")
    testImplementation("androidx.room:room-testing:2.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
```

## Fases de implementación

### Fase 1: Base (2 semanas)
1. Proyecto Android Studio + dependencias
2. Room database con 12 entidades (≡ SwiftData)
3. Repositories + DAOs
4. Theme Material 3 (dark/light)
5. Navegación Compose (NavHost)
6. MainScreen con estructura básica

### Fase 2: CRUD (1 semana)
7. ClientesScreen (lista + detalle + formulario)
8. ArticulosScreen (lista + categorías + formulario)
9. FacturasScreen (dashboard + lista + detalle)
10. GastosScreen (lista + formulario)

### Fase 3: IA + Voz (2 semanas)
11. SpeechService (SpeechRecognizer Android)
12. AIProvider interface
13. GeminiAIProvider (Gemini Nano on-device o Gemini API)
14. ClaudeAIProvider + OpenAIProvider (reutilizar schemas)
15. FacturaActions.kt (lógica compartida)
16. ToolExecutor (routing de tool calls)
17. CommandInputBar + chat UI
18. TTSService (TextToSpeech)

### Fase 4: PDF + VeriFactu (1 semana)
19. FacturaPDFGenerator (Canvas + PdfDocument)
20. QR generator (ZXing)
21. VeriFactuHashService (MessageDigest SHA-256)
22. VeriFactuXMLGenerator (misma estructura XML)
23. VeriFactuSOAPClient (OkHttp + certificado)

### Fase 5: Features avanzadas (1 semana)
24. Importador CSV (CSVParser.kt)
25. Escáner OCR (CameraX + ML Kit)
26. Fotos en facturas
27. Firma del cliente (Canvas Compose)
28. Presupuestos + rectificativas
29. Facturas recurrentes + plantillas

### Fase 6: Infra + publicación (1 semana)
30. Firebase Firestore sync
31. Google Play Billing (suscripción Pro)
32. WorkManager (vencimientos background)
33. Widget (Glance)
34. Notificaciones
35. Offline queue
36. Backup JSON
37. Privacy + proguard
38. Google Play Store submission

## Total estimado: 8 semanas

## Código compartido (reutilizable entre iOS y Android)

| Componente | Reutilizable | Formato |
|---|---|---|
| Backend proxy (CloudFlare Worker) | 100% | JavaScript |
| CloudToolSchemas (JSON) | 100% | JSON → Kotlin |
| Lógica VeriFactu (hash, XML) | ~90% lógica | Swift → Kotlin (traducir) |
| CSV sinónimos (MapeoUniversal) | 100% datos | Copiar arrays |
| System prompt IA | 100% | String |
| Traducciones | 100% | .strings → strings.xml |
| PDF layout (medidas, colores) | ~95% | Traducir coordenadas |

## Notas importantes

- **Gemini Nano** es el equivalente de Apple Intelligence en Android — on-device, gratuito, pero solo en Pixel 8+ y Samsung Galaxy S24+
- **Gemini API** (cloud) es la alternativa para otros dispositivos Android — similar a Claude/OpenAI
- **Room** es más explícito que SwiftData (necesita DAOs, queries SQL) pero más predecible
- **Jetpack Compose** es muy similar a SwiftUI en concepto (declarativo, state-driven)
- **Material 3** tiene su propio design system (diferente de iOS pero igualmente moderno)
- **No existe equivalente exacto de CloudKit** en Android — Firebase Firestore es la alternativa más cercana
