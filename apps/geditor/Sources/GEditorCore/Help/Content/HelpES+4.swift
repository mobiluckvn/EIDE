import Foundation

/// Contenido de ayuda en español — parte 4: datos tabulares, limpieza y minería.
extension HelpES {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Datos tabulares",
        summary: "Ver CSV como tabla, filtrar, ordenar, comprobar estructura, consultar con SQL, convertir.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Ver un CSV como tabla",
        summary: "Un millón de filas sigue desplazándose con fluidez, la cabecera no se mueve y el texto fuente queda intacto.",
        keywords: ["csv", "tabla", "cuadrícula", "tsv", "excel", "columnas"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Alternar entre tabla y texto")]),
            .paragraph("""
                La tabla está **virtualizada**: solo se construyen las filas visibles, así que un \
                archivo de un millón de filas se desplaza como uno de cien.
                """),
            .bullets([
                "**La fila de cabecera se queda fija** al desplazarse — en la fila 40 000 todavía sabe qué es la novena columna.",
                "Edite una celda en la tabla; el cambio va directo al texto fuente.",
                "Tabla y texto son **dos miradas a un archivo**, no dos copias.",
                "**⌘C copia la fila seleccionada**, con celdas separadas por tabuladores — péguela directamente en Excel o Numbers y cada celda cae donde debe. Las celdas con tabuladores o saltos de línea se entrecomillan, para que el destino no las parta en dos.",
            ]),
            .note("""
                El separador se detecta al abrir (coma, punto y coma, tabulador, barra vertical). Si la \
                suposición es errónea, cámbielo con `CSV ▸ Cambiar separador…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Libros con varias hojas",
        summary: "Abrir cualquier hoja de un .xlsx, y ⌘S escribe de vuelta en la hoja que está viendo.",
        keywords: ["excel", "xlsx", "hoja", "libro"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Abra un `.xlsx` y GEditor muestra la **primera hoja** como tabla CSV. `CSV ▸ Elegir \
                hoja…` lista cada hoja del archivo y abre la que elija en la misma pestaña.
                """),
            .heading("Escribir de vuelta en la hoja CORRECTA"),
            .paragraph("""
                `⌘S` escribe sus cambios en **la hoja que está viendo**, no en la primera. Las demás \
                hojas no se tocan ni en un byte.
                """),
            .note("""
                La hoja se recuerda por **nombre**, no por posición. Así, reordenar las hojas en Excel \
                entre dos sesiones no desvía la escritura.
                """),
            .warning("""
                Si la hoja abierta ha sido **renombrada o borrada** en Excel desde que la abrió, `⌘S` \
                **se niega a escribir** y lo dice. Recurrir a la primera hoja equivaldría a verter el \
                contenido de una hoja sobre otra — el archivo se guardaría igual, se volvería a abrir \
                igual, y simplemente tendría los datos en el sitio equivocado.
                """),
            .heading("Cambiar de hoja con cambios sin guardar"),
            .paragraph("""
                Cambiar de hoja sustituye todo el contenido de la pestaña, así que si hay algo sin \
                guardar GEditor **pregunta antes**. `⌘Z` no puede recuperarlo, porque se intercambió el \
                documento entero.
                """),
            .heading("Qué cuesta reducir Excel a una tabla"),
            .paragraph("""
                Lo que sobrevive son los **valores** — incluidos los resultados de fórmulas, justo los \
                números que Excel muestra. Lo que no: tipografías, colores, celdas combinadas, gráficos \
                incrustados y las fórmulas mismas.
                """),
            .paragraph("""
                A cambio, esa hoja gana todo el resto del producto: filtrado, ordenación, consultas SQL, \
                el banco de limpieza, la puntuación de calidad, la minería, los gráficos.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtrar y ordenar en la tabla",
        summary: "Un campo de filtro por columna, que entiende comparación numérica y escritura sin tildes.",
        keywords: ["filtro", "ordenar", "columna", "buscar en la tabla"],
        blocks: [
            .paragraph("Pulse una cabecera de columna para ordenar. El campo de filtro de debajo acepta:"),
            .table(
                headers: ["Escriba en el filtro", "Significado"],
                rows: [
                    ["`hue`", "Contiene `hue`, **insensible a tildes** — también encuentra `Huế`"],
                    ["`=Huế`", "Exactamente `Huế` (sigue siendo insensible a tildes)"],
                    ["`>100`", "Mayor que 100"],
                    ["`>=100`", "100 o más"],
                    ["`<0`", "Menor que 0"],
                    ["`100..200`", "Entre 100 y 200"],
                    ["vacío", "Sin filtro en esta columna"],
                ]
            ),
            .paragraph("""
                Filtrar varias columnas es una **y**: una fila debe satisfacerlas todas. La comparación \
                numérica salta las celdas no numéricas en vez de tratarlas como cero.
                """),
            .note("""
                Filtrar es una **forma de mirar**, no un borrado. Limpie el filtro y vuelven todas las \
                filas.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Comprobar la estructura de la tabla",
        summary: "Encontrar filas con el número de columnas equivocado y celdas del tipo equivocado — esto primero.",
        keywords: ["validar", "comprobar", "número de columnas", "tipo erróneo", "datos rotos"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Esto es lo que hay que ejecutar **antes** que nada en un archivo que le han enviado. \
                Responde a dos preguntas:
                """),
            .bullets([
                "**¿Qué filas tienen el número de columnas equivocado?** Normalmente una celda con una coma sin entrecomillar — y descuadra todas las filas siguientes.",
                "**¿Qué celdas tienen un tipo distinto al del resto de su columna?** Por ejemplo un `n/a` en una columna de números.",
            ]),
            .paragraph("Los resultados aparecen como lista; pulse uno para saltar a esa fila."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Borrar columnas",
        summary: "Quitar del archivo una o varias columnas por completo.",
        keywords: ["borrar columna", "quitar columna"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Elija de la lista las columnas que descartar y aplique. Es **un** paso de deshacer, por \
                muchas filas que tenga el archivo.
                """),
            .warning("""
                A diferencia de filtrar, esto **edita el archivo de verdad**. Para solo ocultar \
                columnas, use una consulta SQL que liste las que quiere.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Consultar CSV con SQL",
        summary: "El SQL completo de DuckDB, ejecutado directamente sobre el archivo abierto — solo lectura.",
        keywords: ["sql", "consulta", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                La tabla abierta se llama **`t`**. El motor es **DuckDB**, así que `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, las funciones de ventana y las subconsultas funcionan \
                todas.
                """),
            .code(language: "sql", caption: "Ingresos por provincia, de mayor a menor",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filtrar por fecha y por una condición de texto",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "La cuota de cada provincia sobre el total — con una función de ventana",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Unir con otro archivo del disco",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Solo lectura, y es una garantía firme"),
            .bullets([
                "La base de datos vive **en memoria**; el archivo fuente solo se lee.",
                "Se acepta exactamente **una sentencia**, y **debe ser un `SELECT`**. Todo lo demás — incluido `COPY … TO 'archivo'`, que DuckDB puede usar perfectamente para escribir en disco — se bloquea antes de llegar a dato alguno.",
            ]),
            .warning("""
                DuckDB lee **archivos**, no memoria. Si el documento tiene cambios sin guardar, GEditor \
                debe escribir una copia temporal antes de consultar. Con un archivo muy grande y \
                cambios sin guardar, **se detiene y lo dice** en vez de escribir en silencio cientos de \
                megabytes en disco para una sola consulta.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Tablas dinámicas y gráficos rápidos",
        summary: "Pivotar y dibujar directamente desde un resultado de consulta.",
        keywords: ["tabla dinámica", "gráfico", "tabla cruzada", "agregado"],
        blocks: [
            .paragraph("""
                Ambos se abren desde la **tabla de resultados**: ejecute una sentencia SQL y luego use el \
                botón Dinámica o Gráfico del panel.
                """),
            .heading("Tabla dinámica"),
            .paragraph("""
                Elija la columna de **filas**, la de **columnas**, la de **valores** y el agregado \
                (suma, cuenta, media, mín., máx.) — como la tabla dinámica de una hoja de cálculo.
                """),
            .heading("Gráficos"),
            .paragraph("""
                Barras, líneas, sectores, dispersión. Números con formato vietnamita o europeo, y el \
                gráfico se exporta como PNG o SVG para pegarlo en otro sitio.
                """),
            .note("""
                ¿Quiere un gráfico que **se actualice con los datos** en cada reconstrucción? Ese es el \
                bloque `chart` de un informe `.greport.md`.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Convertir una tabla a otro formato",
        summary: "TSV, JSON, XML, tablas Markdown, sentencias SQL INSERT — con vista previa.",
        keywords: ["convertir", "exportar", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Formato", "Útil para"],
                rows: [
                    ["TSV", "Pegar en una hoja de cálculo sin preocuparse por las comas de las celdas"],
                    ["JSON", "Alimentar una API, un script u otra herramienta"],
                    ["XML", "Sistemas antiguos que exigen XML"],
                    ["Tabla Markdown", "Pegar en documentación, un README, un ticket"],
                    ["Sentencias SQL INSERT", "Cargar en una base de datos"],
                ]
            ),
            .paragraph("""
                El diálogo **previsualiza las cinco primeras filas** antes de crear la pestaña nueva — \
                cinco líneas bastan para confirmar el nombre de la tabla, el entrecomillado y qué \
                columnas pasaron a ser números.
                """),
            .note("""
                La vista previa llama a **la misma función** que produce la salida real, limitada a \
                cinco filas. No es una simulación que pudiera discrepar del resultado final.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Cambiar el separador",
        summary: "Convertir un archivo entre coma, punto y coma, tabulador y barra vertical.",
        keywords: ["separador", "coma", "punto y coma", "tabulador", "csv europeo"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Los archivos exportados de un Excel vietnamita o europeo suelen usar **punto y coma**, \
                porque allí la coma es el separador decimal.
                """),
            .warning("""
                Cambiar el separador **reescribe todo el archivo**. Las celdas que contengan el nuevo \
                separador se entrecomillan — de otro modo la estructura de la tabla se rompe.
                """),
            .note("""
                **Si la detección se equivocó, esta no es la orden que quiere.** Aquí hay dos tareas \
                distintas, igual que en la pareja de codificación «reinterpretar» / «convertir»:

                • *El archivo de verdad usa punto y coma y adivinamos coma* — pulse el segmento \
                `CSV · …` de la **barra de estado** y elija el correcto. No cambia ni un byte del \
                archivo; solo cómo se lee.

                • *El archivo de verdad usa comas y usted quiere puntos y comas* — use la orden de esta \
                página. Reescribe el archivo.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Limpieza

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Limpieza de datos — todo el flujo",
        summary: "De un archivo en bruto que le han enviado a una tabla usable, y un estándar que repetir cada mes.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "El flujo de limpieza, de principio a fin",
        summary: "Seis pasos de un archivo desconocido a una tabla fiable, y un estándar para el mes que viene.",
        keywords: ["limpieza", "flujo", "normalizar", "datos limpios"],
        blocks: [
            .paragraph("""
                Limpiar datos **rara vez es cosa de una vez**. La gente recibe la misma plantilla de \
                informe cada mes, y cada mes hay que normalizar las mismas columnas del mismo modo. Este \
                flujo está pensado para eso: lo hace a mano una vez y luego lo repite con una sola \
                orden.
                """),
            .heading("Seis pasos"),
            .steps([
                "**Mire primero la estructura.** `CSV ▸ Comprobar datos` — qué filas tienen mal el número de columnas, qué celdas mal el tipo. Esto va primero porque una sola fila descuadrada deja sin sentido toda estadística posterior.",
                "**Lea el perfil de datos.** Por columna: cuántas celdas vacías, cuántos valores distintos, qué tipo, dónde están los valores atípicos. Aquí entiende el archivo, antes de cambiar nada.",
                "**Abra el banco de limpieza** (`⇧⌘L`). Detecta formatos de fecha mezclados, números vietnamitas mezclados con europeos, espacios sueltos, valores que faltan. **Vista previa antes→después** y luego aplique.",
                "**Trate los duplicados aproximados** si una columna de nombres o direcciones tiene variantes escritas a mano. Aquí decide usted; la máquina solo propone.",
                "**Guárdelo como receta.** La secuencia que acaba de ejecutar se escribe en un archivo JSON con nombre — ese archivo es su conocimiento sobre estos datos.",
                "**Escriba un conjunto de reglas de calidad** `.gquality.yaml` y puntúe. A partir de ahora el archivo del mes que viene pasa por la receta y recibe una nota, y la **puerta de línea de órdenes** devuelve un código de salida distinto de cero cuando no pasa.",
            ]),
            .heading("Por qué este orden"),
            .bullets([
                "Estructura **antes** que perfil: las estadísticas sobre una tabla descuadrada son estadísticas sobre otra columna.",
                "Perfil **antes** que limpieza: hay que saber «2 % vacío» antes de decidir si rellenar o descartar.",
                "Duplicados aproximados **después** de normalizar: `CÔNG TY  A` y `Công ty A` solo se revelan como uno cuando espacios y mayúsculas están resueltos.",
                "Receta **antes** que conjunto de reglas: la receta arregla, las reglas juzgan — puntuar una tabla sin arreglar solo produce un número bajo que ya esperaba.",
            ]),
            .heading("Tras la primera vez, cada mes es una orden"),
            .code(language: "bash", caption: "Limpiar y luego puntuar, devolviendo un código de salida para la CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                El código de salida **0** significa aprobado, **1** suspenso, **2** error de ejecución. \
                `--record-history` añade una línea al archivo de historial para que la ejecución \
                siguiente pueda comparar la deriva.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Perfil de datos",
        summary: "Una descripción por columna: tipo, vacíos, valores distintos, distribución.",
        keywords: ["perfil", "estadística de columna", "nulo", "distinto"],
        blocks: [
            .paragraph("""
                Un perfil **describe**; no juzga. Dice *«esta columna está vacía un 2 %»*; si el 2 % es \
                aceptable pertenece al conjunto de reglas de calidad.
                """),
            .table(
                headers: ["Medida", "Cómo leerla"],
                rows: [
                    ["Tipo", "Deducido de los datos mismos, no del nombre de la columna"],
                    ["Celdas vacías", "Número y proporción de valores que faltan"],
                    ["Valores distintos", "1 significa columna constante; igual al número de filas, columna clave"],
                    ["Mín · máx · media", "Solo columnas numéricas"],
                    ["Valores más frecuentes", "Detectar de inmediato un código de error o un valor por omisión abusado"],
                ]
            ),
            .warning("""
                El recuento de valores distintos tiene un umbral. Pasado ese punto, el número mostrado es \
                una **cota inferior**, y el perfil **dice que es una estimación** en vez de mezclarlo con \
                los recuentos exactos.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "El banco de limpieza de datos",
        summary: "Siete normalizaciones, siempre con vista previa, siempre un paso de deshacer, nunca adivinando.",
        keywords: ["limpiar", "normalizar", "fechas", "números", "rellenar"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Abrir el banco de limpieza")]),
            .table(
                headers: ["Operación", "Qué hace"],
                rows: [
                    ["Normalizar fechas", "Llevar todas las formas de fecha de la columna a una sola"],
                    ["Normalizar números", "Resolver el separador decimal y el de miles"],
                    ["Recortar espacios", "Quitarlos en ambos extremos; opcionalmente compactar también los internos"],
                    ["Cambiar mayúsculas", "Hacer coherente la capitalización de la columna"],
                    ["Rellenar con un valor fijo", "Sustituir las celdas vacías por un valor que escriba"],
                    ["Rellenar desde una vecina", "Tomar el valor de la fila de arriba o de abajo"],
                    ["Borrar filas con celdas vacías", "Descartar las filas a las que faltan datos"],
                ]
            ),
            .heading("Tres garantías de todo el banco"),
            .bullets([
                "**Siempre con vista previa.** Una tabla antes→después, con el número de celdas que van a cambiar.",
                "**Un paso de deshacer** para toda la pasada, aunque toque un millón de celdas.",
                "**Un informe después**: cuántas celdas cambiaron y cuáles no se pudieron leer.",
            ]),
            .heading("El principio: nunca adivinar"),
            .paragraph("""
                Una celda que no se puede leer con certeza se **marca y se deja en paz**. Tome \
                `03/04/2026` en una columna que mezcla ambas convenciones: ¿es 3 de abril o 4 de marzo? \
                GEditor le pregunta el orden día/mes en vez de elegir por usted.
                """),
            .warning("""
                Normalizar mal una columna de fechas es la clase de corrupción **casi imposible de \
                detectar**: los números siguen pareciendo correctos, simplemente son otra fecha. Por eso \
                este banco prefiere negarse antes que inferir.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Duplicados aproximados",
        summary: "Encontrar variantes escritas a mano del mismo nombre — y no fusionarlas nunca de forma automática.",
        keywords: ["aproximado", "duplicados", "fusionar", "variantes", "erratas"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — tres formas de \
                escribir un mismo cliente. La eliminación de duplicados corriente no las ve como \
                iguales.
                """),
            .steps([
                "Elija la columna a examinar y un umbral de similitud.",
                "GEditor agrupa los valores cercanos en **conglomerados** y muestra la forma de comparación.",
                "Para **cada conglomerado**, usted elige qué valor conservar — o lo salta.",
                "Aplique. Un paso de deshacer.",
            ]),
            .warning("""
                Esta herramienta **nunca fusiona por su cuenta**, y no hay botón de «fusionar todo». Dos \
                cadenas parecidas al 92 % pueden ser una errata, o dos empresas realmente distintas que \
                se diferencian en una palabra — una máquina no puede saberlo.
                """),
            .paragraph("""
                Fusionar mal dos registros es pérdida de datos **silenciosa**: ninguna celda queda vacía, \
                ninguna fila se vuelve roja, dos entidades simplemente pasan a ser una y nadie se entera \
                hasta que se cuadran las cuentas.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Recetas de limpieza",
        summary: "Grabar la secuencia como archivo JSON y repetirla con los datos del mes que viene.",
        keywords: ["receta", "repetir", "automatizar", "mensual", "lote"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Tras limpiar, guarde los pasos como **receta**. Es un archivo JSON legible por humanos \
                que puede guardar junto a los datos, enviar a un compañero y meter en un repositorio para \
                que los cambios queden registrados.
                """),
            .code(language: "json", caption: "sales-standard.json — abreviado",
                  source: """
                    {
                      "version": 1,
                      "name": "Sales report standardisation",
                      "sourceFile": "sales-2026-08.csv",
                      "steps": [
                        { "enabled": true, "column": "ngay",       "action": "normalizeDates" },
                        { "enabled": true, "column": "doanh_thu",  "action": "normalizeNumbers" },
                        { "enabled": true, "column": "khach_hang", "action": "trim" }
                      ]
                    }
                    """),
            .paragraph("""
                Cada paso se puede **desactivar** (`enabled`), así que una receta puede servir para \
                varias clases de archivo casi idénticas.
                """),
            .heading("Repetir"),
            .bullets([
                "En la aplicación: `CSV ▸ Ejecutar receta de limpieza…`",
                "Desde el terminal, sobre toda una carpeta: vea la página de la línea de órdenes.",
            ]),
            .code(language: "bash", caption: "Una prueba en seco antes de escribir nada — no se toca ningún archivo",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Por omisión el resultado se escribe en un archivo nuevo junto al original \
                (`sales-clean.csv`). Sobrescribir el original hay que pedirlo explícitamente con \
                `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Puntuación de calidad de datos",
        summary: "Seis dimensiones, una nota de 0 a 100, y cada fórmula impresa para que pueda recalcularla.",
        keywords: ["calidad", "nota", "dqr", "seis dimensiones"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Se diferencia del perfil de datos en algo fundamental: un perfil **describe**, una nota \
                **juzga contra el estándar que usted declaró** en un archivo `.gquality.yaml`.
                """),
            .table(
                headers: ["Dimensión", "Qué mide"],
                rows: [
                    ["Completitud", "Proporción de celdas rellenas según las reglas `not_null`"],
                    ["Validez", "Proporción de reglas de formato, tipo, rango y regex que pasan"],
                    ["Unicidad", "Contra la clave declarada en `uniqueness_key`"],
                    ["Coherencia", "Reglas entre columnas y entre archivos"],
                    ["Exactitud (estimada)", "Valores atípicos en las columnas numéricas que designe"],
                    ["Vigencia", "Cuán antiguos son los datos frente al umbral `freshness`"],
                ]
            ),
            .heading("Tres garantías sobre la nota"),
            .bullets([
                "**La fórmula se imprime en el resultado** — puede recalcularla a mano.",
                "**Determinista**: los mismos datos y las mismas reglas dan la misma nota. Solo la *Vigencia* depende del momento, así que `now` es un **parámetro** y queda registrado en el resultado.",
                "**Una dimensión que no se puede puntuar queda en blanco con su razón**, nunca con un 100 dado en silencio.",
            ]),
            .warning("""
                Esa última garantía importa. Una tabla sin `uniqueness_key` declarada a la que se otorga \
                un 100 en «unicidad» es una nota que miente — y miente en la dirección halagadora, que es \
                la peligrosa.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Sintaxis de `.gquality.yaml`",
        summary: "Cada clave del archivo de reglas, con un conjunto completo que se ejecuta.",
        keywords: ["gquality", "yaml", "reglas", "sintaxis", "estándar de datos"],
        blocks: [
            .paragraph("""
                El archivo vive **junto a los datos**, no dentro de la aplicación: un estándar de datos \
                tiene que poder revisarse, y revisar es lo que la gente hace con los estándares.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — un conjunto de reglas completo",
                  source: """
                    schemaVersion: 1

                    # Pesos de las seis dimensiones. Una dimensión ausente pesa 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # La clave que hace única una fila. Sin ella, la dimensión «Unicidad»
                    # NO PUEDE puntuarse — y el total lo dirá.
                    uniqueness_key: [ma_don]

                    # Columnas numéricas examinadas en busca de atípicos para «Exactitud (estimada)».
                    accuracy_columns: [doanh_thu, so_luong]

                    # La dimensión «Vigencia».
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Avisar cuando esta ejecución baje respecto de la anterior.
                    drift:
                      max_total_drop: 3
                      max_dimension_drop: 5
                      max_row_change_pct: 20
                      max_null_increase_pct: 1
                      warn_on_new_failure: true

                    rules:
                      - col: ma_don
                        not_null: true
                      - col: ma_don
                        unique: true
                      - col: doanh_thu
                        dtype: float
                      - col: doanh_thu
                        range: { min: 0 }
                      - col: so_luong
                        dtype: int
                        severity: warn
                      - col: ngay
                        date_format: "yyyy-MM-dd"
                      - col: email
                        regex: "^[^@ ]+@[^@ ]+\\\\.[a-z]{2,}$"
                      - col: trang_thai
                        in_set: [moi, dang_giao, hoan_tat, huy]
                      - col: ghi_chu
                        length: { max: 500 }
                      - col: ma_tinh
                        not_null: true
                        max_null_pct: 2          # se permite un 2 % vacío
                      # Regla entre columnas: no hace falta `col`
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regla entre archivos: el valor debe existir en otro archivo
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Los tipos de regla"),
            .table(
                headers: ["Clave", "Significado", "Dimensión"],
                rows: [
                    ["`not_null: true`", "La celda debe estar rellena; `max_null_pct` lo relaja", "Completitud"],
                    ["`unique: true`", "Sin valores repetidos en la columna", "Unicidad"],
                    ["`dtype: int\\|float\\|date\\|text`", "Tipo correcto", "Validez"],
                    ["`range: { min:, max: }`", "Dentro de un rango numérico", "Validez"],
                    ["`length: { min:, max: }`", "Longitud de la cadena", "Validez"],
                    ["`regex: \"…\"`", "Coincide con una expresión regular", "Validez"],
                    ["`in_set: [ … ]`", "Uno de una lista dada", "Validez"],
                    ["`date_format: \"…\"`", "Forma de fecha correcta", "Validez"],
                    ["`compare: { a:, op:, b: }`", "Comparar dos columnas; `op` es `<` `<=` `=` `>=` `>` `<>`", "Coherencia"],
                    ["`foreign_key: { file:, column: }`", "El valor debe existir en otro archivo", "Coherencia"],
                    ["`severity: error\\|warn`", "Gravedad de la regla; `error` por omisión", "—"],
                ]
            ),
            .warning("""
                Si escribe mal una clave de regla, el archivo se **rechaza con un mensaje**, en vez de \
                saltarse esa regla en silencio. Saltársela en silencio significa que usted cree que los \
                datos se comprobaron contra una regla que nunca se ejecutó.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Una puerta de calidad en CI",
        summary: "Detener los datos defectuosos en la tubería, usando códigos de salida.",
        keywords: ["ci", "puerta", "fail-under", "código de salida", "historial", "deriva"],
        blocks: [
            .code(language: "bash", caption: "Puntuar y devolver un código de salida",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Opción", "Significado"],
                rows: [
                    ["`--quality <archivo.yaml>`", "El conjunto de reglas con el que puntuar"],
                    ["`--fail-under <0…100>`", "Por debajo de esta nota es SUSPENSO"],
                    ["`--json <archivo\\|->`", "Resultado legible por máquina; `-` escribe en la salida estándar"],
                    ["`--record-history`", "Añade una línea a `sales-standard.history.jsonl`"],
                    ["`--now <AAAA-MM-DD>`", "Fija la fecha de referencia de la *Vigencia*"],
                    ["`--recipe <archivo.json>`", "Limpiar **en memoria** antes de puntuar, sin escribir archivo"],
                ]
            ),
            .table(
                headers: ["Código de salida", "Significado"],
                rows: [["`0`", "Aprobado"], ["`1`", "Suspenso"], ["`2`", "Error de ejecución"]]
            ),
            .heading("Por qué la CI debería pasar `--now`"),
            .paragraph("""
                Sin ello, la *Vigencia* compara los datos con el momento de la ejecución — así que el \
                mismo archivo va perdiendo puntos según pasan los días, y una mañana la tubería se pone \
                en rojo sin que nadie haya cambiado nada.
                """),
            .heading("Seguimiento de la deriva"),
            .paragraph("""
                Con `--record-history`, cada ejecución añade una línea a un archivo de historial JSONL. \
                La vez siguiente, los umbrales del bloque `drift:` comparan con la ejecución más reciente \
                y avisan cuando la caída es demasiado grande.
                """),
            .note("""
                Todo umbral de deriva viene **desactivado por omisión**, salvo `warn_on_new_failure`. Un \
                aviso activado de fábrica con un número que eligió la aplicación saltaría en la segunda \
                ejecución de todo el mundo — y lo que grita «que viene el lobo» el primer día se ignora \
                al tercero.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Minería

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Minería de datos — todo el flujo",
        summary: "Anomalías, correlación, conglomerados, previsión, reglas de asociación — y cómo leerlas.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "El flujo de minería, de principio a fin",
        summary: "Seis herramientas, el orden en que usarlas, y una regla: sin medición, no hay conclusión.",
        keywords: ["minería", "análisis", "flujo", "estadística"],
        blocks: [
            .warning("""
                **Primero limpiar, luego minar.** Una columna de fechas sin normalizar produce previsiones \
                erróneas; una columna numérica que mezcla separadores de miles europeos produce atípicos \
                fantasma. Cada herramienta de abajo da por supuesto que la tabla está limpia.
                """),
            .heading("El orden a seguir"),
            .steps([
                "**Buscar anomalías** — responde a *«¿hay alguna fila rara?»*. Lo más barato y a menudo útil de inmediato.",
                "**Matriz de correlación** — responde a *«¿qué columna se mueve con cuál?»*. Guía todo lo que viene después.",
                "**Conglomerados** — responde a *«¿cuántos grupos naturales hay aquí dentro?»*.",
                "**Previsión** — solo con una columna de tiempo y al menos **dos ciclos completos**.",
                "**Reglas de asociación** — solo para datos con forma de cesta: una transacción por fila, o dos columnas de identificador de transacción y artículo.",
                "**Minería por grupo** — repite las tres primeras **de forma independiente dentro de cada grupo**. Este paso invierte con frecuencia la conclusión sacada de la tabla agregada.",
            ]),
            .heading("Tres reglas para toda la familia"),
            .bullets([
                "**Cada resultado lleva un bloque «Método»**: algoritmo, parámetros, semilla, fórmula. No hay forma de desactivarlo — una tabla de tres números que no dice de dónde salen no sirve para decidir.",
                "**Sin medición, no hay conclusión.** Muestra demasiado pequeña, varianza cero, matriz singular — GEditor se niega y dice por qué, en vez de devolver un número que solo parece correcto.",
                "**Resultados deterministas.** Los mismos datos dan el mismo resultado; donde hace falta azar, la semilla queda registrada en la salida.",
            ]),
            .heading("Del resultado de vuelta a los datos"),
            .paragraph("""
                Cada panel **marca de vuelta en los datos fuente**: pulse una fila anómala, una celda de \
                correlación o una regla de asociación y las líneas pertinentes quedan marcadas en la \
                tabla. Así se pasa de *«algo va raro»* a *«va raro exactamente en estas filas»*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Encontrar filas anómalas",
        summary: "Cuatro medidas, tres niveles de gravedad y una explicación de por qué una fila es rara.",
        keywords: ["atípico", "anomalía", "puntuación z", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Medida", "Cuándo usarla"],
                rows: [
                    ["Puntuación z", "La columna sigue más o menos una normal"],
                    ["IQR", "La columna es asimétrica con cola larga — la opción segura por omisión"],
                    ["MAD", "La columna ya contiene muchos atípicos y necesita una medida robusta"],
                    ["Mahalanobis", "**Varias columnas a la vez** — caza filas raras en combinación, no en ninguna columna suelta"],
                ]
            ),
            .paragraph("""
                Los resultados se colorean por **tres niveles de gravedad** en vez de un color plano — de \
                otro modo una fila levemente inusual no se distinguiría de una salvajemente inusual.
                """),
            .heading("Explicar el porqué"),
            .paragraph("""
                Para la medida multicolumna, GEditor descompone la contribución de cada columna y produce \
                una frase como *«anómala sobre todo por la combinación ingresos (50 %) × cantidad \
                (50 %)»*.
                """),
            .note("""
                Ese porcentaje es *de la parte explicable*, no *de la distancia*. El bloque Método lo dice \
                justo debajo de la tabla.
                """),
            .warning("""
                Una columna cuyo IQR o MAD sea cero hace que la medida **se niegue a ejecutarse**, en vez \
                de dividir por algo minúsculo y producir una puntuación enorme. En el caso multicolumna, \
                si la matriz de covarianzas es singular, GEditor **dice qué columna quitar** en lugar de \
                usar una pseudoinversa para «hacer que funcione».
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Matriz de correlación",
        summary: "Pearson y Spearman para cada par, con diagrama de dispersión al pulsar.",
        keywords: ["correlación", "pearson", "spearman", "mapa de calor", "dispersión"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Coeficiente", "Qué mide"],
                rows: [
                    ["Pearson", "Una relación **lineal**"],
                    ["Spearman", "**Cualquier** relación **monótona**, incluidas las curvas — calculada sobre rangos"],
                ]
            ),
            .paragraph("""
                Pulse una celda del mapa de calor para ver el diagrama de dispersión de ese par, con \
                recta de regresión y R².
                """),
            .heading("Cuatro detalles que cambian cómo se lee"),
            .bullets([
                "**Los empates usan rangos medios**, así que reordenar la tabla no cambia el coeficiente de Spearman.",
                "**Las celdas vacías se tratan por pares**, y el `n` de cada celda está ahí mismo en la tabla — `0,93` sobre 6 filas no significa lo que `0,93` sobre 6.000 filas.",
                "**Una columna constante devuelve vacío**, no 0. Cero significa *medido, no se halló relación*.",
                "**La escala de color es azul↔naranja**, no rojo-verde: el 8 % de los hombres ve una escala rojo-verde como una masa gris, lo que hace que `+0,9` y `−0,9` parezcan idénticos.",
            ]),
            .warning("""
                **Correlación no implica causalidad.** Esa frase se dibuja **dentro del propio gráfico**, \
                así que viaja con la imagen cuando la exporta.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Conglomerados",
        summary: "k-medias y DBSCAN, dos formas de elegir k — y un aviso sobre el escalado.",
        keywords: ["conglomerado", "cluster", "kmeans", "dbscan", "silueta", "codo"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritmo", "Cuándo usarlo"],
                rows: [
                    ["k-medias", "Conoce (o quiere probar) el número de conglomerados; son en forma de nube"],
                    ["DBSCAN", "No conoce el número; los conglomerados tienen formas arbitrarias; quiere separar el ruido"],
                ]
            ),
            .heading("El escalado viene activado — y por qué"),
            .paragraph("""
                Una columna `ingresos` (en millones) junto a una columna `cantidad` (en unidades): la \
                distancia entre dos filas la decide casi por completo la mayor. Eso no es «subóptimo» — es \
                **responder a otra pregunta**. El escalado en vigor queda registrado en el resultado.
                """),
            .heading("Elegir el número de conglomerados"),
            .bullets([
                "**Silueta** — cuanto más alta la puntuación, mejor separados están. En una tabla grande **toma una muestra** (a intervalos regulares, no las primeras 2.000 filas), y el resultado se declara una estimación.",
                "**Codo** — dibuja la suma de cuadrados intra-conglomerado frente a k. Es una **forma de leer un gráfico**, no una optimización: esa cantidad siempre baja al subir k, así que no existe un «k óptimo» estadísticamente.",
            ]),
            .note("""
                Para DBSCAN, el gráfico de **k-distancias** ayuda a elegir un radio: la rodilla de la \
                curva suele ser un valor de partida sensato.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Previsión de series temporales",
        summary: "Descomposición de tendencia y estacionalidad, Holt-Winters, y una referencia que corre siempre al lado.",
        keywords: ["previsión", "serie temporal", "estacionalidad", "holt-winters", "tendencia"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Elija una columna de tiempo y una de valores. GEditor descompone la serie en **tendencia · \
                estacionalidad · residuo** y luego prevé con Holt-Winters (aditivo o multiplicativo), con \
                intervalos al 80 % y al 95 %.
                """),
            .heading("La referencia corre siempre, y dice sin rodeos quién ganó"),
            .paragraph("""
                Junto al modelo, GEditor ejecuta dos métodos ingenuos: *tomar el periodo anterior* y *tomar \
                el mismo periodo de la temporada pasada*. Si el modelo **pierde** frente a una referencia, \
                esa frase aparece en la **primera línea, en otro color** — no debajo de una tabla de \
                números.
                """),
            .paragraph("""
                La razón: las herramientas de previsión tienden a presentar el modelo como un hecho, y el \
                usuario no tiene forma de enterarse de que «coger sin más la cifra del mes pasado» habría \
                sido más exacto.
                """),
            .heading("Tres lugares donde GEditor se niega, o se declara"),
            .bullets([
                "**Sin dos ciclos completos vuelve al método ingenuo.** Ajustar la estacionalidad al ruido de un solo ciclo y repetirla hacia el futuro produce una previsión muy convincente y del todo inventada.",
                "**Si el MAPE topa con un cero lo dice**, y si más del 25 % de los periodos son cero retiene la métrica — saltárselos en silencio produce un número calculado sobre un subconjunto sistemáticamente sesgado.",
                "**El intervalo de confianza se declara aproximado**, y advierte de que se ensancha demasiado despacio a horizontes largos.",
            ]),
            .note("""
                El periodo estacional se detecta sobre la **primera diferencia**, no sobre la serie cruda: \
                una tendencia hace que todos los retardos estén muy correlacionados y ahoga el pico \
                estacional.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Reglas de asociación",
        summary: "Compra A, a menudo compra B — y por qué la tabla se ordena por lift, no por confianza.",
        keywords: ["apriori", "reglas de asociación", "cesta", "lift", "soporte"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Se aceptan dos formas de datos:"),
            .bullets([
                "**Una cesta por fila** — una columna con una lista de artículos.",
                "**Dos columnas** — identificador de transacción y artículo, un artículo por fila.",
            ]),
            .table(
                headers: ["Métrica", "Significado"],
                rows: [
                    ["soporte", "Proporción de cestas que contienen ambos lados"],
                    ["confianza", "De las cestas con el lado izquierdo, qué proporción tiene el derecho"],
                    ["**lift**", "La confianza dividida por la tasa base del lado derecho"],
                    ["leverage", "La distancia respecto a lo que predeciría la independencia"],
                ]
            ),
            .heading("Ordenado por lift, no por confianza"),
            .paragraph("""
                Si el lado derecho aparece de todos modos en el 95 % de las cestas, entonces **toda** \
                regla que lleve a él tiene alrededor de un 95 % de confianza — sin decir nada en \
                absoluto. Ordenar por confianza pone arriba precisamente las reglas más vacías de \
                sentido.
                """),
            .warning("""
                `lift < 1` se **señala en la propia fila**: un 80 % de confianza hacia algo con una tasa \
                base del 95 % significa una relación **inversa** — un número correcto que lleva a una \
                conclusión falsa.
                """),
            .bullets([
                "Comprar dos briks de leche sigue siendo **una** transacción con leche: los duplicados dentro de una cesta se descartan, o el soporte se infla con la cantidad.",
                "Poner el umbral de soporte demasiado bajo hace que el conjunto de candidatos explote de forma combinatoria; al alcanzar el techo, GEditor **se detiene y declara la tabla incompleta**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Minar por grupo",
        summary: "Repetir el análisis de forma independiente por grupo — el paso que más a menudo invierte una conclusión.",
        keywords: ["por grupo", "simpson", "sucursales", "comparar grupos"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Elija una columna de texto como clave de agrupación. Cada grupo recibe anomalías, previsión \
                y correlación ejecutadas **de forma totalmente independiente**, y luego se ordenan por el \
                criterio que elija.
                """),
            .heading("Por qué los grupos deben separarse, no agregarse"),
            .paragraph("""
                Dos sucursales, una en torno a 10 y otra en torno a 100. Una valla de atípicos calculada \
                sobre la tabla **agregada** cae alrededor de ±135 — y falla **en ambas direcciones**:
                """),
            .bullets([
                "**Falsos negativos**: un valor de 20, claramente anómalo para la sucursal pequeña, queda bien dentro de la valla común. Cuantos más grupos, más ciega se vuelve.",
                "**Falsos positivos**: a un grupo muy disperso la valla común le corta su cola normal, y una multitud de filas corrientes queda señalada.",
            ]),
            .heading("La columna «divergencia de correlación» caza la paradoja de Simpson"),
            .paragraph("""
                Tres grupos en los que **cada** grupo correlaciona sus dos columnas a `−1`, y sin embargo \
                agregados correlacionan a `> 0,9`. Quien lea solo la tabla agregada concluye **justo lo \
                contrario**. Esta columna apunta precisamente a esos casos.
                """),
            .note("""
                El panel ofrece solo **columnas de texto** como clave de agrupación y se detiene a los \
                1.000 grupos con un aviso — para evitar que se elija una columna de números de pedido y \
                cada fila acabe siendo un grupo propio.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Minería de texto",
        summary: "n-gramas y TF-IDF sobre una columna de texto — encontrar las expresiones características.",
        keywords: ["minería de texto", "n-grama", "tf-idf", "palabras clave", "expresiones"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Se ejecuta sobre una columna de texto — descripciones de producto, opiniones de clientes, \
                campos de notas.
                """),
            .bullets([
                "**n-gramas** — las expresiones de 1, 2 y 3 palabras más frecuentes.",
                "**TF-IDF** — palabras **características** de cada grupo de documentos, es decir, frecuentes aquí y raras en otros sitios.",
            ]),
            .paragraph("""
                La diferencia: los n-gramas le dicen *«qué mencionan los clientes una y otra vez»*, y el \
                TF-IDF le dice *«en qué se diferencia este grupo de los demás»*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
