import Foundation

/// Contenido de ayuda en español — parte 5: informes, conocimiento, automatización y aplicación.
extension HelpES {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Informes y diagramas",
        summary: "Un archivo de texto que produce un informe HTML cuyas cifras se recalculan, más diagramas Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "Informes `.greport.md`",
        summary: "Markdown más cuatro tipos de bloque ejecutables — escribir a la izquierda, previsualizar a la derecha.",
        keywords: ["informe", "greport", "html", "exportar", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Un archivo `.greport.md` es **Markdown corriente** más unos pocos bloques delimitados \
                ejecutables. Dibujarlo produce un archivo HTML **autocontenido** — sin red, sin archivos \
                acompañantes — que cualquiera puede abrir.
                """),
            .paragraph("""
                Como es texto llano, se puede **comparar, versionar y compartir** — la misma filosofía \
                que las recetas de limpieza y los conjuntos de reglas de calidad.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — un informe completo",
                  source: """
                    ---
                    title: Informe de ventas de agosto
                    source: sales-2026-08.csv
                    ---

                    # Informe de ventas de agosto

                    Cifras a 31 de agosto de 2026.

                    ## Ingresos por provincia

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Ingresos por provincia
                    y_label: Ingresos
                    number_format: vi
                    suffix: " ₫"
                    source: Fuente — sales-2026-08.csv
                    ```

                    ## Calidad de los datos de origen

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Los tipos de bloque"),
            .table(
                headers: ["Bloque", "Produce"],
                rows: [
                    ["`query`", "Una tabla, desde una sentencia SQL de DuckDB"],
                    ["`chart`", "Un gráfico"],
                    ["`quality`", "Una tarjeta de puntuación de calidad de datos"],
                    ["`mining`", "Una tabla de clasificación de minería por grupo"],
                    ["`mermaid`", "Un diagrama"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                El bloque `---` de arriba declara `title` y `source` — la fuente de datos por omisión de \
                todo bloque que no indique la suya.
                """),
            .note("""
                La vista previa se reconstruye cuando deja de escribir, pero **solo analiza**; no ejecuta \
                consultas en cada pulsación. Los errores de documento y los de datos se informan por \
                separado — *«al bloque chart le falta la clave `kind`»* es un error de archivo, *«la \
                columna `doanh_thu` no existe»* es un error de datos.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "El bloque `query`",
        summary: "Una sentencia de DuckDB se convierte en una tabla del informe.",
        keywords: ["consulta", "sql", "tabla", "informe", "bloque"],
        blocks: [
            .paragraph("""
                El contenido del bloque es **una sentencia SQL**, ejecutada sobre la fuente del informe. \
                La tabla se llama `t`, en el mismo dialecto que el panel de consultas.
                """),
            .code(language: "text", caption: "Un bloque query con parámetros",
                  source: """
                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu
                    FROM t
                    WHERE thang = :thang
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    ```
                    """),
            .paragraph("""
                `:thang` es un **parámetro**. Se suministra al dibujar — desde el terminal con `--param \
                thang=8`, o desde un archivo de lista al generar informes en lote.
                """),
            .note("""
                Las tablas de un informe de datos **deberían venir de un bloque query**, no escribirse a \
                mano. Una tabla escrita a mano no se recalcula cuando cambian las cifras y, antes o \
                después, discrepa del resto del informe.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "El bloque `chart`",
        summary: "Una configuración YAML se convierte en un gráfico — y la regla más importante del formato.",
        keywords: ["gráfico", "yaml", "informe", "dibujar"],
        blocks: [
            .code(language: "yaml", caption: "Cada clave de un bloque chart",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Ingresos por provincia
                    x_label: Provincia
                    y_label: Ingresos
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Fuente — sales.csv, a 26 de agosto de 2026
                    """),
            .heading("Sin `query`, usa el resultado del bloque query INMEDIATAMENTE ENCIMA"),
            .paragraph("""
                Esta es la regla más importante del formato. Gracias a ella, el informe habitual de «una \
                tabla y luego un gráfico de esa tabla» no repite el SQL — y repetirlo significa que las \
                dos copias acaban divergiendo, momento en el que la tabla y el gráfico dicen cosas \
                distintas en la misma página.
                """),
            .warning("""
                A cambio, **el orden de los bloques importa**: insertar un bloque query en medio cambia \
                los datos del gráfico de abajo.
                """),
            .heading("Por qué `source` es una clave propia"),
            .paragraph("""
                Una nota de fuente escrita como prosa bajo el gráfico se ve perfectamente — en pantalla. \
                Pero el gráfico se exportará como PNG y se pegará en otro sitio, y la prosa se queda \
                atrás. Como clave, se dibuja **dentro de la imagen** y viaja con ella.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "El bloque `quality`",
        summary: "Una tarjeta de puntuación de calidad de datos dentro del informe.",
        keywords: ["calidad", "tarjeta", "informe", "bloque"],
        blocks: [
            .code(language: "yaml", caption: "Cada clave de un bloque quality",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # vacío significa la fuente propia del informe
                    title: Calidad de los datos de ventas de agosto
                    rules: true                 # mostrar la tabla de reglas aprobadas/suspensas
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # fijar la fecha de referencia de «Vigencia»
                    fail_under: 90              # por debajo, la tarjeta pasa a color de aviso
                    """),
            .table(
                headers: ["`chart`", "Dibuja"],
                rows: [
                    ["`violations`", "El número de filas de las reglas **suspendidas** — responde a «qué arreglar primero»"],
                    ["`dimensions`", "Las notas de las seis dimensiones"],
                    ["`none`", "Solo tabla, sin gráfico"],
                ]
            ),
            .note("""
                Ponga `now:` en un informe periódico. Sin ello, la *Vigencia* se compara con el momento \
                de dibujar, así que volver a dibujar el informe del mes pasado da una nota distinta de la \
                que publicó.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "El bloque `mining`",
        summary: "Clasificar grupos por anomalías, error de previsión o divergencia de correlación.",
        keywords: ["minería", "informe", "clasificación de grupos"],
        blocks: [
            .code(language: "yaml", caption: "Cada clave de un bloque mining",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # la columna para anomalías y previsión
                    pair: chi_phi             # una segunda columna, para la correlación por grupo
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # vacío significa la fuente propia del informe
                    title: Minería por provincia
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Clasifica por"],
                rows: [
                    ["`anomalies`", "El grupo con más filas anómalas"],
                    ["`forecast_error`", "El grupo cuya previsión es peor"],
                    ["`correlation_gap`", "El grupo cuya correlación más se aparta de la tabla agregada — caza la paradoja de Simpson"],
                ]
            ),
            .warning("""
                **Ninguna clave desactiva el bloque «Método».** Una clasificación de grupos sin su método \
                no deja al lector forma alguna de saber contra qué valla se midió «más anomalías». Quien \
                quiere ocultarlo ya conoce la respuesta que desea.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Generar informes en lote",
        summary: "Una plantilla, una lista de parámetros, muchos informes.",
        keywords: ["lote", "masivo", "parámetros", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Una plantilla de informe, ejecutada para cada sucursal o cada mes. La lista de parámetros \
                es un archivo CSV o JSON — **una fila por informe**.
                """),
            .code(language: "text", caption: "list.csv — una fila por informe",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Dibujar todo el lote desde el terminal",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "O un informe con parámetros pasados a mano",
                  source: """
                    geditor --report template.greport.md \\
                            --param thang=8 --param tinh="Hà Nội" \\
                            --out ./reports/
                    """),
            .seeAlso(["khoi-query", "dong-lenh"]),
        ]
    )

    static let mermaid = HelpTopic(
        id: "mermaid",
        title: "Diagramas Mermaid",
        summary: "Dibujar diagramas en texto, editarlos con órdenes, previsualizar sincronizado en ambos sentidos.",
        keywords: ["mermaid", "diagrama", "diagrama de flujo", "secuencia", "dibujar"],
        commands: [
            "Sơ đồ Mermaid: xem trước", "Sơ đồ Mermaid: chèn mẫu…",
            "Sơ đồ Mermaid: thêm phần tử…", "Sơ đồ Mermaid: nối hai phần tử đang chọn",
            "Sơ đồ Mermaid: sửa nhãn phần tử đang chọn…", "Sơ đồ Mermaid: xoá phần tử đang chọn",
            "Sơ đồ Mermaid: đưa message lên trên", "Sơ đồ Mermaid: đưa message xuống dưới",
            "Sơ đồ Mermaid: định dạng lại", "Sơ đồ Mermaid: tách khối ra tệp .mmd…",
            "Sơ đồ Mermaid: nhúng tệp tham chiếu trở lại",
        ],
        blocks: [
            .paragraph("""
                Mermaid dibuja diagramas **a partir de texto**: usted escribe una descripción y la máquina \
                la dibuja. Por eso un diagrama se puede comparar y versionar — algo que un archivo de \
                imagen no puede.
                """),
            .paragraph("""
                Abra `Diagrama Mermaid: vista previa` para tener una vista junto al editor. Ambos están \
                **sincronizados en los dos sentidos**: seleccione un elemento en la imagen y el cursor \
                salta a su línea.
                """),
            .heading("Editar con órdenes, no reescribiendo"),
            .table(
                headers: ["Orden", "Qué hace"],
                rows: [
                    ["Insertar una plantilla…", "Insertar un esqueleto listo para cada tipo de diagrama"],
                    ["Añadir un elemento…", "Añadir un nodo o un participante"],
                    ["Conectar los dos elementos seleccionados", "Dibujar una flecha entre ellos"],
                    ["Editar la etiqueta del elemento seleccionado…", "Cambiar el texto sin buscar la línea"],
                    ["Borrar el elemento seleccionado", "Quitar el nodo **y** cada arista que lo toque"],
                    ["Subir / bajar el mensaje", "Reordenar pasos en un diagrama de secuencia"],
                    ["Reformatear", "Sangrar y alinear todo el bloque"],
                ]
            ),
            .heading("Sacarlo a un archivo y volver a incrustarlo"),
            .paragraph("""
                Los diagramas grandes merecen su propio archivo `.mmd`: `Sacar el bloque a un archivo \
                .mmd…` lo mueve y deja una referencia. `Volver a incrustar el archivo referenciado` hace \
                lo contrario cuando tiene que enviar un único archivo.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Sintaxis habitual de Mermaid",
        summary: "Los cuatro tipos de diagrama más usados, cada uno con una plantilla que funciona.",
        keywords: ["mermaid", "sintaxis", "flujo", "secuencia", "gantt", "clases", "plantilla"],
        blocks: [
            .code(language: "mermaid", caption: "Diagrama de flujo — un proceso de aprobación de pedidos",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Diagrama de secuencia — un flujo de pago",
                  source: """
                    sequenceDiagram
                        participant K as Khách
                        participant W as Website
                        participant T as Cổng thanh toán
                        K->>W: Đặt hàng
                        W->>T: Tạo giao dịch
                        T-->>W: Mã giao dịch
                        W-->>K: Chuyển tới trang thanh toán
                        K->>T: Xác nhận
                        T-->>W: Kết quả
                    """),
            .code(language: "mermaid", caption: "Diagrama de clases — un modelo de datos",
                  source: """
                    classDiagram
                        class DonHang {
                            +String maDon
                            +Date ngayDat
                            +tongTien() Double
                        }
                        class KhachHang {
                            +String ten
                            +String soDienThoai
                        }
                        KhachHang "1" --> "*" DonHang : đặt
                    """),
            .code(language: "mermaid", caption: "Gantt — un plan de publicación",
                  source: """
                    gantt
                        title Kế hoạch phát hành
                        dateFormat YYYY-MM-DD
                        section Chuẩn bị
                        Viết tài liệu     :a1, 2026-09-01, 10d
                        Kiểm thử          :a2, after a1, 7d
                        section Phát hành
                        Nộp App Store     :a3, after a2, 3d
                    """),
            .table(
                headers: ["Forma del nodo", "Escriba"],
                rows: [
                    ["Rectángulo", "`A[Label]`"],
                    ["Redondeado", "`A(Label)`"],
                    ["Estadio", "`A([Label])`"],
                    ["Rombo (decisión)", "`A{Label}`"],
                    ["Cilindro (datos)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Flecha", "Escriba"],
                rows: [
                    ["Sólida, con punta", "`A --> B`"],
                    ["Punteada", "`A -.-> B`"],
                    ["Gruesa", "`A ==> B`"],
                    ["Con etiqueta", "`A -- label --> B`"],
                ]
            ),
            .note("""
                La dirección de un diagrama de flujo va justo después de `flowchart`: `TD` de arriba \
                abajo, `LR` de izquierda a derecha, más `BT` y `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Paquete de conocimiento

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "El paquete de conocimiento",
        summary: "Trocear, índices de búsqueda, grafos de conocimiento, entidades y evaluación de recuperación.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Qué es el paquete de conocimiento",
        summary: "Herramientas para preparar y comprobar datos destinados a un sistema de preguntas y respuestas sobre documentos.",
        keywords: ["rag", "conocimiento", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Al construir un sistema que responde preguntas a partir de un corpus de documentos, la \
                mayor parte del trabajo no está en el modelo sino en **preparar los datos**: cortar los \
                documentos en pasajes sensatos, comprobar la calidad de esos pasajes, construir un \
                índice y **medir si la recuperación encuentra de verdad lo correcto**.
                """),
            .paragraph("""
                Este capítulo es exactamente el instrumental para eso. Funciona **por entero en su \
                máquina** y nunca llama a la red.
                """),
            .table(
                headers: ["Tarea", "Herramienta"],
                rows: [
                    ["Cortar documentos en pasajes", "Vista previa de troceado"],
                    ["Inspeccionar y puntuar pasajes", "Inspección de trozos JSONL"],
                    ["Convertir entre formas de datos", "Conversión de conocimiento"],
                    ["Construir e inspeccionar un grafo de relaciones", "Grafo de conocimiento"],
                    ["Encontrar nombres propios en un texto", "Marcado de entidades"],
                    ["Medir la calidad de la recuperación", "Laboratorio de recuperación"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Trocear e inspeccionar un corpus JSONL",
        summary: "Previsualizar los límites de troceado sobre el propio texto y luego puntuar todo el corpus.",
        keywords: ["chunk", "jsonl", "corpus", "solapamiento", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Vista previa de troceado"),
            .paragraph("""
                Abra un documento de texto o Markdown, elija una estrategia y un tamaño de trozo. Los \
                límites se **resaltan sobre el propio texto**, así que ve dónde cae un corte a mitad de \
                frase o atravesando una tabla antes de exportar nada.
                """),
            .bullets([
                "**Tamaño fijo** con solapamiento.",
                "**Por estructura** — en los títulos de Markdown, manteniendo intacto el hilo del documento.",
                "**Por párrafo**, fundiendo hasta alcanzar el tamaño.",
            ]),
            .heading("Inspeccionar un corpus JSONL existente"),
            .paragraph("""
                Para un corpus que ya tiene (un trozo JSON por línea), `JSONL: inspeccionar trozos…` \
                responde: qué líneas no son JSON válido, qué trozos son demasiado cortos o largos, cuáles \
                se duplican entre sí y cuáles se cortaron a mitad de frase.
                """),
            .note("""
                Un corpus también se puede puntuar con el **mismo marco de seis dimensiones** que los \
                datos tabulares — use la clave `corpus:` en un bloque `quality` de un informe.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Convertir formatos de conocimiento",
        summary: "Trozos entre JSONL · CSV · Markdown, grafos entre DOT · Mermaid · listas de aristas.",
        keywords: ["convertir", "jsonl", "dot", "mermaid", "lista de aristas"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["De", "A"],
                rows: [
                    ["Trozos JSONL", "CSV · Markdown"],
                    ["Trozos CSV", "JSONL · Markdown"],
                    ["Grafo DOT", "Mermaid · lista de aristas"],
                    ["Lista de aristas", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Hay una **vista previa de cinco filas** antes de crear la pestaña nueva, el mismo \
                mecanismo que en la conversión de CSV.
                """),
            .paragraph("""
                `Abrir tripletas/aristas como tabla` muestra un archivo de tripletas o una lista de \
                aristas como tabla — filtre y ordene como en cualquier otro CSV.
                """),
            .note("""
                El sentido **Markdown → JSONL** no está en esta orden: ese sentido *es* el troceado, y la \
                orden le remite allí. Dos implementaciones de un mismo corte producirían dos resultados \
                distintos.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Grafos de conocimiento",
        summary: "Comprobar sintaxis, puntuar salud y ejecutar algoritmos sobre grafos de un millón de aristas.",
        keywords: ["grafo", "dot", "cypher", "pagerank", "louvain", "comprobación de sintaxis"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor lee grafos como **DOT**, como **listas de aristas** y como **tripletas**. \
                `Comprobar sintaxis del grafo` caza errores de sintaxis, nodos colgantes y aristas que \
                apuntan a nodos inexistentes.
                """),
            .heading("Algoritmos disponibles"),
            .table(
                headers: ["Algoritmo", "Responde a"],
                rows: [
                    ["Vecindad a k saltos", "Qué se relaciona con este nodo en k pasos"],
                    ["Componentes conexas", "En cuántas piezas inconexas se parte el grafo"],
                    ["PageRank", "Qué nodos son importantes"],
                    ["Louvain", "Cómo se divide el grafo en comunidades"],
                ]
            ),
            .paragraph("""
                En un grafo de **un millón de aristas**, los cuatro se ejecutan entre unos pocos \
                milisegundos y alrededor de un segundo.
                """),
            .note("""
                Un grafo también se puede puntuar con el **marco de seis dimensiones** usado para tablas \
                y corpus — use la clave `graph:` en un bloque `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Marcar entidades desde una lista",
        summary: "Cargar una lista de nombres propios y encontrar cada aparición — bajo tres reglas pensadas para el vietnamita.",
        keywords: ["entidad", "nombre propio", "ner", "marcado", "coincidencia"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Cargue una lista de nombres (empresas, productos, lugares) y GEditor resalta cada \
                aparición en el documento, con una tabla de recuentos.
                """),
            .heading("Tres reglas de coincidencia, todas nacidas de datos vietnamitas"),
            .bullets([
                "**Gana la coincidencia más larga.** Con `An Phát` y `Công ty An Phát` ambos en la lista, una frase que contenga la expresión larga debe coincidir con la larga — de otro modo se parte en dos y cuenta como dos entidades, lo que **infla** las estadísticas.",
                "**Se exigen límites de palabra.** `An` no debe coincidir dentro de `Anh` ni de `Hoàn`. Los nombres propios vietnamitas son cortos y comparten sílabas con incontables palabras corrientes.",
                "**Insensible a mayúsculas, pero SENSIBLE a las tildes.** `CÔNG TY` y `Công ty` son uno; `má` y `ma` no lo son.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Resolver variantes de entidades",
        summary: "Reconocer `Cty An Phát` y `Công ty An Phát` como una sola — dejándole la decisión igualmente.",
        keywords: ["resolución de entidades", "variantes", "normalización de nombres", "duplicados"],
        blocks: [
            .paragraph("""
                El mismo agrupamiento que los **duplicados aproximados** de una tabla CSV — una \
                implementación compartida, no dos.
                """),
            .paragraph("""
                La salida es una **propuesta**: usted revisa cada conglomerado y elige la forma canónica. \
                No hay botón de fusionar todo, porque dos nombres parecidos al 92 % pueden ser dos \
                organizaciones reales.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "El laboratorio de recuperación",
        summary: "Medir si el índice encuentra lo correcto, usando un conjunto de preguntas con respuestas.",
        keywords: ["recuperación", "bm25", "recall", "mrr", "ndcg", "evaluación"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Cargue un **conjunto de evaluación** — cada línea una pregunta con los identificadores de \
                trozo que deberían devolverse — y luego ejecute todo el lote contra el índice.
                """),
            .table(
                headers: ["Métrica", "Responde a"],
                rows: [
                    ["recall@k", "Cuánto del conjunto de respuestas aparece en los k primeros"],
                    ["MRR", "A qué profundidad está el primer resultado correcto"],
                    ["nDCG@k", "Si la ordenación es buena, contando la posición"],
                ]
            ),
            .paragraph("""
                Los resultados vienen también **por pregunta**, los peores primero — esa es su lista de \
                cosas que arreglar en el corpus, en el orden que más compensa.
                """),
            .warning("""
                Las tres métricas son **medias**, y una media esconde muchísimo. Lea siempre la tabla por \
                pregunta antes de concluir que «el índice ya es bastante bueno».
                """),
            .paragraph("""
                Dos configuraciones se pueden comparar lado a lado, y el resultado cae directamente en un \
                informe `.greport.md` para que la ejecución siguiente sea idéntica.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Macros y automatización

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Macros y automatización",
        summary: "Grabar acciones, ejecutarlas en lote, escribir scripts y manejarlo desde el terminal.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Grabar y reproducir macros",
        summary: "Grabar una secuencia y repetirla — toda la ejecución es un paso de deshacer.",
        keywords: ["macro", "grabar", "reproducir", "repetir", "automatizar"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Empezar / parar la grabación"),
                HelpShortcut("⌃P", "Reproducir"),
            ]),
            .steps([
                "`⌃R` empieza a grabar.",
                "Haga aquello que quiera repetir — escribir, mover el cursor, buscar, reemplazar.",
                "`⌃R` otra vez para parar.",
                "`⌃P` lo reproduce, o `Macro ▸ Reproducir hasta el final del documento` lo ejecuta hasta el final.",
                "`Macro ▸ Guardar macro…` le pone nombre para sesiones posteriores.",
            ]),
            .heading("Graba ÓRDENES, no pulsaciones en bruto"),
            .paragraph("""
                Una macro guarda **lo que hizo**, no qué teclas pulsó. Eso la hace independiente de la \
                distribución del teclado y del método de entrada activo, y hace que el archivo de macro \
                sea **legible** cuando lo abre.
                """),
            .heading("Cuándo se detiene una macro"),
            .table(
                headers: ["Motivo", "Significado"],
                rows: [
                    ["Se agotó el número de repeticiones", "Normal"],
                    ["Un paso `find` no encontró nada", "Así es como «reproducir hasta el final del archivo» se detiene sola"],
                    ["Se llegó al final del documento", "No hay adónde seguir"],
                    ["Usted canceló", "`Macro ▸ Cancelar la macro en marcha`"],
                    ["Una iteración no cambió ni movió nada", "Se detiene para que no dé vueltas sin fin"],
                ]
            ),
            .note("Toda la ejecución — aunque sean diez mil repeticiones — es **un** paso de deshacer."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Ejecutar una macro en lote",
        summary: "Sobre todas las pestañas abiertas, o sobre una carpeta de archivos sin abrir.",
        keywords: ["lote", "todas las pestañas", "carpeta", "macro", "máscara"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Orden", "Alcance", "Deshacible"],
                rows: [
                    ["Ejecutar en todas las pestañas", "Las pestañas abiertas", "Sí — un paso de deshacer por pestaña"],
                    ["Ejecutar sobre una carpeta…", "Archivos del disco **sin abrir**", "No"],
                ]
            ),
            .warning("""
                Ejecutar sobre una carpeta toca archivos que no están abiertos en ninguna pestaña, así \
                que **no hay deshacer**. Por omisión GEditor **escribe archivos nuevos** en vez de \
                sobrescribir los originales. Mantenga ese valor salvo que tenga copia de seguridad o un \
                repositorio versionado.
                """),
            .heading("Filtrar archivos con una máscara"),
            .paragraph("""
                El selector de carpeta tiene un **filtro de nombre de archivo**: escriba `*.csv;*.log` y \
                la macro solo toca esos. Es la misma sintaxis de máscara que usa `Buscar en una carpeta`, \
                con varios patrones separados por `;` o `,`.
                """),
            .bullets([
                "Déjelo **vacío** y toma todo archivo de texto que GEditor sepa leer — el comportamiento anterior.",
                "La máscara **sustituye** esa lista de extensiones en vez de estrecharla aún más: escriba `*.bak` y se ejecuta sobre archivos `.bak`, aunque esa extensión no esté en la lista de texto.",
                "Si nada coincide, el mensaje **le repite la máscara** en vez de culpar a una carpeta vacía.",
            ]),
            .paragraph("""
                Esta casilla tiene una razón muy práctica: una carpeta tiene 400 archivos `.json` y 12 \
                `.log`, y su macro solo ordena registros. Sin máscara, los otros 400 también se procesan \
                — y como el lote escribe archivos nuevos, un error deja 400 piezas de basura.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Sintaxis del archivo de macro",
        summary: "Siete tipos de paso, el formato JSON completo y dos macros que funcionan.",
        keywords: ["macro", "json", "sintaxis", "formato", "editar a mano", "compartir"],
        blocks: [
            .paragraph("""
                Cada macro es **su propio archivo JSON** en la carpeta `macros/` de GEditor. Un daño \
                queda confinado a una macro, y compartir una con un compañero es enviar un archivo.
                """),
            .code(language: "text", caption: "Dónde viven los archivos",
                  source: "~/Library/Application Support/GEditor/macros/<nombre-de-macro>.json"),
            .heading("Los siete tipos de paso"),
            .table(
                headers: ["Paso", "Se escribe", "Significado"],
                rows: [
                    ["Insertar texto", "`{\"insert\": {\"_0\": \"texto\"}}`", "Escribir en el cursor; con selección, la sustituye"],
                    ["Borrar hacia atrás", "`{\"deleteBackward\": {}}`", "Como la tecla Suprimir"],
                    ["Borrar hacia delante", "`{\"deleteForward\": {}}`", "Como ⌦"],
                    ["Mover", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Vea la lista de direcciones de abajo"],
                    ["Seleccionar la línea", "`{\"selectLine\": {}}`", "Sin el salto de línea"],
                    ["Buscar", "`{\"find\": { … }}`", "Encuentra y **selecciona** la siguiente coincidencia"],
                    ["Reemplazar la selección", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` sirve si el paso anterior fue un `find` con regex"],
                ]
            ),
            .heading("Direcciones de movimiento"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("El paso `find` completo"),
            .code(language: "json", caption: "Las cuatro claves de un paso find",
                  source: """
                    {
                      "find": {
                        "pattern": "^([a-z]{2})\\\\t",
                        "mode": "regex",
                        "matchCase": false,
                        "wholeWord": false
                      }
                    }
                    """),
            .paragraph("`mode` admite `normal`, `extended` o `regex` — los mismos tres modos que el campo de búsqueda."),
            .heading("Ejemplo 1 — poner en mayúsculas el código de provincia al inicio de cada línea"),
            .code(language: "json", caption: "macros/uppercase-province.json",
                  source: """
                    {
                      "name": "Uppercase province code",
                      "steps": [
                        {
                          "find": {
                            "pattern": "^([a-z]{2,3})\\\\t",
                            "mode": "regex",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "replaceSelection": { "_0": "\\\\U$1\\\\E\\t" } }
                      ]
                    }
                    """),
            .paragraph("""
                Ejecútela con `Macro ▸ Reproducir hasta el final del documento`: que el paso `find` no \
                encuentre nada más es exactamente la condición de parada.
                """),
            .heading("Ejemplo 2 — borrar la línea siguiente a cada línea que contenga TODO"),
            .code(language: "json", caption: "macros/delete-line-after-todo.json",
                  source: """
                    {
                      "name": "Delete line after TODO",
                      "steps": [
                        {
                          "find": {
                            "pattern": "TODO",
                            "mode": "normal",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "move": { "_0": "nextLine" } },
                        { "move": { "_0": "lineStart" } },
                        { "selectLine": {} },
                        { "deleteForward": {} },
                        { "deleteForward": {} }
                      ]
                    }
                    """),
            .warning("""
                Pruebe primero en una copia una macro editada a mano. Un paso `find` mal escrito hace que \
                la macro se detenga al momento — ese es el caso benigno. El maligno es un patrón que \
                coincide más ampliamente de lo que creía, editando miles de sitios dentro de un solo paso \
                de deshacer.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "Scripts de JavaScript",
        summary: "Cuatro funciones, un archivo `.js`, y todo lo que hace es un paso de deshacer.",
        keywords: ["script", "javascript", "js", "automatizar", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Ponga un archivo `.js` en la carpeta `scripts/` de GEditor y ejecútelo desde `Macro ▸ \
                Script…`. Un script ve exactamente **cuatro** cosas:
                """),
            .table(
                headers: ["Llamada", "Significado"],
                rows: [
                    ["`doc.text`", "Todo el texto del documento"],
                    ["`doc.selection`", "La selección (cadena vacía si no hay nada seleccionado)"],
                    ["`doc.replace(s)`", "Sustituir el **documento entero** por `s` — un paso de deshacer"],
                    ["`doc.log(s)`", "Escribir una línea en el panel de resultados"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Numerar cada línea.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — conservar las tres primeras columnas CSV",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Tres límites que conviene saber"),
            .bullets([
                "**Sin acceso a archivos, sin red, sin lanzar procesos.** La superficie de API es deliberadamente estrecha: ampliarla después es fácil, estrecharla rompe todos los scripts ya escritos.",
                "**Esto no es una frontera de seguridad.** Los scripts corren en el mismo proceso. No ejecute un script que no haya leído.",
                "**Hay un límite de cinco segundos.** Pasado ese punto recibe un mensaje y la aplicación sigue usable — pero el hilo de ese script **sigue girando hasta que salga**, comiéndose un núcleo. El mensaje lo dice.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtrar con una orden externa",
        summary: "Pasar la selección por una orden de Unix y recuperar el resultado.",
        keywords: ["filtro", "orden externa", "shell", "tubería", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                La selección (o todo el documento) se envía al `stdin` de una orden, y el `stdout` de esa \
                orden la sustituye.
                """),
            .code(language: "bash", caption: "Unas cuantas habituales",
                  source: """
                    sort -u                     # ordenar y quitar duplicados
                    jq .                        # reformatear JSON
                    tr 'a-z' 'A-Z'              # a mayúsculas
                    grep -v '^#'                # quitar las líneas de comentario
                    awk -F, '{print $3","$1}'   # intercambiar el orden de columnas
                    """),
            .note("""
                El resultado es **un** paso de deshacer. Si la orden devuelve un código de error, GEditor \
                deja el texto en paz y muestra `stderr`.
                """),
            .warning("""
                Esta orden existe **solo en la versión de descarga directa**. El App Sandbox prohíbe \
                ejecutar código fuera de la aplicación, así que en la versión App Store el elemento de \
                menú se queda y explica por qué no está disponible.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "La herramienta de línea de órdenes `geditor`",
        summary: "Abrir, limpiar, consultar, puntuar y dibujar informes — sin abrir la aplicación.",
        keywords: ["cli", "línea de órdenes", "terminal", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Disponible solo en la **versión de descarga directa**. La versión App Store corre en un \
                sandbox, así que un proceso externo de línea de órdenes no puede conectarse a ella.
                """),
            .heading("Abrir archivos"),
            .code(language: "bash", caption: "Abrir, saltar a una posición, leer de una tubería",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # línea 120, columna 5
                    geditor -w notes.md            # esperar a que se cierre el archivo antes de salir
                    geditor -r app.log             # abrir de solo lectura
                    git diff | geditor             # leer la entrada estándar en una pestaña nueva
                    """),
            .table(
                headers: ["Opción", "Significado"],
                rows: [
                    ["`-w`, `--wait`", "Esperar a que se cierre el archivo antes de salir — para usarlo como editor de `git`"],
                    ["`-n`, `--new-window`", "Abrir en una ventana nueva"],
                    ["`-r`, `--read-only`", "Abrir de solo lectura"],
                    ["`-i`, `--info`", "Imprimir codificación, finales de línea y número de líneas, y salir — **sin** abrir la aplicación"],
                    ["`-h`, `--help`", "Mostrar la ayuda"],
                    ["`-v`, `--version`", "Mostrar la versión"],
                ]
            ),
            .heading("Ejecutar sin abrir la aplicación"),
            .paragraph("""
                Los cuatro grupos de órdenes de abajo corren **por entero en el proceso de línea de \
                órdenes**, así que funcionan en CI, donde nadie ha iniciado una sesión gráfica.
                """),
            .code(language: "bash", caption: "Limpiar con una receta",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Consultar",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "La puerta de calidad — código 0 aprobado · 1 suspenso · 2 error",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Dibujar informes",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript y el menú Servicios",
        summary: "Leer y escribir el documento desde AppleScript, o enviar texto a GEditor desde otra aplicación.",
        keywords: ["applescript", "osascript", "servicios", "automatización", "atajos"],
        blocks: [
            .code(language: "applescript", caption: "Leer el documento abierto",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Sobrescribir el contenido y leer la selección",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Abrir un archivo",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("El menú Servicios"),
            .paragraph("""
                Seleccione texto en cualquier aplicación y use el menú `Servicios` para enviarlo a \
                GEditor como pestaña nueva.
                """),
            .note("""
                La primera vez que ejecute AppleScript, macOS pide permiso de automatización. Ese es el \
                diálogo del sistema, no de GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Paquetes de extensión y complementos",
        summary: "Dos clases de extensión, y en qué versión corre cada una.",
        keywords: ["complemento", "extensión", "paquete", "nativo"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Paquetes de extensión"),
            .paragraph("""
                Un paquete es **un archivo JSON** que agrupa un tema, scripts y lenguajes definidos por el \
                usuario. Instalar copia un archivo, quitar borra uno — y la lista de paquetes se deriva \
                del **disco**, no de un registro que pudiera mentir.
                """),
            .paragraph("Funciona en **ambas versiones**."),
            .heading("Complementos nativos"),
            .paragraph("""
                Los complementos precompilados corren en un **proceso aparte** con una superficie de API \
                estrecha — un complemento que se cae no se lleva la aplicación con él.
                """),
            .warning("""
                Los complementos nativos existen **solo en la versión de descarga directa**, porque el \
                App Sandbox prohíbe cargar código de fuera de la aplicación. Cada complemento debe \
                **aprobarse a mano una vez**, por su hash, antes de ejecutarse.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Configuración y la aplicación

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Configuración y la aplicación",
        summary: "Ajustes, atajos, temas, actualizaciones, migrar desde Notepad++, resolución de problemas.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Ajustes",
        summary: "Cada opción vive en un archivo JSON legible que puede copiar a otro Mac.",
        keywords: ["ajustes", "preferencias", "opciones", "configuración", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Abrir los ajustes")]),
            .paragraph("""
                No hay Aceptar ni Cancelar — un cambio surte efecto y se escribe al instante, al estilo \
                de macOS.
                """),
            .heading("El archivo de configuración"),
            .code(language: "text", caption: "Dónde vive",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Es un **archivo JSON sangrado que puede leer y editar a mano**. Cópielo a otro Mac y toda \
                su configuración se va con él. El botón `Abrir el archivo de configuración` de los \
                ajustes le lleva directo allí.
                """),
            .heading("Las claves"),
            .table(
                headers: ["Clave", "Por omisión", "Significado"],
                rows: [
                    ["`fontSize`", "`13`", "Tamaño de letra del editor"],
                    ["`tabWidth`", "`4`", "Cuántas columnas de ancho tiene un tabulador"],
                    ["`usesTabsForIndent`", "`false`", "Sangrar con tabuladores en vez de espacios"],
                    ["`languageIndent`", "`{}`", "Sangría por lenguaje — vea la página de espacios"],
                    ["`smartIndent`", "`true`", "Sangría automática en una línea nueva"],
                    ["`highlightAllMatches`", "`true`", "Resaltar cada coincidencia de búsqueda"],
                    ["`ligatures`", "`false`", "Ligaduras — vea la nota bajo la tabla"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Recortar espacios finales al guardar"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalizar Unicode a NFC al guardar"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Codificación de los archivos nuevos"],
                    ["`defaultEOL`", "`\"lf\"`", "Finales de línea de los archivos nuevos"],
                    ["`language`", "`\"system\"`", "Idioma de la interfaz"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "el tema por omisión", "Qué tema de color está en uso"],
                    ["`showWelcomeOnLaunch`", "`true`", "Abrir la ventana de bienvenida al arrancar"],
                    ["`keyBindings`", "`{}`", "Solo las teclas que usted cambió"],
                ]
            ),
            .note("""
                **Por qué las ligaduras vienen DESACTIVADAS.** Una ligadura funde `!=` o `->` en **un \
                solo** glifo, así que los caracteres que ve en pantalla ya no se corresponden con los del \
                archivo — y el editor de columnas, el modo columna y el ajuste por columna miden todos en \
                columnas. Actívelas para escribir prosa, o si eligió una tipografía de programación (Fira \
                Code, JetBrains Mono) precisamente por sus ligaduras.
                """),
            .heading("Las carpetas vecinas"),
            .table(
                headers: ["Carpeta", "Contiene"],
                rows: [
                    ["`macros/`", "Macros guardadas, un archivo JSON cada una"],
                    ["`scripts/`", "Scripts de JavaScript"],
                    ["`themes/`", "Temas de color"],
                    ["`grammars/`", "Lenguajes definidos por el usuario"],
                ]
            ),
            .warning("""
                Un archivo de configuración escrito por un GEditor **más nuevo no lo sobrescribe** uno \
                más antiguo — este corre con los valores por omisión y lo dice. Sobrescribir es el modo \
                más seguro de destruir la configuración de alguien que sincroniza dos máquinas, y nunca \
                sabría por qué.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "La barra de estado",
        summary: "Diez segmentos abajo — todos legibles y todos pulsables.",
        keywords: ["barra de estado", "posición", "codificación", "solo lectura", "tamaño"],
        blocks: [
            .paragraph("""
                Esta es la mayor diferencia respecto a las barras de estado de otros editores: **ningún \
                segmento es de solo lectura**. Si ve un valor equivocado, pulsarlo es la forma de \
                arreglarlo, en vez de rebuscar por los menús.
                """),
            .table(
                headers: ["Segmento", "Le dice", "Al pulsarlo"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "posición del cursor — columna en CARACTERES, `@340` la posición en bytes",
                     "abre el campo `Ir a`"],
                    ["`11 byte · 3 dòng`", "tamaño del documento",
                     "cuenta bytes · caracteres · palabras · líneas"],
                    ["`🔒 Chỉ đọc`", "se muestra solo cuando el documento está bloqueado",
                     "dice POR QUÉ está bloqueado, y lo desbloquea cuando es posible"],
                    ["`View` / `Code`", "en qué vista está", "alterna (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "modo CSV y separador en uso",
                     "conmuta el modo CSV, o **vuelve a elegir el separador**"],
                    ["`Đang theo dõi`", "`tail -f` está en marcha", "—"],
                    ["`UTF-8`", "la codificación", "reinterpretar, o convertir a otra codificación"],
                    ["`LF`", "estilo de final de línea", "alternar LF · CRLF · CR"],
                    ["`Python`", "lenguaje del coloreado de sintaxis", "elegir otro, o volver a la detección por extensión"],
                    ["`Tab: 4`", "anchura de sangría", "2 · 4 · 8, global o **solo para este lenguaje**"],
                    ["`Ngắt: tắt`", "modo de ajuste de línea", "recorre los tres modos"],
                ]
            ),
            .heading("Tres segmentos que merecen una segunda mirada"),
            .bullets([
                "**`@340` — la posición en bytes.** Es el número que habla cualquier otra herramienta del producto: los errores de JSON y XML, la salida de `--doc-sweep`, el visor binario y el campo `Ir a @340`. Léalo aquí, escríbalo allí.",
                "**Una `~` en la columna** significa que el número cuenta BYTES y no columnas visuales — solo ocurre en líneas de más de 200 KB, donde contar caracteres ralentizaría cada movimiento del cursor.",
                "**`CSV · …` se pulsa para volver a elegir el separador.** La detección puede fallar, y cuando falla toda operación de columnas queda descuadrada sin nada que lo señale. Así se dice lo contrario — solo VUELVE A LEER el archivo, sin cambiar un byte (a diferencia de `CSV ▸ Cambiar separador…`, que lo reescribe).",
            ]),
            .note("""
                Un segmento que no aplica al archivo abierto está **oculto**, no atenuado: `Solo lectura` \
                aparece solo cuando el documento está bloqueado de verdad, y `CSV · …` solo en modo CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Cambiar los atajos de teclado",
        summary: "Cambiar teclas sueltas, o adoptar de golpe el mapa de Notepad++.",
        keywords: ["atajo", "mapa de teclas", "preajuste"],
        blocks: [
            .paragraph("""
                `Ajustes…` tiene una sección de Atajos con dos botones rápidos: **Usar el preajuste de \
                Notepad++** y **Volver a los valores por omisión**.
                """),
            .paragraph("""
                El archivo de configuración registra solo lo que usted **cambió respecto de los valores \
                por omisión**. Así, cuando GEditor cambie una tecla por omisión en una versión nueva, no \
                se quedará atascado en el mapa antiguo sin que nadie se lo diga.
                """),
            .note("""
                Dos órdenes no pueden compartir un atajo. Cuando lo hacen, AppKit dispara en silencio \
                solo el **primer** elemento de menú y la otra orden parece rota — por eso GEditor tiene \
                una comprobación que lo impide.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Temas, claro y oscuro",
        summary: "Seguir al sistema, claro u oscuro; y un tema es un archivo JSON que puede editar.",
        keywords: ["tema", "colores", "modo oscuro", "claro", "apariencia"],
        blocks: [
            .paragraph("`Ajustes…` elige `Seguir al sistema`, `Claro` u `Oscuro`, y selecciona un tema de color."),
            .paragraph("""
                Un tema es un archivo JSON en `themes/`. El botón `Exportar el tema actual` escribe uno \
                como punto de partida para el suyo.
                """),
            .note("""
                Un color mal escrito en un archivo de tema recae en el color del **tema por omisión**, no \
                en el negro. El negro parece una decisión de diseño, y el usuario iría a buscar el \
                problema a otra parte.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Actualizaciones, versiones y salir",
        summary: "En qué se diferencia la actualización entre las dos versiones.",
        keywords: ["actualización", "versión", "acerca de", "salir"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Versión", "Se actualiza por"],
                rows: [
                    ["App Store", "El App Store, como cualquier otra app"],
                    ["Descarga directa", "`Buscar actualizaciones…` dentro de la aplicación"],
                ]
            ),
            .paragraph("""
                `Acerca de GEditor` muestra la versión en marcha y de qué versión se trata — útil al \
                informar de un problema.
                """),
            .note("""
                En la versión App Store, `Buscar actualizaciones…` **se queda en el menú** y explica por \
                qué no aplica, en vez de desaparecer. Un elemento de menú que falta se convierte en una \
                consulta al soporte.
                """),
            .paragraph("Salir no pierde trabajo: la sesión vuelve la próxima vez que abra."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Usar esta ventana de ayuda",
        summary: "Buscar en el libro, cambiar su idioma y recuperar la ventana de bienvenida.",
        keywords: ["ayuda", "guía", "búsqueda", "bienvenida", "idioma"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Abrir la ventana de ayuda")]),
            .bullets([
                "El campo de búsqueda de arriba a la izquierda mira dentro del **texto y los ejemplos de código** — escribir una clave de configuración como `fail_under` lleva a la página correcta.",
                "Escribir **sin tildes** encuentra igualmente texto acentuado.",
                "El botón `Atrás` vuelve a la página anterior.",
                "El botón `Copiar` de cada bloque de código copia ese bloque.",
            ]),
            .heading("Leer en otro idioma"),
            .paragraph("""
                El menú emergente de arriba a la derecha de esta ventana elige el **idioma del libro**, \
                con independencia del idioma de la interfaz. El cambio le mantiene **en la página que \
                está leyendo** — los identificadores de página no se traducen a propósito, justo para que \
                esto funcione.
                """),
            .note("""
                Solo se listan los idiomas que de verdad tienen libro. Un elemento de menú que cambia a \
                algo y deja el texto igual sería un elemento de menú que miente.
                """),
            .heading("Recuperar la ventana de bienvenida"),
            .paragraph("""
                Si marcó **No abrir esta ventana al arrancar**, vuelva a abrirla con `Ayuda ▸ Recorrido \
                por las funciones` — la casilla al pie de la ventana reaparece y se puede desmarcar.
                """),
            .paragraph("O vuelva a poner `showWelcomeOnLaunch` en `true` dentro de `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "De Notepad++ a GEditor",
        summary: "Qué teclas intercambian su sitio, qué funciona distinto y qué falta.",
        keywords: ["notepad++", "migración", "windows", "atajos"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Unas cuantas teclas **intercambian su sitio** en macOS en vez de simplemente convertir \
                `Ctrl` en `⌘`. Aquí está la comparación.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Por qué"],
                rows: [
                    ["`Ctrl+D` Duplicar línea", "**⇧⌘D**", "Aquí `⌘D` es el multicursor, como en todo editor de Mac"],
                    ["`Ctrl+L` Borrar línea", "**⌘K**", "En macOS `⌘L` significa «ir a la línea»"],
                    ["`Ctrl+G` Ir a la línea", "**⌘L**", "Estos dos intercambian su sitio"],
                    ["`Ctrl+Q` Comentar", "**⌘/**", "Convención de macOS"],
                    ["`Ctrl+Shift+↑/↓` Mover línea", "**⌥↑ / ⌥↓**", "En macOS `⌃` pertenece a Mission Control"],
                    ["`F3` Buscar siguiente", "**⌘G**", "Convención de macOS"],
                    ["`Ctrl+F2` Alternar marcador", "**⌘F2**", "F2 y ⇧F2 siguen saltando entre marcas"],
                    ["`Alt` + arrastrar para columnas", "**⌥ + arrastrar**", "Idéntico"],
                    ["`Ctrl+Alt+Shift+↓` Editor de columnas", "**⌥⌘C**", "Convención de macOS"],
                ]
            ),
            .note("¿Prefiere no reaprender? `Ajustes ▸ Atajos ▸ Usar el preajuste de Notepad++`."),
            .heading("Cosas que Notepad++ tiene y aquí funcionan distinto"),
            .bullets([
                "**Las sesiones** se restauran solas, incluidas las pestañas sin guardar — nada que activar.",
                "**Los marcadores tienen nueve colores**, y una línea puede llevar varios a la vez.",
                "**El mapa del documento** describe *todo* el archivo, no solo la parte visible.",
                "**Las macros** pueden reproducirse «hasta el final del documento» y «en todas las pestañas», y toda una ejecución es un paso de deshacer.",
            ]),
            .heading("Lo que GEditor añade"),
            .bullets([
                "Un **banco de limpieza de datos** y **perfiles de datos** para archivos CSV.",
                "**Consultas SQL** directamente sobre un archivo CSV.",
                "**Codificaciones vietnamitas antiguas** — TCVN3, VISCII, VNI-Windows, leídas, escritas y detectadas automáticamente.",
                "**Búsqueda insensible a tildes** en cada campo de filtro.",
                "**Informes `.greport.md`** con tablas y gráficos que se recalculan.",
                "La **herramienta de línea de órdenes `geditor`** en la versión de descarga directa.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Problemas comunes",
        summary: "Seis situaciones que hacen pensar que la aplicación está rota.",
        keywords: ["error", "problema", "no funciona", "resolver", "por qué"],
        blocks: [
            .table(
                headers: ["Síntoma", "Causa habitual"],
                rows: [
                    ["El texto vietnamita se ve como basura", "Codificación equivocada — pulse la codificación en la barra de estado"],
                    ["Buscar texto acentuado no encuentra nada", "El archivo está en Unicode descompuesto — ejecute `Normalizar Unicode` a NFC"],
                    ["Un elemento de menú está atenuado", "La versión App Store no puede ejecutar esa orden — el elemento explica por qué"],
                    ["El emparejado de paréntesis se niega", "El documento pasa de 1 MB — resaltar el par equivocado es peor que ninguno"],
                    ["La columna de la barra de estado lleva `~`", "El documento pasa de 200 KB, así que es un recuento de bytes, no una columna visual"],
                    ["Una consulta SQL dice que hay que guardar primero", "DuckDB lee **archivos**, no el búfer que está editando"],
                ]
            ),
            .heading("Cuando GEditor se cierra inesperadamente"),
            .paragraph("""
                En el arranque siguiente un aviso lo dice, con un botón **Abrir informe** — el informe se \
                abre como pestaña que puede leer y de la que puede copiar como de cualquier archivo de \
                texto.
                """),
            .bullets([
                "El informe lleva solo la **versión, la versión de macOS, la arquitectura de la máquina, el nombre de la señal y la pila de llamadas**.",
                "**Ningún contenido del documento, y tampoco rutas de archivo** — una ruta como `~/Escritorio/nóminas-diciembre.xlsx` ya ha revelado tres cosas privadas antes de que nadie la abra.",
                "**No se envía nada a ninguna parte.** No hay subida automática ni servidor que la reciba; el archivo se queda en `~/Library/Application Support/GEditor/crash/` hasta que usted lo abra o lo borre.",
                "Una vez que ha abierto el informe, el arranque siguiente no vuelve a mencionarlo.",
            ]),
            .heading("Dónde mirar después"),
            .bullets([
                "La barra de estado muestra codificación, finales de línea, lenguaje y modo de ajuste — cada segmento es pulsable.",
                "`settings.json` se puede editar a mano cuando la ventana de ajustes no basta.",
                "`Acerca de GEditor` da la versión y la variante, que un informe de fallo necesita.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
