// CloudToolSchemas.swift
// FacturaApp — JSON tool definitions for Claude and OpenAI function calling APIs

import Foundation
import SwiftData

enum CloudToolSchemas {

    enum ToolMode {
        case command
        case edit
    }

    // MARK: - Claude format (Anthropic Messages API)

    static func claudeTools(mode: ToolMode) -> [[String: Any]] {
        switch mode {
        case .command: return commandToolsClaude
        case .edit: return editToolsClaude
        }
    }

    // MARK: - OpenAI format (Chat Completions API)

    static func openAITools(mode: ToolMode) -> [[String: Any]] {
        switch mode {
        case .command: return commandToolsOpenAI
        case .edit: return editToolsOpenAI
        }
    }

    // MARK: - Command Tools — Claude format (10 tools)

    nonisolated(unsafe) private static let commandToolsClaude: [[String: Any]] = [
        [
            "name": "configurar_negocio",
            "description": """
                Configura los datos del negocio del autónomo. Usa esta herramienta cuando el usuario \
                diga su nombre, NIF, dirección, teléfono o email para configurar el negocio. \
                También cuando diga "me llamo...", "mi NIF es...", "mi empresa se llama...".
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "nombre": ["type": "string", "description": "Nombre del negocio o nombre del autónomo"],
                    "nif": ["type": "string", "description": "NIF o CIF. Vacío si no se proporciona."],
                    "direccion": ["type": "string", "description": "Dirección fiscal. Vacía si no se proporciona."],
                    "ciudad": ["type": "string", "description": "Ciudad. Vacía si no se proporciona."],
                    "provincia": ["type": "string", "description": "Provincia. Vacía si no se proporciona."],
                    "codigoPostal": ["type": "string", "description": "Código postal. Vacío si no se proporciona."],
                    "telefono": ["type": "string", "description": "Teléfono. Vacío si no se proporciona."],
                    "email": ["type": "string", "description": "Email. Vacío si no se proporciona."]
                ] as [String: Any],
                "required": ["nombre"]
            ] as [String: Any]
        ],
        [
            "name": "crear_cliente",
            "description": """
                Crea un nuevo cliente en la base de datos. Usa esta herramienta cuando el usuario \
                quiera añadir, crear o dar de alta un cliente nuevo. \
                Ejemplo: "Añade un cliente que se llama Juan García, teléfono 612345678"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "nombre": ["type": "string", "description": "Nombre completo del cliente"],
                    "nif": ["type": "string", "description": "NIF o CIF del cliente. Vacío si no se proporciona."],
                    "telefono": ["type": "string", "description": "Teléfono. Vacío si no se proporciona."],
                    "email": ["type": "string", "description": "Email. Vacío si no se proporciona."],
                    "direccion": ["type": "string", "description": "Dirección completa. Vacía si no se proporciona."],
                    "ciudad": ["type": "string", "description": "Ciudad. Vacía si no se proporciona."]
                ] as [String: Any],
                "required": ["nombre"]
            ] as [String: Any]
        ],
        [
            "name": "buscar_cliente",
            "description": """
                Busca clientes en la base de datos por nombre o teléfono. \
                Usa esta herramienta cuando el usuario pregunte por un cliente, \
                quiera ver sus datos, o necesites encontrar un cliente para una factura.
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "consulta": ["type": "string", "description": "Término de búsqueda: nombre, teléfono o parte del nombre"]
                ] as [String: Any],
                "required": ["consulta"]
            ] as [String: Any]
        ],
        [
            "name": "crear_articulo",
            "description": """
                Crea un nuevo artículo, producto o servicio en el catálogo. \
                Usa esta herramienta cuando el usuario quiera añadir un nuevo producto, \
                material o servicio al catálogo. \
                Ejemplo: "Añade bombilla LED E27 a 3,50 euros"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "nombre": ["type": "string", "description": "Nombre del artículo o servicio"],
                    "precioUnitario": ["type": "number", "description": "Precio de venta sin IVA en euros"],
                    "referencia": ["type": "string", "description": "Referencia o código. Vacío si no se proporciona."],
                    "unidad": ["type": "string", "description": "Unidad de medida: ud, m, m², h, kg, l, rollo, caja, servicio", "enum": ["ud", "m", "m²", "h", "kg", "l", "rollo", "caja", "servicio"]],
                    "proveedor": ["type": "string", "description": "Nombre del proveedor. Vacío si no se proporciona."],
                    "precioCoste": ["type": "number", "description": "Precio de coste en euros. 0 si no se proporciona."],
                    "etiquetas": ["type": "string", "description": "Etiquetas para búsqueda separadas por comas. Ej: led, iluminación, bajo consumo"]
                ] as [String: Any],
                "required": ["nombre", "precioUnitario"]
            ] as [String: Any]
        ],
        [
            "name": "buscar_articulo",
            "description": """
                Busca artículos en el catálogo por nombre, referencia o etiquetas. \
                Usa esta herramienta para encontrar productos cuando el usuario \
                pregunte por precios, stock, o para resolver artículos de una factura.
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "consulta": ["type": "string", "description": "Término de búsqueda: nombre del producto, referencia o descripción"]
                ] as [String: Any],
                "required": ["consulta"]
            ] as [String: Any]
        ],
        [
            "name": "crear_factura",
            "description": """
                Crea una nueva factura borrador o presupuesto con un cliente y artículos. \
                Usa esta herramienta cuando el usuario quiera generar, hacer o crear una factura o presupuesto. \
                Ejemplo: "Hazme una factura para Juan García con 5 bombillas LED y 2 horas de mano de obra". \
                Si el usuario dice "presupuesto para..." usa esPresupuesto=true.
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "nombreCliente": ["type": "string", "description": "Nombre del cliente"],
                    "articulosTexto": ["type": "string", "description": "Artículos con cantidad. Formato: 'cantidad nombre'. Ej: '5 bombillas LED, 2 horas mano de obra'"],
                    "descuento": ["type": "number", "description": "Descuento global en porcentaje. 0 si no hay descuento."],
                    "observaciones": ["type": "string", "description": "Observaciones o notas. Vacío si no hay."],
                    "esPresupuesto": ["type": "boolean", "description": "true si es presupuesto, false si es factura. Default false."]
                ] as [String: Any],
                "required": ["nombreCliente", "articulosTexto"]
            ] as [String: Any]
        ],
        [
            "name": "marcar_pagada",
            "description": """
                Marca una factura como pagada/cobrada. \
                Usa esta herramienta cuando el usuario diga que ha cobrado una factura. \
                Ejemplo: "La factura de Juan García ya está cobrada"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "identificador": ["type": "string", "description": "Número de factura o nombre del cliente para identificar la factura"]
                ] as [String: Any],
                "required": ["identificador"]
            ] as [String: Any]
        ],
        [
            "name": "anular_factura",
            "description": """
                Anula una factura. Usa esta herramienta cuando el usuario quiera anular, cancelar o borrar una factura. \
                Ejemplo: "Anula la factura de Juan" o "Borra la última factura"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "identificador": ["type": "string", "description": "Número de factura o nombre del cliente para identificar la factura"]
                ] as [String: Any],
                "required": ["identificador"]
            ] as [String: Any]
        ],
        [
            "name": "importar_datos",
            "description": """
                Abre el importador de datos CSV/Excel. Usa esta herramienta cuando el usuario \
                quiera importar artículos o clientes desde un archivo, CSV, o desde otro programa \
                como Salfon, Contaplus, Holded, etc. \
                Ejemplo: "Importa artículos de Salfon" o "Carga clientes desde un archivo"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "tipo": ["type": "string", "description": "Tipo de datos a importar", "enum": ["articulos", "clientes"]]
                ] as [String: Any],
                "required": ["tipo"]
            ] as [String: Any]
        ],
        [
            "name": "consultar_resumen",
            "description": """
                Consulta el resumen del estado actual: facturas pendientes, cobradas, vencidas, \
                totales, número de clientes y artículos. \
                Usa esta herramienta cuando el usuario pregunte cómo va el negocio, \
                cuánto tiene pendiente, o pida un resumen.
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "tipo": ["type": "string", "description": "Tipo de resumen", "enum": ["general", "pendientes", "cobradas", "vencidas", "clientes", "articulos"]]
                ] as [String: Any],
                "required": ["tipo"]
            ] as [String: Any]
        ],
        [
            "name": "registrar_gasto",
            "description": """
                Registra un gasto o compra del negocio. Usa esta herramienta cuando el usuario diga que ha \
                comprado algo, ha tenido un gasto, o quiera registrar una compra. \
                Ejemplo: "He comprado material por 50 euros" o "Gasto de gasolina 30 euros"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "concepto": ["type": "string", "description": "Concepto del gasto"],
                    "importe": ["type": "number", "description": "Importe en euros"],
                    "categoria": ["type": "string", "description": "Categoria: material, herramientas, vehiculo, oficina, formacion, seguros, otros", "enum": ["material", "herramientas", "vehiculo", "oficina", "formacion", "seguros", "otros"]],
                    "proveedor": ["type": "string", "description": "Proveedor. Vacio si no se da."]
                ] as [String: Any],
                "required": ["concepto", "importe"]
            ] as [String: Any]
        ],
        [
            "name": "deshacer",
            "description": """
                Deshace la última acción (crear cliente, artículo o factura). \
                Usa cuando el usuario diga 'deshaz', 'deshacer', 'anula lo último' o 'no quería eso'.
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "motivo": ["type": "string", "description": "Motivo del deshacer. Vacío si no se da."]
                ] as [String: Any],
                "required": [] as [String]
            ] as [String: Any]
        ]
    ]

    // MARK: - Edit Tools — Claude format (4 tools)

    nonisolated(unsafe) private static let editToolsClaude: [[String: Any]] = [
        [
            "name": "modificar_linea",
            "description": """
                Modifica una línea existente de la factura. Busca la línea por concepto (nombre del artículo/servicio). \
                Puedes cambiar la cantidad, el precio unitario o el concepto. \
                Ejemplo: "Cambia las bombillas a 10 unidades" o "Pon el precio de la mano de obra a 35 euros"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "concepto": ["type": "string", "description": "Texto del concepto para encontrar la línea (búsqueda parcial, no sensible a mayúsculas)"],
                    "cantidad": ["type": "number", "description": "Nueva cantidad. Usa 0 para no cambiar la cantidad."],
                    "precioUnitario": ["type": "number", "description": "Nuevo precio unitario sin IVA. Usa -1 para no cambiar el precio."],
                    "nuevoConcepto": ["type": "string", "description": "Nuevo texto de concepto. Vacío para no cambiar el concepto."]
                ] as [String: Any],
                "required": ["concepto"]
            ] as [String: Any]
        ],
        [
            "name": "anadir_linea",
            "description": """
                Añade una nueva línea (artículo o servicio) a la factura. \
                Ejemplo: "Añade 3 metros de cable eléctrico a 2,50 euros" o "Añade una hora de mano de obra a 30 euros"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "concepto": ["type": "string", "description": "Nombre o descripción del artículo/servicio"],
                    "cantidad": ["type": "number", "description": "Cantidad"],
                    "precioUnitario": ["type": "number", "description": "Precio unitario sin IVA en euros"],
                    "unidad": ["type": "string", "description": "Unidad de medida", "enum": ["ud", "m", "m²", "h", "kg", "l", "rollo", "caja", "servicio"]]
                ] as [String: Any],
                "required": ["concepto", "cantidad", "precioUnitario"]
            ] as [String: Any]
        ],
        [
            "name": "eliminar_linea",
            "description": """
                Elimina una línea de la factura buscándola por concepto. \
                Ejemplo: "Quita las bombillas" o "Elimina la mano de obra"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "concepto": ["type": "string", "description": "Texto del concepto para encontrar la línea a eliminar (búsqueda parcial, no sensible a mayúsculas)"]
                ] as [String: Any],
                "required": ["concepto"]
            ] as [String: Any]
        ],
        [
            "name": "cambiar_descuento",
            "description": """
                Cambia el porcentaje de descuento global de la factura. \
                Ejemplo: "Aplica un 10% de descuento" o "Quita el descuento"
                """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "porcentaje": ["type": "number", "description": "Porcentaje de descuento global (0-100). Usa 0 para quitar el descuento."]
                ] as [String: Any],
                "required": ["porcentaje"]
            ] as [String: Any]
        ]
    ]

    // MARK: - Command Tools — OpenAI format (10 tools)

    nonisolated(unsafe) private static let commandToolsOpenAI: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "configurar_negocio",
                "description": """
                    Configura los datos del negocio del autónomo. Usa esta herramienta cuando el usuario \
                    diga su nombre, NIF, dirección, teléfono o email para configurar el negocio. \
                    También cuando diga "me llamo...", "mi NIF es...", "mi empresa se llama...".
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "nombre": ["type": "string", "description": "Nombre del negocio o nombre del autónomo"],
                        "nif": ["type": "string", "description": "NIF o CIF. Vacío si no se proporciona."],
                        "direccion": ["type": "string", "description": "Dirección fiscal. Vacía si no se proporciona."],
                        "ciudad": ["type": "string", "description": "Ciudad. Vacía si no se proporciona."],
                        "provincia": ["type": "string", "description": "Provincia. Vacía si no se proporciona."],
                        "codigoPostal": ["type": "string", "description": "Código postal. Vacío si no se proporciona."],
                        "telefono": ["type": "string", "description": "Teléfono. Vacío si no se proporciona."],
                        "email": ["type": "string", "description": "Email. Vacío si no se proporciona."]
                    ] as [String: Any],
                    "required": ["nombre"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "crear_cliente",
                "description": """
                    Crea un nuevo cliente en la base de datos. Usa esta herramienta cuando el usuario \
                    quiera añadir, crear o dar de alta un cliente nuevo. \
                    Ejemplo: "Añade un cliente que se llama Juan García, teléfono 612345678"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "nombre": ["type": "string", "description": "Nombre completo del cliente"],
                        "nif": ["type": "string", "description": "NIF o CIF del cliente. Vacío si no se proporciona."],
                        "telefono": ["type": "string", "description": "Teléfono. Vacío si no se proporciona."],
                        "email": ["type": "string", "description": "Email. Vacío si no se proporciona."],
                        "direccion": ["type": "string", "description": "Dirección completa. Vacía si no se proporciona."],
                        "ciudad": ["type": "string", "description": "Ciudad. Vacía si no se proporciona."]
                    ] as [String: Any],
                    "required": ["nombre"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "buscar_cliente",
                "description": """
                    Busca clientes en la base de datos por nombre o teléfono. \
                    Usa esta herramienta cuando el usuario pregunte por un cliente, \
                    quiera ver sus datos, o necesites encontrar un cliente para una factura.
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "consulta": ["type": "string", "description": "Término de búsqueda: nombre, teléfono o parte del nombre"]
                    ] as [String: Any],
                    "required": ["consulta"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "crear_articulo",
                "description": """
                    Crea un nuevo artículo, producto o servicio en el catálogo. \
                    Usa esta herramienta cuando el usuario quiera añadir un nuevo producto, \
                    material o servicio al catálogo. \
                    Ejemplo: "Añade bombilla LED E27 a 3,50 euros"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "nombre": ["type": "string", "description": "Nombre del artículo o servicio"],
                        "precioUnitario": ["type": "number", "description": "Precio de venta sin IVA en euros"],
                        "referencia": ["type": "string", "description": "Referencia o código. Vacío si no se proporciona."],
                        "unidad": ["type": "string", "description": "Unidad de medida: ud, m, m², h, kg, l, rollo, caja, servicio", "enum": ["ud", "m", "m²", "h", "kg", "l", "rollo", "caja", "servicio"]],
                        "proveedor": ["type": "string", "description": "Nombre del proveedor. Vacío si no se proporciona."],
                        "precioCoste": ["type": "number", "description": "Precio de coste en euros. 0 si no se proporciona."],
                        "etiquetas": ["type": "string", "description": "Etiquetas para búsqueda separadas por comas. Ej: led, iluminación, bajo consumo"]
                    ] as [String: Any],
                    "required": ["nombre", "precioUnitario"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "buscar_articulo",
                "description": """
                    Busca artículos en el catálogo por nombre, referencia o etiquetas. \
                    Usa esta herramienta para encontrar productos cuando el usuario \
                    pregunte por precios, stock, o para resolver artículos de una factura.
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "consulta": ["type": "string", "description": "Término de búsqueda: nombre del producto, referencia o descripción"]
                    ] as [String: Any],
                    "required": ["consulta"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "crear_factura",
                "description": """
                    Crea una nueva factura borrador o presupuesto con un cliente y artículos. \
                    Usa esta herramienta cuando el usuario quiera generar, hacer o crear una factura o presupuesto. \
                    Ejemplo: "Hazme una factura para Juan García con 5 bombillas LED y 2 horas de mano de obra". \
                    Si el usuario dice "presupuesto para..." usa esPresupuesto=true.
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "nombreCliente": ["type": "string", "description": "Nombre del cliente"],
                        "articulosTexto": ["type": "string", "description": "Artículos con cantidad. Formato: 'cantidad nombre'. Ej: '5 bombillas LED, 2 horas mano de obra'"],
                        "descuento": ["type": "number", "description": "Descuento global en porcentaje. 0 si no hay descuento."],
                        "observaciones": ["type": "string", "description": "Observaciones o notas. Vacío si no hay."],
                        "esPresupuesto": ["type": "boolean", "description": "true si es presupuesto, false si es factura. Default false."]
                    ] as [String: Any],
                    "required": ["nombreCliente", "articulosTexto"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "marcar_pagada",
                "description": """
                    Marca una factura como pagada/cobrada. \
                    Usa esta herramienta cuando el usuario diga que ha cobrado una factura. \
                    Ejemplo: "La factura de Juan García ya está cobrada"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "identificador": ["type": "string", "description": "Número de factura o nombre del cliente para identificar la factura"]
                    ] as [String: Any],
                    "required": ["identificador"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "anular_factura",
                "description": """
                    Anula una factura. Usa esta herramienta cuando el usuario quiera anular, cancelar o borrar una factura. \
                    Ejemplo: "Anula la factura de Juan" o "Borra la última factura"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "identificador": ["type": "string", "description": "Número de factura o nombre del cliente para identificar la factura"]
                    ] as [String: Any],
                    "required": ["identificador"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "importar_datos",
                "description": """
                    Abre el importador de datos CSV/Excel. Usa esta herramienta cuando el usuario \
                    quiera importar artículos o clientes desde un archivo, CSV, o desde otro programa \
                    como Salfon, Contaplus, Holded, etc. \
                    Ejemplo: "Importa artículos de Salfon" o "Carga clientes desde un archivo"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "tipo": ["type": "string", "description": "Tipo de datos a importar", "enum": ["articulos", "clientes"]]
                    ] as [String: Any],
                    "required": ["tipo"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "consultar_resumen",
                "description": """
                    Consulta el resumen del estado actual: facturas pendientes, cobradas, vencidas, \
                    totales, número de clientes y artículos. \
                    Usa esta herramienta cuando el usuario pregunte cómo va el negocio, \
                    cuánto tiene pendiente, o pida un resumen.
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "tipo": ["type": "string", "description": "Tipo de resumen", "enum": ["general", "pendientes", "cobradas", "vencidas", "clientes", "articulos"]]
                    ] as [String: Any],
                    "required": ["tipo"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "registrar_gasto",
                "description": """
                    Registra un gasto o compra del negocio. Usa esta herramienta cuando el usuario diga que ha \
                    comprado algo, ha tenido un gasto, o quiera registrar una compra. \
                    Ejemplo: "He comprado material por 50 euros" o "Gasto de gasolina 30 euros"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "concepto": ["type": "string", "description": "Concepto del gasto"],
                        "importe": ["type": "number", "description": "Importe en euros"],
                        "categoria": ["type": "string", "description": "Categoria: material, herramientas, vehiculo, oficina, formacion, seguros, otros", "enum": ["material", "herramientas", "vehiculo", "oficina", "formacion", "seguros", "otros"]],
                        "proveedor": ["type": "string", "description": "Proveedor. Vacio si no se da."]
                    ] as [String: Any],
                    "required": ["concepto", "importe"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "deshacer",
                "description": """
                    Deshace la última acción (crear cliente, artículo o factura). \
                    Usa cuando el usuario diga 'deshaz', 'deshacer', 'anula lo último' o 'no quería eso'.
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "motivo": ["type": "string", "description": "Motivo del deshacer. Vacío si no se da."]
                    ] as [String: Any],
                    "required": [] as [String]
                ] as [String: Any]
            ] as [String: Any]
        ]
    ]

    // MARK: - Edit Tools — OpenAI format (4 tools)

    nonisolated(unsafe) private static let editToolsOpenAI: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "modificar_linea",
                "description": """
                    Modifica una línea existente de la factura. Busca la línea por concepto (nombre del artículo/servicio). \
                    Puedes cambiar la cantidad, el precio unitario o el concepto. \
                    Ejemplo: "Cambia las bombillas a 10 unidades" o "Pon el precio de la mano de obra a 35 euros"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "concepto": ["type": "string", "description": "Texto del concepto para encontrar la línea (búsqueda parcial, no sensible a mayúsculas)"],
                        "cantidad": ["type": "number", "description": "Nueva cantidad. Usa 0 para no cambiar la cantidad."],
                        "precioUnitario": ["type": "number", "description": "Nuevo precio unitario sin IVA. Usa -1 para no cambiar el precio."],
                        "nuevoConcepto": ["type": "string", "description": "Nuevo texto de concepto. Vacío para no cambiar el concepto."]
                    ] as [String: Any],
                    "required": ["concepto"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "anadir_linea",
                "description": """
                    Añade una nueva línea (artículo o servicio) a la factura. \
                    Ejemplo: "Añade 3 metros de cable eléctrico a 2,50 euros" o "Añade una hora de mano de obra a 30 euros"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "concepto": ["type": "string", "description": "Nombre o descripción del artículo/servicio"],
                        "cantidad": ["type": "number", "description": "Cantidad"],
                        "precioUnitario": ["type": "number", "description": "Precio unitario sin IVA en euros"],
                        "unidad": ["type": "string", "description": "Unidad de medida", "enum": ["ud", "m", "m²", "h", "kg", "l", "rollo", "caja", "servicio"]]
                    ] as [String: Any],
                    "required": ["concepto", "cantidad", "precioUnitario"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "eliminar_linea",
                "description": """
                    Elimina una línea de la factura buscándola por concepto. \
                    Ejemplo: "Quita las bombillas" o "Elimina la mano de obra"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "concepto": ["type": "string", "description": "Texto del concepto para encontrar la línea a eliminar (búsqueda parcial, no sensible a mayúsculas)"]
                    ] as [String: Any],
                    "required": ["concepto"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "cambiar_descuento",
                "description": """
                    Cambia el porcentaje de descuento global de la factura. \
                    Ejemplo: "Aplica un 10% de descuento" o "Quita el descuento"
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "porcentaje": ["type": "number", "description": "Porcentaje de descuento global (0-100). Usa 0 para quitar el descuento."]
                    ] as [String: Any],
                    "required": ["porcentaje"]
                ] as [String: Any]
            ] as [String: Any]
        ]
    ]
}

// MARK: - Tool execution router

extension CloudToolSchemas {

    @MainActor
    static func executeTool(
        name: String,
        arguments: [String: Any],
        modelContext: ModelContext,
        factura: Factura? = nil,
        onUpdate: (@Sendable () -> Void)? = nil
    ) async -> String {
        switch name {

        // MARK: Command tools (routed through FacturacionStore actor)

        case "configurar_negocio":
            return await FacturacionStore.shared.configurarNegocio(
                ConfigurarNegocioParams(
                    nombre: arguments["nombre"] as? String ?? "",
                    nif: arguments["nif"] as? String ?? "",
                    direccion: arguments["direccion"] as? String ?? "",
                    ciudad: arguments["ciudad"] as? String ?? "",
                    provincia: arguments["provincia"] as? String ?? "",
                    codigoPostal: arguments["codigoPostal"] as? String ?? "",
                    telefono: arguments["telefono"] as? String ?? "",
                    email: arguments["email"] as? String ?? ""
                )
            )

        case "crear_cliente":
            return await FacturacionStore.shared.crearCliente(
                CrearClienteParams(
                    nombre: arguments["nombre"] as? String ?? "",
                    nif: arguments["nif"] as? String ?? "",
                    telefono: arguments["telefono"] as? String ?? "",
                    email: arguments["email"] as? String ?? "",
                    direccion: arguments["direccion"] as? String ?? "",
                    ciudad: arguments["ciudad"] as? String ?? ""
                )
            )

        case "buscar_cliente":
            return await FacturacionStore.shared.buscarCliente(
                BuscarClienteParams(
                    consulta: arguments["consulta"] as? String ?? ""
                )
            )

        case "crear_articulo":
            return await FacturacionStore.shared.crearArticulo(
                CrearArticuloParams(
                    nombre: arguments["nombre"] as? String ?? "",
                    precioUnitario: arguments["precioUnitario"] as? Double ?? 0,
                    referencia: arguments["referencia"] as? String ?? "",
                    unidad: arguments["unidad"] as? String ?? "ud",
                    proveedor: arguments["proveedor"] as? String ?? "",
                    precioCoste: arguments["precioCoste"] as? Double ?? 0,
                    etiquetas: arguments["etiquetas"] as? String ?? ""
                )
            )

        case "buscar_articulo":
            return await FacturacionStore.shared.buscarArticulo(
                BuscarArticuloParams(
                    consulta: arguments["consulta"] as? String ?? ""
                )
            )

        case "crear_factura":
            return await FacturacionStore.shared.crearFactura(
                CrearFacturaParams(
                    nombreCliente: arguments["nombreCliente"] as? String ?? "",
                    articulosTexto: arguments["articulosTexto"] as? String ?? "",
                    descuento: arguments["descuento"] as? Double ?? 0,
                    observaciones: arguments["observaciones"] as? String ?? "",
                    esPresupuesto: arguments["esPresupuesto"] as? Bool ?? false
                )
            )

        case "marcar_pagada":
            return await FacturacionStore.shared.marcarPagada(
                MarcarPagadaParams(
                    identificador: arguments["identificador"] as? String ?? ""
                )
            )

        case "anular_factura":
            return await FacturacionStore.shared.anularFactura(
                AnularFacturaParams(
                    identificador: arguments["identificador"] as? String ?? ""
                )
            )

        case "importar_datos":
            return await FacturacionStore.shared.importarDatos(
                ImportarDatosParams(
                    tipo: arguments["tipo"] as? String ?? "articulos"
                )
            )

        case "consultar_resumen":
            return await FacturacionStore.shared.consultarResumen(
                ConsultarResumenParams(
                    tipo: arguments["tipo"] as? String ?? "general"
                )
            )

        case "registrar_gasto":
            return await FacturacionStore.shared.registrarGasto(
                RegistrarGastoParams(
                    concepto: arguments["concepto"] as? String ?? "",
                    importe: arguments["importe"] as? Double ?? 0,
                    categoria: arguments["categoria"] as? String ?? "otros",
                    proveedor: arguments["proveedor"] as? String ?? ""
                )
            )

        case "deshacer":
            return await FacturacionStore.shared.deshacerUltimaAccion()

        // MARK: Edit tools (4) — stay on MainActor via FacturaActions

        case "modificar_linea":
            guard let factura, let onUpdate else {
                return "Error: No hay factura activa para editar."
            }
            return FacturaActions.modificarLinea(
                ModificarLineaParams(
                    concepto: arguments["concepto"] as? String ?? "",
                    cantidad: arguments["cantidad"] as? Double ?? 0,
                    precioUnitario: arguments["precioUnitario"] as? Double ?? -1,
                    nuevoConcepto: arguments["nuevoConcepto"] as? String ?? ""
                ),
                factura: factura,
                modelContext: modelContext,
                onUpdate: onUpdate
            )

        case "anadir_linea":
            guard let factura, let onUpdate else {
                return "Error: No hay factura activa para editar."
            }
            return FacturaActions.anadirLinea(
                AnadirLineaParams(
                    concepto: arguments["concepto"] as? String ?? "",
                    cantidad: arguments["cantidad"] as? Double ?? 1,
                    precioUnitario: arguments["precioUnitario"] as? Double ?? 0,
                    unidad: arguments["unidad"] as? String ?? "ud"
                ),
                factura: factura,
                modelContext: modelContext,
                onUpdate: onUpdate
            )

        case "eliminar_linea":
            guard let factura, let onUpdate else {
                return "Error: No hay factura activa para editar."
            }
            return FacturaActions.eliminarLinea(
                EliminarLineaParams(
                    concepto: arguments["concepto"] as? String ?? ""
                ),
                factura: factura,
                modelContext: modelContext,
                onUpdate: onUpdate
            )

        case "cambiar_descuento":
            guard let factura, let onUpdate else {
                return "Error: No hay factura activa para editar."
            }
            return FacturaActions.cambiarDescuento(
                CambiarDescuentoParams(
                    porcentaje: arguments["porcentaje"] as? Double ?? 0
                ),
                factura: factura,
                modelContext: modelContext,
                onUpdate: onUpdate
            )

        default:
            return "Herramienta no reconocida: \(name)"
        }
    }
}
