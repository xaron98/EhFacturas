# EhFacturas!

App de facturación voice-first para autónomos y pequeñas empresas en España. Controla toda la app con tu voz: crea clientes, artículos, facturas — todo hablando. La IA interpreta el lenguaje natural y ejecuta las acciones automáticamente.

**iOS 17+ / macOS 14+** — Apple Intelligence on-device (iOS 26+) o Claude/OpenAI cloud

---

## Novedades — v1.0.0

| | Novedad | Descripción |
|---|---|---|
| 🎙️ | **Control por voz** | Crea facturas, clientes y artículos hablando. La IA interpreta tus comandos. |
| 📄 | **Facturas y presupuestos** | PDF profesional A4 con código QR, desglose IVA/IRPF y logo personalizable. |
| 🛡️ | **VeriFactu** | Cumplimiento del RD 1007/2023: hash SHA-256, XML AEAT, firma digital. |
| 🔄 | **Facturas recurrentes** | Programa facturas semanales, mensuales, trimestrales o anuales. |
| 📋 | **Plantillas** | Guarda combinaciones frecuentes y crea facturas en un toque. |
| 📊 | **Informes financieros** | Dashboard interactivo con gráficos, top clientes, gastos por categoría y exportación CSV. |
| 📸 | **Fotos y firma** | Adjunta fotos del trabajo realizado y recoge la firma del cliente en pantalla. |
| 📱 | **Escáner OCR** | Escanea tickets y documentos con la cámara para procesarlos con IA. |
| 📥 | **Importador universal** | Importa datos de Salfon, Contaplus, Holded, Billin y más desde CSV. |
| ☁️ | **Sincronización iCloud** | Tus datos en todos tus dispositivos automáticamente. |
| 🌍 | **Multi-idioma** | Disponible en español, inglés, catalán, euskera y gallego. |
| 🔊 | **Voz de la IA** | La IA lee las respuestas en voz alta. Elige entre voz femenina o masculina. |
| ✨ | **Apple Intelligence + Cloud** | IA on-device en iOS 26+. Claude y OpenAI como alternativa en iOS 17+. |
| 💰 | **Gastos** | Registra gastos del negocio para calcular el beneficio neto real. |
| 📡 | **Modo offline** | Cola de comandos inteligente cuando no hay conexión. |
| ✏️ | **Firma del cliente** | El cliente firma en la pantalla del dispositivo. |
| 💾 | **Backup** | Exporta todos tus datos como archivo JSON. |
| 📱 | **Modo iPad** | Layout sidebar adaptativo en iPad. |

---

## Características

### Voice-First
- Micrófono como interfaz principal — habla y la IA ejecuta
- 16 herramientas de IA: crear clientes, artículos, facturas, presupuestos, buscar, anular, deshacer, importar, gastos, recurrentes, configurar negocio
- Onboarding conversacional: configura tu negocio hablando
- Multi-comando: "crea un cliente y hazle una factura" en una frase
- Contexto persistente: "hazle otra factura al mismo cliente"
- Feedback dinámico: "Generando factura...", "Buscando cliente...", etc.

### Facturación completa
- CRUD de clientes, artículos y facturas
- Presupuestos (convertibles a factura)
- Facturas rectificativas y anulaciones
- Facturas con múltiples tipos de IVA (21%, 10%, 4%, exento)
- IRPF configurable (7% nuevos autónomos / 15% general)
- Numeración correlativa automática
- Descuentos por línea y globales
- Plantillas de factura reutilizables
- Facturas recurrentes (semanal/mensual/trimestral/anual)

### Edición en tiempo real con IA
- Tarjeta de factura interactiva en el chat
- Editor a pantalla completa con edición manual + IA
- "Cambia las bombillas a 10" — se actualiza al instante
- Deshacer por voz: "deshaz lo último"

### PDF profesional
- Formato A4 con colores corporativos
- Logo del negocio configurable
- Desglose de IVA por tipo
- Código QR verificable (VeriFactu)
- Fotos del trabajo adjuntables
- Firma del cliente
- Compartir por email, WhatsApp, AirDrop

### Importador universal CSV
- Compatible con: Salfon, Contaplus, a3factura, Holded, Billin, Quipu, FacturaDirecta, Debitoor/SumUp
- Detección automática del programa de origen
- 500+ sinónimos para mapeo automático
- Perfiles guardables para reutilizar

### Informes financieros
- Dashboard con gráficos interactivos (toca para ver detalle)
- Resumen: facturado, cobrado, pendiente, vencido
- Top 5 clientes
- Gastos por categoría
- Beneficio neto real
- Exportar a CSV

