import Foundation

/// Conteúdo de ajuda em português — parte 5: relatórios, conhecimento, automatização e aplicação.
extension HelpPT {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Relatórios e diagramas",
        summary: "Um ficheiro de texto que produz um relatório HTML cujos números são recalculados, mais diagramas Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "Relatórios `.greport.md`",
        summary: "Markdown mais quatro tipos de bloco executáveis — escrever à esquerda, pré-visualizar à direita.",
        keywords: ["relatório", "greport", "html", "exportar", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Um ficheiro `.greport.md` é **Markdown vulgar** mais alguns blocos delimitados executáveis. \
                Desenhá-lo produz um ficheiro HTML **autónomo** — sem rede, sem ficheiros acompanhantes — \
                que qualquer pessoa pode abrir.
                """),
            .paragraph("""
                Como é texto simples, pode ser **comparado, versionado e partilhado** — a mesma filosofia \
                das receitas de limpeza e dos conjuntos de regras de qualidade.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — um relatório completo",
                  source: """
                    ---
                    title: Relatório de vendas de agosto
                    source: sales-2026-08.csv
                    ---

                    # Relatório de vendas de agosto

                    Números a 31 de agosto de 2026.

                    ## Receita por província

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Receita por província
                    y_label: Receita
                    number_format: vi
                    suffix: " ₫"
                    source: Fonte — sales-2026-08.csv
                    ```

                    ## Qualidade dos dados de origem

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Os tipos de bloco"),
            .table(
                headers: ["Bloco", "Produz"],
                rows: [
                    ["`query`", "Uma tabela, a partir de uma instrução SQL do DuckDB"],
                    ["`chart`", "Um gráfico"],
                    ["`quality`", "Um cartão de pontuação de qualidade dos dados"],
                    ["`mining`", "Uma tabela de classificação de mineração por grupo"],
                    ["`mermaid`", "Um diagrama"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                O bloco `---` no topo declara `title` e `source` — a fonte de dados por omissão de todo o \
                bloco que não indique a sua.
                """),
            .note("""
                A pré-visualização reconstrói-se quando para de escrever, mas **só analisa**; não executa \
                consultas a cada tecla. Os erros de documento e os de dados são comunicados em separado — \
                *«falta a chave `kind` ao bloco chart»* é um erro de ficheiro, *«a coluna `doanh_thu` não \
                existe»* é um erro de dados.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "O bloco `query`",
        summary: "Uma instrução do DuckDB torna-se uma tabela no relatório.",
        keywords: ["consulta", "sql", "tabela", "relatório", "bloco"],
        blocks: [
            .paragraph("""
                O conteúdo do bloco é **uma instrução SQL**, executada sobre a fonte do relatório. A tabela \
                chama-se `t`, no mesmo dialeto do painel de consultas.
                """),
            .code(language: "text", caption: "Um bloco query com parâmetros",
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
                `:thang` é um **parâmetro**. É fornecido ao desenhar — a partir da consola com `--param \
                thang=8`, ou a partir de um ficheiro de lista ao gerar relatórios em lote.
                """),
            .note("""
                As tabelas de um relatório de dados **devem vir de um bloco query**, não ser escritas à \
                mão. Uma tabela escrita à mão não se recalcula quando os números mudam e, mais tarde ou \
                mais cedo, contradiz o resto do relatório.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "O bloco `chart`",
        summary: "Uma configuração YAML torna-se um gráfico — e a regra mais importante do formato.",
        keywords: ["gráfico", "yaml", "relatório", "desenhar"],
        blocks: [
            .code(language: "yaml", caption: "Cada chave de um bloco chart",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Receita por província
                    x_label: Província
                    y_label: Receita
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Fonte — sales.csv, a 26 de agosto de 2026
                    """),
            .heading("Sem `query`, usa o resultado do bloco query IMEDIATAMENTE ACIMA"),
            .paragraph("""
                Esta é a regra mais importante do formato. Graças a ela, o relatório habitual de «uma tabela \
                e depois um gráfico dessa tabela» não repete o SQL — e repeti-lo significa que as duas \
                cópias acabam por divergir, altura em que a tabela e o gráfico dizem coisas diferentes na \
                mesma página.
                """),
            .warning("""
                Em troca, **a ordem dos blocos conta**: inserir um bloco query no meio muda os dados do \
                gráfico de baixo.
                """),
            .heading("Porque `source` é uma chave própria"),
            .paragraph("""
                Uma nota de fonte escrita em prosa sob o gráfico aparece perfeitamente — no ecrã. Mas o \
                gráfico vai ser exportado como PNG e colado noutro sítio, e a prosa fica para trás. Como \
                chave, é desenhada **dentro da imagem** e viaja com ela.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "O bloco `quality`",
        summary: "Um cartão de pontuação de qualidade dos dados dentro do relatório.",
        keywords: ["qualidade", "cartão", "relatório", "bloco"],
        blocks: [
            .code(language: "yaml", caption: "Cada chave de um bloco quality",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # vazio significa a fonte própria do relatório
                    title: Qualidade dos dados de vendas de agosto
                    rules: true                 # mostrar a tabela de regras aprovadas/reprovadas
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # fixar a data de referência da «Atualidade»
                    fail_under: 90              # abaixo disso, o cartão passa a cor de aviso
                    """),
            .table(
                headers: ["`chart`", "Desenha"],
                rows: [
                    ["`violations`", "O número de linhas das regras **reprovadas** — responde a «o que corrigir primeiro»"],
                    ["`dimensions`", "As notas das seis dimensões"],
                    ["`none`", "Só tabela, sem gráfico"],
                ]
            ),
            .note("""
                Ponha `now:` num relatório periódico. Sem isso, a *Atualidade* compara-se ao momento de \
                desenhar, por isso voltar a desenhar o relatório do mês passado dá uma nota diferente da que \
                publicou.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "O bloco `mining`",
        summary: "Classificar grupos por anomalias, erro de previsão ou divergência de correlação.",
        keywords: ["mineração", "relatório", "classificação de grupos"],
        blocks: [
            .code(language: "yaml", caption: "Cada chave de um bloco mining",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # a coluna para anomalias e previsão
                    pair: chi_phi             # uma segunda coluna, para a correlação por grupo
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # vazio significa a fonte própria do relatório
                    title: Mineração por província
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Classifica por"],
                rows: [
                    ["`anomalies`", "O grupo com mais linhas anómalas"],
                    ["`forecast_error`", "O grupo cuja previsão é pior"],
                    ["`correlation_gap`", "O grupo cuja correlação mais diverge da tabela agregada — apanha o paradoxo de Simpson"],
                ]
            ),
            .warning("""
                **Nenhuma chave desliga o bloco «Método».** Uma classificação de grupos sem o seu método não \
                dá ao leitor forma alguma de saber contra que cerca «mais anomalias» foi medido. Quem quer \
                escondê-lo já sabe a resposta que deseja.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Gerar relatórios em lote",
        summary: "Um modelo, uma lista de parâmetros, muitos relatórios.",
        keywords: ["lote", "em massa", "parâmetros", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Um modelo de relatório, executado para cada filial ou cada mês. A lista de parâmetros é um \
                ficheiro CSV ou JSON — **uma linha por relatório**.
                """),
            .code(language: "text", caption: "list.csv — uma linha por relatório",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Desenhar o lote todo a partir da consola",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Ou um relatório com parâmetros passados à mão",
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
        summary: "Desenhar diagramas em texto, editá-los com comandos, pré-visualizar sincronizado nos dois sentidos.",
        keywords: ["mermaid", "diagrama", "fluxograma", "sequência", "desenhar"],
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
                O Mermaid desenha diagramas **a partir de texto**: você escreve uma descrição e a máquina \
                desenha-a. Por isso um diagrama pode ser comparado e versionado — coisa que um ficheiro de \
                imagem não pode.
                """),
            .paragraph("""
                Abra `Diagrama Mermaid: pré-visualizar` para ter uma vista ao lado do editor. Ambos estão \
                **sincronizados nos dois sentidos**: selecione um elemento na imagem e o cursor salta para \
                a sua linha.
                """),
            .heading("Editar com comandos, não a reescrever"),
            .table(
                headers: ["Comando", "O que faz"],
                rows: [
                    ["Inserir um modelo…", "Inserir um esqueleto pronto para cada tipo de diagrama"],
                    ["Acrescentar um elemento…", "Acrescentar um nó ou um participante"],
                    ["Ligar os dois elementos selecionados", "Desenhar uma seta entre eles"],
                    ["Editar a etiqueta do elemento selecionado…", "Mudar o texto sem procurar a linha"],
                    ["Apagar o elemento selecionado", "Retirar o nó **e** cada aresta que lhe toque"],
                    ["Subir / descer a mensagem", "Reordenar passos num diagrama de sequência"],
                    ["Reformatar", "Indentar e alinhar o bloco todo"],
                ]
            ),
            .heading("Separar para um ficheiro e voltar a embutir"),
            .paragraph("""
                Os diagramas grandes merecem o seu próprio ficheiro `.mmd`: `Separar o bloco para um \
                ficheiro .mmd…` move-o e deixa uma referência. `Voltar a embutir o ficheiro referenciado` \
                faz o contrário quando tem de enviar um único ficheiro.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Sintaxe comum do Mermaid",
        summary: "Os quatro tipos de diagrama mais usados, cada um com um modelo que funciona.",
        keywords: ["mermaid", "sintaxe", "fluxograma", "sequência", "gantt", "classes", "modelo"],
        blocks: [
            .code(language: "mermaid", caption: "Fluxograma — um processo de aprovação de encomendas",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Diagrama de sequência — um fluxo de pagamento",
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
            .code(language: "mermaid", caption: "Diagrama de classes — um modelo de dados",
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
            .code(language: "mermaid", caption: "Gantt — um plano de lançamento",
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
                headers: ["Forma do nó", "Escreva"],
                rows: [
                    ["Retângulo", "`A[Label]`"],
                    ["Arredondado", "`A(Label)`"],
                    ["Estádio", "`A([Label])`"],
                    ["Losango (decisão)", "`A{Label}`"],
                    ["Cilindro (dados)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Seta", "Escreva"],
                rows: [
                    ["Sólida, com ponta", "`A --> B`"],
                    ["Pontilhada", "`A -.-> B`"],
                    ["Grossa", "`A ==> B`"],
                    ["Com etiqueta", "`A -- label --> B`"],
                ]
            ),
            .note("""
                A direção de um fluxograma vem logo a seguir a `flowchart`: `TD` de cima para baixo, `LR` da \
                esquerda para a direita, além de `BT` e `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Pacote de conhecimento

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "O pacote de conhecimento",
        summary: "Fatiar, índices de procura, grafos de conhecimento, entidades e avaliação de recuperação.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "O que é o pacote de conhecimento",
        summary: "Ferramentas para preparar e verificar dados destinados a um sistema de perguntas e respostas sobre documentos.",
        keywords: ["rag", "conhecimento", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Ao construir um sistema que responde a perguntas a partir de um corpus de documentos, a \
                maior parte do trabalho não está no modelo mas em **preparar os dados**: cortar os \
                documentos em passagens sensatas, verificar a qualidade dessas passagens, construir um \
                índice e **medir se a recuperação encontra mesmo o que é preciso**.
                """),
            .paragraph("""
                Este capítulo é exatamente o instrumental para isso. Corre **inteiramente na sua máquina** e \
                nunca chama a rede.
                """),
            .table(
                headers: ["Tarefa", "Ferramenta"],
                rows: [
                    ["Cortar documentos em passagens", "Pré-visualização de fatiamento"],
                    ["Inspecionar e pontuar passagens", "Inspeção de fatias JSONL"],
                    ["Converter entre formas de dados", "Conversão de conhecimento"],
                    ["Construir e inspecionar um grafo de relações", "Grafo de conhecimento"],
                    ["Encontrar nomes próprios num texto", "Marcação de entidades"],
                    ["Medir a qualidade da recuperação", "Laboratório de recuperação"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Fatiar e inspecionar um corpus JSONL",
        summary: "Pré-visualizar os limites de fatiamento sobre o próprio texto e depois pontuar o corpus todo.",
        keywords: ["chunk", "jsonl", "corpus", "sobreposição", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Pré-visualização de fatiamento"),
            .paragraph("""
                Abra um documento de texto ou Markdown, escolha uma estratégia e um tamanho de fatia. Os \
                limites são **realçados sobre o próprio texto**, por isso vê onde um corte cai a meio de uma \
                frase ou atravessa uma tabela antes de exportar seja o que for.
                """),
            .bullets([
                "**Tamanho fixo** com sobreposição.",
                "**Por estrutura** — nos títulos de Markdown, mantendo intacto o fio do documento.",
                "**Por parágrafo**, juntando até atingir o tamanho.",
            ]),
            .heading("Inspecionar um corpus JSONL existente"),
            .paragraph("""
                Para um corpus que já tem (uma fatia JSON por linha), `JSONL: inspecionar fatias…` responde: \
                que linhas não são JSON válido, que fatias são demasiado curtas ou longas, quais se duplicam \
                entre si e quais foram cortadas a meio de uma frase.
                """),
            .note("""
                Um corpus também pode ser pontuado com o **mesmo quadro de seis dimensões** dos dados \
                tabulares — use a chave `corpus:` num bloco `quality` de um relatório.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Converter formatos de conhecimento",
        summary: "Fatias entre JSONL · CSV · Markdown, grafos entre DOT · Mermaid · listas de arestas.",
        keywords: ["converter", "jsonl", "dot", "mermaid", "lista de arestas"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["De", "Para"],
                rows: [
                    ["Fatias JSONL", "CSV · Markdown"],
                    ["Fatias CSV", "JSONL · Markdown"],
                    ["Grafo DOT", "Mermaid · lista de arestas"],
                    ["Lista de arestas", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Há uma **pré-visualização de cinco linhas** antes de criar o separador novo, o mesmo \
                mecanismo da conversão de CSV.
                """),
            .paragraph("""
                `Abrir triplos/arestas como tabela` mostra um ficheiro de triplos ou uma lista de arestas \
                como tabela — filtre e ordene como em qualquer outro CSV.
                """),
            .note("""
                O sentido **Markdown → JSONL** não está neste comando: esse sentido *é* o fatiamento, e o \
                comando remete-o para lá. Duas implementações do mesmo corte produziriam dois resultados \
                diferentes.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Grafos de conhecimento",
        summary: "Verificar sintaxe, pontuar a saúde e correr algoritmos em grafos de um milhão de arestas.",
        keywords: ["grafo", "dot", "cypher", "pagerank", "louvain", "verificação de sintaxe"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                O GEditor lê grafos como **DOT**, como **listas de arestas** e como **triplos**. `Verificar \
                a sintaxe do grafo` apanha erros de sintaxe, nós soltos e arestas que apontam para nós \
                inexistentes.
                """),
            .heading("Algoritmos disponíveis"),
            .table(
                headers: ["Algoritmo", "Responde a"],
                rows: [
                    ["Vizinhança a k saltos", "O que se relaciona com este nó em k passos"],
                    ["Componentes ligados", "Em quantas peças desligadas o grafo se divide"],
                    ["PageRank", "Que nós são importantes"],
                    ["Louvain", "Como o grafo se divide em comunidades"],
                ]
            ),
            .paragraph("""
                Num grafo de **um milhão de arestas**, os quatro correm entre alguns milissegundos e cerca \
                de um segundo.
                """),
            .note("""
                Um grafo também pode ser pontuado com o **quadro de seis dimensões** usado para tabelas e \
                corpora — use a chave `graph:` num bloco `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Marcar entidades a partir de uma lista",
        summary: "Carregar uma lista de nomes próprios e encontrar cada ocorrência — sob três regras pensadas para o vietnamita.",
        keywords: ["entidade", "nome próprio", "ner", "marcação", "correspondência"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Carregue uma lista de nomes (empresas, produtos, lugares) e o GEditor realça cada ocorrência \
                no documento, com uma tabela de contagens.
                """),
            .heading("Três regras de correspondência, todas nascidas de dados vietnamitas"),
            .bullets([
                "**Ganha a correspondência mais longa.** Com `An Phát` e `Công ty An Phát` ambos na lista, uma frase que contenha a expressão longa tem de corresponder à longa — de outro modo é partida em duas e contada como duas entidades, o que **inflaciona** as estatísticas.",
                "**Exigem-se limites de palavra.** `An` não pode corresponder dentro de `Anh` nem de `Hoàn`. Os nomes próprios vietnamitas são curtos e partilham sílabas com incontáveis palavras vulgares.",
                "**Insensível a maiúsculas, mas SENSÍVEL aos acentos.** `CÔNG TY` e `Công ty` são um; `má` e `ma` não são.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Resolver variantes de entidades",
        summary: "Reconhecer `Cty An Phát` e `Công ty An Phát` como uma só — deixando-lhe a decisão na mesma.",
        keywords: ["resolução de entidades", "variantes", "normalização de nomes", "duplicados"],
        blocks: [
            .paragraph("""
                O mesmo agrupamento dos **duplicados aproximados** de uma tabela CSV — uma implementação \
                partilhada, não duas.
                """),
            .paragraph("""
                A saída é uma **proposta**: você revê cada aglomerado e escolhe a forma canónica. Não há \
                botão de juntar tudo, porque dois nomes 92 % semelhantes podem ser duas organizações reais.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "O laboratório de recuperação",
        summary: "Medir se o índice encontra o que é preciso, usando um conjunto de perguntas com respostas.",
        keywords: ["recuperação", "bm25", "recall", "mrr", "ndcg", "avaliação"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Carregue um **conjunto de avaliação** — cada linha uma pergunta com os identificadores de \
                fatia que deveriam ser devolvidos — e depois corra o lote todo contra o índice.
                """),
            .table(
                headers: ["Métrica", "Responde a"],
                rows: [
                    ["recall@k", "Quanto do conjunto de respostas aparece nos k primeiros"],
                    ["MRR", "A que profundidade está o primeiro resultado certo"],
                    ["nDCG@k", "Se a ordenação é boa, contando a posição"],
                ]
            ),
            .paragraph("""
                Os resultados vêm também **por pergunta**, os piores primeiro — essa é a sua lista de coisas \
                a corrigir no corpus, pela ordem que mais compensa.
                """),
            .warning("""
                As três métricas são **médias**, e uma média esconde muitíssimo. Leia sempre a tabela por \
                pergunta antes de concluir que «o índice já é suficientemente bom».
                """),
            .paragraph("""
                Duas configurações podem ser comparadas lado a lado, e o resultado cai diretamente num \
                relatório `.greport.md` para que a execução seguinte seja igual.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Macros e automatização

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Macros e automatização",
        summary: "Gravar ações, executá-las em lote, escrever scripts e comandar a partir da consola.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Gravar e reproduzir macros",
        summary: "Gravar uma sequência e repeti-la — a execução toda é um passo de desfazer.",
        keywords: ["macro", "gravar", "reproduzir", "repetir", "automatizar"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Começar / parar a gravação"),
                HelpShortcut("⌃P", "Reproduzir"),
            ]),
            .steps([
                "`⌃R` começa a gravar.",
                "Faça aquilo que quer repetir — escrever, mover o cursor, procurar, substituir.",
                "`⌃R` outra vez para parar.",
                "`⌃P` reproduz, ou `Macro ▸ Reproduzir até ao fim do documento` corre até ao fim.",
                "`Macro ▸ Guardar macro…` dá-lhe nome para sessões futuras.",
            ]),
            .heading("Grava COMANDOS, não teclas em bruto"),
            .paragraph("""
                Uma macro guarda **o que fez**, não que teclas carregou. Isso torna-a independente da \
                disposição do teclado e do método de entrada ativo, e torna o ficheiro de macro **legível** \
                quando o abre.
                """),
            .heading("Quando uma macro para"),
            .table(
                headers: ["Motivo", "Significado"],
                rows: [
                    ["Esgotou-se o número de repetições", "Normal"],
                    ["Um passo `find` não encontrou nada", "É assim que «reproduzir até ao fim do ficheiro» para sozinha"],
                    ["Chegou-se ao fim do documento", "Não há para onde seguir"],
                    ["Você cancelou", "`Macro ▸ Cancelar a macro em curso`"],
                    ["Uma iteração não mudou nem moveu nada", "Para não andar em círculos sem fim"],
                ]
            ),
            .note("A execução toda — mesmo dez mil repetições — é **um** passo de desfazer."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Executar uma macro em lote",
        summary: "Sobre todos os separadores abertos, ou sobre uma pasta de ficheiros por abrir.",
        keywords: ["lote", "todos os separadores", "pasta", "macro", "máscara"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Comando", "Âmbito", "Reversível"],
                rows: [
                    ["Executar em todos os separadores", "Os separadores abertos", "Sim — um passo de desfazer por separador"],
                    ["Executar sobre uma pasta…", "Ficheiros do disco **por abrir**", "Não"],
                ]
            ),
            .warning("""
                Executar sobre uma pasta toca em ficheiros que não estão abertos em nenhum separador, por \
                isso **não há desfazer**. Por omissão o GEditor **escreve ficheiros novos** em vez de \
                sobrescrever os originais. Mantenha esse valor a não ser que tenha cópia de segurança ou um \
                repositório com versões.
                """),
            .heading("Filtrar ficheiros com uma máscara"),
            .paragraph("""
                O seletor de pasta tem um **filtro de nome de ficheiro**: escreva `*.csv;*.log` e a macro só \
                toca nesses. É a mesma sintaxe de máscara que o `Procurar numa pasta` usa, com vários \
                padrões separados por `;` ou `,`.
                """),
            .bullets([
                "Deixe-o **vazio** e apanha todo o ficheiro de texto que o GEditor saiba ler — o comportamento anterior.",
                "A máscara **substitui** essa lista de extensões em vez de a estreitar ainda mais: escreva `*.bak` e corre sobre ficheiros `.bak`, mesmo que essa extensão não esteja na lista de texto.",
                "Se nada corresponder, a mensagem **repete-lhe a máscara** em vez de culpar uma pasta vazia.",
            ]),
            .paragraph("""
                Esta caixa tem uma razão muito prática: uma pasta tem 400 ficheiros `.json` e 12 `.log`, e a \
                sua macro só arruma registos. Sem máscara, os outros 400 também são processados — e como o \
                lote escreve ficheiros novos, um engano deixa 400 pedaços de lixo.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Sintaxe do ficheiro de macro",
        summary: "Sete tipos de passo, o formato JSON completo e duas macros que funcionam.",
        keywords: ["macro", "json", "sintaxe", "formato", "editar à mão", "partilhar"],
        blocks: [
            .paragraph("""
                Cada macro é **o seu próprio ficheiro JSON** na pasta `macros/` do GEditor. Um estrago fica \
                confinado a uma macro, e partilhar uma com um colega é enviar um ficheiro.
                """),
            .code(language: "text", caption: "Onde vivem os ficheiros",
                  source: "~/Library/Application Support/GEditor/macros/<nome-da-macro>.json"),
            .heading("Os sete tipos de passo"),
            .table(
                headers: ["Passo", "Escreve-se", "Significado"],
                rows: [
                    ["Inserir texto", "`{\"insert\": {\"_0\": \"texto\"}}`", "Escrever no cursor; com seleção, substitui-a"],
                    ["Apagar para trás", "`{\"deleteBackward\": {}}`", "Como a tecla Apagar"],
                    ["Apagar para a frente", "`{\"deleteForward\": {}}`", "Como ⌦"],
                    ["Mover", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Veja a lista de direções abaixo"],
                    ["Selecionar a linha", "`{\"selectLine\": {}}`", "Sem o fim de linha"],
                    ["Procurar", "`{\"find\": { … }}`", "Encontra e **seleciona** a ocorrência seguinte"],
                    ["Substituir a seleção", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` serve se o passo anterior foi um `find` com regex"],
                ]
            ),
            .heading("Direções de movimento"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("O passo `find` completo"),
            .code(language: "json", caption: "As quatro chaves de um passo find",
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
            .paragraph("`mode` aceita `normal`, `extended` ou `regex` — os mesmos três modos do campo de procura."),
            .heading("Exemplo 1 — pôr em maiúsculas o código de província no início de cada linha"),
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
                Execute-a com `Macro ▸ Reproduzir até ao fim do documento`: o passo `find` deixar de \
                encontrar seja o que for é exatamente a condição de paragem.
                """),
            .heading("Exemplo 2 — apagar a linha a seguir a cada linha que contenha TODO"),
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
                Experimente primeiro numa cópia uma macro editada à mão. Um passo `find` mal escrito faz a \
                macro parar de imediato — esse é o caso benigno. O maligno é um padrão que corresponde mais \
                amplamente do que julgava, a editar milhares de sítios dentro de um único passo de \
                desfazer.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "Scripts de JavaScript",
        summary: "Quatro funções, um ficheiro `.js`, e tudo o que faz é um passo de desfazer.",
        keywords: ["script", "javascript", "js", "automatizar", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Ponha um ficheiro `.js` na pasta `scripts/` do GEditor e execute-o a partir de `Macro ▸ \
                Script…`. Um script vê exatamente **quatro** coisas:
                """),
            .table(
                headers: ["Chamada", "Significado"],
                rows: [
                    ["`doc.text`", "Todo o texto do documento"],
                    ["`doc.selection`", "A seleção (cadeia vazia quando nada está selecionado)"],
                    ["`doc.replace(s)`", "Substituir o **documento inteiro** por `s` — um passo de desfazer"],
                    ["`doc.log(s)`", "Escrever uma linha no painel de resultados"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Numerar cada linha.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — manter as três primeiras colunas CSV",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Três limites a saber"),
            .bullets([
                "**Sem acesso a ficheiros, sem rede, sem lançar processos.** A superfície da API é deliberadamente estreita: alargá-la depois é fácil, estreitá-la quebra todos os scripts já escritos.",
                "**Isto não é uma fronteira de segurança.** Os scripts correm no mesmo processo. Não execute um script que não tenha lido.",
                "**Há um limite de cinco segundos.** Passado esse ponto recebe uma mensagem e a aplicação continua utilizável — mas o fio desse script **continua a girar até sair**, a comer um núcleo. A mensagem di-lo.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtrar por um comando externo",
        summary: "Passar a seleção por um comando Unix e retomar o resultado.",
        keywords: ["filtro", "comando externo", "shell", "tubo", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                A seleção (ou o documento todo) é entregue ao `stdin` de um comando, e o `stdout` desse \
                comando substitui-a.
                """),
            .code(language: "bash", caption: "Alguns habituais",
                  source: """
                    sort -u                     # ordenar e eliminar duplicados
                    jq .                        # reformatar JSON
                    tr 'a-z' 'A-Z'              # para maiúsculas
                    grep -v '^#'                # retirar as linhas de comentário
                    awk -F, '{print $3","$1}'   # trocar a ordem das colunas
                    """),
            .note("""
                O resultado é **um** passo de desfazer. Se o comando devolver um código de erro, o GEditor \
                deixa o texto em paz e mostra o `stderr`.
                """),
            .warning("""
                Este comando existe **só na versão de transferência direta**. A App Sandbox proíbe executar \
                código fora da aplicação, por isso na versão da App Store o item de menu fica e explica \
                porque não está disponível.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "A ferramenta de linha de comandos `geditor`",
        summary: "Abrir, limpar, consultar, pontuar e desenhar relatórios — sem abrir a aplicação.",
        keywords: ["cli", "linha de comandos", "terminal", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Disponível só na **versão de transferência direta**. A versão da App Store corre numa \
                sandbox, por isso um processo externo de linha de comandos não se consegue ligar a ela.
                """),
            .heading("Abrir ficheiros"),
            .code(language: "bash", caption: "Abrir, saltar para uma posição, ler de um tubo",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # linha 120, coluna 5
                    geditor -w notes.md            # esperar que o ficheiro feche antes de sair
                    geditor -r app.log             # abrir só de leitura
                    git diff | geditor             # ler a entrada padrão para um separador novo
                    """),
            .table(
                headers: ["Opção", "Significado"],
                rows: [
                    ["`-w`, `--wait`", "Esperar que o ficheiro feche antes de sair — para servir de editor do `git`"],
                    ["`-n`, `--new-window`", "Abrir numa janela nova"],
                    ["`-r`, `--read-only`", "Abrir só de leitura"],
                    ["`-i`, `--info`", "Imprimir codificação, fins de linha e número de linhas, e sair — **sem** abrir a aplicação"],
                    ["`-h`, `--help`", "Mostrar a ajuda"],
                    ["`-v`, `--version`", "Mostrar a versão"],
                ]
            ),
            .heading("Correr sem abrir a aplicação"),
            .paragraph("""
                Os quatro grupos de comandos abaixo correm **inteiramente no processo de linha de \
                comandos**, por isso funcionam em CI, onde ninguém iniciou uma sessão gráfica.
                """),
            .code(language: "bash", caption: "Limpar com uma receita",
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
            .code(language: "bash", caption: "O portão de qualidade — código 0 aprovado · 1 reprovado · 2 erro",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Desenhar relatórios",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript e o menu Serviços",
        summary: "Ler e escrever o documento a partir do AppleScript, ou enviar texto para o GEditor a partir de outra aplicação.",
        keywords: ["applescript", "osascript", "serviços", "automatização", "atalhos"],
        blocks: [
            .code(language: "applescript", caption: "Ler o documento aberto",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Sobrescrever o conteúdo e ler a seleção",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Abrir um ficheiro",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("O menu Serviços"),
            .paragraph("""
                Selecione texto em qualquer aplicação e use o menu `Serviços` para o enviar ao GEditor como \
                separador novo.
                """),
            .note("""
                Da primeira vez que executar AppleScript, o macOS pede autorização de automatização. Essa é \
                a caixa do sistema, não do GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Pacotes de extensão e plug-ins",
        summary: "Dois tipos de extensão, e em que versão cada um corre.",
        keywords: ["plug-in", "extensão", "pacote", "nativo"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Pacotes de extensão"),
            .paragraph("""
                Um pacote é **um ficheiro JSON** que junta um tema, scripts e linguagens definidas pelo \
                utilizador. Instalar copia um ficheiro, remover apaga um — e a lista de pacotes é derivada \
                do **disco**, não de um registo que pudesse mentir.
                """),
            .paragraph("Funciona em **ambas as versões**."),
            .heading("Plug-ins nativos"),
            .paragraph("""
                Os plug-ins pré-compilados correm num **processo à parte** com uma superfície de API \
                estreita — um plug-in que rebenta não leva a aplicação com ele.
                """),
            .warning("""
                Os plug-ins nativos existem **só na versão de transferência direta**, porque a App Sandbox \
                proíbe carregar código de fora da aplicação. Cada plug-in tem de ser **aprovado à mão uma \
                vez**, pelo seu hash, antes de correr.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Configuração e a aplicação

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Configuração e a aplicação",
        summary: "Definições, atalhos, temas, atualizações, migrar do Notepad++, resolução de problemas.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Definições",
        summary: "Cada opção vive num ficheiro JSON legível que pode copiar para outro Mac.",
        keywords: ["definições", "preferências", "opções", "configuração", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Abrir as definições")]),
            .paragraph("""
                Não há OK nem Cancelar — uma alteração produz efeito e é escrita de imediato, à maneira do \
                macOS.
                """),
            .heading("O ficheiro de configuração"),
            .code(language: "text", caption: "Onde vive",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                É um **ficheiro JSON indentado que pode ler e editar à mão**. Copie-o para outro Mac e toda \
                a sua configuração vai com ele. O botão `Abrir o ficheiro de configuração` das definições \
                leva-o diretamente lá.
                """),
            .heading("As chaves"),
            .table(
                headers: ["Chave", "Por omissão", "Significado"],
                rows: [
                    ["`fontSize`", "`13`", "Tamanho da letra do editor"],
                    ["`tabWidth`", "`4`", "Quantas colunas de largura tem uma tabulação"],
                    ["`usesTabsForIndent`", "`false`", "Indentar com tabulações em vez de espaços"],
                    ["`languageIndent`", "`{}`", "Indentação por linguagem — veja a página dos espaços"],
                    ["`smartIndent`", "`true`", "Indentação automática numa linha nova"],
                    ["`highlightAllMatches`", "`true`", "Realçar cada ocorrência de procura"],
                    ["`ligatures`", "`false`", "Ligaduras — veja a nota debaixo da tabela"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Cortar espaços finais ao guardar"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalizar Unicode para NFC ao guardar"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Codificação dos ficheiros novos"],
                    ["`defaultEOL`", "`\"lf\"`", "Fins de linha dos ficheiros novos"],
                    ["`language`", "`\"system\"`", "Idioma da interface"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "o tema por omissão", "Que tema de cor está em uso"],
                    ["`showWelcomeOnLaunch`", "`true`", "Abrir a janela de boas-vindas ao arrancar"],
                    ["`keyBindings`", "`{}`", "Só as teclas que você alterou"],
                ]
            ),
            .note("""
                **Porque as ligaduras vêm DESLIGADAS.** Uma ligadura funde `!=` ou `->` num **único** \
                glifo, por isso os caracteres que vê no ecrã deixam de corresponder aos do ficheiro — e o \
                editor de colunas, o modo coluna e a mudança de linha numa coluna medem todos em colunas. \
                Ligue-as para escrever prosa, ou se escolheu uma letra de programação (Fira Code, JetBrains \
                Mono) precisamente pelas ligaduras.
                """),
            .heading("As pastas vizinhas"),
            .table(
                headers: ["Pasta", "Contém"],
                rows: [
                    ["`macros/`", "Macros guardadas, um ficheiro JSON cada"],
                    ["`scripts/`", "Scripts de JavaScript"],
                    ["`themes/`", "Temas de cor"],
                    ["`grammars/`", "Linguagens definidas pelo utilizador"],
                ]
            ),
            .warning("""
                Um ficheiro de configuração escrito por um GEditor **mais recente não é sobrescrito** por um \
                mais antigo — este corre com os valores por omissão e di-lo. Sobrescrever é a forma mais \
                segura de destruir a configuração de quem sincroniza duas máquinas, e nunca saberia porquê.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "A barra de estado",
        summary: "Dez segmentos em baixo — todos legíveis e todos clicáveis.",
        keywords: ["barra de estado", "posição", "codificação", "só de leitura", "tamanho"],
        blocks: [
            .paragraph("""
                Esta é a maior diferença face às barras de estado de outros editores: **nenhum segmento é só \
                de leitura**. Se vir um valor errado, carregar nele é a forma de o corrigir, em vez de \
                revirar os menus.
                """),
            .table(
                headers: ["Segmento", "Diz-lhe", "Ao carregar"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "posição do cursor — coluna em CARACTERES, `@340` a posição em bytes",
                     "abre o campo `Ir para`"],
                    ["`11 byte · 3 dòng`", "tamanho do documento",
                     "conta bytes · caracteres · palavras · linhas"],
                    ["`🔒 Chỉ đọc`", "mostrado só quando o documento está bloqueado",
                     "diz PORQUE está bloqueado, e desbloqueia quando é possível"],
                    ["`View` / `Code`", "em que vista está", "alterna (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "modo CSV e separador em uso",
                     "comuta o modo CSV, ou **volta a escolher o separador**"],
                    ["`Đang theo dõi`", "`tail -f` está em curso", "—"],
                    ["`UTF-8`", "a codificação", "reinterpretar, ou converter para outra codificação"],
                    ["`LF`", "estilo de fim de linha", "alternar LF · CRLF · CR"],
                    ["`Python`", "linguagem da coloração de sintaxe", "escolher outra, ou voltar à deteção por extensão"],
                    ["`Tab: 4`", "largura da indentação", "2 · 4 · 8, global ou **só para esta linguagem**"],
                    ["`Ngắt: tắt`", "modo de mudança de linha", "percorre os três modos"],
                ]
            ),
            .heading("Três segmentos que merecem segundo olhar"),
            .bullets([
                "**`@340` — a posição em bytes.** É o número que qualquer outra ferramenta do produto fala: os erros de JSON e XML, a saída de `--doc-sweep`, o visualizador binário e o campo `Ir para @340`. Leia-o aqui, escreva-o ali.",
                "**Um `~` na coluna** significa que o número conta BYTES e não colunas visuais — só acontece em linhas com mais de 200 KB, onde contar caracteres tornaria lento cada movimento do cursor.",
                "**`CSV · …` é clicável para voltar a escolher o separador.** A deteção pode falhar, e quando falha toda a operação de colunas fica desalinhada sem nada que o assinale. É assim que diz o contrário — apenas VOLTA A LER o ficheiro, sem mudar um byte (ao contrário de `CSV ▸ Mudar separador…`, que o reescreve).",
            ]),
            .note("""
                Um segmento que não se aplica ao ficheiro aberto está **escondido**, não esbatido: `Só de \
                leitura` só aparece quando o documento está mesmo bloqueado, e `CSV · …` só em modo CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Mudar os atalhos de teclado",
        summary: "Mudar teclas soltas, ou adotar de uma vez o mapa do Notepad++.",
        keywords: ["atalho", "mapa de teclas", "predefinição"],
        blocks: [
            .paragraph("""
                As `Definições…` têm uma secção de Atalhos com dois botões rápidos: **Usar a predefinição do \
                Notepad++** e **Voltar aos valores por omissão**.
                """),
            .paragraph("""
                O ficheiro de configuração regista só o que você **mudou face aos valores por omissão**. \
                Assim, quando o GEditor mudar uma tecla por omissão numa versão nova, não fica preso ao mapa \
                antigo sem que ninguém lho diga.
                """),
            .note("""
                Dois comandos não podem partilhar um atalho. Quando partilham, o AppKit dispara em silêncio \
                só o **primeiro** item de menu e o outro comando parece avariado — por isso o GEditor tem uma \
                verificação que o impede.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Temas, claro e escuro",
        summary: "Seguir o sistema, claro ou escuro; e um tema é um ficheiro JSON que pode editar.",
        keywords: ["tema", "cores", "modo escuro", "claro", "aspeto"],
        blocks: [
            .paragraph("As `Definições…` escolhem `Seguir o sistema`, `Claro` ou `Escuro`, e selecionam um tema de cor."),
            .paragraph("""
                Um tema é um ficheiro JSON em `themes/`. O botão `Exportar o tema atual` escreve um como \
                ponto de partida para o seu.
                """),
            .note("""
                Uma cor mal escrita num ficheiro de tema recai na cor do **tema por omissão**, não no preto. \
                O preto parece uma decisão de design, e o utilizador iria procurar o problema noutro sítio.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Atualizações, versões e sair",
        summary: "Em que difere a atualização entre as duas versões.",
        keywords: ["atualização", "versão", "acerca", "sair"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Versão", "Atualiza-se por"],
                rows: [
                    ["App Store", "A App Store, como qualquer outra app"],
                    ["Transferência direta", "`Procurar atualizações…` dentro da aplicação"],
                ]
            ),
            .paragraph("""
                `Acerca do GEditor` mostra a versão em curso e de que versão se trata — útil ao comunicar um \
                problema.
                """),
            .note("""
                Na versão da App Store, `Procurar atualizações…` **fica no menu** e explica porque não se \
                aplica, em vez de desaparecer. Um item de menu em falta torna-se um pedido ao suporte.
                """),
            .paragraph("Sair não perde trabalho: a sessão volta na próxima vez que abrir."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Usar esta janela de ajuda",
        summary: "Procurar no livro, mudar o seu idioma e trazer de volta a janela de boas-vindas.",
        keywords: ["ajuda", "guia", "procura", "boas-vindas", "idioma"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Abrir a janela de ajuda")]),
            .bullets([
                "O campo de procura no canto superior esquerdo olha para dentro do **texto e dos exemplos de código** — escrever uma chave de configuração como `fail_under` leva à página certa.",
                "Escrever **sem acentos** encontra na mesma texto acentuado.",
                "O botão `Voltar` regressa à página anterior.",
                "O botão `Copiar` de cada bloco de código copia esse bloco.",
            ]),
            .heading("Ler noutro idioma"),
            .paragraph("""
                O menu no canto superior direito desta janela escolhe o **idioma do livro**, independente do \
                idioma da interface. A mudança mantém-no **na página que está a ler** — os identificadores de \
                página não são traduzidos de propósito, justamente para isto funcionar.
                """),
            .note("""
                Só são listados os idiomas que têm mesmo livro. Um item de menu que muda para algo e deixa o \
                texto na mesma seria um item de menu que mente.
                """),
            .heading("Trazer de volta a janela de boas-vindas"),
            .paragraph("""
                Se marcou **Não abrir esta janela ao arrancar**, volte a abri-la com `Ajuda ▸ Passeio pelas \
                funcionalidades` — a caixa ao fundo da janela reaparece e pode ser desmarcada.
                """),
            .paragraph("Ou volte a pôr `showWelcomeOnLaunch` a `true` em `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Do Notepad++ para o GEditor",
        summary: "Que teclas trocam de lugar, o que funciona de forma diferente e o que falta.",
        keywords: ["notepad++", "migração", "windows", "atalhos"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Algumas teclas **trocam de lugar** no macOS em vez de simplesmente transformar `Ctrl` em \
                `⌘`. Aqui está a comparação.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Porquê"],
                rows: [
                    ["`Ctrl+D` Duplicar linha", "**⇧⌘D**", "Aqui `⌘D` é o multicursor, como em todos os editores de Mac"],
                    ["`Ctrl+L` Apagar linha", "**⌘K**", "No macOS `⌘L` significa «ir para a linha»"],
                    ["`Ctrl+G` Ir para a linha", "**⌘L**", "Estes dois trocam de lugar"],
                    ["`Ctrl+Q` Comentar", "**⌘/**", "Convenção do macOS"],
                    ["`Ctrl+Shift+↑/↓` Mover linha", "**⌥↑ / ⌥↓**", "No macOS o `⌃` pertence ao Mission Control"],
                    ["`F3` Procurar seguinte", "**⌘G**", "Convenção do macOS"],
                    ["`Ctrl+F2` Alternar marcador", "**⌘F2**", "F2 e ⇧F2 continuam a saltar entre marcas"],
                    ["`Alt` + arrastar para colunas", "**⌥ + arrastar**", "Idêntico"],
                    ["`Ctrl+Alt+Shift+↓` Editor de colunas", "**⌥⌘C**", "Convenção do macOS"],
                ]
            ),
            .note("Prefere não reaprender? `Definições ▸ Atalhos ▸ Usar a predefinição do Notepad++`."),
            .heading("Coisas que o Notepad++ tem e aqui funcionam de forma diferente"),
            .bullets([
                "**As sessões** restauram-se sozinhas, incluindo separadores por guardar — nada a ligar.",
                "**Os marcadores têm nove cores**, e uma linha pode levar vários ao mesmo tempo.",
                "**O mapa do documento** descreve o ficheiro *todo*, não só a parte visível.",
                "**As macros** podem correr «até ao fim do documento» e «em todos os separadores», e uma execução inteira é um passo de desfazer.",
            ]),
            .heading("O que o GEditor acrescenta"),
            .bullets([
                "Uma **bancada de limpeza de dados** e **perfis de dados** para ficheiros CSV.",
                "**Consultas SQL** diretamente sobre um ficheiro CSV.",
                "**Codificações vietnamitas antigas** — TCVN3, VISCII, VNI-Windows, lidas, escritas e detetadas automaticamente.",
                "**Procura insensível a acentos** em cada campo de filtro.",
                "**Relatórios `.greport.md`** com tabelas e gráficos que são recalculados.",
                "A **ferramenta de linha de comandos `geditor`** na versão de transferência direta.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Problemas comuns",
        summary: "Seis situações que fazem pensar que a aplicação está avariada.",
        keywords: ["erro", "problema", "não funciona", "resolver", "porquê"],
        blocks: [
            .table(
                headers: ["Sintoma", "Causa habitual"],
                rows: [
                    ["O texto vietnamita aparece como lixo", "Codificação errada — carregue na codificação na barra de estado"],
                    ["Procurar texto acentuado não encontra nada", "O ficheiro está em Unicode decomposto — corra `Normalizar Unicode` para NFC"],
                    ["Um item de menu está esbatido", "A versão da App Store não pode executar esse comando — o item explica porquê"],
                    ["O emparelhamento de parênteses recusa", "O documento passa de 1 MB — realçar o par errado é pior do que nenhum"],
                    ["A coluna na barra de estado tem um `~`", "O documento passa de 200 KB, por isso é uma contagem de bytes e não uma coluna visual"],
                    ["Uma consulta SQL diz que é preciso guardar primeiro", "O DuckDB lê **ficheiros**, não o buffer que está a editar"],
                ]
            ),
            .heading("Quando o GEditor termina inesperadamente"),
            .paragraph("""
                No arranque seguinte um aviso di-lo, com um botão **Abrir relatório** — o relatório abre como \
                separador que pode ler e de onde pode copiar como de qualquer ficheiro de texto.
                """),
            .bullets([
                "O relatório leva só a **versão, a versão do macOS, a arquitetura da máquina, o nome do sinal e a pilha de chamadas**.",
                "**Nenhum conteúdo do documento, e também nenhum caminho de ficheiro** — um caminho como `~/Secretária/salarios-dezembro.xlsx` já revelou três coisas privadas antes de alguém o abrir.",
                "**Nada é enviado para lado nenhum.** Não há envio automático nem servidor que o receba; o ficheiro fica em `~/Library/Application Support/GEditor/crash/` até que o abra ou o apague.",
                "Depois de ter aberto o relatório, o arranque seguinte não volta a mencioná-lo.",
            ]),
            .heading("Onde olhar a seguir"),
            .bullets([
                "A barra de estado mostra codificação, fins de linha, linguagem e modo de mudança de linha — cada segmento é clicável.",
                "O `settings.json` pode ser editado à mão quando a janela de definições não chega.",
                "`Acerca do GEditor` dá a versão e a variante, de que um relatório de erro precisa.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
