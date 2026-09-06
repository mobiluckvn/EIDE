import Foundation

/// Contenido de ayuda en español — parte 2: búsqueda, archivos y sesiones.
extension HelpES {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Búsqueda",
        summary: "Buscar, reemplazar, expresiones regulares, búsqueda en carpetas y marcas de línea.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Buscar y reemplazar",
        summary: "Tres modos de búsqueda, y por qué ^ significa inicio de LÍNEA por omisión.",
        keywords: ["buscar", "reemplazar", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Buscar"),
                HelpShortcut("⌥⌘F", "Buscar y reemplazar"),
                HelpShortcut("⌘G / ⇧⌘G", "Coincidencia siguiente / anterior"),
            ]),
            .heading("Tres modos"),
            .table(
                headers: ["Modo", "Entiende", "Para"],
                rows: [
                    ["Normal", "Texto llano, ningún carácter especial", "La mayoría de búsquedas"],
                    ["Extendido", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Encontrar saltos de línea, tabuladores, bytes concretos"],
                    ["Regex", "PCRE2 completo", "Buscar por patrón"],
                ]
            ),
            .note("""
                El modo **extendido** no entiende sintaxis de regex. Solo expande unas pocas secuencias \
                de escape — buscar `a.b` allí encuentra exactamente esos tres caracteres; el punto no \
                es un comodín.
                """),
            .heading("Dos interruptores"),
            .bullets([
                "**Distinguir mayúsculas** — desactivado por omisión.",
                "**Palabra completa** — solo coincide cuando ambos extremos son límites de palabra.",
            ]),
            .heading("`^` y `$` coinciden en los bordes de cada LÍNEA"),
            .paragraph("""
                Activado por omisión. Quien viene de Notepad++ espera que `^` signifique «inicio de \
                línea»; sin ello, `^abc` solo coincidiría si todo el documento empezara por `abc` — \
                casi nadie quiere eso en un editor de texto.
                """),
            .heading("Una expresión mala no bloqueará la aplicación"),
            .paragraph("""
                El motor es **PCRE2 con compilación JIT** y tiene un presupuesto de retroceso. Un \
                patrón que explota combinatoriamente se detiene y se informa, en vez de congelar la \
                ventana.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Expresiones regulares",
        summary: "La sintaxis PCRE2 que de verdad se usa, con ejemplos que corren sobre datos vietnamitas.",
        keywords: ["regex", "pcre", "patrón"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor usa **PCRE2**, el mismo motor que PHP y muchas herramientas de línea de \
                órdenes. Abra `Buscar ▸ Probar expresión regular…` para probar un patrón contra un \
                texto de ejemplo y ver qué captura cada grupo **antes** de aplicarlo a un documento \
                real.
                """),
            .heading("Clases de caracteres"),
            .table(
                headers: ["Escriba", "Coincide con"],
                rows: [
                    ["`.`", "Cualquier carácter salvo un salto de línea"],
                    ["`\\d` · `\\D`", "Un dígito · no un dígito"],
                    ["`\\w` · `\\W`", "Un carácter de palabra (letra, dígito, `_`) · lo contrario"],
                    ["`\\s` · `\\S`", "Espacio en blanco · no espacio"],
                    ["`[abc]`", "Uno de los caracteres entre corchetes"],
                    ["`[^abc]`", "Un carácter que NO esté entre corchetes"],
                    ["`[a-z]`", "Un carácter del rango"],
                ]
            ),
            .heading("Repetición"),
            .table(
                headers: ["Escriba", "Significado"],
                rows: [
                    ["`*`", "Cero o más"],
                    ["`+`", "Uno o más"],
                    ["`?`", "Cero o uno"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Exactamente 3 · entre 2 y 5 · 2 o más"],
                    ["`*?` `+?` `??`", "Las formas **perezosas** — tomar lo menos posible"],
                ]
            ),
            .warning("""
                `.*` es **codicioso**: come hasta el final de la línea y luego retrocede. Al separar \
                campos dentro de una línea casi siempre necesita `.*?` o una clase estrecha como \
                `[^,]*`.
                """),
            .heading("Anclas y grupos"),
            .table(
                headers: ["Escriba", "Significado"],
                rows: [
                    ["`^` · `$`", "Inicio de línea · fin de línea"],
                    ["`\\b`", "Límite de palabra"],
                    ["`(…)`", "Un grupo **de captura** — reutilizable en el reemplazo"],
                    ["`(?:…)`", "Grupo sin captura"],
                    ["`(?<name>…)`", "Grupo con nombre"],
                    ["`a|b`", "a o b"],
                    ["`(?=…)` · `(?!…)`", "Anticipación: debe seguir · no debe seguir"],
                    ["`(?<=…)` · `(?<!…)`", "Retrospección: debe preceder · no debe preceder"],
                ]
            ),
            .heading("Ejemplos que funcionan"),
            .code(language: "regex", caption: "Todo número de teléfono vietnamita de 10 dígitos",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Partir una fecha 31/12/2026 en tres grupos",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "La tercera celda de una fila CSV simple (sin comillas)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Líneas de registro en ERROR o FATAL, con su marca de tiempo",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Líneas vacías, o con solo espacios",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Letras vietnamitas acentuadas — use la clase Unicode, no las enumere",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` significa «cualquier letra Unicode», así que también coincide con `ế` y `đ`. \
                Enumerar a mano cada vocal acentuada es el modo seguro de dejarse alguna.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Cadenas de reemplazo",
        summary: "Reutilizar grupos capturados y cambiar mayúsculas al reemplazar.",
        keywords: ["reemplazar", "retrorreferencia", "grupo", "$1", "\\U"],
        blocks: [
            .heading("Llamar a un grupo capturado"),
            .table(
                headers: ["Escriba", "Significado"],
                rows: [
                    ["`$1` … `$9`", "El contenido del grupo n"],
                    ["`${1}`", "Lo mismo con límites explícitos — úselo cuando sigue un dígito"],
                    ["`\\1`", "También se acepta; GEditor lo reescribe como `${1}`"],
                    ["`$0`", "La coincidencia entera"],
                ]
            ),
            .note("""
                Escriba `${1}` en vez de `$1` cuando el siguiente carácter sea un dígito. `$123` se lee \
                como el grupo 123; `${1}23` es el grupo 1 seguido de dos dígitos.
                """),
            .heading("Cambiar mayúsculas durante un reemplazo"),
            .table(
                headers: ["Escriba", "Significado"],
                rows: [
                    ["`\\U`", "MAYÚSCULAS desde aquí"],
                    ["`\\L`", "minúsculas desde aquí"],
                    ["`\\u`", "Solo el siguiente carácter en mayúscula"],
                    ["`\\l`", "Solo el siguiente carácter en minúscula"],
                    ["`\\E`", "Fin de la región `\\U` o `\\L`"],
                ]
            ),
            .heading("Ejemplos"),
            .code(language: "text", caption: "Convertir 31/12/2026 en 2026-12-31",
                  source: """
                    Buscar:     (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Reemplazar: $3-$2-$1
                    """),
            .code(language: "text", caption: "Poner en mayúsculas el código de provincia al inicio de línea, conservar el resto",
                  source: """
                    Buscar:     ^([a-z]{2,3})(\\s)
                    Reemplazar: \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Envolver cada línea como cadena JSON",
                  source: """
                    Buscar:     ^(.+)$
                    Reemplazar: "$1",
                    """),
            .paragraph("""
                Un grupo que **no participó** en la coincidencia se convierte en cadena vacía, no en \
                error — así un patrón con alternativas como `(a)|(b)` reemplaza limpiamente sin \
                escribirlo dos veces.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Buscar y reemplazar en una carpeta",
        summary: "Recorrer muchos archivos a la vez y ver los resultados antes de escribir nada.",
        keywords: ["buscar en archivos", "grep", "reemplazo masivo", "carpeta"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Buscar en una carpeta")]),
            .paragraph("""
                Elija la carpeta raíz, filtre por patrón de nombre y recorra. Los resultados aparecen \
                agrupados por archivo; pulsar una línea abre ese archivo en esa posición.
                """),
            .bullets([
                "Los mismos tres modos de búsqueda y el mismo motor de regex que el campo de búsqueda del documento.",
                "El reemplazo en carpeta **previsualiza** cuántos archivos y cuántas coincidencias cambiarán antes de escribir.",
                "El recorrido va en paralelo y **se puede cancelar** a mitad.",
            ]),
            .warning("""
                El reemplazo en carpeta escribe directamente en archivos que **no están abiertos**. Esos \
                archivos no están en el historial de deshacer del documento abierto — previsualice \
                primero y tenga una copia de seguridad o un repositorio versionado.
                """),
            .heading("Búsquedas anteriores y exportar resultados"),
            .paragraph("""
                El panel de resultados **conserva las búsquedas de esta sesión**. El menú emergente de \
                arriba las lista con su número de coincidencias — busque `TODO`, lea a medias, busque \
                `FIXME` para comparar y vuelva a la primera lista sin recorrer la carpeta de nuevo.
                """),
            .paragraph("""
                El botón **Exportar** abre la búsqueda actual como pestaña de texto, un resultado por \
                línea como `ruta:línea:columna: texto` — la forma que usa `grep -n` y la que usan los \
                compiladores para los errores. Cada línea se pega tal cual en el campo `Ir a` de este \
                mismo producto, y sus `grep`, `awk` y `sed` la leen sin un analizador propio.
                """),
            .note("""
                El historial vive **en memoria** y nunca se escribe en disco: los resultados de búsqueda \
                llevan el contenido de cada línea coincidente, que es la misma clase de datos que el \
                historial del portapapeles deliberadamente no conserva.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Marcas de línea",
        summary: "Nueve colores de marca y cuatro órdenes que convierten las líneas marcadas en un resultado.",
        keywords: ["marcador", "marca", "f2", "filtrar líneas"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Marcar es la forma de filtrar un documento **sin cambiarlo**. Marque cada línea que \
                coincida con un patrón y luego copie solo esas, o quédese solo con ellas.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Marcar cada línea que coincida con la búsqueda actual"),
                HelpShortcut("⌘F2", "Marcar / desmarcar la línea actual"),
                HelpShortcut("F2 / ⇧F2", "Ir a la marca siguiente / anterior"),
            ]),
            .heading("Un flujo habitual"),
            .steps([
                "`⌘F` con el patrón por el que quiere filtrar, p. ej. `\\bERROR\\b`.",
                "`⌘M` marca cada línea coincidente.",
                "`Buscar ▸ Copiar líneas marcadas` las lleva a una pestaña nueva — o `Conservar solo las líneas marcadas` filtra en el sitio.",
            ]),
            .heading("Nueve colores"),
            .paragraph("""
                Una línea puede llevar **varios colores a la vez**. Use colores distintos para \
                criterios distintos y combínelos: rojo para líneas de error, amarillo para líneas de un \
                mismo número de pedido, y luego busque las líneas que lleven ambos.
                """),
            .bullets([
                "`Invertir marcas` — las líneas marcadas se desmarcan y viceversa.",
                "`Borrar todas las marcas` — quita cada marca sin tocar el contenido.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Ir a la línea",
        summary: "Saltar a una línea, una columna o una posición en bytes.",
        keywords: ["ir a", "número de línea", "cmd+l", "posición", "columna"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Ir a la línea")]),
            .paragraph("""
                El campo entiende **tres notaciones** y las distingue por lo que usted escribe — no hay \
                un selector extra que pulsar.
                """),
            .table(
                headers: ["Escriba", "Va a"],
                rows: [
                    ["`120`", "el inicio de la línea 120"],
                    ["`120,5` o `120:5`", "línea 120, columna 5 — la columna cuenta CARACTERES"],
                    ["`@1024`", "la posición 1024 en bytes del archivo"],
                ]
            ),
            .note("""
                `línea:columna` es exactamente como compiladores y linters imprimen una posición, así \
                que una línea recién copiada de un terminal se pega tal cual.

                La `@` de las posiciones en bytes tiene su razón: ¿`1234` es una línea o un byte? No \
                hay respuesta correcta, y adivinar mal manda el cursor a otro sitio sin señal alguna. \
                Esa cifra en bytes es también la que muestra la barra de estado en el segmento de \
                posición (`@1024`): lo que lee allí puede escribirlo aquí.
                """),
            .bullets([
                "Una columna **más allá de la longitud de la línea** se detiene al final de esa línea; no se derrama en la siguiente.",
                "Una posición en bytes **más allá del archivo** lo lleva al final — ese número suele venir de una ejecución anterior, y el archivo puede haber encogido.",
                "El texto que no puede leer se **informa**, y el cursor no se mueve; no salta al principio del archivo.",
            ]),
            .paragraph("""
                En archivos muy grandes GEditor no lee todo el archivo para llegar — el índice de \
                líneas se construye poco a poco en segundo plano.
                """),
            .note("""
                La herramienta de línea de órdenes también acepta una posición: `geditor \
                informe.csv:120:5` abre el archivo con el cursor en la línea 120, columna 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Archivos y sesiones

    static let files = HelpChapter(
        id: "tep",
        title: "Archivos y sesiones",
        summary: "Abrir, guardar, pestañas, ventanas, espacios de trabajo y cómo vuelve la sesión.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Abrir y guardar",
        summary: "Abrir un archivo de cualquier tamaño y guardarlo con otra codificación o final de línea.",
        keywords: ["abrir", "guardar", "duplicar", "renombrar", "mover"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Documento nuevo"),
                HelpShortcut("⌘O", "Abrir un archivo"),
                HelpShortcut("⌘S", "Guardar"),
                HelpShortcut("⇧⌘S", "Guardar como"),
            ]),
            .paragraph("""
                Arrastrar un archivo a la ventana también lo abre. `Archivo ▸ Abrir reciente` guarda la \
                lista de archivos con los que acaba de trabajar.
                """),
            .heading("Guardar como: tres cosas que puede cambiar"),
            .table(
                headers: ["Cambio", "Significado"],
                rows: [
                    ["Codificación", "Escribir en UTF-8, TCVN3, VNI-Windows… — 36 codificaciones"],
                    ["Finales de línea", "LF (Unix) · CRLF (Windows) · CR (Mac clásico)"],
                    ["Nombre y ubicación", "Como en cualquier diálogo de guardado de macOS"],
                ]
            ),
            .paragraph("""
                La barra de estado siempre muestra la codificación, el estilo de final de línea y el \
                lenguaje detectado. **Pulsar cualquiera de ellos lo cambia al instante**, sin pasar por \
                un diálogo.
                """),
            .heading("Duplicar · renombrar · mover"),
            .paragraph("""
                Estas tres actúan sobre el ARCHIVO y no sobre su contenido — y la pestaña abierta sigue \
                al archivo, así que nunca pierde su sitio.
                """),
            .table(
                headers: ["Orden", "Qué hace"],
                rows: [
                    ["`Duplicar archivo`",
                     "Lo copia como `nombre 2.txt` junto al original y **abre la copia** — porque se duplica para editar la copia"],
                    ["`Renombrar archivo…`", "Renombra en disco; la pestaña sigue el nombre nuevo"],
                    ["`Mover archivo a…`", "Mueve a otra carpeta; la pestaña le sigue"],
                ]
            ),
            .note("""
                Las tres **se niegan si ya existe un archivo con ese nombre** en el destino; nunca \
                sobrescriben. Y las tres necesitan un archivo guardado al menos una vez — un documento \
                que nunca estuvo en disco no tiene nada que duplicar ni mover.
                """),
            .heading("Escritura segura"),
            .bullets([
                "La escritura es **atómica**: un corte de luz a medias nunca deja un archivo truncado.",
                "Si otro programa cambia el archivo mientras lo tiene abierto, GEditor lo nota y pregunta antes de sobrescribir.",
                "Los archivos en iCloud Drive o en un volumen de red pasan por el coordinador de archivos del sistema, para que dos máquinas no se pisen.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Pestañas, ventanas y vista dividida",
        summary: "Muchas pestañas por ventana, muchas ventanas y pestañas que puede arrastrar entre ellas.",
        keywords: ["pestaña", "ventana", "dividir", "panel"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Nueva pestaña"),
                HelpShortcut("⌘W", "Cerrar pestaña"),
                HelpShortcut("⇧⌘T", "Volver a abrir la última pestaña cerrada"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Pestaña siguiente / anterior"),
                HelpShortcut("⌥⌘N", "Ventana nueva"),
                HelpShortcut("⌃⌘N", "Separar la pestaña actual en su propia ventana"),
            ]),
            .paragraph("""
                Puede arrastrar una pestaña a otra ventana, o soltarla en un hueco vacío para crear una \
                ventana. **Una pestaña fijada no viaja** — fijar significa «deja esta aquí».
                """),
            .note("""
                `⇧⌘T` vuelve a abrir la última pestaña cerrada, incluida una **no guardada**: su \
                contenido sigue ahí.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Abrir una carpeta como espacio de trabajo",
        summary: "Un árbol de archivos en la barra lateral, búsqueda en todo el proyecto y apertura con un clic.",
        keywords: ["espacio de trabajo", "carpeta", "proyecto", "barra lateral"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Abrir una carpeta como espacio de trabajo")]),
            .paragraph("""
                El árbol aparece en la barra lateral (`⌘0`). Pulse un archivo para abrirlo, y `⇧⌘F` \
                busca en toda la carpeta.
                """),
            .note("""
                En la versión App Store, el acceso a la carpeta lo sostiene un **marcador de ámbito de \
                seguridad**, así que el siguiente arranque todavía llega a ella sin pedirle que elija la \
                carpeta otra vez.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "La sesión se restaura sola",
        summary: "Salga y vuelva a abrir: cada pestaña regresa, incluidas las no guardadas.",
        keywords: ["sesión", "restaurar", "no guardado", "recuperar"],
        blocks: [
            .paragraph("""
                Nada que activar. Salga de GEditor y ábralo de nuevo: las pestañas, su orden, las \
                posiciones del cursor y del desplazamiento vuelven todas.
                """),
            .heading("Y las pestañas no guardadas"),
            .paragraph("""
                Su contenido se guarda en una instantánea aparte, así que también vuelven. Si la \
                aplicación termina de forma anormal, el siguiente arranque **pregunta** antes de \
                restaurar borradores huérfanos — en vez de reconstruir en silencio un montón de \
                pestañas que usted no recuerda.
                """),
            .warning("""
                Una sesión **no es una copia de seguridad**. Conserva el estado de trabajo, no el \
                historial. Todo lo que importe hay que guardarlo igualmente en un archivo.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Versiones guardadas antes",
        summary: "Ver y restaurar versiones antiguas de un archivo.",
        keywords: ["versiones", "historial", "restaurar", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                En cada guardado, GEditor registra la versión **anterior** antes de sobrescribir. \
                `Macro ▸ Versiones guardadas…` abre su navegador.
                """),
            .bullets([
                "El almacén de versiones es el del **sistema operativo**, el mismo mecanismo que usan las apps de Apple.",
                "Restaurar una versión antigua es una **edición corriente** — `⌘Z` la deshace.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Seguir un archivo que aún se está escribiendo",
        summary: "Como `tail -f`: lo que se añade aparece según llega.",
        keywords: ["tail", "seguir", "registro", "tiempo real"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Archivo ▸ Seguir archivo (tail -f)` carga lo que aparece al final del archivo y se \
                desplaza con él.
                """),
            .warning("""
                Mientras sigue, el documento queda **de solo lectura**. Escribir mientras se carga texto \
                nuevo desde el disco son dos escritores peleando por un documento, y el perdedor es \
                siempre lo que acaba de teclear.
                """),
            .note("""
                La barra de estado dice **Siguiendo** todo el rato, así que minutos después todavía sabe \
                por qué el archivo no acepta escritura. Pulsar el segmento de **solo lectura** dice la \
                razón sin rodeos.

                El seguimiento pertenece a la **pestaña que lo inició**, no a la ventana: abra otra \
                pestaña y siga escribiendo, y las líneas nuevas de registro siguen fluyendo a su propia \
                pestaña sin tocar el archivo que está editando.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Imprimir",
        summary: "Imprimir por el diálogo de impresión estándar de macOS.",
        keywords: ["imprimir", "papel", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Imprimir")]),
            .paragraph("""
                Usa el diálogo de impresión del sistema, así que exportar a PDF también ocurre ahí — el \
                botón `PDF` de abajo a la izquierda.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Imágenes, PDF, archivos de Office, audio, vídeo y comprimidos",
        summary: "Ocho clases de archivo se abren dentro de GEditor sin otra aplicación.",
        keywords: ["imagen", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "comprimido",
                   "audio", "vídeo"],
        blocks: [
            .table(
                headers: ["Clase", "Qué puede hacer"],
                rows: [
                    ["Imágenes", "Ver, ampliar, girar; **las imágenes animadas se reproducen** y se pueden pausar"],
                    ["Audio", "Reproducir, buscar, cambiar volumen"],
                    ["Vídeo", "Reproducir, buscar, pantalla completa, imagen sobre imagen"],
                    ["PDF", "Leer, buscar, **anotar**"],
                    ["Word · Excel · PowerPoint", "Ver **y editar** — `⌘S` escribe de vuelta en el archivo"],
                    ["ZIP · TAR · GZ · XZ", "Listar entradas y abrir cada una como pestaña"],
                    ["7z · RAR y siete formatos más", "Lo mismo, mediante libarchive"],
                ]
            ),
            .paragraph("""
                Abrir una entrada de un comprimido crea una pestaña con su contenido. Las tildes \
                vietnamitas sobreviven tanto en los nombres como en el contenido.
                """),
            .note("""
                Edite uno de los tres formatos de Office, pulse `⌘S`, y se escribe de vuelta en el \
                archivo — LibreOffice lee el resultado. Este camino está probado de extremo a extremo, \
                no meramente exportado a una copia.
                """),
            .heading("El audio y el vídeo usan los reproductores de macOS"),
            .paragraph("""
                La reproducción pasa por los descodificadores del sistema, así que no se descarga ni se \
                incluye nada extra. A cambio, algunos formatos **no se reproducirán** — `.mkv`, \
                `.webm`, `.avi`, `.wmv` — porque macOS no trae descodificador para ellos.
                """),
            .paragraph("""
                Para un archivo así GEditor **dice por qué** en vez de mostrar un rectángulo negro, y \
                ofrece el visor binario u otra aplicación.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "Herramientas de PDF",
        summary: "Leer, anotar y toda una capa de páginas: girar · mover · borrar · extraer · combinar.",
        keywords: ["pdf", "página", "girar", "borrar página", "extraer", "combinar",
                   "anotar", "resaltar", "firmar"],
        blocks: [
            .paragraph("""
                La vista de PDF tiene **dos barras de herramientas**, que responden a preguntas \
                distintas. La fila superior actúa sobre el **contenido** de una página; la inferior, \
                sobre el **conjunto de páginas**.
                """),
            .heading("Fila superior — leer y anotar"),
            .table(
                headers: ["Botón", "Qué hace"],
                rows: [
                    ["Resaltar · Subrayar", "Marcar el texto seleccionado"],
                    ["Nota…", "Adjuntar una nota a la página"],
                    ["Quitar anotaciones", "Quitar toda anotación de la página actual"],
                    ["Extraer texto a una pestaña", "Llevar todo el texto a una pestaña para buscar, filtrar, usar otras herramientas"],
                    ["Campo de búsqueda", "Buscar dentro del PDF — **escribir sin tildes encuentra igualmente texto acentuado**"],
                ]
            ),
            .note("""
                Un PDF escaneado no tiene capa de texto. La orden de extracción **lo dice** en vez de \
                abrir una pestaña vacía y dejarle adivinar.
                """),
            .heading("Fila inferior — operaciones de página"),
            .table(
                headers: ["Botón", "Qué hace", "Deshacible"],
                rows: [
                    ["Girar izquierda · derecha", "Girar la página actual 90°", "Sí"],
                    ["Página arriba · abajo", "Intercambiar la página actual con su vecina", "Sí"],
                    ["Borrar páginas…", "Borrar por intervalo, p. ej. `2-4,7`", "Sí"],
                    ["Extraer páginas…", "Escribir un intervalo de páginas como **archivo nuevo**", "No toca el archivo abierto"],
                    ["Combinar un PDF…", "Insertar otro PDF justo después de la página actual", "Sí"],
                    ["Firmar…", "Colocar una imagen de firma en la página actual", "Sí"],
                    ["Editar texto…", "Dibujar texto de reemplazo sobre la selección", "Sí"],
                    ["Siguiente campo vacío", "Ir al siguiente campo de formulario sin rellenar", "—"],
                    ["Borrar valores rellenados", "Vaciar todos los campos de formulario", "Sí"],
                    ["Deshacer cambio de página", "Retroceder una operación de página", "—"],
                    ["Guardar la copia editada…", "Escribir un archivo nuevo y luego **volver a abrirlo para verificar**", "—"],
                ]
            ),
            .heading("Formularios rellenables"),
            .paragraph("""
                Abra un PDF con campos de formulario y la barra de estado dice **cuántos** hay. Escriba \
                directamente en los campos de la página y luego `Guardar la copia editada…`.
                """),
            .bullets([
                "Los valores se guardan como **campos de formulario vivos**, no como texto aplanado — así el Acrobat del destinatario sigue viendo un formulario relleno y puede corregirlo.",
                "Las tildes vietnamitas sobreviven al ciclo escribir-y-reabrir. Una prueba vigila justamente eso, con el nombre `Nguyễn Văn Anh`.",
                "`Siguiente campo vacío` salta al siguiente en blanco — el camino natural por un formulario largo.",
            ]),
            .heading("Firmar"),
            .paragraph("""
                Prepare una imagen de firma (un PNG con fondo transparente va mejor), **seleccione el \
                lugar donde firmar** — normalmente la raya o la palabra «Firma» — y pulse `Firmar…`. Sin \
                nada seleccionado, la firma cae abajo a la derecha.
                """),
            .note("""
                La firma conserva la **proporción** de la imagen: una firma aplastada o estirada parece \
                falsa al instante.
                """),
            .heading("Editar texto — y tres cosas que saber antes"),
            .paragraph("""
                Seleccione el texto que cambiar y pulse `Editar texto…`. GEditor **cubre esa zona con un \
                color de fondo tomado justo al lado** y dibuja el texto nuevo encima.
                """),
            .warning("""
                **El texto viejo queda CUBIERTO, no ELIMINADO.** Sigue en el archivo y sigue siendo \
                extraíble con `Extraer texto a una pestaña` o cualquier otra herramienta. Esto **no es \
                censura**: ocultar así un número de identidad lo oculta al ojo humano, no a una máquina.
                """),
            .bullets([
                "**El texto nuevo sigue siendo localizable con `⌘F`.** Se dibuja como texto de verdad, no como imagen — medido por una prueba, no supuesto.",
                "**La tipografía es una del sistema**, no la original del documento. A propósito: las tipografías incrustadas en un PDF suelen carecer de tildes vietnamitas, y `Nguyễn` llegaría como `Nguy?n`.",
                "**Sobre un fondo con dibujo el parche se ve** — el color de cobertura se toma de un solo punto justo a la izquierda de la selección.",
            ]),
            .heading("Por qué dibujar encima en vez de editar el flujo de contenido"),
            .paragraph("""
                Editar directamente el flujo de contenido de un PDF significa lidiar con tipografías \
                subconjunto que llevan su propia codificación, frases partidas en tres fragmentos por el \
                interletraje y tablas de anchura de caracteres que hay que recalcular. Hacerlo bien para \
                **todos** los archivos es un proyecto en sí; hacerlo mal corrompe el documento de \
                alguien.
                """),
            .paragraph("""
                A cambio, el resto de la página **no cambia ni un byte**, y la página sigue siendo una \
                página — el texto todavía se selecciona, se copia y se busca. Redibujar **no** la \
                convierte en imagen.
                """),
            .heading("Sintaxis de intervalos de páginas"),
            .table(
                headers: ["Escriba", "Significado"],
                rows: [
                    ["`5`", "Solo la página 5"],
                    ["`2-4`", "Páginas 2, 3, 4"],
                    ["`-3`", "Desde el principio hasta la página 3"],
                    ["`8-`", "Desde la página 8 hasta el final"],
                    ["`1-3,5,9-`", "Varias partes unidas por comas"],
                ]
            ),
            .paragraph("Las páginas se cuentan **desde 1**, el número que ve en pantalla."),
            .warning("""
                Un intervalo invertido (`5-2`) y uno más allá del final (`1-999`) se **rechazan ambos \
                con una razón**, nunca se corrigen en silencio a algo parecido. En una orden de borrar \
                páginas, adivinar mal significa perder páginas, y recortar en silencio convierte una \
                errata en una orden válida.
                """),
            .heading("El archivo original nunca se sobrescribe"),
            .paragraph("""
                Todo lo anterior cambia el documento **en memoria**. Solo cuando pulsa `Guardar la copia \
                editada…` y elige una ubicación se escribe un archivo — y tras escribirlo, GEditor \
                **vuelve a abrir ese mismo archivo** para confirmar que conserva todas sus páginas.
                """),
            .paragraph("""
                La razón: un archivo mal escrito reposa en el disco con aspecto perfectamente normal, y \
                el usuario se entera solo después de enviarlo.
                """),
            .note("""
                La línea de estado de la vista dice **· editado, sin guardar** siempre que el documento \
                difiere del archivo en disco.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
