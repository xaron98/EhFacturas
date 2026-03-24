# EhFacturas!

App de facturación voice-first para autónomos y pequeñas empresas en España. Controla toda la app con tu voz: crea clientes, artículos, facturas — todo hablando. La IA interpreta el lenguaje natural y ejecuta las acciones automáticamente.

**iOS 26+ / macOS 26+ (Mac Catalyst)** — Requiere Apple Intelligence

---

## Características

### Voice-First
- Micrófono como interfaz principal — habla y la IA ejecuta
- 10 herramientas de IA: crear clientes, artículos, facturas, buscar, anular, importar, consultar resumen, configurar negocio
- Onboarding conversacional: configura tu negocio hablando
- Campo de texto como alternativa al micrófono

### Facturación completa
- CRUD de clientes, artículos y facturas
- Categorías de artículos predefinidas
- Facturas con múltiples tipos de IVA (21%, 10%, 4%, exento)
- IRPF configurable (7% nuevos autónomos / 15% general)
- Numeración correlativa automática
- Descuentos por línea y globales
- Facturas rectificativas y anulaciones

### Edición en tiempo real con IA
- Tarjeta de factura interactiva en el chat
- Editor a pantalla completa con edición manual + IA
- "Cambia las bombillas a 10" — la factura se actualiza al instante
- Genera PDF desde el editor

### Importador universal CSV
- Importa artículos y clientes desde cualquier programa de facturación
- Compatible con: Salfon, Contaplus, a3factura, Holded, Billin, Quipu, FacturaDirecta, Debitoor/SumUp, y CSV genérico
- Detección automática del programa de origen
- 500+ sinónimos para mapeo automático de columnas
- Mapeo manual cuando falla la detección
- Perfiles guardables para reutilizar
- Multi-encoding: UTF-8, ISO-8859-1, Windows-1252
- Por voz: "Importa artículos de Salfon"

### PDF profesional
- Formato A4 con colores corporativos
- Logo del negocio configurable
- Desglose de IVA por tipo
- Código QR verificable (VeriFactu)
- Compartir por email, WhatsApp, AirDrop

### VeriFactu (RD 1007/2023)
Cumplimiento completo del reglamento de facturación verificable:

- **Hash chain SHA-256** — cadena inmutable de registros
- **XML conforme XSD AEAT V1.0** — formato oficial de la Agencia Tributaria
- **Cliente SOAP** — envío automático a la AEAT con certificado digital X.509
- **Firma XMLDSig** — canonicalización C14N + RSA-SHA256
- **Cola offline** — reintentos automáticos (plazo máximo 4 días)
- **Inalterabilidad** — facturas emitidas bloqueadas, solo anulación o rectificativa
- **Registro de fabricante** — declaración responsable conforme al RD
- **Exportar XML** — comparte el XML VeriFactu de cada factura

### Extras
- Vencimientos con notificaciones locales
- Log de eventos para auditoría
- Background tasks para revisar vencimientos
- Borrado lógico (datos nunca se pierden)

---

## Stack tecnológico

| Componente | Tecnología |
|---|---|
| UI | SwiftUI |
| Base de datos | SwiftData |
| IA on-device | Apple Foundation Models |
| Voz | Speech framework (es-ES) |
| PDF | UIGraphicsPDFRenderer + PDFKit |
| QR | CoreImage (CIQRCodeGenerator) |
| Hashes | CryptoKit (SHA-256) |
| Firma digital | Security.framework (RSA-SHA256) |
| Certificados | Security.framework (Keychain) |
| SOAP | URLSession + client certificate |
| Notificaciones | UserNotifications |
| Background | BackgroundTasks |
| Importación | CSV parser nativo (multi-encoding) |

---

## Estructura del proyecto

```
FacturaApp/
├── Models.swift                     # 9 modelos SwiftData + enums
├── SpeechService.swift              # Reconocimiento de voz es-ES
├── CommandAIService.swift           # 10 Tools IA (Foundation Models)
├── VoiceMainView.swift              # Chat principal + @main
├── ClientesView.swift               # CRUD clientes
├── ArticulosView.swift              # CRUD artículos + FlowLayout
├── FacturasListView.swift           # Dashboard + detalle + acciones
├── FacturaCardView.swift            # Tarjeta de factura en chat
├── FacturaEditView.swift            # Editor factura + IA inline
├── FacturaEditAIService.swift       # 4 Tools edición de factura
├── FacturaPDFGenerator.swift        # PDF A4 + QR + preview
├── MapeoUniversal.swift             # Sinónimos + detector programa + mapeo
├── ImportadorService.swift          # Parser CSV + importador + vista
├── AjustesView.swift                # Config negocio + certificado
├── VeriFactuHashService.swift       # SHA-256 cadena de hashes
├── VeriFactuXMLGenerator.swift      # XML XSD AEAT V1.0
├── VeriFactuSOAPClient.swift        # Cliente SOAP + cola offline
├── VeriFactuCertificateManager.swift # Certificado .p12 + Keychain
├── VeriFactuXMLSigner.swift         # Firma XMLDSig (C14N + RSA)
├── EventLogService.swift            # Registro de eventos
├── EventLogView.swift               # Vista log de auditoría
├── FacturaVencimientoService.swift  # Vencimientos + notificaciones
├── FacturaAIService.swift           # Legacy (referencia)
└── FacturaAIView.swift              # Legacy (referencia)
```

---

## Requisitos

- **iOS 26.0+** / **macOS 26.0+** (Mac Catalyst)
- **Apple Intelligence** activado en el dispositivo
- iPhone 15 Pro o superior / iPad con M1+ / Mac con Apple Silicon
- Xcode 26+

---

## Configuración

1. Clona el repositorio
2. Abre `FacturaApp.xcodeproj` en Xcode 26
3. Selecciona tu equipo de desarrollo en Signing & Capabilities
4. Ejecuta en un dispositivo compatible con Apple Intelligence

### VeriFactu (opcional)
Para enviar facturas a la AEAT:
1. Ve a Ajustes > VeriFactu
2. Importa tu certificado digital (.p12)
3. Activa "Envío automático a AEAT"
4. Usa "Entorno de pruebas" durante el desarrollo

---

## Comandos de voz de ejemplo

| Comando | Acción |
|---|---|
| "Me llamo Juan García, NIF 12345678A" | Configura el negocio |
| "Añade un cliente Pedro López, teléfono 612345678" | Crea cliente |
| "Añade bombilla LED a 3,50 euros" | Crea artículo |
| "Factura para Pedro con 5 bombillas y 2 horas de mano de obra" | Crea factura |
| "Cambia las bombillas a 10" | Edita la factura en tiempo real |
| "La factura de Pedro ya está cobrada" | Marca como pagada |
| "Anula la última factura" | Anula factura |
| "Importa artículos de Salfon" | Abre importador CSV |
| "Carga clientes desde un archivo" | Importa clientes CSV |
| "¿Cuánto tengo pendiente de cobrar?" | Consulta resumen |

---

## Programas de importación compatibles

| Programa | Detección automática |
|---|---|
| Salfon (Saltoki) | Sí |
| Contaplus / Contawin | Sí |
| a3factura (Wolters Kluwer) | Sí |
| Holded | Sí |
| Billin | Sí |
| Quipu | Sí |
| FacturaDirecta | Sí |
| Debitoor / SumUp | Parcial |
| Cualquier CSV genérico | Sí (por sinónimos) |

---

## Licencia

MIT

---

Desarrollado con [Claude Code](https://claude.ai/claude-code)
