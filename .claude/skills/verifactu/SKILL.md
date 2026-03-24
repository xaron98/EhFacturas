---
name: verifactu
description: Conocimiento del sistema VeriFactu (Real Decreto 1007/2023) para facturación electrónica en España. Usar cuando se trabaje con hashes SHA-256, registros de facturación, inalterabilidad, facturas rectificativas, generación XML para AEAT, o cualquier aspecto fiscal/legal de la app.
user-invocable: false
---

# VeriFactu — Normativa y requisitos técnicos

## Normativa
- Real Decreto 1007/2023 (5 diciembre) — Sistema de emisión de facturas verificables
- Aplica en territorio común (no País Vasco ni Navarra)
- Obligatorio para autónomos y sociedades

## Estado actual de la app (Fase 1 — NO VeriFactu)
- Hash chain SHA-256 implementado en `VeriFactuHashService.swift`
- Registros inmutables en `RegistroFacturacion` (Models.swift)
- Bloqueo de edición post-emisión
- Facturas rectificativas y registros de anulación
- NO envía a la AEAT todavía (sistema NO VeriFactu)

## Cadena de hashes
- Algoritmo: SHA-256 (CryptoKit)
- Campos concatenados con `|`: nifEmisor, numeroFactura, serieFactura, fechaExpedicion (yyyyMMdd), tipoFactura, importeTotal (2 decimales), hashAnterior, fechaHoraGeneracion (ISO8601)
- Una cadena por NIF (un NIF por instalación)
- Primer registro: hashAnterior = "" (vacío)

## Reglas de inalterabilidad
- Factura emitida → NUNCA se modifica. Solo anulación o rectificativa.
- Anulación → crea RegistroFacturacion(tipo: .anulacion) con hash
- Rectificativa → nueva factura con tipoFactura = .rectificativa que referencia la original
- Los borradores SÍ se pueden editar libremente

## Fases pendientes
- Fase 2: Generación XML (XSD AEAT)
- Fase 3: Cliente SOAP para AEAT + certificado digital X.509
- Fase 4: Código QR verificable en PDFs
- Fase 5: Log de eventos y registro de fabricante

## Archivos clave
- `Models.swift` — RegistroFacturacion, TipoRegistro, TipoFacturaVF
- `VeriFactuHashService.swift` — calcularHash, crearRegistroAlta, crearRegistroAnulacion, verificarCadena
- `FacturaEditView.swift` — esEditable, bloqueo post-emisión
- `FacturasListView.swift` — emitirFactura, anularFactura, crearRectificativa
