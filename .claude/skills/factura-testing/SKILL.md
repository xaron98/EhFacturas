---
name: factura-testing
description: Comandos de voz y flujos de prueba para FacturaApp. Usar cuando se necesite verificar que la app funciona correctamente después de cambios.
disable-model-invocation: true
---

# Flujos de prueba — FacturaApp

## Comandos de voz/texto que deben funcionar

### Clientes
- "Añade un cliente Juan García, teléfono 612345678"
- "Nuevo cliente Comunidad de Vecinos Calle Mayor 15, NIF H12345678"
- "Busca al cliente García"
- "¿Cuántos clientes tengo?"

### Artículos
- "Añade bombilla LED E27 a 3 con 50" → 3.50€
- "Nuevo artículo cable 2.5 milímetros a 1,20 euros el metro" → unidad: metro
- "Añade mano de obra a 35 euros la hora" → unidad: hora
- "¿Cuánto cuesta la bombilla LED?"

### Facturas
- "Hazme una factura para Juan García con 5 bombillas LED y 2 horas de mano de obra"
- "Factura para la comunidad de vecinos con 3 horas de revisión eléctrica"
- "La factura de Juan ya está cobrada"
- "¿Cuánto tengo pendiente de cobrar?"

### Flujo VeriFactu completo
1. Crear cliente → "Añade cliente Pedro López"
2. Crear artículos → "Añade interruptor a 5 euros" + "Añade hora de trabajo a 30 euros"
3. Crear factura → "Factura para Pedro con 3 interruptores y 2 horas de trabajo"
4. Verificar tarjeta de factura en chat
5. Tocar tarjeta → abrir editor
6. En editor IA: "cambia los interruptores a 5"
7. Tocar "Emitir" → verificar que se bloquea la edición y se genera hash
8. Intentar editar → debe mostrar "no se puede editar"
9. Tocar "Rectificar" → nueva factura borrador
10. Generar PDF → verificar formato

### Verificaciones de IVA
- Factura con materiales (21%) + servicios (10%) → desglose IVA doble en PDF
- IRPF activado → se resta del total
- Descuento global → se aplica proporcionalmente

### Precios en español
- "3 con 50" → 3.50€
- "1,20 euros" → 1.20€
- "tres euros" → 3.00€
