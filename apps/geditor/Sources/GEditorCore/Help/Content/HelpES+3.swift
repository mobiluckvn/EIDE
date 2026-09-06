import Foundation

/// Contenido de ayuda en español — parte 3: formas de ver, vietnamita, lenguajes y formatos.
extension HelpES {

    static let views = HelpChapter(
        id: "xem",
        title: "Formas de ver un documento",
        summary: "Barra lateral, mapa, plegado, vista dividida, ajuste de línea, invisibles, modos de color.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Barra lateral y lista de funciones",
        summary: "El árbol de archivos y la lista de funciones del archivo abierto, en una misma columna.",
        keywords: ["barra lateral", "lista de funciones", "esquema", "árbol de archivos"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Mostrar / ocultar la barra lateral")]),
            .paragraph("""
                La lista de funciones se construye desde el **árbol sintáctico** del lenguaje, así que \
                sigue la estructura real en vez de adivinarla por la sangría. Pulse una entrada para \
                saltar allí.
                """),
            .note("El campo de filtro de la lista **encuentra texto acentuado escribiendo sin tildes**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Mapa del documento",
        summary: "Todo el archivo en una columna estrecha a la derecha — incluso con cientos de MB.",
        keywords: ["minimapa", "mapa", "vista general"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Mostrar / ocultar el mapa del documento")]),
            .paragraph("""
                El mapa describe **todo el archivo**, no solo lo que hay en pantalla. Arrastrar sobre él \
                salta a la región correspondiente.
                """),
            .paragraph("""
                Las coincidencias de búsqueda y las líneas marcadas aparecen en el mapa, así que puede \
                ver si están dispersas o agrupadas antes de desplazarse allí.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Plegado",
        summary: "Plegar funciones, bloques y arreglos por estructura — o plegar todo el archivo a un nivel.",
        keywords: ["plegar", "code folding", "contraer"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Plegar / desplegar el bloque del cursor"),
                HelpShortcut("⌥⇧⌘←", "Plegar todo"),
                HelpShortcut("⌥⌘→", "Desplegar todo"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Plegar todo el archivo al nivel 1…8"),
            ]),
            .paragraph("""
                En lenguajes con árbol sintáctico, el plegado sigue la **estructura real**. En archivos \
                sin gramática, sigue la sangría.
                """),
            .paragraph("""
                `Plegar al nivel` se gana el sueldo con JSON y YAML profundos: plegar al nivel 2 pone la \
                forma de todo el archivo en una pantalla.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Vista dividida",
        summary: "Dos paneles lado a lado, para dos archivos — o dos puntos de un mismo archivo.",
        keywords: ["dividir", "paneles", "comparar"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Dividir en vertical"),
                HelpShortcut("⌥⌘-", "Dividir en horizontal"),
                HelpShortcut("⌥⌘0", "Quitar la división"),
                HelpShortcut("⌥⌘]", "Abrir esta pestaña en el otro panel"),
                HelpShortcut("⌥⌘[", "Saltar al otro panel"),
            ]),
            .paragraph("""
                Cada panel tiene su propia barra de pestañas. Abrir el **mismo archivo** en ambos \
                paneles está bien — se desplazan de forma independiente, lo que facilita comparar el \
                principio y el final de un archivo.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Ajuste de línea",
        summary: "Tres modos: desactivado, en el borde de la ventana o en una columna fija.",
        keywords: ["ajuste de línea", "salto suave"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Modo", "Una línea larga"],
                rows: [
                    ["Desactivado", "Se desplaza en horizontal"],
                    ["En la ventana", "Salta en el borde de la ventana, siguiendo su tamaño"],
                    ["En una columna", "Salta en la columna que fije — 80 o 100, digamos"],
                ]
            ),
            .paragraph("""
                El ajuste es una **forma de mirar**, no una edición: no se inserta ningún salto de \
                línea y nunca entra en el historial de deshacer.
                """),
            .note("La vía rápida es el segmento `Ngắt: …` de la barra de estado."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Tamaño de letra",
        summary: "Ampliar entre 8 y 32 pt.",
        keywords: ["zoom", "tamaño", "más grande", "más pequeño"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Más grande"),
                HelpShortcut("⌘-", "Más pequeño"),
                HelpShortcut("⌃⌘0", "Volver al tamaño por omisión"),
            ]),
            .paragraph("""
                Acotado entre 8 y 32 pt. Esto también es una **forma de mirar**: sin edición, nada en el \
                historial de deshacer. El tamaño por omisión vive en `Ajustes…`.
                """),
            .note("`⌘0` **no** es el tamaño por omisión — esa tecla muestra y oculta la barra lateral."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Mostrar caracteres invisibles",
        summary: "Un grupo cada vez, porque todos a la vez suele ser demasiado.",
        keywords: ["invisible", "espacios", "nbsp", "ancho cero", "tabulador"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Mostrar / ocultar todos los caracteres invisibles")]),
            .paragraph("""
                Cuatro grupos se activan por separado, porque encenderlos todos a la vez entierra el \
                contenido bajo un bosque de puntos.
                """),
            .table(
                headers: ["Grupo", "Qué caza"],
                rows: [
                    ["Espacios", "Espacios al final de línea, sangría inconsistente"],
                    ["Tabuladores", "Archivos que mezclan tabuladores con espacios"],
                    ["Finales de línea", "Archivos que mezclan CRLF con LF"],
                    ["NBSP · ancho cero · control", "Caracteres invisibles de Word, de la web, de hojas de cálculo"],
                ]
            ),
            .warning("""
                El último grupo es el que salva a la gente. Un espacio duro (NBSP) pegado de una página \
                web parece **exactamente** un espacio corriente y, sin embargo, hace fallar toda \
                comparación de cadenas y todo filtro — y no hay forma de verlo sin este grupo activado.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "Modo CSV y modo Registro",
        summary: "Dos coloreados que sustituyen al resaltado de sintaxis, para dos clases de archivo de datos.",
        keywords: ["modo csv", "modo registro", "resaltado", "columnas", "nivel"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("Modo CSV"),
            .paragraph("""
                Da a cada columna su propio color en la vista de **texto**, así ve qué celda se ha \
                desplazado una columna sin cambiar a la tabla.
                """),
            .heading("Modo Registro"),
            .paragraph("""
                Colorea por la **gravedad** que lee de la línea: errores en rojo, avisos en ámbar, \
                mientras `debug` y `trace` se atenúan — componen la mayor parte de un registro, y \
                resaltarlos atenúa justo lo que está buscando.
                """),
            .paragraph("`Filtrar registro por nivel…` oculta del todo los niveles que no necesita."),
            .note("""
                Estos dos colorean **en lugar del** resaltado de sintaxis, no encima. Un registro no \
                tiene sintaxis que colorear, y dos fuentes de color escribiendo en el mismo rango de \
                bytes no dejan un ganador previsible.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Vista binaria",
        summary: "Una tabla hexadecimal para cualquier archivo — incluido uno de 1 GB, que se abre casi al instante.",
        keywords: ["hex", "binario", "byte", "posición", "volcado"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Ver ▸ Vista binaria` muestra cada byte como una tabla de tres columnas: **posición · \
                hex · texto**. Funciona con **cualquier** archivo del disco, no solo con imágenes o \
                vídeo.
                """),
            .table(
                headers: ["Columna", "Contenido"],
                rows: [
                    ["Posición", "Posición del byte, en hexadecimal"],
                    ["Hex", "16 bytes por fila, separados tras el octavo para contar mejor"],
                    ["Texto", "Bytes ASCII imprimibles; todo lo demás es un `.`"],
                ]
            ),
            .note("""
                La columna de texto **no descodifica UTF-8**. Una letra vietnamita ocupa dos o tres \
                bytes, así que mostrarla desalinearía la columna de texto respecto a la hexadecimal — y \
                esa alineación es todo el sentido de la columna. Para leer texto acentuado, use la vista \
                normal.
                """),
            .heading("Archivos grandes"),
            .paragraph("""
                El archivo está **mapeado en memoria**, así que abrir uno de 1 GB en vista binaria \
                cuesta solo lo que usted mire. Medido en la batería de autopruebas: **menos de un \
                milisegundo**.
                """),
            .paragraph("""
                La vista muestra **una ventana de 4 MB** cada vez, y la barra superior dice en qué \
                intervalo está. Es un límite del dibujante de tablas del sistema, no de la lectura: 1 GB \
                son 62,5 millones de filas, y pasado cierto punto las filas empiezan a saltar al \
                desplazarse — y una tabla hexadecimal que salta no sirve de nada.
                """),
            .heading("Saltar a una posición"),
            .table(
                headers: ["Escriba en el campo de posición", "Significado"],
                rows: [
                    ["`1F400`", "Hexadecimal — lo predeterminado"],
                    ["`0x1F400`", "Lo mismo, con prefijo explícito"],
                    ["`#128000`", "Decimal, cuando tiene un recuento de bytes y no una posición hexadecimal"],
                ]
            ),
            .bullets([
                "`‹` y `›` van a la ventana anterior / siguiente.",
                "**Copiar las filas seleccionadas** copia exactamente lo que ve — sin selección, copia toda la ventana.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Vista previa de Markdown",
        summary: "Mostrar Markdown como texto con formato — y decir claramente qué no muestra.",
        keywords: ["markdown", "vista previa", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("Se dibuja con el soporte de Markdown del sistema: negrita, cursiva, código, enlaces, listas."),
            .warning("""
                **Sin tablas y sin color de sintaxis dentro de los bloques de código.** La ventana de \
                vista previa lo dice al pie. Los documentos de más de **4 MB** se rechazan.
                """),
            .paragraph("""
                ¿Necesita tablas y gráficos en un documento publicable? Para eso están los informes \
                `.greport.md`, no esta vista previa.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Dos modos: Vista y Código",
        summary: "Una tecla alterna entre la forma dibujada y la fuente editable, para cada tipo de archivo.",
        keywords: ["vista", "código", "modo", "fuente", "dibujado", "previa"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Alternar entre Vista y Código")]),
            .paragraph("""
                El control está en la **barra justo bajo las pestañas** — en el mismo sitio para cada \
                tipo de archivo: un conmutador `View | Code` y luego el nombre del modo Vista de ese \
                archivo («Páginas del documento», «Árbol clave-valor», «Diagrama»…). Un archivo con un \
                solo modo atenúa el conmutador y la barra dice por qué. En el borde derecho están los \
                botones propios de cada tipo: `.xlsx` tiene **Tabla** (editable, se escribe de vuelta), \
                `.pptx` tiene **Esquema**.
                """),
            .note("""
                **Word y PowerPoint se comportan como un lector de documentos.** Su modo Vista construye \
                páginas reales — tipografías, tamaños y colores correctos, con imágenes, tablas, \
                encabezados y pies con números de página. Una página es **exactamente igual de ancha que \
                el marco** y se puede ampliar. Excel es una excepción deliberada: su Vista es una **hoja \
                de cálculo editable**, porque una hoja de cálculo no tiene tamaño de papel hasta que se \
                imprime.
                """),
            .note("""
                A cambio, las páginas son **de solo lectura** y muestran la **copia del disco**: si \
                edita en Código sin guardar, las páginas muestran la versión antigua — la barra lo dice, \
                con un botón `Guardar y volver a dibujar`.
                """),
            .heading("Definiciones"),
            .bullets([
                "**Código** es la **fuente editable**. En un archivo de texto es el texto mismo. En un archivo binario — PDF, imagen, audio, vídeo — no hay fuente textual, así que Código son los **bytes**, mostrados en hexadecimal.",
                "**Vista** es lo que se **dibuja** a partir del Código. Puede ser más bonito, más corto o ejecutable — pero siempre es una consecuencia, nunca el original.",
            ]),
            .paragraph("""
                Decir de un PDF que *«este tipo no tiene Código»* sería cómodo, pero falso: los bytes sí \
                son su fuente.
                """),
            .heading("Dónde se edita"),
            .paragraph("""
                La edición ocurre en **Código**. Hay exactamente **dos excepciones**, ambas porque editar \
                en Vista es mucho más natural: las **celdas de la tabla CSV** y los **campos de \
                formulario PDF**. Ambas escriben directamente en la fuente, así que no aparece una \
                segunda copia con la que discutir.
                """),
            .heading("Por tipo de archivo"),
            .table(
                headers: ["Tipo de archivo", "Vista", "Código", "Editar en"],
                rows: [
                    ["CSV · TSV", "Tabla", "Texto crudo", "**Ambos**"],
                    ["Excel `.xlsx`", "Tabla de la hoja abierta", "Esa hoja como CSV", "**Ambos**"],
                    ["PDF", "Páginas dibujadas", "Binario", "**Ambos** — anotaciones, campos, páginas"],
                    ["Markdown `.md`", "Texto dibujado", "Fuente Markdown", "Código"],
                    ["Informe `.greport.md`", "Informe con consultas ejecutadas y gráficos dibujados", "Fuente", "Código"],
                    ["JSON", "Árbol clave-valor, plegable", "Fuente JSON", "Código"],
                    ["XML · HTML", "Árbol de etiquetas, plegable", "Fuente XML", "Código"],
                    ["YAML", "Árbol clave-valor por sangría", "Fuente YAML", "Código"],
                    ["Diagramas `.mmd` · `.dot`", "El diagrama dibujado, ocupando la pestaña", "Fuente mermaid o DOT", "Código"],
                    ["Word `.docx`", "Páginas de documento dibujadas", "Markdown extraído", "Código"],
                    ["PowerPoint `.pptx`", "Páginas de diapositivas dibujadas", "Esquema Markdown", "Código"],
                    ["Archivos de registro", "Coloreados por nivel, filtrables", "Texto crudo", "Código"],
                    ["Imágenes", "La imagen (las animadas se reproducen)", "Binario", "Solo lectura"],
                    ["Audio · vídeo", "Un reproductor", "Binario", "Solo lectura"],
                    ["Comprimidos", "Lista de entradas", "Binario", "Solo lectura"],
                    ["Código fuente, texto llano", "— ninguna", "El texto mismo", "Código"],
                ]
            ),
            .note("""
                El código fuente **no tiene Vista**, y eso es normal más que una carencia: un archivo \
                Swift no tiene forma dibujada que merezca mirarse.
                """),
            .heading("El lector de páginas para Word y PowerPoint"),
            .paragraph("""
                Las páginas se apilan en vertical y se desplazan de continuo, cada una una hoja blanca \
                sobre fondo gris — como todo lector de documentos. Sus controles están a la derecha de la \
                barra.
                """),
            .table(
                headers: ["Botón / tecla", "Qué hace"],
                rows: [
                    ["`Ajustar ancho`", "La hoja es exactamente igual de ancha que el marco — lo predeterminado"],
                    ["`Ajustar página`", "La hoja entera cabe en el marco"],
                    ["`−` `+`", "Ampliar por pasos; o pellizcar, o ⌘ + rueda"],
                    ["El campo `Buscar`, o ⌘F", "Buscar dentro de las páginas, saltar allí y resaltar"],
                    ["Intro en el campo de búsqueda", "Coincidencia siguiente"],
                    ["Arrastrar", "Seleccionar texto; doble clic para una palabra, triple para un párrafo"],
                    ["⌘A · ⌘C", "Seleccionar todo · copiar la selección"],
                    ["Av Pág · Re Pág · Inicio · Fin", "Moverse por el documento"],
                ]
            ),
            .paragraph("""
                El campo de búsqueda **ignora tildes y mayúsculas**: escribir `vuong quoc` encuentra \
                `Vương quốc`. La etiqueta «Página 12/363» de la barra le dice dónde está.
                """),
            .note("""
                **Lo que no se dibuja, dicho sin rodeos:** las imágenes flotantes ancladas (texto que \
                rodea una figura) aparecen como imágenes en línea; las notas al pie, los gráficos y el \
                SmartArt de PowerPoint no se dibujan. Cuando necesite coincidencia exacta con la copia \
                impresa, ábralo en Word.
                """),
            .heading("Pulsar un nodo vuelve a la fuente"),
            .paragraph("""
                Un árbol JSON no es una impresión bonita: pulsar un nodo mueve el cursor **al VALOR de \
                ese nodo** en el texto y devuelve la pestaña a Código — porque lo siguiente que quiere \
                es casi siempre editar lo que acaba de pulsar.
                """),
            .bullets([
                "Los nodos contenedores muestran su **número de elementos** (`{12}`, `[340]`) en vez de su contenido — eso es lo que responde a «¿merece la pena abrirlo?».",
                "Los **dos primeros niveles** vienen desplegados: desplegar del todo un archivo de diez mil nodos produce una lista más larga que la fuente, mientras que plegarlo del todo obliga a hacer clic para descubrir nada.",
                "Un archivo con **sintaxis inválida** no recibe medio árbol — un árbol truncado parece un documento que simplemente contiene tan poco.",
                "En un árbol XML los atributos llevan prefijo `@` en notación XPath, y **el espacio entre etiquetas no se convierte en nodo** — es formato, no contenido.",
                "Un árbol YAML lee **archivos multidocumento** (`---`): cada documento tiene su raíz. Las colecciones escritas en línea (`ports: [80, 443]`) siguen siendo una hoja — ya lo ve todo, y desplegar costaría un clic. La **sangría con tabuladores** se informa con la línea exacta: es un error de YAML que el ojo no ve.",
                "El esquema de PowerPoint se construye desde el **texto abierto**, no desde el archivo del disco: si acaba de editar el esquema en Código, el árbol debe describir la versión nueva y sus nodos deben saltar a esa versión nueva. Las notas del ponente se pliegan en un nodo, para que una diapositiva habladora no parezca una con mucho contenido.",
                "**Un diagrama a pestaña completa sigue la misma regla**: pulse un nodo y vuelve a Código con el cursor en su declaración. En el panel `Mermaid Studio` lado a lado la pestaña no se cierra — el editor está ahí mismo, y basta con mover el cursor para verlo.",
                "Los diagramas también **se abren donde usted está**: el elemento que corresponde a la línea del cursor queda resaltado en cuanto aparece la pestaña, para no tener que buscarlo.",
            ]),
            .heading("El campo de filtro: en un árbol de diez mil nodos, buscar es el trabajo"),
            .paragraph("""
                Justo bajo el recuento de nodos hay un campo de filtro. Escriba ahí y el árbol conserva \
                solo los nodos coincidentes — **junto con la ruta desde la raíz hasta ellos**, porque \
                cuando una clave `name` aparece en diez sitios la pregunta real es «cuál», y solo la \
                rama que la contiene responde. El resto se despliega por usted: hacerle abrir cada nivel \
                a clics es hacerle filtrar otra vez a mano.
                """),
            .bullets([
                "Filtra por **etiquetas y valores**: buscar `Huế` es tan común como buscar la clave `province`.",
                "**Escribir sin tildes sigue coincidiendo con texto acentuado** — `da nang` encuentra `Đà Nẵng`. La misma comparación que el filtro de la tabla CSV y que la lista de funciones, para no tener que recordar tres reglas de búsqueda en una sola aplicación.",
                "Sin coincidencias, la cabecera dice **«Sin resultados»** en vez de dejarle mirando un árbol vacío preguntándose si el archivo está roto.",
                "Cambiar de archivo o volver a entrar en Vista **borra el filtro**: un árbol que se abre ya truncado, sin nada que lo explique, es el estado más confuso de todos.",
            ]),
            .heading("Todo el árbol se maneja con el teclado"),
            .paragraph("""
                Entrar en Vista pone el foco en el árbol; no hace falta pulsarlo antes. Arriba y abajo se \
                mueven entre nodos, izquierda y derecha pliegan y despliegan, y dos teclas terminan la \
                sesión de mirar — haciendo cosas **distintas**:
                """),
            .bullets([
                "**Intro** — ir al nodo seleccionado: vuelta a Código con el cursor dentro del rango de bytes de ese nodo. Igual que pulsarlo.",
                "**Tab** — moverse entre el árbol y el campo de filtro.",
                "**⌘C** — copia la **ruta** del nodo seleccionado, no el texto que hay tras el árbol. JSON y YAML producen JSONPath (`$.customer['name']`) que se pega tal cual en el campo de consulta JSONPath de este mismo producto, o en `yq`; XML produce XPath (`/order/item[2]/@code`) con índices cuando dos etiquetas comparten nombre; un esquema de PowerPoint copia el texto de la línea, porque un esquema no tiene un lenguaje de rutas que inventar.",
                "**Esc** — el camino de vuelta: volver a Código con el cursor **exactamente donde estaba**. Estaba mirando un árbol, no viajando a ningún sitio.",
            ]),
            .heading("Y al revés: el árbol se abre donde está el cursor"),
            .paragraph("""
                Entrar en Vista desde la mitad de un archivo de diez mil líneas **no** abre el árbol \
                arriba: despliega la ruta hasta el nodo que corresponde a donde estaba el cursor y lo \
                selecciona. Esta es la otra mitad del salto a la fuente — sin ella, Vista y Código serían \
                dos miradas a un documento en una **sola** dirección.
                """),
            .bullets([
                "Despliega **más de dos niveles** cuando hace falta: la regla de dos niveles responde a «cómo es este archivo», mientras que aquí la pregunta es otra — «dónde estoy en este árbol».",
                "Un cursor sobre una **clave** (`\"address\":`) selecciona esa entrada, aunque el rango de bytes del nodo cubra solo el valor. El texto justo antes de un nodo pertenece a ese nodo.",
                "Un cursor al **inicio de un bloque** — la clave de un bloque YAML, un título de diapositiva, un nombre de etiqueta XML — selecciona ese bloque en vez de sumergirse en su primer hijo.",
                "Entrar en Vista **no mueve el cursor**. Salga de Vista y estará justo donde estaba; Vista es una forma de mirar, no una orden que cambie de sitio.",
            ]),
            .heading("Ya no falta Vista en ningún tipo"),
            .paragraph("""
                **Todo tipo de archivo con margen para un modo Vista dibuja ahora uno.** La lista de \
                tipos que faltaban quedó vacía y se eliminó.

                El código fuente y el texto llano siguen sin Vista — eso es normal, no una carencia, así \
                que nunca estuvieron en esa lista.

                Si llega un tipo de archivo nuevo cuya Vista aún no está construida, la orden de alternar \
                lo dirá y nombrará qué falta, en vez de abrir un marco vacío — un marco vacío es una \
                promesa vacía, mientras que una negativa con nombre es información.
                """),
            .heading("Las seis órdenes antiguas siguen ahí"),
            .paragraph("""
                `Vista tabla / texto`, `Vista previa de Markdown`, `Vista binaria`, `Vista previa del \
                informe`, `Vista previa del diagrama Mermaid`, `Modo registro` — todas siguen justo donde \
                estaban. `⌥⌘V` es una **entrada compartida**, no un sustituto.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamita

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamita",
        summary: "Codificaciones antiguas, normalización Unicode, búsqueda sin tildes y métodos de entrada.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Codificaciones vietnamitas",
        summary: "Leer y escribir TCVN3, VISCII, VNI-Windows y otras 33, detectadas automáticamente.",
        keywords: ["codificación", "tcvn3", "abc", "viscii", "vni", "caracteres raros"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                ¿Abrió un archivo vietnamita antiguo y obtuvo `Tr¦êng §¹i häc` en vez de `Trường Đại \
                học`? El archivo no está dañado — se guardó en una codificación anterior a Unicode.
                """),
            .steps([
                "Pulse la codificación en la **barra de estado** (o `Formato ▸ Codificación…`).",
                "Elija la correcta — en archivos vietnamitas antiguos suele ser `TCVN3 (ABC)`, `VNI-Windows` o `VISCII`.",
                "El texto se corrige al instante; no hace falta volver a abrir el archivo.",
                "Para que quede así, `Guardar como…` con la codificación `UTF-8`.",
            ]),
            .heading("Las tres codificaciones vietnamitas antiguas"),
            .table(
                headers: ["Codificación", "Se encuentra sobre todo en"],
                rows: [
                    ["TCVN3 (ABC)", "Papeleo oficial y documentos Word antiguos del norte"],
                    ["VNI-Windows", "Edición, prensa e imprentas — común en el sur"],
                    ["VISCII", "Correo y Usenet de los primeros tiempos"],
                ]
            ),
            .paragraph("""
                GEditor **detecta la codificación** al abrir. Cuando se equivoca, un clic lo arregla, y \
                el contenido se vuelve a descodificar en vez de parchearse letra a letra.
                """),
            .warning("""
                Escribir a una codificación antigua pierde los caracteres que esa codificación no tiene. \
                GEditor **los cuenta y se lo dice antes** — por ejemplo *«12 caracteres no están en \
                TCVN3»* — en lugar de convertirlos en interrogantes en silencio.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Finales de línea",
        summary: "LF, CRLF, CR — convertidos para todo el archivo con un clic.",
        keywords: ["eol", "crlf", "lf", "final de línea", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Estilo", "Lo usa", "Bytes"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac anterior a 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                El estilo actual se ve en la barra de estado; púlselo para cambiarlo. Un archivo que \
                **mezcla** dos estilos también se informa ahí — active `Mostrar invisibles ▸ Finales de \
                línea` para ver exactamente dónde.
                """),
            .note("El estilo de final de línea para archivos **nuevos** se ajusta en `Ajustes…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Normalización Unicode",
        summary: "Por qué buscar «ế» a veces no encuentra nada, y cómo arreglar un archivo entero.",
        keywords: ["unicode", "nfc", "nfd", "compuesto", "descompuesto", "normalizar"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                En Unicode, `ế` se puede escribir de **dos formas**: como un punto de código \
                precompuesto (NFC), o como `e` más dos marcas separadas (NFD). En pantalla parecen \
                idénticos; para una máquina son dos cadenas distintas.
                """),
            .paragraph("""
                La consecuencia: buscar `ế` en un archivo NFD no encuentra **nada**, y el usuario \
                concluye que el dato no está.
                """),
            .steps([
                "`Formato ▸ Normalizar Unicode…`",
                "Elija **NFC** (precompuesto) — la forma que usa casi todo lo demás.",
                "Aplique. Es un solo paso de deshacer.",
            ]),
            .note("""
                Los archivos que vienen de macOS suelen ser NFD, porque el sistema de archivos de Apple \
                guarda así los nombres. Esta es la razón más común de que los datos copiados del Finder \
                no vuelvan a encontrarse.
                """),
            .paragraph("""
                Hay un interruptor **normalizar a NFC al guardar** en `Ajustes…`. Desactivado por \
                omisión, porque cambia los bytes del archivo.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Escribir sin tildes encuentra igualmente texto acentuado",
        summary: "Cada campo de búsqueda y de filtro compara con las tildes quitadas.",
        keywords: ["tildes", "diacríticos", "búsqueda", "filtro"],
        blocks: [
            .paragraph("""
                Escriba `hue` para encontrar `Huế`. Escriba `da nang` para encontrar `Đà Nẵng`. La regla \
                vale para el filtro de la tabla CSV, la búsqueda de funciones, la búsqueda en la ayuda y \
                los demás campos de filtro.
                """),
            .note("""
                `Đ` se trata aparte, porque en Unicode es **una letra propia** y no una `D` con una \
                marca — el quitado de tildes corriente no la toca.
                """),
            .paragraph("""
                El filtro CSV también acepta un prefijo `=` para comparación exacta. La forma `=` es \
                **igualmente insensible a tildes**, porque un filtro que distinga diacríticos deja al \
                usuario creyendo que el dato falta.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Métodos de entrada vietnamitas",
        summary: "EVKey, OpenKey, Unikey y la fuente de entrada de macOS escriben directamente en el documento.",
        keywords: ["método de entrada", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                Nada que configurar. Telex y VNI funcionan ambos, también con **cursores múltiples** — \
                escriba una vez y cada cursor recibe la letra correctamente acentuada.
                """),
            .paragraph("""
                Los campos de búsqueda, los de filtro y todos los diálogos aceptan el método de entrada \
                igual que el editor.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Lenguajes y formatos

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Lenguajes y formatos",
        summary: "Veinte lenguajes integrados, otros definidos por el usuario, y herramientas para JSON · XML · YAML · registros.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Veinte lenguajes integrados",
        summary: "Coloreado desde un árbol sintáctico real, con los marcadores de comentario de cada lenguaje.",
        keywords: ["sintaxis", "resaltado", "lenguaje", "tree-sitter", "gramática"],
        blocks: [
            .paragraph("""
                El lenguaje se detecta por la **extensión del archivo** (más unos pocos nombres \
                especiales como `Makefile`, `Dockerfile`, `Gemfile`). Puede cambiarlo a mano en la barra \
                de estado.
                """),
            .table(
                headers: ["Lenguaje", "Extensiones", "Comentario de línea · de bloque"],
                rows: [
                    ["Shell", "`sh` `bash` `zsh` `command`", "`#` · —"],
                    ["C", "`c` `h`", "`//` · `/* */`"],
                    ["C++", "`cpp` `cc` `cxx` `hpp` `hh` `hxx`", "`//` · `/* */`"],
                    ["C#", "`cs`", "`//` · `/* */`"],
                    ["CSS", "`css`", "— · `/* */`"],
                    ["Go", "`go`", "`//` · `/* */`"],
                    ["HTML", "`html` `htm` `xhtml`", "— · `<!-- -->`"],
                    ["Java", "`java`", "`//` · `/* */`"],
                    ["JavaScript", "`js` `mjs` `cjs` `jsx`", "`//` · `/* */`"],
                    ["JSON", "`json` `jsonl` `geojson`", "— · —"],
                    ["Lua", "`lua`", "`--` · `--[[ ]]`"],
                    ["PHP", "`php` `phtml`", "`//` · `/* */`"],
                    ["Python", "`py` `pyw` `pyi`", "`#` · —"],
                    ["Regex", "—", "— · —"],
                    ["Ruby", "`rb` `rake` `gemspec`", "`#` · —"],
                    ["Rust", "`rs`", "`//` · `/* */`"],
                    ["TOML", "`toml`", "`#` · —"],
                    ["TypeScript", "`ts` `mts` `cts`", "`//` · `/* */`"],
                    ["XML", "`xml` `xsd` `xsl` `svg` `plist`", "— · `<!-- -->`"],
                    ["YAML", "`yaml` `yml`", "`#` · —"],
                ]
            ),
            .paragraph("""
                La última columna es lo que usa `⌘/`. Los lenguajes sin comentario de línea (JSON, CSS, \
                XML) reciben en su lugar la forma de bloque.
                """),
            .heading("Lo que llega con un árbol sintáctico"),
            .bullets([
                "La **lista de funciones** de la barra lateral sigue la estructura real, no conjeturas de sangría.",
                "**Plegado** por estructura.",
                "**Emparejado de paréntesis** que salta los que están dentro de cadenas y comentarios.",
                "**Sangría automática** que añade un nivel tras `{`, y tras `:` en Python y YAML.",
            ]),
            .note("""
                Tres gramáticas pesadas (C++, C#, Ruby) viven en una biblioteca **de carga perezosa** — \
                solo se cargan al abrir un archivo de esos lenguajes. Así el tiempo de arranque se \
                mantiene por debajo de medio segundo.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Lenguajes definidos por el usuario",
        summary: "Colorear su propio formato con un archivo JSON — sin gramática que escribir.",
        keywords: ["udl", "lenguaje propio", "registro propio"],
        blocks: [
            .paragraph("""
                El formato de registro interno de una empresa, un lenguaje de configuración propio, un \
                pequeño DSL — ninguno tiene gramática de tree-sitter, y escribir una exige un compilador \
                y algo de teoría de análisis sintáctico.
                """),
            .paragraph("""
                En su lugar, GEditor acepta un **analizador léxico dirigido por tablas** declarado en \
                JSON. Ponga el archivo en la carpeta `grammars/` del directorio de configuración de \
                GEditor y reinicie.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — un lenguaje completo",
                  source: """
                    {
                      "name": "Internal log",
                      "extensions": ["nklog", "trace"],
                      "caseSensitive": false,
                      "lineComment": ";",
                      "blockComment": ["/*", "*/"],
                      "stringDelimiters": ["\\"", "'"],
                      "escapeCharacter": "\\\\",
                      "keywordGroups": {
                        "keyword": ["BEGIN", "END", "RETRY", "COMMIT", "ROLLBACK"],
                        "type":    ["INT", "TEXT", "DATE", "MONEY"],
                        "constant": ["TRUE", "FALSE", "NULL"]
                      }
                    }
                    """),
            .heading("Cada clave"),
            .table(
                headers: ["Clave", "Tipo", "Significado"],
                rows: [
                    ["`name`", "cadena", "El nombre que se ve en la barra de estado"],
                    ["`extensions`", "lista de cadenas", "Extensiones de archivo, **sin el punto**"],
                    ["`caseSensitive`", "booleano", "Si las palabras clave distinguen mayúsculas"],
                    ["`lineComment`", "cadena", "Marcador de comentario hasta fin de línea; omítalo si no hay"],
                    ["`blockComment`", "lista de 2 cadenas", "`[apertura, cierre]`"],
                    ["`stringDelimiters`", "lista de cadenas", "Cada entrada es **un** carácter que abre/cierra una cadena"],
                    ["`escapeCharacter`", "cadena", "Carácter de escape dentro de cadenas; vacío si el lenguaje no tiene"],
                    ["`keywordGroups`", "objeto", "Nombre de grupo → lista de palabras clave; tres grupos reciben tres colores"],
                ]
            ),
            .paragraph("Los tres nombres de grupo con color propio son `keyword`, `type` y `constant`."),
            .warning("""
                Este analizador **no entiende el anidamiento**. El plegado estructural, la lista de \
                funciones y el emparejado inteligente de paréntesis siguen siendo exclusivos de los \
                veinte lenguajes integrados. Es un canje deliberado: a cambio, usted declara un lenguaje \
                en diez minutos en vez de en un día.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "Herramientas JSON",
        summary: "Reformatear, minificar, ordenar claves y validar contra un JSON Schema.",
        keywords: ["json", "formatear", "minificar", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Orden", "Qué hace"],
                rows: [
                    ["Reformatear", "Parte y sangra para poder leerlo"],
                    ["Minificar", "Quita todo espacio superfluo"],
                    ["Ordenar claves", "Alfabetiza las claves de cada objeto — para que dos archivos JSON se puedan **comparar**"],
                    ["Validar contra JSON Schema…", "Comprueba el documento contra un esquema y lista cada problema con su línea"],
                ]
            ),
            .paragraph("""
                Las reglas aplicadas son **RFC 8259 estricto**: sin comas finales, sin comentarios, sin \
                `NaN`. Un error de sintaxis apunta a la línea y columna exactas.
                """),
            .note("""
                Los archivos **JSONL** (un objeto por línea) también se reconocen y tienen su propio \
                juego de herramientas en el capítulo del paquete de conocimiento.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "Consultas JSONPath",
        summary: "Sacar exactamente la parte que necesita de un archivo JSON grande.",
        keywords: ["jsonpath", "consulta json", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Escriba una expresión; los resultados aparecen como una lista a la que puede saltar."),
            .table(
                headers: ["Escriba", "Significado"],
                rows: [
                    ["`$`", "La raíz del documento"],
                    ["`$.name`", "La clave `name` en la raíz"],
                    ["`$.orders[0]`", "El primer elemento de una lista"],
                    ["`$.orders[*].total`", "La clave `total` de **cada** elemento"],
                    ["`$..province`", "La clave `province` a **cualquier profundidad**"],
                    ["`$.orders[1:3]`", "Un corte: elementos 1 y 2"],
                ]
            ),
            .code(language: "text", caption: "El código de provincia de cada pedido, por anidado que esté",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "Herramientas XML",
        summary: "Reformatear, minificar, comprobar sintaxis y validar contra una DTD o un XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "validar", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Orden", "Qué hace"],
                rows: [
                    ["Reformatear", "Sangra según la profundidad de etiquetas"],
                    ["Minificar", "Quita el espacio entre etiquetas"],
                    ["Comprobar sintaxis", "Etiquetas de cierre que faltan, anidamiento erróneo, caracteres inválidos"],
                    ["Validar contra DTD/XSD…", "Comprueba contra un esquema e informa de cada problema con su línea"],
                    ["Evaluar XPath…", "Ejecuta una expresión XPath; los resultados se abren en una pestaña nueva"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Escriba una expresión y los resultados se abren como **una pestaña de texto**, un nodo \
                por línea. Por ejemplo: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Los resultados NO saltan a una posición del archivo fuente.** El evaluador XPath del \
                sistema construye su propio árbol y no conserva la posición en bytes de cada nodo, así \
                que lo que vuelve es CONTENIDO y no coordenadas. Para llegar al punto exacto, use `⌘F` \
                sobre la cadena que acaba de encontrar.
                """),
            .paragraph("""
                En archivos `.xml` y `.html`, escribir `>` para terminar una etiqueta de apertura hace \
                **aparecer la de cierre** con el cursor entre ambas. Las etiquetas autocerradas \
                (`<br/>`), las declaraciones (`<?xml …?>`) y los comentarios no — no tienen nada que \
                cerrar.
                """),
            .warning("""
                Reformatear XML **cambia el espacio entre etiquetas**. En documentos donde ese espacio \
                importa — XHTML con texto dentro de etiquetas, por ejemplo — eso cambia lo que se \
                muestra. Es un solo paso de deshacer, así que `⌘Z` lo revierte.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "Comprobación de YAML",
        summary: "Cazar los dos errores de YAML más comunes: claves duplicadas y sangría con tabuladores.",
        keywords: ["yaml", "yml", "lint", "clave duplicada", "sangría"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Claves duplicadas** en un mismo mapa — la mayoría de lectores de YAML toman la **última** y descartan las anteriores en silencio, así que un archivo de configuración puede comportarse de forma muy distinta a lo que usted cree.",
                "**Sangría con tabuladores** — YAML prohíbe los tabuladores en la sangría, y los mensajes de error de las bibliotecas al respecto suelen ser incomprensibles.",
            ]),
            .note("Active `Mostrar invisibles ▸ Tabuladores` para ver al instante qué espacio es un tabulador."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Archivos de registro",
        summary: "Siete niveles de gravedad, filtrado por nivel y cómo leer un registro muy grande.",
        keywords: ["registro", "log", "error", "aviso", "filtro", "nivel"],
        blocks: [
            .paragraph("""
                Active `Ver ▸ Modo registro (colorear por nivel)`. GEditor lee la gravedad al **inicio \
                de cada línea** — tras la marca de tiempo y el nombre del proceso.
                """),
            .table(
                headers: ["Nivel", "Color"],
                rows: [
                    ["CRITICAL · ERROR", "Rojo"],
                    ["WARNING", "Ámbar"],
                    ["NOTICE", "Color de acento"],
                    ["INFO", "Texto corriente"],
                    ["DEBUG · TRACE", "Atenuado"],
                ]
            ),
            .paragraph("""
                `Filtrar registro por nivel…` oculta por completo los niveles inferiores. Las líneas \
                cuyo nivel **no se reconoce** — la continuación de una traza de pila, por ejemplo — se \
                dejan en paz en vez de asignarles el nivel de la línea anterior.
                """),
            .heading("Leer un registro grande, paso a paso"),
            .steps([
                "Abra el archivo — incluso a escala de gigabytes se abre casi al instante.",
                "`Ver ▸ Modo registro` para ver dónde está el rojo.",
                "`⌥⌘M` para el mapa del documento: ¿el rojo está agrupado en un tramo o repartido por todo el archivo?",
                "`⌘F` para el código de error, `⌘M` para marcar cada línea coincidente.",
                "`Buscar ▸ Copiar líneas marcadas` para llevarlas a una pestaña nueva.",
                "¿Sigue en marcha? `Archivo ▸ Seguir archivo (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
