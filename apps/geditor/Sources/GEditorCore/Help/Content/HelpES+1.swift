import Foundation

/// Contenido de ayuda en español — parte 1: primeros pasos y edición.
///
/// **Los `id` de tema NUNCA se traducen.** Son a lo que apunta `.seeAlso`, lo que abre el menú y lo
/// que permite a la ventana de ayuda cambiar de idioma **sin devolver al lector al índice**. Cambiar
/// un id rompe todos los enlaces, en todos los libros a la vez.
///
/// Los títulos de menú en `commands:` siguen en vietnamita: deben coincidir palabra por palabra con
/// las etiquetas reales del menú, que `HelpCoverage` comprueba por esa misma cadena.
enum HelpES {}

extension HelpES {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Primeros pasos",
        summary: "Qué hace GEditor y dónde invertir sus primeros cinco minutos.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Qué es GEditor",
        summary: "Un editor de texto y datos a escala de gigabytes para macOS que habla vietnamita.",
        keywords: ["introducción", "bienvenida", "resumen", "acerca de"],
        blocks: [
            .paragraph("""
                GEditor abre un **archivo de 1 GB sin cargar 1 GB en memoria**. Lee mediante una \
                ventana deslizante sobre un archivo mapeado en memoria, así que un registro de 200 \
                millones de líneas o un CSV de un millón de filas se abre en cosa de un segundo y se \
                desplaza con fluidez.
                """),
            .paragraph("""
                Más allá de editar, es un **banco de trabajo para datos**: ver un CSV como tabla, \
                limpiarlo, puntuar su calidad, consultarlo con SQL, buscar anomalías y tendencias, y \
                luego generar un informe. Y lee las codificaciones vietnamitas antiguas que la mayoría \
                de herramientas de hoy ha olvidado.
                """),
            .heading("Seis cosas que conviene probar primero"),
            .table(
                headers: ["Tarea", "Adónde ir"],
                rows: [
                    ["Abrir un archivo grande sin esperar", "Arrástrelo a la ventana — vea «Abrir archivos grandes»"],
                    ["Editar muchos sitios a la vez", "`⌘D` añade la siguiente coincidencia; luego escriba una sola vez"],
                    ["Buscar con una expresión regular", "`⌘F`, active Regex — el motor es PCRE2 con JIT"],
                    ["Ver un CSV como tabla", "`⌥⌘T` — un millón de filas sigue desplazándose con fluidez"],
                    ["Limpiar una tabla de datos desordenada", "`⇧⌘L` banco de limpieza — vista previa antes de aplicar"],
                    ["Abrir un archivo vietnamita que se ve como basura", "Pulse la codificación en la barra de estado"],
                ]
            ),
            .note("""
                ¿Viene de Notepad++? Hay una página que compara ambos mapas de teclas, porque algunas \
                teclas **intercambian su sitio** en macOS en lugar de simplemente cambiar `Ctrl` por \
                `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Sus primeros cinco minutos",
        summary: "Doce atajos cubren la mayor parte del trabajo diario.",
        keywords: ["atajo", "teclas", "inicio", "básicos"],
        blocks: [
            .paragraph("""
                No hace falta aprenderlo todo. Las doce teclas de abajo cubren la mayor parte del \
                trabajo diario; el resto lo consulta cuando lo necesite.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Abrir un archivo"),
                HelpShortcut("⇧⌘O", "Abrir una carpeta entera como espacio de trabajo"),
                HelpShortcut("⌘T", "Nueva pestaña"),
                HelpShortcut("⌘S", "Guardar"),
                HelpShortcut("⌘F", "Buscar"),
                HelpShortcut("⌥⌘F", "Buscar y reemplazar"),
                HelpShortcut("⇧⌘F", "Buscar en una carpeta"),
                HelpShortcut("⌘D", "Añadir la siguiente aparición a la selección"),
                HelpShortcut("⌘L", "Ir a la línea"),
                HelpShortcut("⌘/", "Comentar la línea con la sintaxis del propio lenguaje"),
                HelpShortcut("⌥⌘T", "Alternar entre tabla y texto (archivos CSV)"),
                HelpShortcut("⌘?", "Volver a abrir esta ventana de ayuda"),
            ]),
            .heading("Tres cosas que sorprenden a los recién llegados"),
            .bullets([
                "**Una operación masiva es UN paso de deshacer**, aunque toque un millón de líneas. ¿Ordenó mal? Un `⌘Z` y desaparece.",
                "**La sesión se restaura sola.** Salga y vuelva a abrir: las pestañas vuelven a su sitio, incluso las no guardadas. Nada que pulsar.",
                "**Escribir sin tildes encuentra igualmente palabras acentuadas** en cada campo de búsqueda y filtro — escriba `hue` y obtiene `Huế`, `da nang` y obtiene `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "¿Qué quiere hacer?",
        summary: "Una tabla que va de tareas reales al capítulo que las cubre.",
        keywords: ["índice", "buscar", "cómo hacer"],
        blocks: [
            .paragraph("""
                El índice de la izquierda está ordenado por **función**. Esta tabla lo está por \
                **tarea**, porque ambos órdenes no coinciden.
                """),
            .table(
                headers: ["Necesito…", "Vea"],
                rows: [
                    ["Editar el mismo punto en cientos de líneas", "Cursores múltiples · Selección en bloque"],
                    ["Reformatear en masa con una regex", "Buscar y reemplazar · Expresiones regulares"],
                    ["Repetir una secuencia de acciones", "Macros"],
                    ["Abrir un CSV que me han enviado", "La tabla CSV"],
                    ["Limpiar una tabla desordenada: fechas mezcladas, números como texto", "El flujo de limpieza de datos"],
                    ["Juzgar si una tabla es de fiar", "Puntuación de calidad de datos"],
                    ["Encontrar anomalías, tendencias, grupos", "El flujo de minería de datos"],
                    ["Hacer preguntas en SQL", "Consultar CSV con SQL"],
                    ["Publicar un informe cuyas cifras se actualicen", "Informes `.greport.md`"],
                    ["Dibujar un diagrama dentro de un documento", "Mermaid"],
                    ["Abrir un archivo vietnamita ilegible", "Codificaciones vietnamitas"],
                    ["Automatizar desde el terminal o AppleScript", "Automatización"],
                    ["Colorear un formato inventado por mi empresa", "Lenguajes definidos por el usuario"],
                ]
            ),
            .note("""
                ¿No aparece? El campo de búsqueda de arriba a la izquierda mira dentro del **texto y \
                los ejemplos de código**, así que teclear una clave de configuración como `fail_under` \
                lleva a la página correcta.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Abrir archivos grandes",
        summary: "Por qué 1 GB llega a abrirse, y dónde GEditor se niega a propósito en vez de adivinar.",
        keywords: ["archivo grande", "gigabyte", "registro", "mmap", "lento", "rendimiento"],
        blocks: [
            .paragraph("""
                El archivo se **mapea en memoria** y se lee con una ventana deslizante; la parte que \
                está editando vive en una piece table. En la práctica: el tiempo de apertura apenas \
                depende del tamaño del archivo, y la memoria ocupada tampoco.
                """),
            .heading("Dónde se niega a propósito"),
            .paragraph("""
                Unos pocos cálculos tendrían que leer todo el archivo en una sola cadena — justo lo \
                que esta arquitectura evita. Ahí, GEditor **dice que no lo hará** en lugar de \
                arrastrarse en silencio o adivinar:
                """),
            .table(
                headers: ["Operación", "Tope", "Más allá"],
                rows: [
                    ["Emparejar paréntesis", "1 MB", "Se niega y lo dice — resaltar el par equivocado es peor que ninguno"],
                    ["Columna visual en la barra de estado", "200 KB", "Vuelve a contar bytes y lo marca con `~` para que el significado se vea"],
                    ["Vista previa de Markdown", "4 MB", "Se niega y lo explica"],
                ]
            ),
            .warning("""
                Un número que parece idéntico pero significa otra cosa es la peor clase de error. Por \
                eso una columna más allá del tope se lee `~1234`, no `1234`.
                """),
            .heading("Trucos para archivos de registro"),
            .bullets([
                "`Archivo ▸ Seguir archivo (tail -f)` incorpora lo que se escriba al final. El documento queda **de solo lectura** mientras sigue — escribir mientras entra texto nuevo son dos escritores peleando por un documento, y el perdedor es siempre lo que acaba de teclear.",
                "Las líneas de registro se **colorean por gravedad** y se pueden filtrar por nivel.",
                "El **mapa del documento** (`⌥⌘M`) describe todo el archivo, no solo la parte en pantalla.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "Versión App Store frente a descarga directa",
        summary: "Tres funciones que solo tiene la versión directa, y por qué.",
        keywords: ["app store", "sandbox", "descarga", "cli", "extensión", "diferencia"],
        blocks: [
            .paragraph("""
                GEditor se publica en dos versiones. Vienen del **mismo código fuente** y la aplicación \
                reconoce al arrancar cuál es. La diferencia está en lo que permite el App Sandbox.
                """),
            .table(
                headers: ["Función", "App Store", "Descarga directa"],
                rows: [
                    ["Toda la edición, CSV, limpieza, minería, informes", "Sí", "Sí"],
                    ["La herramienta de línea de órdenes `geditor`", "No", "Sí"],
                    ["Filtrar texto con una orden externa", "No", "Sí"],
                    ["Extensiones nativas (proceso aparte)", "No", "Sí"],
                    ["Autoactualización", "Por el App Store", "Dentro de la aplicación"],
                ]
            ),
            .paragraph("""
                Cada «No» de arriba nace de la misma regla: el sandbox **prohíbe ejecutar código fuera \
                de la aplicación**. Ese es el precio de distribuir por el App Store, no un descuido.
                """),
            .note("""
                En la versión App Store esas órdenes **siguen en el menú** y explican por qué no están \
                disponibles, en vez de desaparecer. Un elemento de menú que falta se convierte en una \
                consulta al soporte; una respuesta en el sitio, no.
                """),
            .heading("Acceso a archivos en la versión App Store"),
            .paragraph("""
                La versión en sandbox solo toca archivos que usted mismo abrió o arrastró. GEditor \
                guarda un **marcador de ámbito de seguridad** por cada pestaña y por la carpeta del \
                espacio de trabajo, de modo que su sesión vuelve a abrirse tras salir sin volver a \
                pedir permiso.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Edición

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Edición",
        summary: "Editar muchos sitios a la vez, trabajar con líneas y las reglas ocultas que conviene conocer primero.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Cursores múltiples",
        summary: "Seleccionar cada sitio que coincide, escribir una vez, cambiarlos todos.",
        keywords: ["multicursor", "cmd+d", "selección múltiple"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Esto sustituye la mayoría de los momentos en que iba a escribir una expresión regular. \
                Seleccione una palabra, pulse `⌘D` unas cuantas veces para recoger las apariciones \
                siguientes y escriba — todos los sitios cambian a la vez.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Añadir la siguiente aparición a la selección"),
                HelpShortcut("⌘ + clic", "Poner otro cursor donde haga clic"),
                HelpShortcut("Esc", "Descartarlos todos, volver a un cursor"),
                HelpShortcut("⌥ + arrastrar", "Selección en bloque (otra forma de obtener muchos cursores)"),
            ]),
            .heading("Reglas que conviene saber"),
            .bullets([
                "Escribir, borrar y pegar en muchos cursores es **un** paso de deshacer, no uno por cursor.",
                "Los cursores sobreviven al movimiento con flechas — todo el grupo se mueve junto.",
                "`⌘D` salta los sitios que ya están en la selección, así que pulsarlo de más nunca apila cursores uno sobre otro.",
            ]),
            .note("""
                `⌘D` sobre una palabra dentro de una cadena larga era lento antes. La detección de \
                límites de palabra ahora lee por lotes — unas **42× más rápido** en una cadena de 1 MB, \
                lo que lo hace usable en archivos de datos, no solo en código fuente.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Selección en bloque de columnas",
        summary: "Seleccionar un rectángulo a lo largo de muchas líneas — con el ratón o desde el teclado.",
        keywords: ["modo columna", "bloque", "alt arrastrar", "rectángulo", "teclado", "flechas"],
        blocks: [
            .paragraph("""
                Mantenga `⌥` y arrastre para seleccionar un **bloque rectangular**. Escribir, borrar y \
                pegar siguen el bloque. Pegar un bloque en un solo cursor conserva su rectángulo.
                """),
            .shortcuts([
                HelpShortcut("⌥ + arrastrar", "Seleccionar un bloque"),
                HelpShortcut("⌥⌘← →", "Ensanchar el bloque una columna a izquierda/derecha"),
                HelpShortcut("⌥⌘↑ ↓", "Extender el bloque una línea arriba/abajo"),
            ]),
            .paragraph("""
                La vía del teclado no es un apaño frente al ratón: seleccionar un bloque de 40 líneas \
                arrastrando obliga a arrastrar a través de un desplazamiento, mientras que `⌥⌘` + \
                flechas mantiene la precisión columna a columna. Pulsar **cualquier otra** tecla (o \
                escribir) termina el bloque que estaba extendiendo.
                """),
            .heading("Aquí las columnas son columnas VISUALES"),
            .paragraph("""
                Un tabulador se expande hasta la siguiente parada según su anchura de tabulación, en \
                vez de contar como una columna. Eso es lo que hace que las líneas sangradas con \
                tabuladores y con espacios **se alineen como se ven en pantalla**.
                """),
            .paragraph("El texto multibyte sigue siendo una columna: `Nguyễn` ocupa seis columnas, no nueve."),
            .table(
                headers: ["Situación", "Qué hace GEditor"],
                rows: [
                    ["La columna destino cae en medio de un tabulador", "Se ajusta al borde más cercano; en empate, a la izquierda"],
                    ["Una línea es más corta que la columna inicial", "Esa línea aporta una selección vacía, y aun así acepta el texto escrito"],
                    ["Pegar un bloque en un solo cursor", "Conserva el rectángulo e inserta en las líneas de abajo"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Editor de columnas",
        summary: "Insertar texto, una serie de números o de fechas en cada línea de un bloque.",
        keywords: ["editor de columnas", "numeración", "secuencia", "serie"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Seleccione un bloque de columnas y abra `Edición ▸ Editor de columnas…` (`⌥⌘C`). El \
                diálogo tiene **vista previa** antes de aplicar nada.
                """),
            .table(
                headers: ["Modo", "Parámetros", "Cuándo"],
                rows: [
                    ["Texto", "Una cadena fija", "Añadir el mismo prefijo/sufijo a cada línea"],
                    ["Serie de números", "Inicio · paso · base 2·8·10·16 · relleno con ceros", "Numerar filas, generar códigos"],
                    ["Serie de fechas", "Primera fecha · paso en días", "Producir una columna de fechas consecutivas"],
                ]
            ),
            .code(language: "text", caption: "Numeración con ceros a la izquierda, inicio 1, paso 1",
                  source: """
                    Antes:            Después (serie de números, 3 dígitos):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Un paso **negativo** es válido — contar hacia atrás funciona.",
                "Insertar en 5.000 líneas sigue siendo **un** paso de deshacer.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Operaciones con líneas",
        summary: "Ordenar, quitar duplicados, mover, unir, dividir, duplicar, borrar.",
        keywords: ["ordenar", "duplicar", "unir", "dividir", "mover línea"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Con una selección, la orden actúa sobre la selección; sin ella, actúa sobre el \
                **documento entero**. Cada orden de aquí es un solo paso de deshacer.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Duplicar la línea"),
                HelpShortcut("⌘K", "Borrar la línea"),
                HelpShortcut("⌥↑ / ⌥↓", "Mover la línea arriba / abajo"),
            ]),
            .heading("Tres clases de orden, y cuál elegir"),
            .table(
                headers: ["Clase", "`file2` frente a `file10`", "Para"],
                rows: [
                    ["A→Z / Z→A", "`file10` va antes que `file2`", "Listas simples de palabras"],
                    ["Natural", "`file2` va antes que `file10`", "Nombres de archivo, identificadores, versiones"],
                ]
            ),
            .paragraph("""
                El orden **natural** lee las series de dígitos como números. Es casi siempre lo que \
                quiere cuando la lista está numerada.
                """),
            .heading("Quitar duplicados"),
            .bullets([
                "**Documento entero** — descarta toda línea que ya apareció antes y conserva la primera.",
                "**Solo adyacentes** — funde las líneas vecinas idénticas, como `uniq` de Unix.",
            ]),
            .heading("Unir y dividir"),
            .bullets([
                "**Unir líneas** funde las líneas seleccionadas en una.",
                "**Dividir por longitud** corta las líneas largas a un número dado de caracteres.",
                "**Dividir por carácter** corta en cada aparición de un carácter que escriba — por ejemplo, para partir una fila CSV en sus celdas.",
            ]),
            .note("""
                Duplicar la **última línea** de un archivo añade el salto de línea que falta; borrar \
                hasta el final del documento se traga también el salto de la línea anterior. Ambas \
                cosas difieren de la implementación ingenua y existen para que el archivo no acabe con \
                una línea en blanco de más — ni sin la que hacía falta.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Espacios y sangría",
        summary: "Limpiar espacios sueltos, convertir tabulador ↔ espacio, y un ajuste que conviene pensar.",
        keywords: ["espacios", "tabulador", "sangría", "líneas en blanco"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Orden", "Qué hace"],
                rows: [
                    ["Quitar líneas en blanco", "Descarta toda línea sin nada"],
                    ["Compactar líneas en blanco seguidas", "Varias líneas en blanco seguidas quedan en una"],
                    ["Recortar espacios al final de línea", "Quita espacios y tabuladores sueltos al final de cada línea"],
                    ["Tabulador → Espacio", "Convierte tabuladores en espacios con la anchura actual"],
                    ["Espacio → Tabulador", "El sentido contrario"],
                ]
            ),
            .heading("Sangría por lenguaje"),
            .paragraph("""
                Pulse `Tab: 4` en la barra de estado. La parte superior del menú lo cambia para **toda \
                la aplicación**; la inferior — `Solo para Go`, `Solo para Python`… — se aplica solo al \
                lenguaje del archivo abierto y recuerda si usar tabuladores o espacios.
                """),
            .paragraph("""
                La gente no elige la sangría por gusto, sino por **convención de la comunidad**: Go usa \
                tabuladores (`gofmt` manda sobre todo lo demás), Python cuatro espacios según PEP 8, \
                JavaScript y YAML normalmente dos. Un solo número para todos los lenguajes hace que \
                cada archivo que toque gane líneas que nunca editó.
                """),
            .code(language: "json", caption: "settings.json",
                  source: """
                    "languageIndent": {
                      "go":         { "width": 4, "usesTabs": true },
                      "python":     { "width": 4, "usesTabs": false },
                      "javascript": { "width": 2, "usesTabs": false }
                    }
                    """),
            .note("""
                Declararlo en `settings.json` también vale — la clave es el código del lenguaje (`go`, \
                `python`, `javascript`…). Los lenguajes ausentes usan el `tabWidth` común.
                """),
            .heading("Por qué «recortar al guardar» viene DESACTIVADO"),
            .paragraph("""
                El interruptor `Archivo ▸ Recortar espacios finales al guardar` edita **líneas que \
                nunca tocó**. Activado por omisión, una corrección de una palabra en el repositorio de \
                otra persona se convierte en un diff de mil líneas, y el revisor no encuentra el cambio \
                de verdad.
                """),
            .paragraph("""
                Cuando está activo, el recorte es un **paso de deshacer aparte** situado antes de la \
                escritura — un deshacer devuelve el documento a como estaba sin perder lo que acaba de \
                guardar.
                """),
            .heading("Sangría automática"),
            .bullets([
                "Una línea nueva hereda la sangría de la anterior, más un nivel tras un símbolo de apertura — `{` en lenguajes de llaves, `:` en Python y YAML.",
                "La medida es en **columnas visuales**, así que los archivos que mezclan tabuladores y espacios siguen alineados en pantalla.",
                "**No** hay regla de «escribir `}` vuelve a sangrar la línea». Esa regla edita una línea que ya había terminado, y es el comportamiento más criticado de todos los editores que lo tienen.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Mayúsculas y convenciones de nombres",
        summary: "Ocho conversiones, entre ellas camelCase, snake_case y kebab-case.",
        keywords: ["mayúsculas", "minúsculas", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Se aplica a la selección. Todas viven en el menú `Formato`."),
            .table(
                headers: ["Orden", "`tổng doanh thu` pasa a"],
                rows: [
                    ["MAYÚSCULAS", "`TỔNG DOANH THU`"],
                    ["minúsculas", "`tổng doanh thu`"],
                    ["Mayúscula Inicial", "`Tổng Doanh Thu`"],
                    ["Mayúscula de frase", "`Tổng doanh thu`"],
                    ["Invertir mayúsculas", "Voltea cada carácter"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Las tres últimas quitan las tildes vietnamitas, porque producen **identificadores de \
                código** — donde las letras acentuadas no suelen permitirse.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Comentarios y paréntesis",
        summary: "⌘/ usa el marcador propio de cada lenguaje; ⌃⌘B salta al paréntesis pareja.",
        keywords: ["comentario", "paréntesis", "cmd+/", "emparejar"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` elige el marcador de comentario **según el lenguaje del documento**: `#` para \
                Python, `//` para Rust y C, `<!-- -->` para XML y HTML.
                """),
            .heading("Todo el bloque va en un mismo sentido"),
            .paragraph("""
                Si una sola línea del bloque sigue sin comentar, la orden comenta **todo**. Decidir \
                línea a línea convertiría un bloque medio comentado en un tablero de ajedrez. El \
                marcador se inserta en la sangría menos profunda del bloque, así que el bloque conserva \
                su forma.
                """),
            .heading("Saltar al paréntesis pareja"),
            .bullets([
                "`⌃⌘B` salta al paréntesis que hace pareja con el del cursor.",
                "Los paréntesis dentro de **cadenas** o **comentarios** no cuentan — un analizador ligero los distingue.",
                "Pasado **1 MB**, la orden se niega y lo dice en vez de anclarse a medias y adivinar. Resaltar el par equivocado es peor que no resaltar ninguno.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Deshacer y portapapeles",
        summary: "Historial de deshacer ilimitado y un portapapeles con varias ranuras.",
        keywords: ["deshacer", "rehacer", "portapapeles", "pegar", "historial"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Deshacer / Rehacer"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Cortar / Copiar / Pegar"),
                HelpShortcut("⇧⌘V", "Historial del portapapeles"),
            ]),
            .heading("Una operación masiva es UN paso"),
            .paragraph("""
                Ordenar un millón de líneas, reemplazar diez mil coincidencias, insertar en cinco mil \
                líneas con el editor de columnas — cada una de ellas se deshace con **un** `⌘Z`.
                """),
            .paragraph("""
                El historial de deshacer vive en el propio búfer de texto de GEditor y no en el \
                `UndoManager` del sistema, precisamente por eso: `UndoManager` cuenta pulsaciones.
                """),
            .heading("Historial del portapapeles"),
            .paragraph("""
                `⇧⌘V` abre una lista de lo que ha copiado hace poco y pega la entrada que elija. Útil \
                cuando tiene que alternar dos fragmentos en muchos sitios.
                """),
        ]
    )
}
