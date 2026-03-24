---
name: swift-build-check
description: Verificar que el proyecto compila después de hacer cambios. Usar después de editar archivos Swift.
disable-model-invocation: true
---

# Build Check

Ejecutar después de hacer cambios en el código:

```bash
cd "/Users/xaron/Desktop/EhFacturas!" && xcodebuild -project FacturaApp.xcodeproj -scheme FacturaApp -destination 'generic/platform=iOS' -quiet build 2>&1 | grep -E "error:|warning:" | head -20
```

Si hay errores, arreglarlos antes de continuar.
Si no hay output, el build es exitoso.