### Cumplimiento legal — VeriFactu y futuros sistemas
- Hash chain SHA-256 inmutable
- XML conforme XSD AEAT V1.0
- Cliente SOAP con certificado digital X.509
- Firma XMLDSig (C14N + RSA-SHA256)
- Cola offline (4 días máximo)
- Registro de fabricante

> **Nota:** La arquitectura de EhFacturas! está diseñada para ser compatible y adaptable a cualquier sistema de facturación electrónica que entre en vigor en España, ya sea VeriFactu (RD 1007/2023) o cualquier normativa que lo sustituya. La base técnica (cadena de hashes, registros inmutables, firma digital, comunicación con la AEAT) se adaptará al nuevo marco legal cuando se publiquen las especificaciones definitivas.

### Multi-proveedor IA
- Apple Intelligence (on-device, gratis, iOS 26+)
- Claude Haiku (Anthropic, cloud)
- OpenAI GPT-4o-mini (cloud)
- Selección automática o manual en Ajustes
- Suscripción Pro para cloud AI

### Extras
- Gastos del negocio con categorías
- Escáner OCR (VisionKit)
- Siri Shortcuts
- Voz de la IA (femenina/masculina)
- Vencimientos con notificaciones locales
- Modo offline inteligente
- Backup JSON exportable
- Modo iPad con sidebar
- Widget de facturación
- Dark/Light/Auto theme
- Haptic feedback
- Accesibilidad VoiceOver completa
- 5 idiomas (es, en, ca, eu, gl)
- 150+ tests unitarios

---

## Stack tecnológico

| Componente | Tecnología |
|---|---|
| UI | SwiftUI |
| Base de datos | SwiftData + CloudKit |
| IA on-device | Apple Foundation Models |
| IA cloud | Claude API + OpenAI API |
| Voz | Speech framework (es-ES) |
| TTS | AVSpeechSynthesizer |
| PDF | UIGraphicsPDFRenderer + PDFKit |
| QR | CoreImage (CIQRCodeGenerator) |
| OCR | VisionKit (DataScannerViewController) |
| Hashes | CryptoKit (SHA-256) |
| Firma digital | Security.framework (RSA-SHA256) |
| Certificados | Security.framework (Keychain) |
| SOAP | URLSession + client certificate |
| Suscripciones | StoreKit 2 |
| Conectividad | Network (NWPathMonitor) |
| Notificaciones | UserNotifications |
| Background | BackgroundTasks |
| Importación | CSV parser nativo (multi-encoding) |
| Shortcuts | App Intents |

---

## Requisitos

- **iOS 17.0+** / **macOS 14.0+** (Mac Catalyst)
- iPhone, iPad, Mac con Apple Silicon
- iOS 26+ recomendado para Apple Intelligence (IA on-device gratuita)
- Xcode 26+ para compilar

---

## Configuración

1. Clona el repositorio
2. Abre `FacturaApp.xcodeproj` en Xcode 26
3. Selecciona tu equipo de desarrollo en Signing & Capabilities
4. Ejecuta en un dispositivo o simulador

### VeriFactu (opcional)
1. Ajustes > VeriFactu > Importar certificado digital (.p12)
2. Activa "Envío automático a AEAT"
3. Usa "Entorno de pruebas" durante el desarrollo

---

## Comandos de voz de ejemplo

| Comando | Acción |
|---|---|
| "Me llamo Juan García, NIF 12345678A" | Configura el negocio |
| "Añade un cliente Pedro López, teléfono 612345678" | Crea cliente |
| "Añade bombilla LED a 3,50 euros" | Crea artículo |
| "Factura para Pedro con 5 bombillas y 2 horas de mano de obra" | Crea factura |
| "Presupuesto para la comunidad de vecinos" | Crea presupuesto |
| "Cambia las bombillas a 10" | Edita factura en tiempo real |
| "Deshaz lo último" | Revierte la última acción |
| "La factura de Pedro ya está cobrada" | Marca como pagada |
| "Anula la última factura" | Anula factura |
| "Factura mensual para Juan por 150€" | Crea factura recurrente |
| "He comprado material por 50€" | Registra gasto |
| "Importa artículos de Salfon" | Importa CSV |
| "¿Cuánto tengo pendiente de cobrar?" | Consulta resumen |
| "Crea cliente Pedro y hazle factura con 3 bombillas" | Multi-comando |

---

## Licencia

MIT

---

Desarrollado con [Claude Code](https://claude.ai/claude-code)
