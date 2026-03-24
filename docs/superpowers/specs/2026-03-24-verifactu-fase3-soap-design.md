# VeriFactu Fase 3 — Cliente SOAP + Certificado Digital

## Resumen
Implementar la conexión con la AEAT para envío automático de registros VeriFactu vía SOAP 1.1 con certificado digital X.509, cola de envío offline con reintentos.

## Endpoints oficiales
- **Producción:** https://www1.agenciatributaria.gob.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP
- **Pruebas:** https://prewww1.aeat.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP
- **Protocolo:** SOAP 1.1 (document/literal)
- **Autenticación:** Certificado digital X.509 (client certificate)

## Archivos
| Archivo | Acción |
|---|---|
| VeriFactuSOAPClient.swift | NUEVO — cliente SOAP + cola offline |
| VeriFactuCertificateManager.swift | NUEVO — importar/guardar certificado .p12 |
| Models.swift | Modificar — añadir estadoEnvio a RegistroFacturacion |
| AjustesView.swift | Modificar — sección certificado digital + toggle entorno |
| FacturasListView.swift | Modificar — emitir envía a AEAT automáticamente |
| FacturaEditView.swift | Modificar — mostrar estado envío en sección VeriFactu |
