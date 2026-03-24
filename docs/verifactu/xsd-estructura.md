# VeriFactu XSD — Estructura oficial (V1.0)

## Fuentes
- https://sede.agenciatributaria.gob.es/Sede/iva/sistemas-informaticos-facturacion-verifactu/informacion-tecnica/esquemas.html
- https://www.agenciatributaria.es/AEAT.desarrolladores/Desarrolladores/_menu_/Documentacion/Sistemas_Informaticos_de_Facturacion_y_Sistemas_VERI_FACTU/Esquemas_de_los_servicios_web/Esquemas_de_los_servicios_web.html

## URLs XSD (entorno pruebas)
- SuministroLR.xsd: https://prewww2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tikeV1.0/cont/ws/SuministroLR.xsd
- SuministroInformacion.xsd: https://prewww2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tikeV1.0/cont/ws/SuministroInformacion.xsd
- RespuestaSuministro.xsd: https://prewww2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tikeV1.0/cont/ws/RespuestaSuministro.xsd
- ConsultaLR.xsd: https://prewww2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tikeV1.0/cont/ws/ConsultaLR.xsd
- RespuestaConsultaLR.xsd: https://prewww2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tikeV1.0/cont/ws/RespuestaConsultaLR.xsd
- EventosSIF.xsd: https://prewww2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tikeV1.0/cont/ws/EventosSIF.xsd
- RespuestaValRegistNoVeriFactu.xsd: https://prewww2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tikeV1.0/cont/ws/RespuestaValRegistNoVeriFactu.xsd

## RegistroFacturacionAltaType (28+ campos)
- IDVersion: "1.0"
- IDFactura: { IDEmisorFactura (NIF 9 chars), NumSerieFactura (max 60), FechaExpedicionFactura (dd-MM-yyyy) }
- NombreRazonEmisor (max 120)
- TipoFactura: F1 (completa), F2 (simplificada), F3 (sustitución), R1-R5 (rectificativas)
- TipoRectificativa: S (sustitutiva), I (incremental) — solo si rectificativa
- FacturasRectificadas (max 1000, opcional)
- DescripcionOperacion (max 500)
- Destinatarios (max 1000, opcional)
- Desglose: { DetalleDesglose (max 12) } — cada uno con Impuesto, ClaveRegimen, CalificacionOperacion, TipoImpositivo, BaseImponible, CuotaRepercutida
- CuotaTotal (±12.2 decimales)
- ImporteTotal (±12.2 decimales)
- Encadenamiento: choice { PrimerRegistro="S" | FacturaAnterior { IDEmisor, NumSerie, Fecha, Huella } }
- SistemaInformatico: { NombreRazon, NIF, NombreSistemaInformatico (max 30), IdSistemaInformatico (max 2), Version (max 50), NumeroInstalacion (max 100), TipoUsoPosibleSoloVerifactu, TipoUsoPosibleMultiOT, IndicadorMultiplesOT }
- FechaHoraHusoGenRegistro (dateTime)
- TipoHuella: "01" (SHA-256)
- Huella (max 64 chars — hex SHA-256)
- Signature (ds:Signature XML, opcional)

## RegistroFacturacionAnulacionType
- IDVersion: "1.0"
- IDFactura: { IDEmisorFacturaAnulada, NumSerieFacturaAnulada, FechaExpedicionFacturaAnulada }
- Encadenamiento: igual que alta
- SistemaInformatico: igual que alta
- FechaHoraHusoGenRegistro
- TipoHuella: "01"
- Huella (max 64)

## Tipos de factura (ClaveTipoFacturaType)
- F1: Factura completa (Art. 6, 7.2, 7.3 RD 1619/2012)
- F2: Factura simplificada (Art. 6.1.d RD 1619/2012)
- F3: Factura emitida en sustitución
- R1: Factura rectificativa (Art. 80.1 y 80.2)
- R2: Factura rectificativa (Art. 80.3)
- R3: Factura rectificativa (Art. 80.4)
- R4: Factura rectificativa (resto)
- R5: Factura rectificativa en facturas simplificadas

## Calificación operación
- S1: Sujeta no exenta, sin inversión sujeto pasivo
- S2: Sujeta no exenta, con inversión sujeto pasivo
- N1: No sujeta (Art. 7, 14, otros)
- N2: No sujeta por reglas de localización

## Formato fecha
- Fecha: dd-MM-yyyy (patrón: \d{2}-\d{2}-\d{4})
- Timestamp: dd-MM-yyyy HH:mm:ss

## Contenedor principal (RegFactuSistemaFacturacion)
- Cabecera: { ObligadoEmision (NombreRazon + NIF) }
- RegistroFactura: max 1000 por envío, cada uno contiene RegistroAlta o RegistroAnulacion
