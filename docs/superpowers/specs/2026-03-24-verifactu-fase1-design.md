# VeriFactu Fase 1 — Hash Chain + Inalterabilidad

## Resumen

Implementar la base del cumplimiento VeriFactu (Real Decreto 1007/2023) en FacturaApp: cadena de hashes SHA-256 por factura, registros de facturación inmutables, bloqueo de edición post-emisión, facturas rectificativas y registros de anulación. Sin envío a la AEAT en esta fase (sistema NO VeriFactu).

## Contexto

- App de facturación voice-first para autónomos en España
- Un solo NIF por instalación (una cadena de hashes)
- Stack: SwiftUI, SwiftData, Swift 6, iOS 26 / macOS 26 (Mac Catalyst)
- CryptoKit disponible nativamente para SHA-256

## Modelo: RegistroFacturacion

Entidad SwiftData inmutable. Se crea al emitir o anular una factura. Nunca se modifica ni se borra.

### Campos

| Campo | Tipo | Descripción |
|---|---|---|
| tipoRegistro | TipoRegistro | .alta o .anulacion |
| nifEmisor | String | Snapshot del NIF del negocio |
| numeroFactura | String | Nº factura |
| serieFactura | String | Serie/prefijo |
| fechaExpedicion | Date | Fecha de emisión |
| tipoFactura | TipoFacturaVF | .completa, .simplificada, .rectificativa |
| facturaRectificadaNumero | String? | Nº de la factura que rectifica |
| descripcionOperacion | String | Resumen de conceptos |
| baseImponible | Double | Base imponible |
| totalIVA | Double | Total IVA |
| totalIRPF | Double | Total IRPF |
| importeTotal | Double | Total factura |
| nifDestinatario | String | NIF del cliente |
| nombreDestinatario | String | Nombre del cliente |
| hashRegistro | String | SHA-256 calculado |
| hashRegistroAnterior | String | Hash del registro previo (vacío si primero) |
| fechaHoraGeneracion | Date | Timestamp exacto |
| factura | Factura? | Referencia a la factura origen |

### Enums

```swift
enum TipoRegistro: String, Codable { case alta, anulacion }
enum TipoFacturaVF: String, Codable { case completa, simplificada, rectificativa }
```

## Motor de hashes (SHA-256)

Archivo: `VeriFactuHashService.swift`

### Cálculo del hash

1. Concatenar campos en orden fijo separados por `|`:
   `nifEmisor|numeroFactura|serieFactura|fechaExpedicion(yyyyMMdd)|tipoFactura|importeTotal(2decimales)|hashRegistroAnterior|fechaHoraGeneracion(ISO8601)`
2. Codificar como UTF-8
3. Aplicar SHA-256 con CryptoKit
4. Resultado como String hexadecimal (64 caracteres)

### Cadena

- Buscar el último RegistroFacturacion (ordenado por fechaHoraGeneracion DESC) para obtener hashAnterior
- El primer registro tiene hashAnterior = "" (cadena vacía)
- Una sola cadena por instalación (un NIF)

## Bloqueo de edición post-emisión

- Factura con estado != .borrador → solo lectura
- FacturaEditView: deshabilitar campos manuales y barra IA
- FacturaEditAIService: rechazar comandos
- FacturasListView: deshabilitar swipe editar en emitidas

## Facturas rectificativas

- Nuevo campo en Factura: `tipoFactura` (TipoFacturaVF, default .completa)
- Nuevo campo en Factura: `facturaRectificada` (Factura?, referencia a la original)
- Acción "Rectificar" en factura emitida/anulada:
  1. Crea nueva factura borrador con datos copiados de la original
  2. tipoFactura = .rectificativa
  3. facturaRectificada = original
  4. Usuario modifica lo que necesite
  5. Al emitir → RegistroFacturacion con tipoFactura = .rectificativa

## Registros de anulación

- Anular factura emitida → crea RegistroFacturacion con tipoRegistro = .anulacion
- El registro de anulación entra en la cadena de hashes
- La factura se marca como .anulada pero no se borra ni modifica

## Flujo de emisión

```
Borrador → [editable]
    ↓ "Emitir"
    1. Crear RegistroFacturacion(tipo: .alta)
    2. Calcular hash SHA-256 (con hashAnterior del último registro)
    3. Guardar registro
    4. Cambiar factura.estado = .emitida
    5. Bloquear edición
    ↓
Emitida → [BLOQUEADA]
    ↓ "Anular"
    1. Crear RegistroFacturacion(tipo: .anulacion)
    2. Calcular hash SHA-256
    3. Guardar registro
    4. Cambiar factura.estado = .anulada
    ↓ "Rectificar"
    1. Crear nueva factura borrador (copia de la original)
    2. factura.tipoFactura = .rectificativa
    3. factura.facturaRectificada = original
    4. Usuario edita → Emitir → nuevo RegistroFacturacion
```

## Archivos afectados

| Archivo | Cambio |
|---|---|
| Models.swift | Añadir RegistroFacturacion, TipoRegistro, TipoFacturaVF, campos nuevos en Factura |
| VeriFactuHashService.swift | NUEVO — SHA-256 + cadena de hashes |
| FacturaEditView.swift | Bloquear edición si no es borrador, mostrar info hash |
| FacturaEditAIService.swift | Rechazar comandos si no es borrador |
| FacturasListView.swift | Acción "Rectificar" en detalle, bloquear swipes en emitidas |
| CommandAIService.swift | Emitir crea registro con hash |
